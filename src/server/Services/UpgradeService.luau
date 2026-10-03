--!strict

-- Compra de mejoras con monedas. Los efectos se aplican solos: los servicios que dependen
-- de `upgrades` (CarryService, PedestalService...) escuchan los cambios de ese campo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local QuestService = require(script.Parent.QuestService)

local Shared = ReplicatedStorage.Shared
local Network = require(Shared.Config.Network)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Upgrades = require(Shared.Config.Upgrades)

local UpgradeService = {}

local limiter = RateLimiter.new(Network.RateLimits.BuyUpgrade)

local function onBuyUpgrade(player: Player, upgradeId: unknown)
    if not limiter.Check(player) then
        return
    end
    if type(upgradeId) ~= "string" then
        return
    end
    local upgrade = Upgrades.ById[upgradeId]
    local data = DataService.GetData(player)
    if upgrade == nil or data == nil then
        return
    end

    local level = ((data.upgrades :: any)[upgradeId] or 0) :: number
    if level >= upgrade.maxLevel then
        Remotes.Notify:FireClient(player, Strings.Upgrades.MaxLevel)
        return
    end
    local cost = Upgrades.GetCost(upgradeId, level)
    if data.coins < cost then
        Remotes.Notify:FireClient(player, Strings.Upgrades.NotEnoughCoins)
        return
    end

    DataService.Increment(player, "coins", -cost)
    DataService.Update(player, "upgrades", function(upgrades: Types.UpgradeLevels)
        (upgrades :: any)[upgradeId] = level + 1
        return upgrades
    end)
    Remotes.Notify:FireClient(
        player,
        string.format(Strings.Upgrades.Bought, Strings.Upgrades.Names[upgradeId], level + 1)
    )
    QuestService.Progress(player, "upgrade", 1)
end

function UpgradeService.Init()
    Remotes.BuyUpgrade.OnServerEvent:Connect(onBuyUpgrade)
end

return UpgradeService
