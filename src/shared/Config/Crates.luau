--!strict

-- Cajas de equipamiento. Cada caja tiene su precio, su tabla de probabilidades por rareza y
-- su seguro de mala suerte (pity). Lo que hay dentro sale de Config/Equipment (picos y
-- armas que se pueden encontrar) y de `Cosmetics` (cosméticos exclusivos de cajas).
-- Para añadir una caja basta con una entrada más en `List` y su nombre en Strings.Crates.
--
-- La apertura la decide siempre el servidor (CrateService). Las probabilidades se enseñan
-- al jugador en el menú, calculadas con `GetOdds`.

local Equipment = require(script.Parent.Equipment)
local Rebirth = require(script.Parent.Rebirth)
local Types = require(script.Parent.Parent.Types)

export type Cost = {
    -- "coins" o "dust".
    currency: string,
    -- Monedas: fracción del coste del siguiente rebirth, con un mínimo. Así el precio
    -- acompaña al progreso del jugador en vez de quedarse en nada.
    rebirthFraction: number?,
    minimum: number?,
    -- Forge Dust: cantidad fija.
    amount: number?,
}

export type Pity = {
    enabled: boolean,
    -- Aperturas seguidas sin sacar al menos `minimum` tras las que la siguiente lo garantiza.
    threshold: number,
    minimum: string,
}

export type Crate = {
    id: string,
    -- Rareza visual de la caja (color, brillo y presentación).
    rarity: string,
    -- nil = no se vende: solo se consigue por otras vías (eventos, administración).
    cost: Cost?,
    -- Peso de cada rareza. La probabilidad es su peso entre la suma de todos.
    weights: { [string]: number },
    pity: Pity,
    -- Si se indica, la caja solo da estos objetos (cajas temáticas o de temporada).
    items: { string }?,
}

export type Reward = {
    -- "pickaxe", "weapon" o "cosmetic".
    kind: string,
    id: string,
    rarity: string,
}

local Crates = {}

-- Segundos mínimos entre dos aperturas del mismo jugador (lo aplica el servidor).
Crates.OpenInterval = 0.8
-- Cajas de cada tipo que se pueden tener guardadas sin abrir.
Crates.MaxStored = 99

-- Cosméticos que solo salen de cajas (definidos en Config/Shop, con `crate = true`).
Crates.Cosmetics = {
    { key = "trailPlasma", rarity = "rare" },
    { key = "trailVoid", rarity = "epic" },
    { key = "baseNebula", rarity = "legendary" },
} :: { { key: string, rarity: string } }

Crates.List = {
    {
        id = "basic",
        rarity = "common",
        cost = { currency = "coins", rebirthFraction = 0.01, minimum = 5000 },
        weights = { common = 62, uncommon = 30, rare = 7, epic = 1 },
        pity = { enabled = true, threshold = 15, minimum = "rare" },
    },
    {
        id = "rare",
        rarity = "rare",
        cost = { currency = "coins", rebirthFraction = 0.05, minimum = 40000 },
        weights = { uncommon = 55, rare = 33, epic = 10, legendary = 2 },
        pity = { enabled = true, threshold = 20, minimum = "epic" },
    },
    {
        id = "epic",
        rarity = "epic",
        cost = { currency = "coins", rebirthFraction = 0.2, minimum = 250000 },
        weights = { rare = 60, epic = 30, legendary = 9, mythic = 1 },
        pity = { enabled = true, threshold = 25, minimum = "legendary" },
    },
    {
        id = "legendary",
        rarity = "legendary",
        cost = { currency = "dust", amount = 600 },
        weights = { epic = 65, legendary = 31, mythic = 4 },
        pity = { enabled = true, threshold = 12, minimum = "legendary" },
    },
    -- No se vende todavía: está para eventos y para probarla desde el panel de administración.
    {
        id = "mythic",
        rarity = "mythic",
        cost = nil,
        weights = { legendary = 80, mythic = 20 },
        pity = { enabled = false, threshold = 10, minimum = "mythic" },
    },
} :: { Crate }

local byId: { [string]: Crate } = {}
for _, crate in Crates.List do
    byId[crate.id] = crate
end
Crates.ById = byId

-- Precio de una caja para ese jugador: (moneda, cantidad). nil si no se vende.
function Crates.GetCost(crate: Crate, data: Types.Profile): (string?, number)
    local cost = crate.cost
    if cost == nil then
        return nil, 0
    end
    if cost.currency == "dust" then
        return "dust", cost.amount or 0
    end
    local price = math.floor(Rebirth.GetCost(data.rebirths) * (cost.rebirthFraction or 0))
    return "coins", math.max(price, cost.minimum or 0)
end

-- Lo que puede dar una caja en cada rareza.
function Crates.GetPool(crate: Crate): { [string]: { Reward } }
    local allowed: { [string]: boolean }? = nil
    local only = crate.items
    if only then
        allowed = {}
        for _, id in only do
            allowed[id] = true
        end
    end
    local pool: { [string]: { Reward } } = {}
    local function add(reward: Reward)
        if crate.weights[reward.rarity] == nil or (allowed and not allowed[reward.id]) then
            return
        end
        local rewards = pool[reward.rarity]
        if rewards == nil then
            rewards = {}
            pool[reward.rarity] = rewards
        end
        table.insert(rewards, reward)
    end
    for _, item in Equipment.List do
        if not item.starter and item.droppable ~= false then
            add({ kind = item.kind, id = item.id, rarity = item.rarity })
        end
    end
    for _, cosmetic in Crates.Cosmetics do
        add({ kind = "cosmetic", id = cosmetic.key, rarity = cosmetic.rarity })
    end
    return pool
end

-- Probabilidad (0-1) de cada rareza de una caja, de la más común a la más rara. Las rarezas
-- sin ningún objeto que dar no cuentan.
function Crates.GetOdds(crate: Crate): { { rarity: string, chance: number } }
    local pool = Crates.GetPool(crate)
    local total = 0
    for rarity, weight in crate.weights do
        if pool[rarity] then
            total += weight
        end
    end
    local odds: { { rarity: string, chance: number } } = {}
    for _, rarity in Equipment.RarityOrder do
        local weight = crate.weights[rarity]
        if weight and pool[rarity] and total > 0 then
            table.insert(odds, { rarity = rarity, chance = weight / total })
        end
    end
    return odds
end

return Crates
