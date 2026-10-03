--!strict

export type MeteorType = {
    id: string,
    -- Segundos entre impactos.
    interval: number,
    -- Segundos desde que arranca el servidor hasta el primer impacto.
    firstImpact: number,
    hits: number,
    -- Segundos que dura en el suelo si no se agotan sus golpes.
    duration: number,
    -- Multiplicador de peso para minerales Raro o superior.
    rareWeightMultiplier: number,
    -- Multiplicador de peso para las mutaciones distintas de "none".
    mutationMultiplier: number,
    radius: number,
    color: Color3,
    -- Si true, se avisa a todo el servidor con un mensaje en pantalla.
    announce: boolean,
}

local Meteors = {}

-- Segundos de aviso antes del impacto.
Meteors.WarningTime = 10

-- Distancia máxima (studs) desde el personaje hasta la superficie del meteorito para minar.
Meteors.MineRange = 12

-- Margen extra que da el servidor sobre MineRange para compensar la latencia.
Meteors.MineRangeTolerance = 2

-- Distancia mínima entre las superficies de dos meteoritos al elegir dónde cae uno nuevo.
Meteors.MinSeparation = 6

-- Intentos de encontrar un punto libre antes de aceptar uno solapado.
Meteors.PlacementAttempts = 10

-- Efecto visual de la caída (solo cliente).
Meteors.FallHeight = 350
Meteors.FallDuration = 1.5

Meteors.Types = {
    normal = {
        id = "normal",
        interval = 45,
        firstImpact = 20,
        hits = 30,
        duration = 120,
        rareWeightMultiplier = 1,
        mutationMultiplier = 1,
        radius = 4,
        color = Color3.fromRGB(120, 90, 80),
        announce = false,
    },
    big = {
        id = "big",
        interval = 5 * 60,
        firstImpact = 5 * 60,
        hits = 80,
        duration = 120,
        rareWeightMultiplier = 2,
        mutationMultiplier = 1,
        radius = 7,
        color = Color3.fromRGB(150, 80, 60),
        announce = true,
    },
    giant = {
        id = "giant",
        interval = 30 * 60,
        firstImpact = 30 * 60,
        hits = 300,
        duration = 180,
        rareWeightMultiplier = 5,
        mutationMultiplier = 3,
        radius = 14,
        color = Color3.fromRGB(110, 60, 140),
        announce = true,
    },
} :: { [string]: MeteorType }

return Meteors
