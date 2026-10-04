--!strict

-- Gestión del inventario de la base más allá de los pedestales: vender minerales por monedas
-- y fusionar varios iguales (pagando monedas) en uno con la mutación siguiente. Solo afecta a minerales que no
-- están colocados en un pedestal.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementService = require(script.Parent.AchievementService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local IndexService = require(script.Parent.IndexService)
local MomentService = require(script.Parent.MomentService)

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Util.Log)
local Format = require(Shared.Util.Format)
local MomentsConfig = require(Shared.Config.Moments)
local Mutations = require(Shared.Config.Mutations)
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)

local InventoryService = {}

local sellLimiter = RateLimiter.new(Network.RateLimits.SellMineral)
local sellJunkLimiter = RateLimiter.new(Network.RateLimits.SellJunk)
local fuseLimiter = RateLimiter.new(Network.RateLimits.FuseMineral)

-- Quita del inventario los objetos con esos ids.
local function removeItems(player: Player, ids: { [string]: boolean })
    DataService.Update(player, "inventory", function(inventory: { Types.InventoryItem })
        local kept: { Types.InventoryItem } = {}
        for _, item in inventory do
            if not ids[item.id] then
                table.insert(kept, item)
            end
        end
        return kept
    end)
end

local function onSellMineral(player: Player, itemId: unknown)
    if not sellLimiter.Check(player) then
        return
    end
    if type(itemId) ~= "string" or #itemId > 64 then
        Log.Suspicious(player, "Inventory", "tipo inválido")
        return
    end
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    local item = PlayerStats.FindItem(data, itemId)
    if item == nil or PlayerStats.GetPedestalOf(data, itemId) ~= nil then
        return
    end

    local price = PlayerStats.GetSellPrice(item)
    removeItems(player, { [itemId] = true })
    IncomeService.AddCoins(player, price, "sell")
    AchievementService.AddStat(player, "sold", 1)
    Remotes.Notify:FireClient(
        player,
        string.format(
            Strings.Inventory.Sold,
            Strings.MineralName(item.mineral, item.mutation),
            Format.Number(price)
        )
    )
end

-- Vende de una vez todos los minerales comunes sin mutación que no están en un pedestal.
local function onSellJunk(player: Player)
    if not sellJunkLimiter.Check(player) then
        return
    end
    local data = DataService.GetData(player)
    if data == nil then
        return
    end

    local ids: { [string]: boolean } = {}
    local count = 0
    local total = 0
    for _, item in data.inventory do
        if PlayerStats.IsJunk(item) and PlayerStats.GetPedestalOf(data, item.id) == nil then
            ids[item.id] = true
            count += 1
            total += PlayerStats.GetSellPrice(item)
        end
    end
    if count == 0 then
        Remotes.Notify:FireClient(player, Strings.Inventory.NothingToSell)
        return
    end

    removeItems(player, ids)
    IncomeService.AddCoins(player, total, "sell")
    AchievementService.AddStat(player, "sold", count)
    Remotes.Notify:FireClient(
        player,
        string.format(Strings.Inventory.SoldMany, count, Format.Number(total))
    )
end

local function onFuseMineral(player: Player, itemId: unknown)
    if not fuseLimiter.Check(player) then
        return
    end
    if type(itemId) ~= "string" or #itemId > 64 then
        Log.Suspicious(player, "Inventory", "tipo inválido")
        return
    end
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    local item = PlayerStats.FindItem(data, itemId)
    if item == nil or PlayerStats.GetPedestalOf(data, itemId) ~= nil then
        return
    end
    local nextMutation = Mutations.GetNext(item.mutation)
    if nextMutation == nil then
        return
    end

    -- El elegido más los primeros iguales que no estén en un pedestal.
    local ids: { [string]: boolean } = { [itemId] = true }
    local found = 1
    for _, other in data.inventory do
        if found >= Mutations.FuseCount then
            break
        end
        if
            other.id ~= itemId
            and other.mineral == item.mineral
            and other.mutation == item.mutation
            and PlayerStats.GetPedestalOf(data, other.id) == nil
        then
            ids[other.id] = true
            found += 1
        end
    end
    if found < Mutations.FuseCount then
        Remotes.Notify:FireClient(
            player,
            string.format(Strings.Inventory.FuseNotEnough, Mutations.FuseCount)
        )
        return
    end

    -- La fusión cuesta monedas. Se cobra antes de tocar el inventario: si no llega, no pasa nada.
    local cost = PlayerStats.GetFuseCost(item)
    if not IncomeService.SpendCoins(player, cost, "fuse") then
        Remotes.Notify:FireClient(
            player,
            string.format(Strings.Inventory.FuseNotEnoughCoins, Format.Number(cost))
        )
        return
    end

    local fused: Types.InventoryItem = {
        id = HttpService:GenerateGUID(false),
        mineral = item.mineral,
        mutation = nextMutation.id,
    }
    -- Se quitan los tres y se añade el nuevo en un solo cambio del inventario.
    DataService.Update(player, "inventory", function(inventory: { Types.InventoryItem })
        local kept: { Types.InventoryItem } = {}
        for _, current in inventory do
            if not ids[current.id] then
                table.insert(kept, current)
            end
        end
        table.insert(kept, fused)
        return kept
    end)
    IndexService.Register(player, fused.mineral, fused.mutation)
    if MomentsConfig.IsDiscovery(fused.mineral, fused.mutation) then
        MomentService.Announce(player, "discovery", fused.mineral, fused.mutation)
    end
    AchievementService.AddStats(player, {
        fused = 1,
        rainbowFused = if Mutations.GetNext(fused.mutation) == nil then 1 else 0,
    })
    Remotes.Notify:FireClient(
        player,
        string.format(Strings.Inventory.Fused, Strings.MineralName(fused.mineral, fused.mutation))
    )
end

function InventoryService.Init()
    Remotes.SellMineral.OnServerEvent:Connect(onSellMineral)
    Remotes.SellJunk.OnServerEvent:Connect(onSellJunk)
    Remotes.FuseMineral.OnServerEvent:Connect(onFuseMineral)
end

return InventoryService
