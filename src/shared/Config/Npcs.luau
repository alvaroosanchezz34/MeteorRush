--!strict

-- NPCs ambientales: personajes que dan vida al mapa y explican el juego con frases cortas y
-- opcionales. No venden nada, no dan misiones ni recompensas, no tienen colisión y no
-- cambian ninguna regla.
-- Para añadir uno basta con otra entrada en `List` y sus frases en Strings.Npcs. Si además
-- debe comentar lo que está pasando, se le añade un proveedor en UI/NpcDialogue.

export type Npc = {
    id: string,
    -- Dónde está: hueco entre la parcela `gap` y la siguiente, a `radius` studs del centro,
    -- desplazado `offset` studs hacia un lado.
    gap: number,
    radius: number,
    offset: number,
    -- Si mira al centro del mapa (al cráter) o hacia fuera (a quien llega desde las bases).
    faceCenter: boolean,
    skin: Color3,
    shirt: Color3,
    pants: Color3,
    hat: Color3,
    -- Animación en reposo: "idle" (respira y balancea los brazos) o "mine" (pica sin parar).
    animation: "idle" | "mine",
    -- Si gira el cuerpo entero hacia el jugador cercano o solo la cabeza.
    turnBody: boolean,
    -- Decorado que lo acompaña: "station", "lab", "stall", "rock" o "none".
    props: string,
}

local Npcs = {}

Npcs.Tag = "Npc"

-- Distancia a la que se puede hablar con uno, a la que se gira hacia un jugador y a la que
-- deja de animarse (studs).
Npcs.TalkDistance = 12
Npcs.TurnDistance = 28
Npcs.AnimateDistance = 160

-- Segundos que se ve una frase y segundos entre dos comentarios espontáneos (mínimo y máximo).
-- Los espontáneos solo salen si el jugador está a menos de IdleLineDistance.
Npcs.BubbleSeconds = 5
Npcs.IdleLineMinWait = 25
Npcs.IdleLineMaxWait = 55
Npcs.IdleLineDistance = 30

Npcs.List = {
    {
        id = "meteorologist",
        gap = 3,
        radius = 316,
        offset = 0,
        faceCenter = true,
        skin = Color3.fromRGB(234, 184, 146),
        shirt = Color3.fromRGB(60, 120, 200),
        pants = Color3.fromRGB(45, 50, 70),
        hat = Color3.fromRGB(255, 200, 60),
        animation = "idle",
        turnBody = true,
        props = "station",
    },
    {
        id = "scientist",
        gap = 5,
        radius = 324,
        offset = 0,
        faceCenter = false,
        skin = Color3.fromRGB(200, 150, 115),
        shirt = Color3.fromRGB(235, 235, 245),
        pants = Color3.fromRGB(60, 60, 75),
        hat = Color3.fromRGB(120, 255, 170),
        animation = "idle",
        turnBody = true,
        props = "lab",
    },
    {
        id = "trader",
        gap = 2,
        radius = 320,
        offset = 24,
        faceCenter = false,
        skin = Color3.fromRGB(160, 110, 80),
        shirt = Color3.fromRGB(190, 80, 60),
        pants = Color3.fromRGB(70, 55, 45),
        hat = Color3.fromRGB(70, 130, 245),
        animation = "idle",
        turnBody = true,
        props = "stall",
    },
    {
        id = "miner",
        gap = 7,
        radius = 311,
        offset = 0,
        faceCenter = true,
        skin = Color3.fromRGB(220, 170, 130),
        shirt = Color3.fromRGB(200, 140, 50),
        pants = Color3.fromRGB(60, 70, 90),
        hat = Color3.fromRGB(255, 210, 50),
        animation = "mine",
        turnBody = false,
        props = "rock",
    },
} :: { Npc }

local byId: { [string]: Npc } = {}
for _, npc in Npcs.List do
    byId[npc.id] = npc
end
Npcs.ById = byId

return Npcs
