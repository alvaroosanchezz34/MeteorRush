--!strict

-- Robo: golpear a quien transporta minerales le hace soltar la mitad en el suelo.
-- El servidor valida distancia, enfriamiento, inmunidad, zona segura, escudo y protección de novato.
-- Los minerales de los pedestales y del inventario de la base nunca se pueden robar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)
local PlotService = require(script.Parent.PlotService)

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Util.Assets)
local MineralVisual = require(Shared.Util.MineralVisual)
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local StealConfig = require(Shared.Config.Steal)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)

local DROP_SIZE = 1.2

type Drop = {
    item: Types.InventoryItem,
    instance: Instance,
    position: Vector3,
    pickableAt: number,
    expiresAt: number,
}

local StealService = {}

local rng = Random.new()
local limiter = RateLimiter.new(Network.RateLimits.HitPlayer)
local lastHitAt: { [Player]: number } = {}
local immuneUntil: { [Player]: number } = {}
local drops: { Drop } = {}
local dropFolder: Folder? = nil

local function getRoot(player: Player): BasePart?
    local character = player.Character
    if character == nil then
        return nil
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
        return nil
    end
    return root
end

local function isNewbie(player: Player): boolean
    return DataService.GetPlaytime(player) < StealConfig.NewbieProtectionSeconds
end

local function findGround(position: Vector3): Vector3
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local excluded: { Instance } = {}
    for _, player in Players:GetPlayers() do
        if player.Character then
            table.insert(excluded, player.Character)
        end
    end
    if dropFolder then
        table.insert(excluded, dropFolder)
    end
    params.FilterDescendantsInstances = excluded
    local result =
        Workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -50, 0), params)
    return if result then result.Position else position
end

local function spawnDrops(items: { Types.InventoryItem }, origin: Vector3)
    local now = os.clock()
    for _, item in items do
        local angle = rng:NextNumber() * math.pi * 2
        local distance = rng:NextNumber(2, StealConfig.DropScatterRadius)
        local ground =
            findGround(origin + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance)
        local position = ground + Vector3.new(0, DROP_SIZE / 2 + 0.2, 0)

        local visual = MineralVisual.Create(item.mineral, item.mutation, DROP_SIZE)
        Assets.PlaceAt(visual, CFrame.new(position))
        visual.Parent = dropFolder

        table.insert(drops, {
            item = item,
            instance = visual,
            position = position,
            pickableAt = now + StealConfig.DropPickupDelay,
            expiresAt = now + StealConfig.DropLifetime,
        })
    end
end

local function showImmunity(player: Player)
    local character = player.Character
    if character == nil then
        return
    end
    local forceField = Instance.new("ForceField")
    forceField.Visible = true
    forceField.Parent = character
    task.delay(StealConfig.VictimImmunity, function()
        forceField:Destroy()
    end)
end

local function onHitPlayer(attacker: Player, target: unknown)
    if not limiter.Check(attacker) then
        return
    end
    if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Player") then
        return
    end
    local victim = target :: Player
    if victim == attacker or victim.Parent ~= Players then
        return
    end

    local now = os.clock()
    if now - (lastHitAt[attacker] or -math.huge) < StealConfig.AttackerCooldown then
        return
    end
    local attackerRoot = getRoot(attacker)
    local victimRoot = getRoot(victim)
    local victimData = DataService.GetData(victim)
    if attackerRoot == nil or victimRoot == nil or victimData == nil then
        return
    end
    local distance = (attackerRoot.Position - victimRoot.Position).Magnitude
    if distance > StealConfig.HitRange + StealConfig.HitRangeTolerance then
        return
    end

    local function reject(message: string)
        Remotes.Notify:FireClient(attacker, message)
    end
    if isNewbie(attacker) or isNewbie(victim) then
        return reject(Strings.Steal.Newbie)
    end
    if CarryService.GetCount(victim) == 0 then
        return reject(Strings.Steal.NothingToSteal)
    end
    if PlotService.IsInOwnPlot(victim, victimRoot.Position) then
        return reject(Strings.Steal.TargetSafe)
    end
    if now < (immuneUntil[victim] or 0) then
        return reject(Strings.Steal.TargetImmune)
    end
    if PlayerStats.IsBoostActive(victimData, "carryShield", os.time()) then
        return reject(Strings.Steal.TargetShielded)
    end

    lastHitAt[attacker] = now
    immuneUntil[victim] = now + StealConfig.VictimImmunity

    local dropCount =
        math.ceil(CarryService.GetCount(victim) * PlayerStats.GetDropFraction(victimData))
    local dropped = CarryService.RemoveRandom(victim, dropCount)
    spawnDrops(dropped, victimRoot.Position)
    showImmunity(victim)

    Remotes.Notify:FireClient(attacker, string.format(Strings.Steal.YouHit, victim.DisplayName))
    Remotes.Notify:FireClient(
        victim,
        string.format(Strings.Steal.YouWereHit, attacker.DisplayName, #dropped)
    )
end

local function updateDrops()
    local now = os.clock()
    local unixNow = os.time()
    for index = #drops, 1, -1 do
        local drop = drops[index]
        local taken = false
        if now >= drop.expiresAt then
            taken = true
        elseif now >= drop.pickableAt then
            for _, player in Players:GetPlayers() do
                local root = getRoot(player)
                local data = DataService.GetData(player)
                if root and data and CarryService.HasRoom(player) then
                    local radius = if PlayerStats.IsBoostActive(data, "magnet", unixNow)
                        then StealConfig.MagnetPickupRadius
                        else StealConfig.PickupRadius
                    if (root.Position - drop.position).Magnitude <= radius then
                        CarryService.Add(player, drop.item)
                        IndexService.Register(player, drop.item.mineral, drop.item.mutation)
                        taken = true
                        break
                    end
                end
            end
        end
        if taken then
            drop.instance:Destroy()
            table.remove(drops, index)
        end
    end
end

function StealService.Init()
    local folder = Instance.new("Folder")
    folder.Name = "Drops"
    folder.Parent = Workspace
    dropFolder = folder

    Remotes.HitPlayer.OnServerEvent:Connect(onHitPlayer)
end

function StealService.Start()
    Players.PlayerRemoving:Connect(function(player: Player)
        lastHitAt[player] = nil
        immuneUntil[player] = nil
    end)
    task.spawn(function()
        while true do
            task.wait(StealConfig.PickupCheckInterval)
            updateDrops()
        end
    end)
end

return StealService
