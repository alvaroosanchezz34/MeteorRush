--!strict

-- Índice de combinaciones mineral + mutación descubiertas (32 en total).
-- Completar una fila (un mineral con sus 4 mutaciones) da una recompensa única de monedas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local MomentService = require(script.Parent.MomentService)

local Shared = ReplicatedStorage.Shared
local IndexConfig = require(Shared.Config.Index)
local Minerals = require(Shared.Config.Minerals)
local Mutations = require(Shared.Config.Mutations)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)

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
    IncomeService.AddCoins(player, reward, "index")
    Remotes.Notify:FireClient(
        player,
        Locale.Msg("Index.RowComplete", Locale.Ref("Minerals." .. mineralId), Locale.Num(reward))
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
    -- El cliente lo muestra como un aviso grande de NUEVO DESCUBRIMIENTO.
    Remotes.IndexDiscovered:FireClient(player, mineralId, mutationId)
    checkRow(player, mineralId)

    -- Índice completo: un momento legendario para todo el servidor.
    local discovered = 0
    for _ in data.index do
        discovered += 1
    end
    if discovered >= #Minerals.List * #Mutations.List then
        MomentService.Announce(player, "collection")
    end
end

return IndexService
