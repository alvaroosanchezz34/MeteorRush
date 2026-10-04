--!strict

-- Árbol de mejoras permanentes. Se compran con Meteor Shards (que da cada rebirth) y no se
-- pierden nunca. Un nodo se desbloquea cuando el jugador tiene los rebirths necesarios y el
-- nodo del que depende ha llegado al nivel pedido. Los efectos se aplican en PlayerStats.

export type Node = {
    id: string,
    maxLevel: number,
    -- Coste en shards del nivel siguiente: baseCost + costStep * nivel.
    baseCost: number,
    costStep: number,
    -- Lo que suma cada nivel. Si `percent` es true es una fracción (0,1 = +10 %).
    perLevel: number,
    percent: boolean?,
    requires: { id: string, level: number }?,
    minRebirths: number?,
}

local Permanent = {}

Permanent.List = {
    -- Ingresos de los pedestales.
    { id = "income", maxLevel = 10, baseCost = 2, costStep = 2, perLevel = 0.1, percent = true },
    -- Monedas con las que se empieza tras un rebirth, como fracción del coste del siguiente.
    {
        id = "startCoins",
        maxLevel = 5,
        baseCost = 3,
        costStep = 2,
        perLevel = 0.002,
        percent = true,
        requires = { id = "income", level = 1 },
        minRebirths = 2,
    },
    -- Ingresos sin conexión (se suma a Income.OfflineRate, hasta el 100 %).
    {
        id = "offline",
        maxLevel = 5,
        baseCost = 3,
        costStep = 2,
        perLevel = 0.1,
        percent = true,
        requires = { id = "income", level = 3 },
        minRebirths = 5,
    },
    -- Capacidad de la mochila.
    { id = "capacity", maxLevel = 5, baseCost = 3, costStep = 2, perLevel = 2 },
    -- WalkSpeed.
    {
        id = "speed",
        maxLevel = 5,
        baseCost = 3,
        costStep = 2,
        perLevel = 1,
        requires = { id = "capacity", level = 1 },
    },
    -- Peso de los minerales Raro o superior (se suma a la mejora de suerte).
    { id = "luck", maxLevel = 5, baseCost = 4, costStep = 3, perLevel = 0.05, percent = true },
    -- Probabilidad de mutación (se suma a la mejora de mutación).
    {
        id = "mutation",
        maxLevel = 5,
        baseCost = 5,
        costStep = 3,
        perLevel = 0.1,
        percent = true,
        requires = { id = "luck", level = 2 },
        minRebirths = 3,
    },
} :: { Node }

local byId: { [string]: Node } = {}
for _, node in Permanent.List do
    byId[node.id] = node
end
Permanent.ById = byId

-- Shards que cuesta el nivel siguiente estando en `level`.
function Permanent.GetCost(nodeId: string, level: number): number
    local node = byId[nodeId]
    return node.baseCost + node.costStep * level
end

-- Efecto total de un nodo a ese nivel.
function Permanent.GetValue(nodeId: string, level: number): number
    return byId[nodeId].perLevel * level
end

return Permanent
