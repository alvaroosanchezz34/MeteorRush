--!strict

-- Minado de meteoritos. El cliente solo avisa de que empieza o deja de minar;
-- el servidor comprueba la distancia, lleva el temporizador y tira el mineral y la mutación.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarryService = require(script.Parent.CarryService)
local AchievementService = require(script.Parent.AchievementService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local EquipmentService = require(script.Parent.EquipmentService)
local EventService = require(script.Parent.EventService)
local IndexService = require(script.Parent.IndexService)
local MeteorService = require(script.Parent.MeteorService)
local MomentService = require(script.Parent.MomentService)
local QuestService = require(script.Parent.QuestService)
local TutorialService = require(script.Parent.TutorialService)

local Shared = ReplicatedStorage.Shared
local Equipment = require(Shared.Config.Equipment)
local Log = require(Shared.Util.Log)
local Loot = require(Shared.Util.Loot)
local MeteorsConfig = require(Shared.Config.Meteors)
local Minerals = require(Shared.Config.Minerals)
local MomentsConfig = require(Shared.Config.Moments)
local Mutations = require(Shared.Config.Mutations)
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)

type MiningState = {
    meteorId: number,
    startedAt: number,
    duration: number,
}

local MiningService = {}

local rng = Random.new()
local miners: { [Player]: MiningState } = {}
local startLimiter = RateLimiter.new(Network.RateLimits.MineStart)
local stopLimiter = RateLimiter.new(Network.RateLimits.MineStop)

local function getRootPosition(player: Player): Vector3?
    local character = player.Character
    if character == nil then
        return nil
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
        return nil
    end
    return root.Position
end

local function isInRange(player: Player, meteor: MeteorService.Meteor): boolean
    local position = getRootPosition(player)
    if position == nil then
        return false
    end
    local surfaceDistance = (position - meteor.position).Magnitude - meteor.radius
    return surfaceDistance <= MeteorsConfig.MineRange + MeteorsConfig.MineRangeTolerance
end

-- Marca el personaje para que los clientes animen el brazo (SwingController).
local function setMiningFlag(player: Player, mining: boolean)
    local character = player.Character
    if character then
        character:SetAttribute("Mining", if mining then true else nil)
    end
end

local function stopMining(player: Player)
    if miners[player] == nil then
        return
    end
    miners[player] = nil
    setMiningFlag(player, false)
    Remotes.MineState:FireClient(player, "stop")
end

local function notifyBackpackFull(player: Player)
    local capacity = CarryService.GetCapacity(player)
    Remotes.Notify:FireClient(
        player,
        Locale.Msg("Mining.BackpackFull", CarryService.GetCount(player), capacity)
    )
end

local function beginCycle(player: Player, meteorId: number, data: Types.Profile)
    local meteor = MeteorService.GetMeteor(meteorId)
    local meteorType = if meteor then MeteorsConfig.Types[meteor.typeId] else nil
    local duration = PlayerStats.GetMineTime(data)
        * (if meteorType then meteorType.mineTimeMultiplier or 1 else 1)
    miners[player] = { meteorId = meteorId, startedAt = os.clock(), duration = duration }
    setMiningFlag(player, true)
    Remotes.MineState:FireClient(player, "start", meteorId, duration)
end

local function rollMineral(meteorTypeId: string, data: Types.Profile): Minerals.Mineral
    local rareMultiplier = MeteorsConfig.Types[meteorTypeId].rareWeightMultiplier
        * PlayerStats.GetLuckMultiplier(data, os.time())
        * EventService.GetRareMultiplier()
    return Loot.RollMineral(rareMultiplier, rng)
end

local function rollMutation(meteorTypeId: string, data: Types.Profile): Mutations.Mutation
    local multiplier = MeteorsConfig.Types[meteorTypeId].mutationMultiplier
        * PlayerStats.GetMutationMultiplier(data)
        * EventService.GetMutationMultiplier()
    local mutation = Loot.RollMutation(multiplier, rng)

    -- Meteoritos con mutación mínima (el Dorado): si sale una peor, se sube a la mínima.
    local minimum = Mutations.ById[MeteorsConfig.Types[meteorTypeId].minMutation or ""]
    if
        minimum
        and (table.find(Mutations.List, mutation) or 0)
            < (table.find(Mutations.List, minimum) or 0)
    then
        return minimum
    end
    return mutation
end

-- Tira un mineral con su mutación, lo mete en la mochila y avisa.
local function grantMineral(
    player: Player,
    data: Types.Profile,
    meteorTypeId: string,
    meteorPosition: Vector3,
    meteorRadius: number
)
    local mineral = rollMineral(meteorTypeId, data)
    local mutation = rollMutation(meteorTypeId, data)
    local item: Types.InventoryItem = {
        id = HttpService:GenerateGUID(false),
        mineral = mineral.id,
        mutation = mutation.id,
    }
    CarryService.Add(player, item)
    IndexService.Register(player, mineral.id, mutation.id)
    EconomyService.RecordMined(player, mineral.id, mutation.id)
    QuestService.Progress(player, "mine", 1)
    local isRare = Minerals.GetRank(mineral.id) >= Minerals.RareRank
    if isRare then
        QuestService.Progress(player, "rare", 1)
    end
    AchievementService.AddStats(player, {
        mined = 1,
        rareMined = if isRare then 1 else 0,
        mutatedMined = if mutation.id ~= Mutations.NoneId then 1 else 0,
        rainbowMined = if mutation == Mutations.List[#Mutations.List] then 1 else 0,
        topMined = if mineral == Minerals.List[#Minerals.List] then 1 else 0,
        radioactiveMined = if mutation.id == "radioactive" then 1 else 0,
        specialMined = if MeteorsConfig.Types[meteorTypeId].special then 1 else 0,
        giantMined = if meteorTypeId == "giant" then 1 else 0,
    })

    -- El cliente muestra el mineral obtenido como un texto flotante sobre el meteorito.
    Remotes.MineReward:FireClient(player, meteorPosition, meteorRadius, mineral.id, mutation.id)
    -- Las mutaciones más raras las ve todo el servidor (MutationFxController).
    if mutation.announce then
        Remotes.MutationFound:FireAllClients(
            player,
            meteorPosition + Vector3.new(0, meteorRadius + 2, 0),
            mutation.id
        )
    end
    -- Lo más raro se anuncia a todo el servidor como momento legendario; si no toca (o está
    -- en espera), queda el aviso de texto de siempre.
    local isMoment = MomentsConfig.IsDiscovery(mineral.id, mutation.id)
        and MomentService.Announce(player, "discovery", mineral.id, mutation.id)
    if
        not isMoment
        and (Minerals.GetRank(mineral.id) >= Minerals.AnnounceRank or mutation.announce)
    then
        Remotes.Notify:FireAllClients(
            Locale.Msg(
                "Mining.Announce",
                player.DisplayName,
                Locale.Mineral(mineral.id, mutation.id)
            )
        )
    end
end

local function completeHit(player: Player, state: MiningState)
    local data = DataService.GetData(player)
    local meteor = MeteorService.GetMeteor(state.meteorId)
    if data == nil or meteor == nil then
        stopMining(player)
        return
    end
    if not CarryService.HasRoom(player) then
        notifyBackpackFull(player)
        stopMining(player)
        return
    end
    -- Se guarda el tipo antes de gastar el golpe: el último golpe elimina el meteorito.
    local meteorTypeId = meteor.typeId
    local meteorPosition, meteorRadius = meteor.position, meteor.radius
    if not MeteorService.ConsumeHit(state.meteorId) then
        stopMining(player)
        return
    end

    grantMineral(player, data, meteorTypeId, meteorPosition, meteorRadius)
    TutorialService.Advance(player, 1)
    -- Mejora "fortune": a veces el mismo golpe da un segundo mineral, si cabe en la mochila.
    if
        CarryService.HasRoom(player)
        and rng:NextNumber() < PlayerStats.GetExtraMineralChance(data)
    then
        grantMineral(player, data, meteorTypeId, meteorPosition, meteorRadius)
        AchievementService.AddStat(player, "doubleMinerals", 1)
    end
    -- Pico equipado: golpe crítico (un mineral más, si cabe) y Forge Dust.
    local critChance = Equipment.GetStat(data, "pickaxe", "crit")
    if critChance > 0 and CarryService.HasRoom(player) and rng:NextNumber() < critChance then
        grantMineral(player, data, meteorTypeId, meteorPosition, meteorRadius)
        AchievementService.AddStat(player, "criticalHits", 1)
        Remotes.MineBonus:FireClient(player, "crit", meteorPosition, meteorRadius, 0)
    end
    local fragmentChance = Equipment.GetStat(data, "pickaxe", "fragment")
    if fragmentChance > 0 and rng:NextNumber() < fragmentChance then
        EquipmentService.AddDust(player, Equipment.FragmentDust)
        Remotes.MineBonus:FireClient(
            player,
            "dust",
            meteorPosition,
            meteorRadius,
            Equipment.FragmentDust
        )
    end
    -- Meteoritos que dan más de un mineral por golpe (el Alienígena), mientras quepan.
    for _ = 2, MeteorsConfig.Types[meteorTypeId].mineralsPerHit or 1 do
        if CarryService.HasRoom(player) then
            grantMineral(player, data, meteorTypeId, meteorPosition, meteorRadius)
        end
    end

    if MeteorService.GetMeteor(state.meteorId) == nil then
        stopMining(player)
    elseif not CarryService.HasRoom(player) then
        notifyBackpackFull(player)
        stopMining(player)
    else
        beginCycle(player, state.meteorId, data)
    end
end

local function onMineStart(player: Player, meteorId: unknown)
    if not startLimiter.Check(player) then
        return
    end
    if type(meteorId) ~= "number" or meteorId ~= meteorId then
        Log.Suspicious(player, "MineStart", "tipo inválido")
        return
    end
    local data = DataService.GetData(player)
    local meteor = MeteorService.GetMeteor(meteorId)
    if data == nil or meteor == nil or not isInRange(player, meteor) then
        return
    end
    local current = miners[player]
    if current and current.meteorId == meteorId then
        return
    end
    if not CarryService.HasRoom(player) then
        notifyBackpackFull(player)
        return
    end
    beginCycle(player, meteorId, data)
end

local function onMineStop(player: Player)
    if not stopLimiter.Check(player) then
        return
    end
    stopMining(player)
end

local function update()
    local now = os.clock()
    for player, state in miners do
        local meteor = MeteorService.GetMeteor(state.meteorId)
        if meteor == nil or not isInRange(player, meteor) then
            stopMining(player)
        elseif now - state.startedAt >= state.duration then
            completeHit(player, state)
        end
    end
end

function MiningService.Init()
    Remotes.MineStart.OnServerEvent:Connect(onMineStart)
    Remotes.MineStop.OnServerEvent:Connect(onMineStop)
end

function MiningService.Start()
    RunService.Heartbeat:Connect(update)
    Players.PlayerRemoving:Connect(function(player: Player)
        miners[player] = nil
    end)
end

return MiningService
