--!strict

-- Presentación de los meteoritos: todo lo que se ve y se oye de cada uno, sin tocar sus
-- reglas (golpes, probabilidades y duración siguen en Config/Meteors).
-- Cada tipo pertenece a un nivel de espectáculo:
--   normal → rápido y discreto          big → llama la atención de todo el servidor
--   giant  → se vive como un evento
-- Los efectos son del cliente (MeteorController) y duran poco; nada queda encendido.

export type Shake = {
    -- Fuerza junto al impacto, distancia a la que deja de notarse y duración en segundos.
    strength: number,
    range: number,
    duration: number,
}

export type Tier = {
    id: string,

    -- Aviso: haz de luz desde el cielo y anillos que laten en el suelo.
    beamWidth: number,
    beamHeight: number,
    pulseRings: number,
    warningSound: string,
    -- Aviso grande en pantalla, cuenta atrás, cielo teñido, rayos y música de evento.
    isEvent: boolean,

    -- Entrada: duración respecto a Meteors.FallDuration y partículas por segundo de la estela.
    fallMultiplier: number,
    emberRate: number,

    -- Impacto.
    impactSound: string,
    -- Si es false, el sonido del impacto se apaga con la distancia (HearRange).
    globalSound: boolean,
    shockwaves: number,
    -- Radio de la onda expansiva, en radios del meteorito.
    shockwaveScale: number,
    -- Rocas que salen despedidas.
    debris: number,
    -- Cuánto tapa la pantalla el destello (0 = sin destello).
    screenFlash: number,
    shake: Shake,

    -- En el suelo: charco de energía bajo el meteorito.
    energyPool: boolean,
    -- Detalle del modelo: cráteres en la corteza, manchas incandescentes, llamas (partículas
    -- por segundo) y púas de energía que asoman.
    craters: number,
    hotSpots: number,
    flameRate: number,
    spikes: number,
    -- Energía que se escapa del interior: partículas por segundo cuando está casi agotado.
    leakRate: number,

    -- Rotura.
    breakSound: string,
    breakFragments: number,
    breakFlash: number,
    -- Destellos de recompensa que suben flotando.
    rewardPopups: number,
    breakShake: Shake?,
}

local MeteorFx = {}

MeteorFx.Tiers = {
    normal = {
        id = "normal",
        beamWidth = 1.5,
        beamHeight = 200,
        pulseRings = 2,
        warningSound = "MeteorWarning",
        isEvent = false,
        fallMultiplier = 1,
        emberRate = 20,
        impactSound = "MeteorImpact",
        globalSound = false,
        shockwaves = 1,
        shockwaveScale = 4,
        debris = 4,
        screenFlash = 0,
        shake = { strength = 0.7, range = 180, duration = 0.4 },
        energyPool = false,
        craters = 4,
        hotSpots = 4,
        flameRate = 3,
        spikes = 0,
        leakRate = 5,
        breakSound = "MeteorBreak",
        breakFragments = 6,
        breakFlash = 0,
        rewardPopups = 3,
    },
    big = {
        id = "big",
        beamWidth = 3,
        beamHeight = 320,
        pulseRings = 3,
        warningSound = "BigWarning",
        isEvent = false,
        fallMultiplier = 1.5,
        emberRate = 40,
        impactSound = "MeteorImpact",
        globalSound = true,
        shockwaves = 2,
        shockwaveScale = 6,
        debris = 8,
        screenFlash = 0.12,
        shake = { strength = 1.2, range = 450, duration = 0.7 },
        energyPool = true,
        craters = 6,
        hotSpots = 8,
        flameRate = 10,
        spikes = 0,
        leakRate = 9,
        breakSound = "MeteorBreak",
        breakFragments = 10,
        breakFlash = 0.12,
        rewardPopups = 5,
    },
    giant = {
        id = "giant",
        beamWidth = 6,
        beamHeight = 500,
        pulseRings = 4,
        warningSound = "GiantWarning",
        isEvent = true,
        fallMultiplier = 2.4,
        emberRate = 60,
        impactSound = "GiantImpact",
        globalSound = true,
        shockwaves = 3,
        shockwaveScale = 9,
        debris = 14,
        screenFlash = 0.4,
        shake = { strength = 2, range = 900, duration = 1.4 },
        energyPool = true,
        craters = 10,
        hotSpots = 14,
        flameRate = 18,
        spikes = 7,
        leakRate = 16,
        breakSound = "GiantBreak",
        breakFragments = 12,
        breakFlash = 0.3,
        rewardPopups = 8,
        breakShake = { strength = 1, range = 500, duration = 0.8 },
    },
} :: { [string]: Tier }

-- Nivel de cada tipo de meteorito. Los que no aparecen aquí usan "normal".
MeteorFx.TypeTiers = {
    normal = "normal",
    big = "big",
    giant = "giant",
    golden = "big",
    corrupt = "big",
    black = "big",
    rainbow = "big",
    alien = "big",
} :: { [string]: string }

-- Distancia a la que deja de oírse el impacto de un meteorito sin sonido global.
MeteorFx.HearRange = 350

-- Anillos del marcador: segundos de cada latido.
MeteorFx.PulseSeconds = 1.2

-- Energía del meteorito en el suelo: latidos por segundo y cuánto sube el brillo al gastarlo.
MeteorFx.EnergyPulseSpeed = 3
MeteorFx.EnergyPulseAmount = 0.25
MeteorFx.EnergyGrowth = 2

-- Cráter temporal que deja al desaparecer: segundos que tarda en borrarse y máximo a la vez.
MeteorFx.CraterSeconds = 45
MeteorFx.MaxCraters = 8

-- Antes de que caiga un meteorito de evento: segundos entre temblores y su fuerza al
-- principio y justo antes de la entrada.
MeteorFx.RumbleSeconds = 1.4
MeteorFx.RumbleStart = 0.08
MeteorFx.RumbleEnd = 0.35

-- Rayos en el cielo mientras hay un meteorito de evento anunciado o en el suelo.
MeteorFx.Lightning = {
    minWait = 0.6,
    maxWait = 1.8,
    segments = 5,
    -- Altura a la que nace el rayo y fracción de esa altura hasta la que baja.
    height = 300,
    reach = 0.55,
    -- Distancia máxima al punto de impacto y desvío de cada tramo.
    spread = 140,
    jitter = 22,
    width = 1.6,
    seconds = 0.14,
    color = Color3.fromRGB(205, 160, 255),
}

-- Nivel de espectáculo de un tipo de meteorito.
function MeteorFx.GetTier(typeId: string): Tier
    return MeteorFx.Tiers[MeteorFx.TypeTiers[typeId] or "normal"] or MeteorFx.Tiers.normal
end

return MeteorFx
