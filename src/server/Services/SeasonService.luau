--!strict

-- Temporadas (Config/LiveOps). Mientras hay una activa, las acciones del jugador suman
-- puntos de temporada y hacen avanzar sus misiones; al llegar a los puntos de cada escalón
-- se entrega su recompensa, una sola vez. El progreso se guarda con el id de la temporada:
-- si el jugador entra con una temporada distinta de la que tiene guardada, empieza de cero.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementService = require(script.Parent.AchievementService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local LiveOpsService = require(script.Parent.LiveOpsService)

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local LiveOps = require(Shared.Config.LiveOps)
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local ShopConfig = require(Shared.Config.Shop)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)

local SeasonService = {}

local ackLimiter = RateLimiter.new(Network.RateLimits.AckVersion)

local function getSeason(): LiveOps.Season?
    if not LiveOpsService.IsEnabled("seasons") then
        return nil
    end
    return LiveOps.GetSeason(os.time())
end

-- Deja el progreso guardado en la temporada actual: si es de otra, empieza de cero.
local function ensureSeason(player: Player, data: Types.Profile): LiveOps.Season?
    local season = getSeason()
    if season and data.season.id ~= season.id then
        DataService.Set(player, "season", {
            id = season.id,
            points = 0,
            progress = {},
            done = {},
            claimed = {},
        })
    end
    return season
end

local function grantTier(player: Player, season: LiveOps.Season, index: number, tier: LiveOps.Tier)
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    -- Se marca antes de entregar: las monedas cambian estadísticas y pueden volver aquí.
    DataService.Update(player, "season", function(progress: Types.SeasonData)
        progress.claimed[tostring(index)] = true
        return progress
    end)

    local reward = ""
    if tier.coinsFraction then
        local coins = PlayerStats.GetSeasonCoins(data, tier.coinsFraction)
        IncomeService.AddCoins(player, coins, "season")
        reward = string.format(Strings.Season.RewardCoins, Format.Number(coins))
    elseif tier.shards then
        DataService.Increment(player, "shards", tier.shards)
        reward = string.format(Strings.Season.RewardShards, tier.shards)
    elseif tier.cosmetic then
        local cosmetic = ShopConfig.CosmeticsByKey[tier.cosmetic]
        if cosmetic and cosmetic.season == season.id then
            DataService.Update(player, "cosmetics", function(cosmetics: Types.CosmeticsData)
                if not table.find(cosmetics.owned, cosmetic.key) then
                    table.insert(cosmetics.owned, cosmetic.key)
                end
                return cosmetics
            end)
            reward = Strings.Shop.Names[cosmetic.key] or cosmetic.key
        end
    end
    Remotes.Notify:FireClient(player, string.format(Strings.Season.TierUnlocked, index, reward))
end

local function checkTiers(player: Player, season: LiveOps.Season)
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    for index, tier in season.tiers do
        if data.season.points >= tier.points and not data.season.claimed[tostring(index)] then
            grantTier(player, season, index, tier)
        end
    end
end

local function onStat(player: Player, stat: string, amount: number)
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    local season = ensureSeason(player, data)
    if season == nil then
        return
    end

    local points = (season.pointSources[stat] or 0) * amount
    local relevant = points > 0
    for _, mission in season.missions do
        if mission.stat == stat and not data.season.done[mission.id] then
            relevant = true
        end
    end
    if not relevant then
        return
    end

    local completed: { LiveOps.Mission } = {}
    DataService.Update(player, "season", function(progress: Types.SeasonData)
        for _, mission in season.missions do
            if mission.stat == stat and not progress.done[mission.id] then
                local value = math.min((progress.progress[mission.id] or 0) + amount, mission.goal)
                progress.progress[mission.id] = value
                if value >= mission.goal then
                    progress.done[mission.id] = true
                    points += mission.points
                    table.insert(completed, mission)
                end
            end
        end
        progress.points += points
        return progress
    end)
    for _, mission in completed do
        Remotes.Notify:FireClient(
            player,
            string.format(
                Strings.Season.MissionDone,
                string.format(mission.text, Format.Number(mission.goal)),
                mission.points
            )
        )
    end
    if points > 0 then
        checkTiers(player, season)
    end
end

-- El cliente avisa de que ya ha mostrado las notas de la versión actual.
local function onAckVersion(player: Player)
    if not ackLimiter.Check(player) then
        return
    end
    local data = DataService.GetData(player)
    if data and data.seenVersion ~= LiveOps.Version then
        DataService.Set(player, "seenVersion", LiveOps.Version)
    end
end

function SeasonService.Init()
    Remotes.AckVersion.OnServerEvent:Connect(onAckVersion)
    AchievementService.OnStat(onStat)
    DataService.OnProfileLoaded(function(player: Player, data: Types.Profile)
        local season = ensureSeason(player, data)
        if season then
            checkTiers(player, season)
        end
    end)
end

function SeasonService.Start()
    -- Si la temporada cambia con el servidor en marcha, se pasa a todos a la nueva.
    task.spawn(function()
        while true do
            task.wait(LiveOps.FeaturePollSeconds)
            for _, player in Players:GetPlayers() do
                local data = DataService.GetData(player)
                if data then
                    ensureSeason(player, data)
                end
            end
        end
    end)
end

return SeasonService
