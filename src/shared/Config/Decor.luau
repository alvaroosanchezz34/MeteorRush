--!strict

-- Personalización de la base: decoraciones en huecos fijos, un efecto de partículas y luz,
-- y el panel de exposición de la colección. Todo es estético: nada tiene colisión ni cambia
-- las reglas del juego. Los textos están en Strings.Decor.

-- Condición para desbloquear algo. Sin condición, es gratis desde el principio.
export type Unlock = {
    rebirths: number?,
    -- Combinaciones descubiertas del índice.
    index: number?,
    -- Id de un logro (Config/Achievements).
    achievement: string?,
}

export type Decoration = {
    id: string,
    kind: "crystal" | "lamp" | "rock" | "trophy",
    color: Color3,
    -- Altura aproximada en studs.
    size: number,
    unlock: Unlock?,
}

export type Effect = {
    id: string,
    -- Colores de las partículas; con más de uno van cambiando de color.
    colors: { Color3 },
    unlock: Unlock?,
}

local Decor = {}

-- Huecos de decoración: posición local en la parcela (-Z es la entrada). Están en los
-- pasillos laterales, entre los pedestales y la valla. El número de huecos es el límite de
-- decoraciones por base.
Decor.Slots = {
    Vector3.new(-26, 0, -14),
    Vector3.new(26, 0, -14),
    Vector3.new(-26, 0, 0),
    Vector3.new(26, 0, 0),
    Vector3.new(-26, 0, 12),
    Vector3.new(26, 0, 12),
}

Decor.Decorations = {
    { id = "crystalBlue", kind = "crystal", color = Color3.fromRGB(90, 200, 255), size = 5 },
    { id = "lamp", kind = "lamp", color = Color3.fromRGB(255, 230, 170), size = 7 },
    { id = "rock", kind = "rock", color = Color3.fromRGB(95, 90, 100), size = 4 },
    {
        id = "crystalPurple",
        kind = "crystal",
        color = Color3.fromRGB(175, 90, 245),
        size = 6,
        unlock = { index = 8 },
    },
    {
        id = "lampRed",
        kind = "lamp",
        color = Color3.fromRGB(255, 80, 70),
        size = 7,
        unlock = { rebirths = 1 },
    },
    {
        id = "crystalGold",
        kind = "crystal",
        color = Color3.fromRGB(255, 200, 60),
        size = 6,
        unlock = { achievement = "coins1" },
    },
    {
        id = "trophy",
        kind = "trophy",
        color = Color3.fromRGB(255, 205, 60),
        size = 5,
        unlock = { achievement = "champion" },
    },
    {
        id = "crystalRainbow",
        kind = "crystal",
        color = Color3.fromRGB(255, 120, 230),
        size = 7,
        unlock = { achievement = "rainbow" },
    },
    {
        id = "trophyStar",
        kind = "trophy",
        color = Color3.fromRGB(255, 110, 90),
        size = 6,
        unlock = { rebirths = 5 },
    },
} :: { Decoration }

Decor.Effects = {
    { id = "stardust", colors = { Color3.fromRGB(235, 240, 255) } },
    { id = "embers", colors = { Color3.fromRGB(255, 130, 50) }, unlock = { rebirths = 1 } },
    { id = "aurora", colors = { Color3.fromRGB(90, 255, 200) }, unlock = { index = 16 } },
    { id = "nebula", colors = { Color3.fromRGB(175, 90, 245) }, unlock = { rebirths = 3 } },
    {
        id = "golden",
        colors = { Color3.fromRGB(255, 205, 60) },
        unlock = { achievement = "coins2" },
    },
    {
        id = "rainbow",
        colors = {
            Color3.fromRGB(255, 80, 80),
            Color3.fromRGB(255, 220, 70),
            Color3.fromRGB(90, 255, 140),
            Color3.fromRGB(90, 170, 255),
            Color3.fromRGB(220, 110, 255),
        },
        unlock = { achievement = "index3" },
    },
} :: { Effect }

-- Efecto de la base: partículas por segundo en toda la parcela y alcance de su luz.
Decor.EffectRate = 8
Decor.EffectLightRange = 45

-- Panel de exposición de la colección, en el muro del fondo: tamaño y posición local.
Decor.BoardSize = Vector3.new(22, 6.5, 0.3)
Decor.BoardOffset = Vector3.new(0, 4.4, 27.4)

local decorationsById: { [string]: Decoration } = {}
for _, decoration in Decor.Decorations do
    decorationsById[decoration.id] = decoration
end
Decor.DecorationsById = decorationsById

local effectsById: { [string]: Effect } = {}
for _, effect in Decor.Effects do
    effectsById[effect.id] = effect
end
Decor.EffectsById = effectsById

return Decor
