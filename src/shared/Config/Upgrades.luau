--!strict

-- Definición de las mejoras. El coste de un nivel es round(baseCost * costFactor ^ nivel).
-- UpgradeService (Fase 5) gestiona la compra; aquí solo están los datos y los efectos.

export type Upgrade = {
    id: string,
    maxLevel: number,
    baseCost: number,
    costFactor: number,
    baseValue: number,
    perLevel: number,
    minValue: number?,
    maxValue: number?,
}

local Steal = require(script.Parent.Steal)

local Upgrades = {}

Upgrades.List = {
    -- Segundos por golpe. perLevel es la fracción de baseValue que se resta por nivel.
    {
        id = "pickaxe",
        maxLevel = 20,
        baseCost = 100,
        costFactor = 1.6,
        baseValue = 1.5,
        perLevel = 0.05,
        minValue = 0.3,
    },
    -- Capacidad de la mochila.
    {
        id = "backpack",
        maxLevel = 15,
        baseCost = 150,
        costFactor = 1.7,
        baseValue = 5,
        perLevel = 2,
    },
    -- WalkSpeed.
    { id = "speed", maxLevel = 10, baseCost = 200, costFactor = 1.8, baseValue = 16, perLevel = 1 },
    -- Pedestales disponibles.
    {
        id = "pedestals",
        maxLevel = 16,
        baseCost = 500,
        costFactor = 1.9,
        baseValue = 8,
        perLevel = 1,
        maxValue = 24,
    },
    -- Multiplicador de peso para minerales Raro o superior. perLevel es aditivo.
    {
        id = "luck",
        maxLevel = 10,
        baseCost = 1000,
        costFactor = 2.2,
        baseValue = 1,
        perLevel = 0.05,
    },
    -- Probabilidad (0-1) de sacar un segundo mineral con el mismo golpe.
    {
        id = "fortune",
        maxLevel = 10,
        baseCost = 2500,
        costFactor = 2,
        baseValue = 0,
        perLevel = 0.04,
    },
    -- Multiplicador de la probabilidad de que un mineral salga con mutación.
    {
        id = "mutation",
        maxLevel = 10,
        baseCost = 5000,
        costFactor = 2.1,
        baseValue = 1,
        perLevel = 0.1,
    },
    -- Multiplicador de los ingresos de los pedestales.
    {
        id = "refinery",
        maxLevel = 20,
        baseCost = 3000,
        costFactor = 1.8,
        baseValue = 1,
        perLevel = 0.05,
    },
    -- Fracción de la mochila que se suelta al recibir un golpe.
    {
        id = "grip",
        maxLevel = 10,
        baseCost = 1500,
        costFactor = 1.9,
        baseValue = Steal.DropFraction,
        perLevel = -0.03,
        minValue = 0.2,
    },
} :: { Upgrade }

local byId: { [string]: Upgrade } = {}
for _, upgrade in Upgrades.List do
    byId[upgrade.id] = upgrade
end
Upgrades.ById = byId

local function clampValue(upgrade: Upgrade, value: number): number
    if upgrade.minValue then
        value = math.max(value, upgrade.minValue)
    end
    if upgrade.maxValue then
        value = math.min(value, upgrade.maxValue)
    end
    return value
end

-- Coste de comprar el nivel siguiente estando en `level`.
function Upgrades.GetCost(upgradeId: string, level: number): number
    local upgrade = byId[upgradeId]
    return math.round(upgrade.baseCost * upgrade.costFactor ^ level)
end

-- Valor de una mejora aditiva (baseValue + perLevel * nivel, dentro de sus límites).
-- Vale para todas menos el pico, que usa GetMineTime.
function Upgrades.GetValue(upgradeId: string, level: number): number
    local upgrade = byId[upgradeId]
    return clampValue(upgrade, upgrade.baseValue + upgrade.perLevel * level)
end

-- Segundos que tarda un golpe de pico.
function Upgrades.GetMineTime(level: number): number
    local upgrade = byId.pickaxe
    return clampValue(upgrade, upgrade.baseValue * (1 - upgrade.perLevel * level))
end

-- Capacidad de la mochila (sin game passes).
function Upgrades.GetBackpackCapacity(level: number): number
    local upgrade = byId.backpack
    return clampValue(upgrade, upgrade.baseValue + upgrade.perLevel * level)
end

-- WalkSpeed base (sin penalización de carga).
function Upgrades.GetWalkSpeed(level: number): number
    local upgrade = byId.speed
    return clampValue(upgrade, upgrade.baseValue + upgrade.perLevel * level)
end

-- Número de pedestales disponibles (sin game passes).
function Upgrades.GetPedestalCount(level: number): number
    local upgrade = byId.pedestals
    return clampValue(upgrade, upgrade.baseValue + upgrade.perLevel * level)
end

-- Multiplicador de peso para minerales Raro o superior.
function Upgrades.GetLuckMultiplier(level: number): number
    local upgrade = byId.luck
    return clampValue(upgrade, upgrade.baseValue + upgrade.perLevel * level)
end

return Upgrades
