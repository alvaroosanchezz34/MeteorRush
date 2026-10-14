--!strict

-- NPCs del puesto avanzado (el Outpost, definido en Config/Map.Hub): personajes que dan vida
-- al mapa, explican el juego con frases cortas y, algunos, abren un menú del juego al hablar
-- con ellos. No venden nada por sí mismos ni cambian ninguna regla: son un acceso con cara a
-- lo que ya existe. No tienen colisión.
-- Para añadir uno basta con otra entrada en `List` y sus textos en Strings.Npcs. Si además
-- debe comentar lo que está pasando, se le añade un proveedor en UI/NpcDialogue.

export type Npc = {
    id: string,
    -- Aspecto: colores, lo que lleva en la cabeza, lo que lleva puesto y lo que lleva en la mano.
    skin: Color3,
    hair: Color3,
    shirt: Color3,
    pants: Color3,
    -- Color de acento: sombrero, detalles de la ropa y su nombre.
    accent: Color3,
    -- "cap", "hardhat", "goggles", "headset", "turban", "tophat", "helmet" o "bandana".
    headgear: string,
    -- "backpack", "coat", "apron", "sash", "toolbelt" o "none".
    accessory: string,
    -- "pick", "hammer", "tablet" o "none".
    item: string,
    -- Animación en reposo: "idle" (respira y balancea los brazos) o "mine" (golpea sin parar).
    animation: "idle" | "mine",
    -- Si gira el cuerpo entero hacia el jugador cercano o solo la cabeza.
    turnBody: boolean,
    -- Su puesto: "station", "lab", "stall", "rock", "crates", "forge", "board" o "supply".
    props: string,
    -- Menú del juego que abre al hablar con él (clave del menú en UI/Hud y, si tiene
    -- pestañas, la pestaña). nil = solo habla.
    opens: { menu: string, tab: string? }?,
}

local Npcs = {}

Npcs.Tag = "Npc"

-- Distancia a la que se puede hablar con uno, a la que se gira hacia un jugador, a la que
-- se lee su nombre y a la que deja de animarse (studs).
Npcs.TalkDistance = 12
Npcs.TurnDistance = 28
Npcs.NameDistance = 90
Npcs.AnimateDistance = 160

-- Segundos que se ve una frase y segundos entre dos comentarios espontáneos (mínimo y máximo).
-- Los espontáneos solo salen si el jugador está a menos de IdleLineDistance.
Npcs.BubbleSeconds = 5
Npcs.IdleLineMinWait = 25
Npcs.IdleLineMaxWait = 55
Npcs.IdleLineDistance = 30

-- En este orden se colocan alrededor de la plaza.
Npcs.List = {
    {
        id = "meteorologist",
        skin = Color3.fromRGB(234, 184, 146),
        hair = Color3.fromRGB(70, 45, 30),
        shirt = Color3.fromRGB(60, 120, 200),
        pants = Color3.fromRGB(45, 50, 70),
        accent = Color3.fromRGB(255, 200, 60),
        headgear = "headset",
        accessory = "coat",
        item = "tablet",
        animation = "idle",
        turnBody = true,
        props = "station",
    },
    {
        id = "crateDealer",
        skin = Color3.fromRGB(205, 160, 125),
        hair = Color3.fromRGB(30, 30, 35),
        shirt = Color3.fromRGB(120, 60, 160),
        pants = Color3.fromRGB(40, 40, 55),
        accent = Color3.fromRGB(255, 170, 30),
        headgear = "tophat",
        accessory = "sash",
        item = "none",
        animation = "idle",
        turnBody = true,
        props = "crates",
        opens = { menu = "inventory", tab = "crates" },
    },
    {
        id = "blacksmith",
        skin = Color3.fromRGB(170, 120, 90),
        hair = Color3.fromRGB(60, 35, 20),
        shirt = Color3.fromRGB(90, 95, 110),
        pants = Color3.fromRGB(50, 45, 45),
        accent = Color3.fromRGB(255, 110, 50),
        headgear = "bandana",
        accessory = "apron",
        item = "hammer",
        animation = "mine",
        turnBody = false,
        props = "forge",
        opens = { menu = "inventory", tab = "equipment" },
    },
    {
        id = "trader",
        skin = Color3.fromRGB(160, 110, 80),
        hair = Color3.fromRGB(25, 20, 20),
        shirt = Color3.fromRGB(190, 80, 60),
        pants = Color3.fromRGB(70, 55, 45),
        accent = Color3.fromRGB(70, 130, 245),
        headgear = "turban",
        accessory = "sash",
        item = "none",
        animation = "idle",
        turnBody = true,
        props = "stall",
        opens = { menu = "trade" },
    },
    {
        id = "scientist",
        skin = Color3.fromRGB(200, 150, 115),
        hair = Color3.fromRGB(200, 200, 210),
        shirt = Color3.fromRGB(235, 235, 245),
        pants = Color3.fromRGB(60, 60, 75),
        accent = Color3.fromRGB(120, 255, 170),
        headgear = "goggles",
        accessory = "coat",
        item = "tablet",
        animation = "idle",
        turnBody = true,
        props = "lab",
        opens = { menu = "index", tab = "index" },
    },
    {
        id = "quartermaster",
        skin = Color3.fromRGB(225, 175, 140),
        hair = Color3.fromRGB(120, 70, 35),
        shirt = Color3.fromRGB(60, 130, 90),
        pants = Color3.fromRGB(55, 60, 50),
        accent = Color3.fromRGB(236, 96, 96),
        headgear = "cap",
        accessory = "toolbelt",
        item = "none",
        animation = "idle",
        turnBody = true,
        props = "board",
        opens = { menu = "quests", tab = "quests" },
    },
    {
        id = "supplyOfficer",
        skin = Color3.fromRGB(190, 140, 105),
        hair = Color3.fromRGB(40, 35, 30),
        shirt = Color3.fromRGB(230, 140, 60),
        pants = Color3.fromRGB(50, 55, 75),
        accent = Color3.fromRGB(250, 150, 60),
        headgear = "helmet",
        accessory = "backpack",
        item = "none",
        animation = "idle",
        turnBody = true,
        props = "supply",
        opens = { menu = "daily" },
    },
    {
        id = "miner",
        skin = Color3.fromRGB(220, 170, 130),
        hair = Color3.fromRGB(150, 150, 155),
        shirt = Color3.fromRGB(200, 140, 50),
        pants = Color3.fromRGB(60, 70, 90),
        accent = Color3.fromRGB(255, 210, 50),
        headgear = "hardhat",
        accessory = "backpack",
        item = "pick",
        animation = "mine",
        turnBody = false,
        props = "rock",
        opens = { menu = "upgrades" },
    },
} :: { Npc }

local byId: { [string]: Npc } = {}
for _, npc in Npcs.List do
    byId[npc.id] = npc
end
Npcs.ById = byId

return Npcs
