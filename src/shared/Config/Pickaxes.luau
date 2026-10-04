--!strict

-- Picos: un pico es un objeto de equipamiento (Config/Equipment) de tipo "pickaxe".
-- Para añadir uno basta con una entrada más en esta lista y su nombre en Strings.Equipment.
--
-- Estadísticas (todas opcionales; lo que no se pone vale 0). Sus topes están en
-- Equipment.Limits, así que ningún pico puede pasarse aunque aquí se escriba un valor mayor:
--   speed     fracción del tiempo por golpe que ahorra (0,05 = 5 % más rápido)
--   crit      probabilidad de golpe crítico: el golpe da un mineral más
--   rareFind  se suma al multiplicador de suerte (minerales Raro o superior)
--   mutation  se suma al multiplicador de probabilidad de mutación
--   fragment  probabilidad de sacar Forge Dust con el golpe
--
-- `style`, `color` y `accent` deciden su aspecto (Util/EquipmentVisual). `ability` es la
-- clave de su descripción en Strings.Equipment.Abilities: lo que hace sale de sus
-- estadísticas, la habilidad solo le pone nombre.

return {
    {
        id = "rustedPick",
        kind = "pickaxe",
        rarity = "common",
        starter = true,
        style = "pickaxe",
        color = Color3.fromRGB(150, 150, 160),
        stats = {},
    },
    {
        id = "ironPick",
        kind = "pickaxe",
        rarity = "common",
        style = "pickaxe",
        color = Color3.fromRGB(190, 195, 205),
        stats = { speed = 0.02 },
    },
    {
        id = "steelPick",
        kind = "pickaxe",
        rarity = "uncommon",
        style = "pickaxe",
        color = Color3.fromRGB(120, 200, 150),
        stats = { speed = 0.04 },
    },
    {
        id = "emberPick",
        kind = "pickaxe",
        rarity = "uncommon",
        style = "pickaxe",
        color = Color3.fromRGB(230, 120, 60),
        accent = Color3.fromRGB(255, 170, 60),
        stats = { speed = 0.03, fragment = 0.03 },
    },
    {
        id = "prismPick",
        kind = "pickaxe",
        rarity = "rare",
        style = "pickaxe",
        color = Color3.fromRGB(90, 160, 255),
        accent = Color3.fromRGB(150, 220, 255),
        ability = "shardSeeker",
        stats = { speed = 0.05, fragment = 0.08 },
    },
    {
        id = "plasmaPick",
        kind = "pickaxe",
        rarity = "epic",
        style = "pickaxe",
        color = Color3.fromRGB(150, 80, 230),
        accent = Color3.fromRGB(220, 130, 255),
        ability = "energyStrike",
        stats = { speed = 0.07, crit = 0.03, mutation = 0.03 },
    },
    {
        id = "starforgePick",
        kind = "pickaxe",
        rarity = "legendary",
        style = "pickaxe",
        color = Color3.fromRGB(255, 180, 50),
        accent = Color3.fromRGB(255, 235, 150),
        ability = "starStrike",
        stats = { speed = 0.09, crit = 0.05, rareFind = 0.05 },
    },
    {
        id = "singularityPick",
        kind = "pickaxe",
        rarity = "mythic",
        style = "pickaxe",
        color = Color3.fromRGB(40, 20, 60),
        accent = Color3.fromRGB(255, 70, 130),
        ability = "eventHorizon",
        stats = { speed = 0.12, crit = 0.06, rareFind = 0.08, mutation = 0.08, fragment = 0.06 },
    },
}
