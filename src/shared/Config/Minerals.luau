--!strict

export type Rarity = {
    id: string,
    -- Orden de rareza: 1 = Común. Se usa para "Raro o superior".
    rank: number,
    color: Color3,
}

export type Mineral = {
    id: string,
    rarity: string,
    weight: number,
    coinsPerSecond: number,
    -- Color del modelo generado (el de la rareza se usa en la interfaz).
    color: Color3,
}

local Minerals = {}

Minerals.Rarities = {
    common = { id = "common", rank = 1, color = Color3.fromRGB(170, 170, 170) },
    uncommon = { id = "uncommon", rank = 2, color = Color3.fromRGB(90, 200, 90) },
    rare = { id = "rare", rank = 3, color = Color3.fromRGB(70, 140, 255) },
    epic = { id = "epic", rank = 4, color = Color3.fromRGB(170, 80, 240) },
    legendary = { id = "legendary", rank = 5, color = Color3.fromRGB(255, 170, 30) },
    mythic = { id = "mythic", rank = 6, color = Color3.fromRGB(255, 60, 90) },
} :: { [string]: Rarity }

-- Rango a partir del cual se aplican los multiplicadores de suerte y de meteorito.
Minerals.RareRank = 3

-- Rango a partir del cual se anuncia el hallazgo a todo el servidor.
Minerals.AnnounceRank = 5

Minerals.List = {
    {
        id = "stone",
        rarity = "common",
        weight = 5000,
        coinsPerSecond = 1,
        color = Color3.fromRGB(130, 125, 120),
    },
    {
        id = "iron",
        rarity = "common",
        weight = 3000,
        coinsPerSecond = 3,
        color = Color3.fromRGB(95, 105, 125),
    },
    {
        id = "copper",
        rarity = "uncommon",
        weight = 1200,
        coinsPerSecond = 8,
        color = Color3.fromRGB(200, 115, 60),
    },
    {
        id = "crystal",
        rarity = "uncommon",
        weight = 500,
        coinsPerSecond = 20,
        color = Color3.fromRGB(130, 225, 255),
    },
    {
        id = "plasma",
        rarity = "rare",
        weight = 200,
        coinsPerSecond = 60,
        color = Color3.fromRGB(70, 150, 255),
    },
    {
        id = "nebula",
        rarity = "epic",
        weight = 50,
        coinsPerSecond = 250,
        color = Color3.fromRGB(175, 90, 245),
    },
    {
        id = "darkmatter",
        rarity = "legendary",
        weight = 8,
        coinsPerSecond = 1200,
        color = Color3.fromRGB(150, 60, 255),
    },
    {
        id = "starheart",
        rarity = "mythic",
        weight = 1,
        coinsPerSecond = 8000,
        color = Color3.fromRGB(255, 110, 90),
    },
} :: { Mineral }

local byId: { [string]: Mineral } = {}
for _, mineral in Minerals.List do
    byId[mineral.id] = mineral
end
Minerals.ById = byId

-- Devuelve el rango de rareza de un mineral.
function Minerals.GetRank(mineralId: string): number
    local mineral = byId[mineralId]
    return if mineral then Minerals.Rarities[mineral.rarity].rank else 0
end

return Minerals
