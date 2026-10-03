--!strict

-- Minado de meteoritos. El cliente solo avisa de que empieza o deja de minar;
-- el servidor comprueba la distancia, lleva el temporizador y tira el mineral y la mutación.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)
local MeteorService = require(script.Parent.MeteorService)
local TutorialService = require(script.Parent.TutorialService)

local Shared = ReplicatedStorage.Shared
local MeteorsConfig = require(Shared.Config.Meteors)
local Minerals = require(Shared.Config.Minerals)
local Mutations = require(Shared.Config.Mutations)
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local WeightedRandom = require(Shared.Util.WeightedRandom)

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

local function stopMining(player: Player)
    if miners[player] == nil then
        return
    end
    miners[player] = nil
    Remotes.MineState:FireClient(player, "stop")
end

local function notifyBackpackFull(player: Player)
    local capacity = CarryService.GetCapacity(player)
    Remotes.Notify:FireClient(
        player,
        string.format(Strings.Mining.BackpackFull, CarryService.GetCount(player), capacity)
    )
end

local function beginCycle(player: Player, meteorId: number, data: Types.Profile)
    local duration = PlayerStats.GetMineTime(data)
    miners[player] = { meteorId = meteorId, startedAt = os.clock(), duration = duration }
    Remotes.MineState:FireClient(player, "start", meteorId, duration)
end

local function rollMineral(meteorTypeId: string, data: Types.Profile): Minerals.Mineral
    local meteorType = MeteorsConfig.Types[meteorTypeId]
    local rareMultiplier = meteorType.rareWeightMultiplier
        * PlayerStats.GetLuckMultiplier(data, os.time())

    local mineral = WeightedRandom.Pick(Minerals.List, function(candidate: Minerals.Mineral): number
        if Minerals.Rarities[candidate.rarity].rank >= Minerals.RareRank then
            return candidate.weight * rareMultiplier
        end
        return candidate.weight
    end, rng)
    return mineral or Minerals.List[1]
end

local function rollMutation(meteorTypeId: string): Mutations.Mutation
    local multiplier = MeteorsConfig.Types[meteorTypeId].mutationMultiplier
    local mutation = WeightedRandom.Pick(
        Mutations.List,
        function(candidate: Mutations.Mutation): number
            if candidate.id == Mutations.NoneId then
                return candidate.chance
            end
            return candidate.chance * multiplier
        end,
        rng
    )
    return mutation or Mutations.ById[Mutations.NoneId]
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

    local mineral = rollMineral(meteorTypeId, data)
    local mutation = rollMutation(meteorTypeId)
    local item: Types.InventoryItem = {
        id = HttpService:GenerateGUID(false),
        mineral = mineral.id,
        mutation = mutation.id,
    }
    CarryService.Add(player, item)
    IndexService.Register(player, mineral.id, mutation.id)
    TutorialService.Advance(player, 1)

    -- El cliente muestra el mineral obtenido como un texto flotante sobre el meteorito.
    Remotes.MineReward:FireClient(player, meteorPosition, meteorRadius, mineral.id, mutation.id)
    local name = Strings.MineralName(mineral.id, mutation.id)
    if Minerals.GetRank(mineral.id) >= Minerals.AnnounceRank then
        Remotes.Notify:FireAllClients(
            string.format(Strings.Mining.Announce, player.DisplayName, name)
        )
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
