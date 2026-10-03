--!strict

-- Índice de combinaciones mineral + mutación descubiertas (32 en total).
-- Completar una fila (un mineral con sus 4 mutaciones) da una recompensa única de monedas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local IndexConfig = require(Shared.Config.Index)
local Mutations = require(Shared.Config.Mutations)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)

local IndexService = {}

local function checkRow(player: Player, mineralId: string)
    local data = DataService.GetData(player)
    if data == nil or data.indexRewards[mineralId] then
        return
    end
    for _, mutation in Mutations.List do
        if not data.index[IndexConfig.Key(mineralId, mutation.id)] then
            return
        end
    end

    DataService.Update(player, "indexRewards", function(rewards: { [string]: boolean })
        rewards[mineralId] = true
        return rewards
    end)
    local reward = IndexConfig.GetRowReward(mineralId)
    IncomeService.AddCoins(player, reward)
    Remotes.Notify:FireClient(
        player,
        string.format(
            Strings.Index.RowComplete,
            Strings.Minerals[mineralId] or mineralId,
            Format.Number(reward)
        )
    )
end

-- Registra una combinación obtenida. Si es nueva, avisa y comprueba si completa su fila.
function IndexService.Register(player: Player, mineralId: string, mutationId: string)
    local data = DataService.GetData(player)
    local key = IndexConfig.Key(mineralId, mutationId)
    if data == nil or data.index[key] then
        return
    end
    DataService.Update(player, "index", function(index: { [string]: boolean })
        index[key] = true
        return index
    end)
    Remotes.Notify:FireClient(
        player,
        string.format(Strings.Index.NewEntry, Strings.MineralName(mineralId, mutationId))
    )
    checkRow(player, mineralId)
end

return IndexService
