--!strict

-- Sistema visual de rareza. Para cada mineral que hay en el mundo (en un pedestal, tirado en
-- el suelo o en la espalda de un jugador) dibuja la composición que sale de Config/RarityFx:
-- identidad del mineral + rareza + mutación, ajustada al nivel de calidad. No hay código
-- específico por mineral ni por combinación.
--
-- El nivel de calidad depende de la distancia a la cámara, del dispositivo y de los gráficos
-- del jugador: de cerca todos los efectos, a media distancia los principales, de lejos solo
-- la luz y el haz de presencia de los más raros, y más allá nada. Hay un tope de minerales
-- en cada nivel y de luces encendidas, así que ocho bases llenas no pasan de un coste fijo.
--
-- Rendimiento: un único bucle por fotograma recorre solo los minerales que tienen algo que
-- mover; otro, unas pocas veces por segundo, solo los que están cerca. No hay conexiones ni
-- bucles por mineral, y todo lo creado se destruye al cambiar de nivel o al desaparecer.
--
-- Los modelos y su material los pone el servidor (Util/MineralVisual), marcados con una
-- etiqueta; aquí solo se añaden y se animan los efectos.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent.Parent.UI.Effects)
local Sound = require(script.Parent.Parent.UI.Sound)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MapConfig = require(Config:WaitForChild("Map"))
local MineralVisual = require(Shared:WaitForChild("Util"):WaitForChild("MineralVisual"))
local Minerals = require(Config:WaitForChild("Minerals"))
local Mutations = require(Config:WaitForChild("Mutations"))
local RarityFx = require(Config:WaitForChild("RarityFx"))

local LEVEL_NONE = 0
local LEVEL_LOW = 1
local LEVEL_MEDIUM = 2
local LEVEL_FULL = 3

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local RAINBOW = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.8, 1)),
    ColorSequenceKeypoint.new(0.25, Color3.fromHSV(0.2, 0.8, 1)),
    ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.45, 0.8, 1)),
    ColorSequenceKeypoint.new(0.75, Color3.fromHSV(0.7, 0.8, 1)),
    ColorSequenceKeypoint.new(1, Color3.fromHSV(0.9, 0.8, 1)),
})
-- Segundos que tarda el arcoíris en dar la vuelta completa de color.
local HUE_SECONDS = 4
-- Giro (radianes por segundo) y vaivén (studs) normales de un mineral en el suelo; la
-- identidad de cada mineral los multiplica.
local DROP_SPIN = 1
local DROP_BOB = 0.25
local TRACK_ATTEMPTS = 8
local DEFAULT_MOTION: RarityFx.Motion = { spin = 1, bob = 1, orbit = 1, jitter = 0 }

type Entry = {
    root: Instance,
    primary: BasePart,
    rank: number,
    -- Composición de sus capas: lo que se dibuja.
    fx: RarityFx.Composition,
    mutationLayer: RarityFx.MutationLayer?,
    identity: RarityFx.Identity?,
    motion: RarityFx.Motion,
    color: Color3,
    state: string,
    -- Tamaño del mineral en studs.
    size: number,
    level: number,
    -- Cuenta para los topes de calidad (los comunes sin mutación casi no cuestan).
    heavy: boolean,
    -- Posición original, para los que este sistema hace girar y flotar (los del suelo).
    origin: CFrame?,
    -- Lo creado para el nivel actual; se destruye al cambiar de nivel.
    effects: { Instance },
    modelParts: { BasePart },
    light: PointLight?,
    brightness: number,
    orbiters: { BasePart },
    fragments: { BasePart },
    rings: { BasePart },
    phase: number,
    nextRay: number,
    nextWave: number,
}

local RarityVisualController = {}

local entries: { [Instance]: Entry } = {}
-- Los que tienen algo que mover a cada fotograma y los que están lo bastante cerca para
-- animar su luz y su color. Así los bucles no recorren todos los minerales del mapa.
local moving: { [Entry]: boolean } = {}
local active: { [Entry]: boolean } = {}
local counts = { [LEVEL_FULL] = 0, [LEVEL_MEDIUM] = 0 }
local lights = 0
local folder: Folder? = nil

local function getFolder(): Folder
    if folder then
        return folder
    end
    local created = Instance.new("Folder")
    created.Name = "RarityEffects"
    created.Parent = Workspace
    folder = created
    return created
end

-- Nivel máximo que permiten el dispositivo y los gráficos elegidos por el jugador.
local function qualityCap(): number
    local quality = RarityFx.Quality
    local cap = LEVEL_FULL
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        cap = quality.mobileMax
    end
    local ok, saved = pcall(function(): number
        return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
    end)
    -- 0 = automático: no se sabe, así que no se limita más.
    if ok and saved > 0 then
        if saved <= quality.lowGraphics then
            cap = math.min(cap, LEVEL_LOW)
        elseif saved <= quality.mediumGraphics then
            cap = math.min(cap, LEVEL_MEDIUM)
        end
    end
    return cap
end

local function fxPart(
    entry: Entry,
    name: string,
    size: Vector3,
    cframe: CFrame,
    color: Color3
): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Size = size
    part.CFrame = cframe
    part.Color = color
    part.Parent = getFolder()
    table.insert(entry.effects, part)
    return part
end

local function emitter(
    entry: Entry,
    parent: Instance,
    rate: number,
    size: number,
    speed: number,
    lifetime: number,
    color: ColorSequence
): ParticleEmitter
    local particles = Instance.new("ParticleEmitter")
    particles.Name = "RarityFx"
    particles.Color = color
    particles.Size = NumberSequence.new(size, 0)
    particles.Transparency = NumberSequence.new(0.1, 1)
    particles.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
    particles.Speed = NumberRange.new(speed * 0.5, speed)
    particles.SpreadAngle = Vector2.new(180, 180)
    particles.LightEmission = 1
    particles.Rate = rate
    particles.Parent = parent
    table.insert(entry.effects, particles)
    return particles
end

-- Esfera invisible alrededor del mineral cuyas partículas nacen en su superficie.
local function shellEmitter(
    entry: Entry,
    name: string,
    diameter: number,
    rate: number,
    size: number,
    speed: number,
    lifetime: number,
    color: ColorSequence
): ParticleEmitter
    local shell =
        fxPart(entry, name, Vector3.one * diameter, CFrame.new(entry.primary.Position), entry.color)
    shell.Shape = Enum.PartType.Ball
    shell.Transparency = 1
    local particles = emitter(entry, shell, rate, size, speed, lifetime, color)
    particles.Shape = Enum.ParticleEmitterShape.Sphere
    particles.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
    particles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
    particles.SpreadAngle = Vector2.zero
    return particles
end

local function clear(entry: Entry)
    for _, effect in entry.effects do
        effect:Destroy()
    end
    table.clear(entry.effects)
    table.clear(entry.orbiters)
    table.clear(entry.fragments)
    table.clear(entry.rings)
    moving[entry] = nil
    active[entry] = nil
    if entry.light then
        lights -= 1
        entry.light = nil
    end
end

-- Crea los efectos del nivel de calidad indicado a partir de la composición del mineral.
local function build(entry: Entry, level: number)
    clear(entry)
    entry.level = level
    local state = RarityFx.States[entry.state]
    local origin = entry.origin
    -- Un mineral del suelo que deja de animarse vuelve a su sitio.
    if origin and level < LEVEL_MEDIUM and entry.root:IsA("PVInstance") then
        (entry.root :: PVInstance):PivotTo(origin)
    end
    if level == LEVEL_NONE then
        return
    end
    local quality = RarityFx.Quality
    local fx = entry.fx
    local identity = entry.identity
    local mutationLayer = entry.mutationLayer
    local primary = entry.primary
    local size = entry.size
    local center = primary.Position
    local color = entry.color
    local animated = fx.animatedColor
    local sequence = if animated
        then RAINBOW
        else ColorSequence.new(color, if identity then identity.accent else color)
    local factor = if level == LEVEL_FULL
        then 1
        elseif level == LEVEL_MEDIUM then quality.mediumParticles
        else quality.lowParticles
    factor *= state.scale

    -- Las partes del modelo, para el color animado (pueden haber llegado después que él).
    table.clear(entry.modelParts)
    for _, descendant in entry.root:GetDescendants() do
        if descendant:IsA("BasePart") then
            table.insert(entry.modelParts, descendant)
        end
    end
    if entry.root:IsA("BasePart") then
        table.insert(entry.modelParts, entry.root)
    end

    -- Luz. Hay un máximo de luces encendidas entre todos los minerales.
    local brightness = fx.light * state.scale * RarityFx.LightScale
    if brightness > 0 and lights < quality.maxLights then
        local light = Instance.new("PointLight")
        light.Name = "RarityFx"
        light.Color = color
        light.Brightness = brightness
        light.Range = fx.lightRange * math.sqrt(state.scale) * RarityFx.LightRangeScale
        light.Shadows = false
        light.Parent = primary
        table.insert(entry.effects, light)
        entry.light = light
        entry.brightness = brightness
        lights += 1
    end

    -- Aura.
    if fx.particles * factor > 0.05 then
        emitter(entry, primary, fx.particles * factor, size * 0.16, size * 0.6, 1, sequence)
    end

    -- Haz de presencia: se ve desde lejos, también en el nivel más bajo.
    if state.beam and fx.beam > 0 then
        local beam = fxPart(
            entry,
            "Presence",
            Vector3.new(fx.beam, size * 0.35, size * 0.35),
            CFrame.new(center + Vector3.new(0, fx.beam / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
            color
        )
        beam.Shape = Enum.PartType.Cylinder
        beam.Transparency = 0.72
    end
    if level == LEVEL_LOW then
        return
    end
    active[entry] = true

    -- Llama de rareza: fuego a los pies del mineral, del color de su rareza o su mutación.
    local flameRank = if mutationLayer
        then math.max(entry.rank, RarityFx.Flame.mutationRank)
        else entry.rank
    local flame = RarityFx.Flame.byRank[flameRank]
    if flame and state.extras then
        local holder = fxPart(
            entry,
            "Flame",
            Vector3.one * 0.4,
            CFrame.new(center - Vector3.new(0, size * 0.45, 0)),
            color
        )
        holder.Transparency = 1
        local fire = Instance.new("Fire")
        fire.Name = "RarityFlame"
        fire.Color = color
        fire.SecondaryColor = color:Lerp(Color3.new(1, 1, 1), 0.55)
        fire.Size = flame.size * state.scale * (if level == LEVEL_FULL then 1 else 0.8)
        fire.Heat = flame.heat
        fire.Parent = holder
    end

    -- Identidad del mineral: sus propias partículas, hacia fuera o cayendo hacia dentro.
    if identity and identity.particles > 0 then
        local rate = identity.particles * factor
        local identityColor = ColorSequence.new(identity.accent, color)
        local particles = if identity.inward and state.extras
            then shellEmitter(
                entry,
                "Shell",
                size * 3.2,
                rate,
                size * 0.18 * identity.size,
                size * 0.6 * identity.speed,
                identity.lifetime,
                identityColor
            )
            else emitter(
                entry,
                primary,
                rate,
                size * 0.18 * identity.size,
                size * 0.6 * identity.speed,
                identity.lifetime,
                identityColor
            )
        particles.LightEmission = identity.emission
        if identity.texture == "smoke" then
            particles.Texture = SMOKE_TEXTURE
            particles.Rotation = NumberRange.new(0, 360)
        end
    end

    -- Partículas propias de la mutación: polvo dorado que cae, humo radiactivo que sube...
    local extra = if mutationLayer then mutationLayer.extra else nil
    if extra then
        local particles = emitter(
            entry,
            primary,
            extra.rate * factor,
            size * 0.18 * extra.size,
            size * 0.6 * extra.speed,
            extra.lifetime,
            ColorSequence.new(color)
        )
        particles.Acceleration = Vector3.new(0, extra.lift * size, 0)
        if extra.texture == "smoke" then
            particles.Texture = SMOKE_TEXTURE
            particles.Rotation = NumberRange.new(0, 360)
            particles.Transparency = NumberSequence.new(0.5, 1)
        end
    end
    -- Destellos sueltos.
    if fx.glints > 0 then
        local glints = emitter(
            entry,
            primary,
            fx.glints * factor,
            size * 0.4,
            size * 0.15,
            0.4,
            if animated then RAINBOW else ColorSequence.new(Color3.new(1, 1, 1), color)
        )
        glints.Rotation = NumberRange.new(0, 360)
    end
    -- Partículas que suben.
    if fx.rising > 0 then
        local rising = emitter(
            entry,
            primary,
            fx.rising * factor,
            size * 0.14,
            size * 1.8,
            2,
            ColorSequence.new(color, Color3.new(1, 1, 1))
        )
        rising.EmissionDirection = Enum.NormalId.Top
        rising.SpreadAngle = Vector2.new(12, 12)
    end

    -- Un mineral del suelo gira y flota a su manera.
    if origin and state.animate then
        moving[entry] = true
    end
    if not state.extras then
        return
    end

    -- Gravedad: energía que cae hacia el núcleo desde una esfera alrededor.
    if fx.gravity then
        shellEmitter(
            entry,
            "Gravity",
            size * 5,
            6 * factor,
            size * 0.22,
            size * 1.6,
            1.4,
            if animated then RAINBOW else ColorSequence.new(Color3.new(1, 1, 1), color)
        )
    end
    -- Estrellitas que titilan alrededor, casi quietas.
    if fx.stars > 0 then
        local stars = shellEmitter(
            entry,
            "Stars",
            size * 3.6,
            fx.stars * factor,
            size * 0.2,
            0.2,
            1.6,
            if animated then RAINBOW else ColorSequence.new(Color3.new(1, 1, 1))
        )
        stars.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.5, size * 0.2),
            NumberSequenceKeypoint.new(1, 0),
        })
    end

    -- Núcleo de energía: una esfera de luz que respira alrededor del mineral.
    if fx.core then
        local core = fxPart(entry, "Core", Vector3.one * size * 1.05, CFrame.new(center), color)
        core.Shape = Enum.PartType.Ball
        core.Transparency = 0.68
        TweenService:Create(
            core,
            TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Size = Vector3.one * size * 1.35, Transparency = 0.85 }
        ):Play()
    end

    -- Puntos de luz en órbita (la mitad a media distancia).
    local orbiters = if level == LEVEL_FULL then fx.orbiters else math.ceil(fx.orbiters / 2)
    for _ = 1, orbiters do
        local orb = fxPart(entry, "Orbiter", Vector3.one * size * 0.14, CFrame.new(center), color)
        orb.Shape = Enum.PartType.Ball
        table.insert(entry.orbiters, orb)
    end
    -- Anillos de energía.
    for index = 1, fx.rings do
        local diameter = size * 2.4 + index * size * 0.7
        local ring =
            fxPart(entry, "Ring", Vector3.new(0.06, diameter, diameter), CFrame.new(center), color)
        ring.Shape = Enum.PartType.Cylinder
        ring.Transparency = 0.8
        table.insert(entry.rings, ring)
    end

    if level == LEVEL_FULL then
        -- Solo de cerca: fragmentos flotando (prismas si la mutación o el mineral lo piden).
        for index = 1, fx.fragments do
            local fragment = fxPart(
                entry,
                "Fragment",
                Vector3.one * size * (0.1 + (index % 3) * 0.04),
                CFrame.new(center),
                if fx.prisms then color:Lerp(Color3.new(1, 1, 1), 0.5) else primary.Color
            )
            if fx.prisms then
                fragment.Shape = Enum.PartType.Wedge
                fragment.Material = Enum.Material.Glass
                fragment.Transparency = 0.35
            else
                fragment.Material = primary.Material
            end
            table.insert(entry.fragments, fragment)
        end

        -- Esfera de cristal alrededor: deforma un poco lo que se ve detrás.
        if identity and identity.distortion then
            local sphere = fxPart(
                entry,
                "Distortion",
                Vector3.one * size * 1.9,
                CFrame.new(center),
                identity.accent
            )
            sphere.Shape = Enum.PartType.Ball
            sphere.Material = Enum.Material.Glass
            sphere.Transparency = 0.88
        end

        -- Sonido ambiental en bucle, si hay uno configurado para esa rareza.
        if fx.ambient then
            local ambient = Sound.Loop(fx.ambient, primary)
            if ambient then
                table.insert(entry.effects, ambient)
            end
        end
    end

    if #entry.orbiters + #entry.fragments + #entry.rings > 0 then
        moving[entry] = true
    end
end

-- Empieza a seguir un mineral. Devuelve false si aún no han llegado sus partes.
local function track(root: Instance, isNew: boolean): boolean
    if entries[root] or not root:IsDescendantOf(Workspace) then
        return true
    end
    local mineral = Minerals.ById[root:GetAttribute("Mineral") :: any]
    if mineral == nil then
        return true
    end
    local primary: BasePart? = nil
    if root:IsA("Model") then
        primary = root.PrimaryPart or root:FindFirstChildWhichIsA("BasePart", true)
    elseif root:IsA("BasePart") then
        primary = root
    end
    if primary == nil then
        return false
    end

    local rank = Minerals.Rarities[mineral.rarity].rank
    local mutation: Mutations.Mutation? = Mutations.ById[root:GetAttribute("Mutation") :: any]
    if mutation and mutation.id == Mutations.NoneId then
        mutation = nil
    end
    local mutationLayer = if mutation then RarityFx.Mutations[mutation.id] else nil
    local identity = RarityFx.Identities[mineral.id]
    local state = "drop"
    if root:HasTag(MapConfig.SpinTag) then
        state = "pedestal"
    elseif not primary.Anchored then
        state = "carried"
    end

    local entry: Entry = {
        root = root,
        primary = primary,
        rank = rank,
        fx = RarityFx.Compose(rank, mineral.id, if mutation then mutation.id else nil),
        mutationLayer = mutationLayer,
        identity = identity,
        motion = if identity then identity.motion else DEFAULT_MOTION,
        -- El aura es del color de la mutación; sin ella, del color de la rareza.
        color = (if mutation then mutation.color else nil) or (if rank >= Minerals.RareRank
            then Minerals.Rarities[mineral.rarity].color
            else mineral.color),
        state = state,
        size = RarityFx.States[state].size,
        level = LEVEL_NONE,
        heavy = rank >= Minerals.RareRank or mutationLayer ~= nil,
        origin = if RarityFx.States[state].animate and root:IsA("PVInstance")
            then (root :: PVInstance):GetPivot()
            else nil,
        effects = {},
        modelParts = {},
        light = nil,
        brightness = 0,
        orbiters = {},
        fragments = {},
        rings = {},
        phase = math.random() * 10,
        nextRay = 0,
        nextWave = 0,
    }
    entries[root] = entry

    -- Aparición: lo que acaba de colocarse o de caer cerca hace una ráfaga según su rareza.
    if isNew and entry.heavy and state ~= "carried" then
        Effects.Burst({
            position = primary.Position,
            color = if entry.fx.animatedColor then RAINBOW else entry.color,
            count = 6 + rank * 4,
            speed = 8 + rank * 2,
            size = 0.5,
        })
    end
    return true
end

-- Un mineral que llega del servidor puede tardar un instante en tener sus partes: se
-- reintenta unas pocas veces.
local function trackWhenReady(root: Instance, isNew: boolean)
    for _ = 1, TRACK_ATTEMPTS do
        if root.Parent == nil or track(root, isNew) then
            return
        end
        task.wait(0.25)
    end
end

local function untrack(root: Instance)
    local entry = entries[root]
    if entry == nil then
        return
    end
    if counts[entry.level] and entry.heavy then
        counts[entry.level] -= 1
    end
    clear(entry)
    entries[root] = nil
end

-- Reparte los niveles de calidad según la distancia de cada mineral a la cámara.
local function updateLevels()
    local camera = Workspace.CurrentCamera
    if camera == nil then
        return
    end
    local focus = camera.CFrame.Position
    local quality = RarityFx.Quality
    local cap = qualityCap()
    for root, entry in entries do
        if entry.primary.Parent == nil then
            untrack(root)
            continue
        end
        local position = if entry.origin then entry.origin.Position else entry.primary.Position
        local distance = (position - focus).Magnitude
        local level = LEVEL_NONE
        if distance <= quality.fullDistance then
            level = LEVEL_FULL
        elseif distance <= quality.mediumDistance then
            level = LEVEL_MEDIUM
        elseif distance <= (quality.lowDistance[entry.rank] or 0) then
            -- De lejos, lo raro conserva lo esencial: su luz, su color y su haz.
            level = LEVEL_LOW
        end
        level = math.min(level, cap)
        -- Los que no caben en un nivel bajan al siguiente (los que ya estaban, se quedan).
        if entry.heavy and level ~= entry.level then
            if level == LEVEL_FULL and counts[LEVEL_FULL] >= quality.maxFull then
                level = LEVEL_MEDIUM
            end
            if level == LEVEL_MEDIUM and counts[LEVEL_MEDIUM] >= quality.maxMedium then
                level = LEVEL_LOW
            end
        end
        if level ~= entry.level then
            if entry.heavy then
                if counts[entry.level] then
                    counts[entry.level] -= 1
                end
                if counts[level] then
                    counts[level] += 1
                end
            end
            build(entry, level)
        end
    end
end

-- A cada fotograma, solo para los que tienen algo que mover: el giro y el vaivén de los
-- minerales del suelo, y sus órbitas, fragmentos y anillos. Cada mineral se mueve a su
-- manera (Identity.motion).
local function animateMotion()
    local now = os.clock()
    for entry in moving do
        local motion = entry.motion
        local size = entry.size
        local time = now + entry.phase
        local center = entry.primary.Position

        local origin = entry.origin
        if origin then
            local jitter = motion.jitter
            local pivot = origin
                * CFrame.new(
                    math.noise(time * 9, entry.phase) * jitter,
                    math.sin(time * 1.6) * DROP_BOB * motion.bob,
                    math.noise(entry.phase, time * 9) * jitter
                )
                * CFrame.Angles(0, time * DROP_SPIN * motion.spin, 0);
            (entry.root :: PVInstance):PivotTo(pivot)
            center = pivot.Position
        end

        local orbitRadius = size * 0.9 + 0.5
        for index, orb in entry.orbiters do
            local angle = time * 1.7 * motion.orbit + index * math.pi * 2 / #entry.orbiters
            orb.CFrame = CFrame.new(
                center
                    + Vector3.new(
                        math.cos(angle) * orbitRadius,
                        math.sin(angle + index) * orbitRadius * 0.4,
                        math.sin(angle) * orbitRadius
                    )
            )
        end
        local fragmentRadius = size * 1.3 + 0.8
        for index, fragment in entry.fragments do
            local angle = -time * 0.5 * motion.orbit + index * math.pi * 2 / #entry.fragments
            fragment.CFrame = CFrame.new(
                center
                    + Vector3.new(
                        math.cos(angle) * fragmentRadius,
                        math.sin(time * 1.3 + index * 2) * 0.4,
                        math.sin(angle) * fragmentRadius
                    )
            ) * CFrame.Angles(time + index, time * 0.7, 0)
        end
        for index, ring in entry.rings do
            local direction = if index % 2 == 0 then -1 else 1
            ring.CFrame = CFrame.new(center)
                * CFrame.Angles(
                    index * 0.9 + math.sin(time * 0.4) * 0.25,
                    time * 0.7 * direction * motion.orbit,
                    0
                )
                * CFrame.Angles(0, 0, math.pi / 2)
        end
    end
end

-- Unas pocas veces por segundo, solo para los cercanos: color animado, pulso de luz, rayos
-- y ondas.
local function animateSlow()
    local now = os.clock()
    for entry in active do
        local fx = entry.fx
        local time = now + entry.phase
        local color = entry.color

        if fx.animatedColor then
            local hue = (time / HUE_SECONDS) % 1
            color = Color3.fromHSV(hue, 0.75, 1)
            for index, part in entry.modelParts do
                part.Color = Color3.fromHSV((hue + index / #entry.modelParts) % 1, 0.75, 1)
            end
            for index, ring in entry.rings do
                ring.Color = Color3.fromHSV((hue + index * 0.3) % 1, 0.75, 1)
            end
            for index, orb in entry.orbiters do
                orb.Color = Color3.fromHSV((hue + index * 0.2) % 1, 0.75, 1)
            end
        end

        local light = entry.light
        if light then
            local brightness = entry.brightness * (1 + math.sin(time * 4) * fx.pulse)
            if fx.flicker then
                brightness *= 0.75 + math.random() * 0.5
            end
            light.Brightness = brightness
            light.Color = color
        end

        -- Rayos y ondas: solo de cerca y solo si el estado los permite.
        if entry.level < LEVEL_FULL or not RarityFx.States[entry.state].extras then
            continue
        end
        local center = entry.primary.Position
        if fx.raySeconds > 0 and now >= entry.nextRay then
            entry.nextRay = now + fx.raySeconds * (0.7 + math.random() * 0.6)
            local direction =
                Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5)
            Effects.Ray({
                position = center,
                direction = if direction.Magnitude > 0.01 then direction.Unit else Vector3.yAxis,
                length = entry.size * 1.6 + 1,
                color = color,
            })
        end
        if fx.waveSeconds > 0 and now >= entry.nextWave then
            entry.nextWave = now + fx.waveSeconds
            Effects.Shockwave({
                position = center - Vector3.new(0, entry.size * 0.45, 0),
                radius = entry.size * 2 + 2,
                color = color,
                duration = 0.9,
            })
        end
    end
end

function RarityVisualController.Start()
    local tag = MineralVisual.Tag
    for _, instance in CollectionService:GetTagged(tag) do
        task.spawn(trackWhenReady, instance, false)
    end
    CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
        task.defer(trackWhenReady, instance, true)
    end)
    CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)

    task.spawn(function()
        while true do
            updateLevels()
            task.wait(RarityFx.Quality.checkSeconds)
        end
    end)

    local lastSlow = 0
    RunService.RenderStepped:Connect(function()
        animateMotion()
        local now = os.clock()
        if now - lastSlow >= 1 / RarityFx.Quality.animationRate then
            lastSlow = now
            animateSlow()
        end
    end)
end

return RarityVisualController
