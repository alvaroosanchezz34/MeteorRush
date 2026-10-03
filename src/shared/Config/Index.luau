--!strict

-- Una fila del índice = un mineral con sus 4 mutaciones.
-- Completarla da una recompensa única de monedas.

local Minerals = require(script.Parent.Minerals)

local Index = {}

-- La recompensa de una fila son los ingresos de ese mineral (sin mutación) durante estos segundos.
Index.RowRewardSeconds = 30 * 60

-- Clave de una entrada del índice.
function Index.Key(mineralId: string, mutationId: string): string
    return `{mineralId}:{mutationId}`
end

-- Monedas que da completar la fila de un mineral.
function Index.GetRowReward(mineralId: string): number
    local mineral = Minerals.ById[mineralId]
    return if mineral then mineral.coinsPerSecond * Index.RowRewardSeconds else 0
end

return Index
