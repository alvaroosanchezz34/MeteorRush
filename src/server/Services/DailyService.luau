--!strict

-- Racha diaria: un cobro cada 24 h; si pasan más de 48 h, la racha vuelve al día 1.
-- Tras el día 7 vuelve a empezar por el día 1.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local IndexService = require(script.Parent.IndexService)

local Shared = ReplicatedStorage.Shared
local DailyConfig = require(Shared.Config.Daily)
local Network = require(Shared.Config.Network)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)

local DailyService = {}

local limiter = RateLimiter.new(Network.RateLimits.ClaimDaily)

local function onClaimDaily(player: Player)
    if not limiter.Check(player) then
        return
    end
    local data = DataService.GetData(player)
    if data == nil then
        return
    end

    local now = os.time()
    local waited = now - data.daily.lastClaim
    if data.daily.lastClaim > 0 and waited < DailyConfig.Cooldown then
        Remotes.Notify:FireClient(
            player,
            Locale.Msg("Daily.NotReady", Locale.Dur(DailyConfig.Cooldown - waited))
        )
        return
    end
    if data.daily.lastClaim > 0 and waited > DailyConfig.ResetAfter then
        Remotes.Notify:FireClient(player, Locale.Msg("Daily.StreakReset"))
    end

    local day = DailyConfig.GetNextDay(data.daily, now)
    local reward = DailyConfig.Rewards[day]
    DataService.Set(player, "daily", { streak = day, lastClaim = now })

    IncomeService.AddCoins(player, reward.coins, "daily")
    local rewardText = Locale.Msg("Daily.Coins", Locale.Num(reward.coins))

    local mineralId = reward.mineral
    if mineralId then
        local item: Types.InventoryItem = {
            id = HttpService:GenerateGUID(false),
            mineral = mineralId,
            mutation = "none",
        }
        DataService.Update(player, "inventory", function(inventory: { Types.InventoryItem })
            table.insert(inventory, item)
            return inventory
        end)
        IndexService.Register(player, mineralId, "none")
        rewardText =
            Locale.Msg("Daily.MineralReward", rewardText, Locale.Ref("Minerals." .. mineralId))
    end

    Remotes.Notify:FireClient(player, Locale.Msg("Daily.Claimed", day, rewardText))
end

function DailyService.Init()
    Remotes.ClaimDaily.OnServerEvent:Connect(onClaimDaily)
end

return DailyService
