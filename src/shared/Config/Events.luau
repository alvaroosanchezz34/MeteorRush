--!strict

-- Eventos globales del servidor. Cada cierto tiempo se elige uno (según su peso y su
-- enfriamiento), se anuncia con una cuenta atrás, dura lo que diga `duration` y termina solo.
-- Para quitar un evento basta con poner `enabled = false`. Los textos están en Strings.Events.

export type Event = {
    id: string,
    enabled: boolean,
    -- "meteor": cae un meteorito especial. "shower": caen varios seguidos.
    -- "supernova": durante el evento todos los meteoritos dan más raros y más mutaciones.
    kind: "meteor" | "shower" | "supernova",
    -- Segundos que dura, desde que empieza hasta que se reparten las recompensas.
    duration: number,
    -- Probabilidad relativa de salir elegido.
    weight: number,
    -- Segundos mínimos entre dos veces seguidas de este mismo evento.
    cooldown: number,
    -- Tipo de meteorito (Config/Meteors) que cae.
    meteorType: string?,
    -- "shower": cuántos meteoritos caen y cada cuántos segundos.
    count: number?,
    spacing: number?,
    -- "supernova": multiplicadores para todos los meteoritos mientras dura.
    rareMultiplier: number?,
    mutationMultiplier: number?,
    -- Color con el que se tiñe el cielo mientras dura.
    skyColor: Color3?,
}

local Events = {}

-- Segundos desde que arranca el servidor hasta el primer evento.
Events.FirstDelay = 8 * 60
-- Segundos entre el final de un evento y el anuncio del siguiente.
Events.Interval = 10 * 60
-- Segundos de cuenta atrás entre el anuncio y el inicio.
Events.Countdown = 30

-- Recompensa por participar (minar al menos un mineral durante el evento): fracción del
-- coste del siguiente rebirth, con un mínimo.
Events.RewardFraction = 0.005
Events.MinReward = 1000

Events.List = {
    {
        id = "meteorShower",
        enabled = true,
        kind = "shower",
        duration = 150,
        weight = 3,
        cooldown = 0,
        meteorType = "normal",
        count = 8,
        spacing = 8,
    },
    {
        id = "supernova",
        enabled = true,
        kind = "supernova",
        duration = 150,
        weight = 2,
        cooldown = 30 * 60,
        meteorType = "big",
        rareMultiplier = 3,
        mutationMultiplier = 3,
        skyColor = Color3.fromRGB(255, 190, 150),
    },
    {
        id = "goldenMeteor",
        enabled = true,
        kind = "meteor",
        duration = 130,
        weight = 2,
        cooldown = 20 * 60,
        meteorType = "golden",
    },
    {
        id = "corruptMeteor",
        enabled = true,
        kind = "meteor",
        duration = 130,
        weight = 2,
        cooldown = 20 * 60,
        meteorType = "corrupt",
    },
    {
        id = "blackMeteor",
        enabled = true,
        kind = "meteor",
        duration = 85,
        weight = 1,
        cooldown = 40 * 60,
        meteorType = "black",
    },
    {
        id = "rainbowMeteor",
        enabled = true,
        kind = "meteor",
        duration = 130,
        weight = 1,
        cooldown = 40 * 60,
        meteorType = "rainbow",
    },
    {
        id = "alienMeteor",
        enabled = true,
        kind = "meteor",
        duration = 130,
        weight = 2,
        cooldown = 20 * 60,
        meteorType = "alien",
    },
} :: { Event }

local byId: { [string]: Event } = {}
for _, event in Events.List do
    byId[event.id] = event
end
Events.ById = byId

return Events
