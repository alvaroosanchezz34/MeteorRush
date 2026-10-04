--!strict

-- Compra de mejoras permanentes con Meteor Shards. Los efectos se aplican solos: están en
-- PlayerStats y los servicios que dependen de ellos escuchan los cambios de `permanent`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Util.Log)
local Network = require(Shared.Config.Network)
local PermanentConfig = require(Shared.Config.Permanent)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)

local PermanentService = {}

local limiter = RateLimiter.new(Network.RateLimits.BuyPermanent)

local function onBuyPermanent(player: Player, nodeId: unknown)
    if not limiter.Check(player) then
        return
    end
    if type(nodeId) ~= "string" then
        Log.Suspicious(player, "BuyPermanent", "tipo inválido")
        return
    end
    local node = PermanentConfig.ById[nodeId]
    local data = DataService.GetData(player)
    if node == nil or data == nil then
        return
    end

    local level = PlayerStats.GetPermanentLevel(data, nodeId)
    if level >= node.maxLevel then
        Remotes.Notify:FireClient(player, Strings.Upgrades.MaxLevel)
        return
    end
    if not PlayerStats.IsPermanentUnlocked(data, node) then
        Remotes.Notify:FireClient(player, Strings.Permanent.Locked)
        return
    end
    local cost = PermanentConfig.GetCost(nodeId, level)
    if data.shards < cost then
        Remotes.Notify:FireClient(player, Strings.Permanent.NotEnoughShards)
        return
    end

    DataService.Increment(player, "shards", -cost)
    DataService.Update(player, "permanent", function(permanent: { [string]: number })
        permanent[nodeId] = level + 1
        return permanent
    end)
    Remotes.Notify:FireClient(
        player,
        string.format(Strings.Upgrades.Bought, Strings.Permanent.Names[nodeId], level + 1)
    )
end

function PermanentService.Init()
    Remotes.BuyPermanent.OnServerEvent:Connect(onBuyPermanent)
end

return PermanentService
