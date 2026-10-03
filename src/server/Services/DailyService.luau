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
local Format = require(Shared.Util.Format)
local Network = require(Shared.Config.Network)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
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
            string.format(Strings.Daily.NotReady, Format.Duration(DailyConfig.Cooldown - waited))
        )
        return
    end
    if data.daily.lastClaim > 0 and waited > DailyConfig.ResetAfter then
        Remotes.Notify:FireClient(player, Strings.Daily.StreakReset)
    end

    local day = DailyConfig.GetNextDay(data.daily, now)
    local reward = DailyConfig.Rewards[day]
    DataService.Set(player, "daily", { streak = day, lastClaim = now })

    IncomeService.AddCoins(player, reward.coins)
    local rewardText = string.format(Strings.Daily.Coins, Format.Number(reward.coins))

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
        rewardText = string.format(
            Strings.Daily.MineralReward,
            rewardText,
            Strings.Minerals[mineralId] or mineralId
        )
    end

    Remotes.Notify:FireClient(player, string.format(Strings.Daily.Claimed, day, rewardText))
end

function DailyService.Init()
    Remotes.ClaimDaily.OnServerEvent:Connect(onClaimDaily)
end

return DailyService
