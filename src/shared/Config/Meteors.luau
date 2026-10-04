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
    -- Color de las vetas brillantes, la luz y las ascuas.
    glowColor: Color3,
    -- Si true, se avisa a todo el servidor con un mensaje en pantalla.
    announce: boolean,
    -- Meteorito especial: no cae por su cuenta, solo en eventos (Config/Events). No usa
    -- `interval` ni `firstImpact`.
    special: boolean?,
    -- Mutación mínima de todo lo que sale de él.
    minMutation: string?,
    -- Multiplicador del tiempo por golpe (más de 1 = se mina más despacio).
    mineTimeMultiplier: number?,
    -- Minerales que da cada golpe (por defecto 1).
    mineralsPerHit: number?,
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

-- Modelo generado. PlateCount es para un radio de 4; los más grandes llevan más placas.
Meteors.PlateCount = 46
Meteors.OutcropCount = 6
Meteors.CrystalCount = 3
Meteors.RimRockCount = 9
Meteors.GroundCrackCount = 6
-- Al minarlo se le van cayendo placas: fracción que conserva con el último golpe, y velocidad
-- (studs/s) y duración (s) de los trozos que saltan.
Meteors.MinPlateFraction = 0.3
Meteors.DebrisSpeed = 22
Meteors.DebrisLifetime = 1.5

-- Animación de picar (solo cliente): segundos por golpe de brazo, ángulo con el brazo
-- levantado y bajado (radianes hacia delante) y parte del ciclo que dura la bajada.
Meteors.SwingPeriod = 0.55
Meteors.SwingRaisedAngle = 2.6
Meteors.SwingLoweredAngle = 0.8
Meteors.SwingChopFraction = 0.3

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
        color = Color3.fromRGB(58, 50, 50),
        glowColor = Color3.fromRGB(255, 95, 30),
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
        color = Color3.fromRGB(50, 40, 42),
        glowColor = Color3.fromRGB(255, 50, 35),
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
        color = Color3.fromRGB(42, 34, 54),
        glowColor = Color3.fromRGB(180, 80, 255),
        announce = true,
    },
    -- Dorado: todo lo que sale de él es, como poco, Dorado.
    golden = {
        id = "golden",
        interval = 0,
        firstImpact = 0,
        hits = 60,
        duration = 120,
        rareWeightMultiplier = 1.5,
        mutationMultiplier = 1,
        radius = 6,
        color = Color3.fromRGB(120, 95, 30),
        glowColor = Color3.fromRGB(255, 205, 60),
        announce = true,
        special = true,
        minMutation = "gold",
    },
    -- Corrupto: muchas mutaciones y más raros, pero se mina más despacio.
    corrupt = {
        id = "corrupt",
        interval = 0,
        firstImpact = 0,
        hits = 60,
        duration = 120,
        rareWeightMultiplier = 3,
        mutationMultiplier = 5,
        radius = 6,
        color = Color3.fromRGB(45, 25, 55),
        glowColor = Color3.fromRGB(120, 255, 80),
        announce = true,
        special = true,
        mineTimeMultiplier = 1.5,
    },
    -- Negro: pocos golpes y poco tiempo, pero casi todo lo bueno sale de aquí.
    black = {
        id = "black",
        interval = 0,
        firstImpact = 0,
        hits = 25,
        duration = 75,
        rareWeightMultiplier = 12,
        mutationMultiplier = 1,
        radius = 5,
        color = Color3.fromRGB(15, 15, 20),
        glowColor = Color3.fromRGB(235, 235, 255),
        announce = true,
        special = true,
    },
    -- Arcoíris: casi la mitad de lo que sale lleva mutación.
    rainbow = {
        id = "rainbow",
        interval = 0,
        firstImpact = 0,
        hits = 60,
        duration = 120,
        rareWeightMultiplier = 1.5,
        mutationMultiplier = 12,
        radius = 6,
        color = Color3.fromRGB(70, 50, 80),
        glowColor = Color3.fromRGB(255, 120, 230),
        announce = true,
        special = true,
    },
    -- Alienígena: cada golpe da dos minerales.
    alien = {
        id = "alien",
        interval = 0,
        firstImpact = 0,
        hits = 50,
        duration = 120,
        rareWeightMultiplier = 3,
        mutationMultiplier = 2,
        radius = 6,
        color = Color3.fromRGB(30, 60, 50),
        glowColor = Color3.fromRGB(60, 255, 190),
        announce = true,
        special = true,
        mineralsPerHit = 2,
    },
} :: { [string]: MeteorType }

return Meteors
