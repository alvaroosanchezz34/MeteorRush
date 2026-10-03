--!strict

-- Ids de sonido. De momento usan los sonidos que vienen con el propio cliente de Roblox
-- (`rbxasset://sounds/...`), que no necesitan ids de la Creator Store. Son provisionales:
-- para cambiarlos, pega aquí un id con el formato "rbxassetid://123".
-- Si un id está vacío o no existe, ese sonido simplemente no suena.

local Sounds = {
    MeteorWarning = "rbxasset://sounds/electronicpingshort.wav",
    MeteorImpact = "rbxasset://sounds/impact_explosion_03.mp3",
    MineHit = "rbxasset://sounds/collide.wav",
    MineralObtained = "rbxasset://sounds/snap.mp3",
    Deposit = "rbxasset://sounds/unsheath.wav",
    Collect = "rbxasset://sounds/clickfast.wav",
    Hit = "rbxasset://sounds/swordslash.wav",
    Purchase = "rbxasset://sounds/victory.wav",
    UiClick = "rbxasset://sounds/switch.wav",
}

return Sounds
