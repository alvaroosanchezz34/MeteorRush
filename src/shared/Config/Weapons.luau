--!strict

-- Armas: objetos de equipamiento (Config/Equipment) de tipo "weapon". Son herramientas para
-- el robo: nunca hacen daño ni matan, solo cambian cómo se hace soltar la carga.
-- Para añadir una basta con una entrada más en esta lista y su nombre en Strings.Equipment.
--
-- Estadísticas (opcionales; sus topes están en Equipment.Limits):
--   range       studs extra de alcance sobre Steal.HitRange
--   cooldown    segundos entre golpes (si no se pone, Steal.AttackerCooldown)
--   dropPower   se suma a la fracción de la mochila que suelta la víctima
--   knockback   velocidad (studs/s) del empujón a la víctima
--   stunChance  probabilidad de aturdir
--   stun        segundos de aturdimiento
--
-- `ability` es la clave de una habilidad activa de Abilities (abajo) o, si no está ahí,
-- solo el nombre de su rasgo (Strings.Equipment.Abilities).

local Weapons = {}

Weapons.List = {
    {
        id = "rustyBat",
        kind = "weapon",
        rarity = "common",
        starter = true,
        style = "bat",
        color = Color3.fromRGB(140, 110, 90),
        stats = {},
    },
    {
        id = "scrapClub",
        kind = "weapon",
        rarity = "common",
        style = "club",
        color = Color3.fromRGB(150, 150, 160),
        stats = { knockback = 20 },
    },
    {
        id = "shockStick",
        kind = "weapon",
        rarity = "uncommon",
        style = "stick",
        color = Color3.fromRGB(70, 80, 100),
        accent = Color3.fromRGB(120, 230, 255),
        ability = "jolt",
        stats = { stunChance = 0.2, stun = 0.4 },
    },
    {
        id = "plasmaBaton",
        kind = "weapon",
        rarity = "rare",
        style = "baton",
        color = Color3.fromRGB(60, 70, 110),
        accent = Color3.fromRGB(90, 160, 255),
        ability = "discharge",
        stats = { dropPower = 0.05, stunChance = 0.25, stun = 0.5 },
    },
    {
        id = "gravityHammer",
        kind = "weapon",
        rarity = "epic",
        style = "hammer",
        color = Color3.fromRGB(80, 60, 120),
        accent = Color3.fromRGB(190, 110, 255),
        ability = "gravityWave",
        stats = { knockback = 55, dropPower = 0.06, cooldown = 2.2 },
    },
    {
        id = "cometBlade",
        kind = "weapon",
        rarity = "legendary",
        style = "blade",
        color = Color3.fromRGB(60, 60, 80),
        accent = Color3.fromRGB(255, 190, 70),
        ability = "swiftEdge",
        stats = { range = 3, cooldown = 1.7, dropPower = 0.08 },
    },
    {
        id = "voidBreaker",
        kind = "weapon",
        rarity = "mythic",
        style = "breaker",
        color = Color3.fromRGB(30, 15, 50),
        accent = Color3.fromRGB(255, 70, 130),
        ability = "voidPulse",
        stats = { range = 2, dropPower = 0.1, knockback = 35 },
    },
}

export type Ability = {
    -- Segundos entre usos.
    cooldown: number,
    -- Radio (studs) alrededor de quien la usa.
    radius: number,
    -- Minerales que suelta cada jugador alcanzado que lleve carga (cantidad fija, no fracción).
    drop: number,
    -- Empujón hacia fuera (studs/s).
    knockback: number,
    -- Fracción de velocidad que conservan los alcanzados y durante cuántos segundos.
    slow: number,
    slowSeconds: number,
    -- Máximo de jugadores a los que afecta un uso.
    maxTargets: number,
}

-- Habilidades activas. Las ejecuta el servidor (StealService), con las mismas protecciones
-- que un golpe: zona segura, novatos, inmunidad y escudo.
Weapons.Abilities = {
    voidPulse = {
        cooldown = 45,
        radius = 14,
        drop = 1,
        knockback = 30,
        slow = 0.5,
        slowSeconds = 1.5,
        maxTargets = 4,
    },
} :: { [string]: Ability }

return Weapons
