--!strict

-- Sistema visual de rareza: qué efectos lleva un mineral según su rareza, su mutación, qué
-- mineral es, dónde está y con qué calidad se puede dibujar. No hay un sistema por mineral:
-- el aspecto final sale de componer cuatro capas.
--
--   identidad del mineral  +  rareza  +  mutación  +  calidad
--
-- Las capas no se suman a ciegas: `RarityFx.Compose` las combina con límites (para que una
-- rareza alta con una mutación fuerte no sea ruido) y aplica, si existe, la composición
-- propia de esa combinación (`Combos`). La identidad del mineral nunca se pierde: sus
-- partículas y su forma de moverse se conservan siempre.
--
-- Lo aplica RarityVisualController (cliente). No cambia rarezas, probabilidades ni
-- multiplicadores, que siguen en Config/Minerals y Config/Mutations.

-- Capa de rareza: cuánto destaca un mineral. Los valores son para un mineral de pedestal.
export type RarityLayer = {
    -- Luz propia: brillo y alcance (0 = sin luz). `pulse` es cuánto late.
    light: number,
    lightRange: number,
    pulse: number,
    -- Partículas por segundo del aura, de las que suben y de las estrellitas alrededor.
    particles: number,
    rising: number,
    stars: number,
    -- Puntos de luz en órbita, fragmentos flotando y anillos de energía.
    orbiters: number,
    fragments: number,
    rings: number,
    -- Segundos entre rayos pequeños y entre ondas de energía (0 = nunca).
    raySeconds: number,
    waveSeconds: number,
    -- "Presencia": altura del haz de luz que lo señala desde lejos (0 = sin haz).
    beam: number,
    -- Núcleo de energía: una esfera de luz que respira alrededor del mineral.
    core: boolean,
    -- Partículas que caen hacia el mineral desde una esfera a su alrededor (gravedad).
    gravity: boolean,
    -- Sonido ambiental en bucle (clave de Config/Sounds; solo suena si tiene id).
    ambient: string?,
}

-- Partículas propias de una mutación (polvo dorado, humo radiactivo...).
export type MutationParticles = {
    texture: "spark" | "smoke",
    rate: number,
    size: number,
    speed: number,
    lifetime: number,
    -- Aceleración vertical: negativa, caen; positiva, suben.
    lift: number,
}

-- Capa de mutación: se compone con la de rareza y cambia el color del aura.
export type MutationLayer = {
    -- Multiplica la luz y el aura de la rareza: un Dorado Legendario brilla mucho más que
    -- un Dorado Raro.
    intensity: number,
    -- Destellos sueltos por segundo.
    glints: number,
    fragments: number,
    rings: number,
    pulse: number,
    raySeconds: number,
    waveSeconds: number,
    -- El color recorre el mineral y su aura sin parar.
    animatedColor: boolean,
    -- Los fragmentos son prismas transparentes.
    prisms: boolean,
    -- La luz parpadea de forma irregular (inestable).
    flicker: boolean,
    extra: MutationParticles?,
}

-- Cómo se mueve un mineral: lo que hace que no todos giren igual.
export type Motion = {
    -- Velocidad de giro respecto a la normal (negativa = al revés) y altura del vaivén.
    spin: number,
    bob: number,
    -- Velocidad de las órbitas y temblor irregular (0 = ninguno).
    orbit: number,
    jitter: number,
}

-- Identidad del mineral: el matiz que lo hace reconocible aunque comparta rareza con otro.
export type Identity = {
    -- Segundo color de las partículas (el primero es el de la rareza o el de la mutación).
    accent: Color3,
    -- Partículas propias por segundo, que lleva siempre (aunque su rareza no tenga aura).
    particles: number,
    texture: "spark" | "smoke",
    -- Tamaño, velocidad y duración de sus partículas respecto a lo normal.
    size: number,
    speed: number,
    lifetime: number,
    -- 1 = brillan, 0 = oscuras (para la materia oscura).
    emission: number,
    -- Sus partículas caen hacia el mineral en vez de salir de él.
    inward: boolean,
    -- Esfera de cristal alrededor que deforma un poco lo que hay detrás.
    distortion: boolean,
    -- Fragmentos propios flotando alrededor, y si son prismas.
    fragments: number,
    prisms: boolean,
    -- Su luz parpadea (plasma) y lleva núcleo de energía aunque su rareza no lo tenga.
    flicker: boolean,
    core: boolean,
    motion: Motion,
}

-- Resultado de componer las capas: lo que de verdad se dibuja.
export type Composition = {
    light: number,
    lightRange: number,
    pulse: number,
    particles: number,
    rising: number,
    stars: number,
    glints: number,
    orbiters: number,
    fragments: number,
    rings: number,
    raySeconds: number,
    waveSeconds: number,
    beam: number,
    core: boolean,
    gravity: boolean,
    animatedColor: boolean,
    prisms: boolean,
    flicker: boolean,
    ambient: string?,
}

export type Discovery = {
    sound: string,
    -- Partículas de la ráfaga, radio de la onda y rayos.
    burst: number,
    wave: number,
    rays: number,
    -- Destello de pantalla y sacudida (0 = nada).
    flash: number,
    shake: number,
    -- Momento cinematográfico: el mineral aparece girando en el centro de la pantalla.
    cinematic: boolean,
}

local RarityFx = {}

-- Niveles de calidad ----------------------------------------------------------------------
-- 3 = todo · 2 = menos partículas, sin fragmentos ni rayos · 1 = luz, aura mínima y haz
-- 0 = nada (el modelo conserva su material y su color).
RarityFx.Quality = {
    -- Distancia a la cámara (studs) hasta la que se usa cada nivel.
    fullDistance = 50,
    mediumDistance = 130,
    -- Más lejos se conserva lo esencial (nivel 1) hasta esta distancia según el rango: los
    -- más raros se reconocen desde más lejos. Por debajo de Raro, nada.
    lowDistance = { 0, 0, 170, 230, 340, 520 },
    -- Máximo de minerales a la vez en cada nivel; los que no caben bajan al siguiente.
    maxFull = 16,
    maxMedium = 36,
    -- Nivel máximo según los gráficos del dispositivo: en móvil y con calidad gráfica media
    -- no se pasa de 2; con calidad gráfica baja, de 1.
    mobileMax = 2,
    mediumGraphics = 6,
    lowGraphics = 3,
    -- Fracción de las partículas en los niveles 2 y 1.
    mediumParticles = 0.5,
    lowParticles = 0.2,
    -- Segundos entre comprobaciones de distancia y veces por segundo que se actualizan los
    -- colores animados y los pulsos de luz (las órbitas van a cada fotograma).
    checkSeconds = 0.4,
    animationRate = 15,
    -- Luces encendidas a la vez como mucho, entre todos los minerales.
    maxLights = 8,
}

-- Dónde está el mineral: en un pedestal, tirado en el suelo o en la espalda de un jugador.
-- `size` es su tamaño en ese estado (studs); `scale` multiplica luz y partículas; `extras`
-- dice si lleva órbitas, fragmentos, anillos, núcleo, rayos y ondas; `beam`, si lleva el haz
-- de presencia; `animate`, si este sistema lo hace girar y flotar (en el pedestal ya lo hace
-- DisplayController).
RarityFx.States = {
    pedestal = { size = 2, scale = 1, extras = true, beam = false, animate = false },
    drop = { size = 1.2, scale = 1.1, extras = true, beam = false, animate = true },
    carried = { size = 1, scale = 0.45, extras = false, beam = false, animate = false },
}

-- Luz --------------------------------------------------------------------------------------
-- Atenuación general de las luces de los minerales: el brillo y el alcance de cada capa se
-- multiplican por esto. Las luces dan ambiente, pero muchas juntas tiñen toda la base.
RarityFx.LightScale = 0.3
RarityFx.LightRangeScale = 0.55

-- Llama de rareza ------------------------------------------------------------------------------
-- El fuego que arde a los pies de un mineral, del color de su rareza (o de su mutación). Es
-- lo que dice de un vistazo cuánto vale: nada en los comunes, una llama pequeña desde Raro y
-- una hoguera en los Míticos. Por rango: tamaño y calor (cuánto sube) del fuego.
-- Un mineral con mutación lleva como mínimo la llama de `mutationRank`.
RarityFx.Flame = {
    mutationRank = 3,
    byRank = {
        [3] = { size = 3, heat = 7 },
        [4] = { size = 4.5, heat = 9 },
        [5] = { size = 6, heat = 11 },
        [6] = { size = 8, heat = 14 },
    } :: { [number]: { size: number, heat: number } },
}

-- Capa de rareza, por rango (1 = Común ... 6 = Mítico) ----------------------------------------
RarityFx.Rarity = {
    -- Común: casi nada. No debe parecer importante.
    {
        light = 0,
        lightRange = 0,
        pulse = 0,
        particles = 0,
        rising = 0,
        stars = 0,
        orbiters = 0,
        fragments = 0,
        rings = 0,
        raySeconds = 0,
        waveSeconds = 0,
        beam = 0,
        core = false,
        gravity = false,
    },
    -- Poco común: un halo pequeño que late.
    {
        light = 0.5,
        lightRange = 6,
        pulse = 0.2,
        particles = 1,
        rising = 0,
        stars = 0,
        orbiters = 0,
        fragments = 0,
        rings = 0,
        raySeconds = 0,
        waveSeconds = 0,
        beam = 0,
        core = false,
        gravity = false,
    },
    -- Raro: aura visible, partículas en órbita y algún fragmento.
    {
        light = 1,
        lightRange = 9,
        pulse = 0.25,
        particles = 3,
        rising = 0,
        stars = 0,
        orbiters = 2,
        fragments = 2,
        rings = 0,
        raySeconds = 0,
        waveSeconds = 0,
        beam = 0,
        core = false,
        gravity = false,
    },
    -- Épico: ya se siente especial. Ondas pequeñas, rayos y un haz corto que lo señala.
    {
        light = 1.6,
        lightRange = 13,
        pulse = 0.3,
        particles = 5,
        rising = 0,
        stars = 0,
        orbiters = 3,
        fragments = 3,
        rings = 0,
        raySeconds = 3.5,
        waveSeconds = 4.5,
        beam = 9,
        core = false,
        gravity = false,
        ambient = "AmbientEpic",
    },
    -- Legendario: anillo orbital, partículas que suben, rayos, ondas y presencia desde lejos.
    {
        light = 2.3,
        lightRange = 18,
        pulse = 0.35,
        particles = 7,
        rising = 3,
        stars = 0,
        orbiters = 4,
        fragments = 4,
        rings = 1,
        raySeconds = 2.2,
        waveSeconds = 3.2,
        beam = 26,
        core = false,
        gravity = false,
        ambient = "AmbientLegendary",
    },
    -- Mítico: otra categoría. No lleva muchas más partículas que un Legendario; lo que cambia
    -- es la composición: núcleo de energía, dos anillos, gravedad, estrellas y un haz enorme.
    {
        light = 3.2,
        lightRange = 26,
        pulse = 0.4,
        particles = 8,
        rising = 4,
        stars = 3,
        orbiters = 5,
        fragments = 5,
        rings = 2,
        raySeconds = 1.6,
        waveSeconds = 2.4,
        beam = 60,
        core = true,
        gravity = true,
        ambient = "AmbientMythic",
    },
} :: { RarityLayer }

-- Capa de mutación ------------------------------------------------------------------------------
RarityFx.Mutations = {
    -- Dorado: valioso. Destellos, polvo brillante que cae despacio y una luz que respira.
    gold = {
        intensity = 1.25,
        glints = 1.5,
        fragments = 1,
        rings = 0,
        pulse = 0.15,
        raySeconds = 0,
        waveSeconds = 0,
        animatedColor = false,
        prisms = false,
        flicker = false,
        extra = {
            texture = "spark",
            rate = 2.5,
            size = 0.6,
            speed = 0.4,
            lifetime = 1.8,
            lift = -1.2,
        },
    },
    -- Radiactivo: inestable. Luz que parpadea, humo verde que sube, descargas y ondas.
    radioactive = {
        intensity = 1.45,
        glints = 0,
        fragments = 0,
        rings = 0,
        pulse = 0.45,
        raySeconds = 2.6,
        waveSeconds = 2.4,
        animatedColor = false,
        prisms = false,
        flicker = true,
        extra = {
            texture = "smoke",
            rate = 2,
            size = 1.6,
            speed = 0.5,
            lifetime = 1.6,
            lift = 1.5,
        },
    },
    -- Arcoíris: el color recorre el mineral y su aura, con prismas, un anillo y rayos de colores.
    rainbow = {
        intensity = 1.8,
        glints = 2,
        fragments = 3,
        rings = 1,
        pulse = 0.3,
        raySeconds = 1.6,
        waveSeconds = 2.8,
        animatedColor = true,
        prisms = true,
        flicker = false,
    },
} :: { [string]: MutationLayer }

-- Identidad de cada mineral ----------------------------------------------------------------------
RarityFx.Identities = {
    -- Roca: un poco de polvo y nada más. Casi no se mueve.
    stone = {
        accent = Color3.fromRGB(150, 140, 130),
        particles = 0.5,
        texture = "smoke",
        size = 0.8,
        speed = 0.4,
        lifetime = 1.4,
        emission = 0,
        inward = false,
        distortion = false,
        fragments = 0,
        prisms = false,
        flicker = false,
        core = false,
        motion = { spin = 0.5, bob = 0.4, orbit = 1, jitter = 0 },
    },
    -- Hierro: chispas cortas y rápidas, y un fragmento metálico atraído por él.
    iron = {
        accent = Color3.fromRGB(200, 220, 255),
        particles = 0.8,
        texture = "spark",
        size = 0.7,
        speed = 2.2,
        lifetime = 0.4,
        emission = 1,
        inward = false,
        distortion = false,
        fragments = 1,
        prisms = false,
        flicker = false,
        core = false,
        motion = { spin = 0.7, bob = 0.5, orbit = 1.4, jitter = 0 },
    },
    -- Cobre: pulsos cálidos y un vaivén amplio y lento.
    copper = {
        accent = Color3.fromRGB(255, 170, 110),
        particles = 0.5,
        texture = "spark",
        size = 0.9,
        speed = 0.8,
        lifetime = 1,
        emission = 1,
        inward = false,
        distortion = false,
        fragments = 0,
        prisms = false,
        flicker = false,
        core = false,
        motion = { spin = 0.8, bob = 1.4, orbit = 0.8, jitter = 0 },
    },
    -- Cristal: giro lento y prismas pequeños flotando.
    crystal = {
        accent = Color3.fromRGB(220, 250, 255),
        particles = 0.5,
        texture = "spark",
        size = 0.8,
        speed = 0.7,
        lifetime = 1.2,
        emission = 1,
        inward = false,
        distortion = false,
        fragments = 2,
        prisms = true,
        flicker = false,
        core = false,
        motion = { spin = 0.45, bob = 0.8, orbit = 0.6, jitter = 0 },
    },
    -- Plasma: núcleo brillante, movimiento rápido e irregular y luz que parpadea.
    plasma = {
        accent = Color3.fromRGB(200, 230, 255),
        particles = 1,
        texture = "spark",
        size = 1.1,
        speed = 2,
        lifetime = 0.6,
        emission = 1,
        inward = false,
        distortion = false,
        fragments = 0,
        prisms = false,
        flicker = true,
        core = true,
        motion = { spin = 2.2, bob = 0.9, orbit = 2.2, jitter = 0.12 },
    },
    -- Nebulosa: humo cósmico de color y un giro pausado.
    nebula = {
        accent = Color3.fromRGB(255, 150, 220),
        particles = 1,
        texture = "smoke",
        size = 2.2,
        speed = 0.4,
        lifetime = 2.2,
        emission = 0.6,
        inward = false,
        distortion = false,
        fragments = 0,
        prisms = false,
        flicker = false,
        core = false,
        motion = { spin = 0.6, bob = 1.1, orbit = 0.7, jitter = 0 },
    },
    -- Materia oscura: partículas oscuras que caen hacia dentro, una esfera que deforma y un
    -- giro muy lento y al revés.
    darkmatter = {
        accent = Color3.fromRGB(25, 10, 45),
        particles = 2,
        texture = "smoke",
        size = 1.4,
        speed = 1.2,
        lifetime = 1.3,
        emission = 0,
        inward = true,
        distortion = true,
        fragments = 0,
        prisms = false,
        flicker = false,
        core = false,
        motion = { spin = -0.3, bob = 0.3, orbit = -0.5, jitter = 0 },
    },
    -- Corazón de Estrella: energía estelar que cae al núcleo, con un giro solemne.
    starheart = {
        accent = Color3.fromRGB(255, 240, 200),
        particles = 2,
        texture = "spark",
        size = 1.3,
        speed = 1.4,
        lifetime = 1.2,
        emission = 1,
        inward = true,
        distortion = true,
        fragments = 0,
        prisms = false,
        flicker = false,
        core = true,
        motion = { spin = 0.9, bob = 1.2, orbit = 1.2, jitter = 0 },
    },
} :: { [string]: Identity }

-- Composición ----------------------------------------------------------------------------------
-- Límites de lo que puede llevar un mineral por mucho que sumen sus capas.
RarityFx.Limits = {
    particles = 14,
    orbiters = 5,
    fragments = 6,
    rings = 3,
    light = 5,
    -- Intervalo mínimo entre rayos y entre ondas.
    raySeconds = 1.2,
    waveSeconds = 2,
}

-- Cuando una mutación cae sobre una rareza que ya lleva mucho (Legendario o superior), el
-- aura de partículas se reduce a esta fracción: el protagonismo pasa a los anillos, los
-- rayos y el color, y se evita el ruido.
RarityFx.HighRank = 5
RarityFx.HighRankAura = 0.7

-- Combinaciones con composición propia: "mineral:mutación". Sus valores sustituyen a los que
-- saldrían de componer las capas.
RarityFx.Combos = {
    -- El objeto más extraordinario del juego: tres anillos de colores, estrellas y rayos,
    -- con menos aura para que se lean el núcleo y las órbitas.
    ["starheart:rainbow"] = {
        particles = 6,
        stars = 5,
        rings = 3,
        orbiters = 5,
        fragments = 4,
        raySeconds = 1.2,
        waveSeconds = 2,
        beam = 80,
    },
    -- Estrella dorada: casi sin aura, mucha luz y destellos.
    ["starheart:gold"] = { particles = 5, glints = 3, rings = 2, light = 4.2 },
    -- Estrella inestable: ondas y descargas más frecuentes.
    ["starheart:radioactive"] = { particles = 6, raySeconds = 1.2, waveSeconds = 2, pulse = 0.9 },
    -- Materia oscura arcoíris: los colores orbitan alrededor de un centro oscuro.
    ["darkmatter:rainbow"] = { particles = 4, rings = 2, orbiters = 5, glints = 1 },
} :: { [string]: { [string]: any } }

-- Sonidos por rareza (claves de Config/Sounds y tono): al recoger uno del suelo y al
-- colocarlo en un pedestal. El de encontrarlo al minar está en `Discovery`.
RarityFx.Audio = {
    { pickup = "Pickup", pickupPitch = 1, place = "Place", placePitch = 1 },
    { pickup = "Pickup", pickupPitch = 1.15, place = "Place", placePitch = 1.05 },
    { pickup = "PickupSpecial", pickupPitch = 1, place = "Place", placePitch = 1.15 },
    { pickup = "PickupSpecial", pickupPitch = 1.2, place = "PlaceSpecial", placePitch = 1 },
    { pickup = "PickupSpecial", pickupPitch = 1.4, place = "PlaceSpecial", placePitch = 1.2 },
    { pickup = "PickupSpecial", pickupPitch = 1.6, place = "PlaceSpecial", placePitch = 1.45 },
} :: { { pickup: string, pickupPitch: number, place: string, placePitch: number } }

-- Momento de descubrimiento al conseguir un mineral, por rango. Por debajo de Raro no hay.
RarityFx.Discovery = {
    [3] = {
        sound = "RareFind",
        burst = 16,
        wave = 0,
        rays = 0,
        flash = 0,
        shake = 0,
        cinematic = false,
    },
    [4] = {
        sound = "EpicFind",
        burst = 26,
        wave = 7,
        rays = 4,
        flash = 0.1,
        shake = 0.2,
        cinematic = false,
    },
    [5] = {
        sound = "LegendaryFind",
        burst = 40,
        wave = 12,
        rays = 8,
        flash = 0.2,
        shake = 0.4,
        cinematic = false,
    },
    [6] = {
        sound = "MythicFind",
        burst = 60,
        wave = 18,
        rays = 12,
        flash = 0,
        shake = 0.6,
        cinematic = true,
    },
} :: { [number]: Discovery }

-- Momento cinematográfico: segundos que dura y cuánto se oscurece la pantalla.
RarityFx.CinematicSeconds = 1.8
RarityFx.CinematicDim = 0.5

-- Menor de dos intervalos, ignorando los que valen 0 (nunca).
local function shortest(a: number, b: number): number
    if a <= 0 then
        return b
    elseif b <= 0 then
        return a
    end
    return math.min(a, b)
end

-- Compone las capas de un mineral: rareza + mutación + identidad, con límites, menos aura si
-- la rareza ya es alta y, si existe, la composición propia de esa combinación.
function RarityFx.Compose(rank: number, mineralId: string, mutationId: string?): Composition
    local rarity = RarityFx.Rarity[rank] or RarityFx.Rarity[1]
    local mutation = if mutationId then RarityFx.Mutations[mutationId] else nil
    local identity = RarityFx.Identities[mineralId]
    local limits = RarityFx.Limits

    local result: Composition = {
        light = rarity.light,
        lightRange = rarity.lightRange,
        pulse = rarity.pulse,
        particles = rarity.particles,
        rising = rarity.rising,
        stars = rarity.stars,
        glints = 0,
        orbiters = rarity.orbiters,
        fragments = rarity.fragments + (if identity then identity.fragments else 0),
        rings = rarity.rings,
        raySeconds = rarity.raySeconds,
        waveSeconds = rarity.waveSeconds,
        beam = rarity.beam,
        core = rarity.core or (identity ~= nil and identity.core),
        gravity = rarity.gravity,
        animatedColor = false,
        prisms = identity ~= nil and identity.prisms,
        flicker = identity ~= nil and identity.flicker,
        ambient = rarity.ambient,
    }

    if mutation then
        -- Un mineral sin aura propia (Común) recibe una mínima: la mutación siempre se nota.
        local aura = if rarity.particles > 0 then rarity.particles else 2
        if rank >= RarityFx.HighRank then
            aura *= RarityFx.HighRankAura
        end
        result.particles = aura * mutation.intensity
        result.light = math.max(rarity.light, 0.6) * mutation.intensity
        result.lightRange = math.max(rarity.lightRange, 7)
        result.pulse += mutation.pulse
        result.glints = mutation.glints
        result.fragments += mutation.fragments
        result.rings += mutation.rings
        result.raySeconds = shortest(rarity.raySeconds, mutation.raySeconds)
        result.waveSeconds = shortest(rarity.waveSeconds, mutation.waveSeconds)
        result.animatedColor = mutation.animatedColor
        result.prisms = result.prisms or mutation.prisms
        result.flicker = result.flicker or mutation.flicker
    end

    -- Composición propia de esa combinación, si la hay.
    local combo = if mutationId then RarityFx.Combos[`{mineralId}:{mutationId}`] else nil
    if combo then
        for key, value in combo do
            (result :: any)[key] = value
        end
    end

    result.particles = math.min(result.particles, limits.particles)
    result.orbiters = math.min(result.orbiters, limits.orbiters)
    result.fragments = math.min(result.fragments, limits.fragments)
    result.rings = math.min(result.rings, limits.rings)
    result.light = math.min(result.light, limits.light)
    if result.raySeconds > 0 then
        result.raySeconds = math.max(result.raySeconds, limits.raySeconds)
    end
    if result.waveSeconds > 0 then
        result.waveSeconds = math.max(result.waveSeconds, limits.waveSeconds)
    end
    return result
end

return RarityFx
