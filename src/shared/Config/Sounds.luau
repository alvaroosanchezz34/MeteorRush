--!strict

-- Sonidos del juego. Un id tiene el formato "rbxassetid://123" (Creator Store) o
-- "rbxasset://sounds/..." (sonidos que trae el cliente de Roblox, provisionales).
-- Si un id está vacío o no existe, ese sonido simplemente no suena.

local Sounds = {
    MeteorWarning = "rbxasset://sounds/electronicpingshort.wav",
    MeteorImpact = "rbxasset://sounds/impact_explosion_03.mp3",
    -- "Pickaxe Hit", de la Creator Store.
    MineHit = "rbxassetid://9120146349",
    -- "gem collect", de la Creator Store.
    MineralObtained = "rbxassetid://11439707919",
    Deposit = "rbxasset://sounds/unsheath.wav",
    Collect = "rbxasset://sounds/clickfast.wav",
    Hit = "rbxasset://sounds/swordslash.wav",
    Purchase = "rbxasset://sounds/victory.wav",
    UiClick = "rbxasset://sounds/switch.wav",
}

-- Volumen de cada sonido (0-1). Los que no aparecen usan DefaultVolume.
local Volume: { [string]: number } = {
    MeteorImpact = 0.8,
    MineHit = 0.7,
    MineralObtained = 0.3,
    Collect = 0.3,
    UiClick = 0.4,
}

-- Música de fondo: las pistas suenan una detrás de otra, en bucle.
-- Son pistas con licencia de la Creator Store (DistroKid).
local Music = {
    Volume = 0.2,
    Tracks = {
        "rbxassetid://85922328966318", -- Galactic Market
        "rbxassetid://136898642923218", -- Cosmic Cafe
        "rbxassetid://102039057339088", -- Zero Gravity
    },
}

return {
    Ids = Sounds :: { [string]: string },
    Volume = Volume,
    DefaultVolume = 0.5,
    Music = Music,
}
