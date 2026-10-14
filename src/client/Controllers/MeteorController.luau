--!strict

-- Efectos de meteoritos en el cliente. Cada tipo tiene un nivel de espectáculo
-- (Config/MeteorFx): aviso con haz, anillos y cuenta atrás; entrada con estela; impacto con
-- onda expansiva, rocas y sacudida; energía que crece mientras se mina; fragmentos en cada
-- golpe; y la secuencia final con el cráter temporal. El gigante es además un evento: aviso
-- grande, cuenta atrás en pantalla, cielo morado, rayos y música.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MeteorFx = require(Config:WaitForChild("MeteorFx"))
local MeteorsConfig = require(Config:WaitForChild("Meteors"))
local Minerals = require(Config:WaitForChild("Minerals"))
local Mutations = require(Config:WaitForChild("Mutations"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local AmbienceController = require(script.Parent.AmbienceController)
local CarryController = require(script.Parent.CarryController)
local Banner = require(script.Parent.Parent.UI.Banner)
local DiscoveryMoment = require(script.Parent.Parent.UI.DiscoveryMoment)
local Effects = require(script.Parent.Parent.UI.Effects)
local RarityStyle = require(script.Parent.Parent.UI.RarityStyle)
local MutationFxController = require(script.Parent.MutationFxController)
local Quality = require(script.Parent.Parent.UI.Quality)
local Sound = require(script.Parent.Parent.UI.Sound)

local MARKER_COLOR = Color3.fromRGB(255, 70, 50)
local FIREBALL_COLOR = Color3.fromRGB(255, 140, 40)
local DUST_COLOR = Color3.fromRGB(150, 120, 100)
local SPARK_COLOR = Color3.fromRGB(255, 220, 120)
-- Texto flotante del mineral obtenido: segundos que dura y studs que sube.
local POPUP_DURATION = 1.4
local POPUP_RISE = 5
local HITS_BAR_COLOR = Color3.fromRGB(255, 120, 50)
-- Color de la barra cuando al meteorito le queda poco: más claro, como la energía que se escapa.
local HITS_BAR_LOW_COLOR = Color3.fromRGB(255, 236, 150)
-- La barra baja deprisa y, detrás, un rastro blanco la sigue con retraso (daño reciente).
local HITS_BAR_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HITS_TRAIL_TWEEN =
    TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.25)
local HITS_PUNCH = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SMOKE_COLOR = Color3.fromRGB(60, 52, 58)
local CRATER_COLOR = Color3.fromRGB(18, 14, 14)
-- Barra de progreso del golpe que se está dando.
local PROGRESS_COLOR = Color3.fromRGB(255, 200, 60)
-- Dos minerales en menos de este tiempo son un golpe doble.
local DOUBLE_WINDOW = 0.15
-- Un destello de pantalla solo se ve a menos de esta distancia (salvo los de evento).
local FLASH_RANGE = 160
-- Segundos que se espera tras un cambio de mochila para saber si venía de minar.
local PICKUP_CHECK_SECONDS = 0.15

-- Estado de cada meteorito que hay en el suelo, para su energía y su rotura.
type Tracked = {
    meteorType: MeteorsConfig.MeteorType,
    tier: MeteorFx.Tier,
    position: Vector3,
    hitsLeft: number,
    light: PointLight?,
    baseBrightness: number,
    pool: BasePart?,
}

local MeteorController = {}

local effectsFolder: Folder? = nil
local progressGui: BillboardGui? = nil
local progressFill: Frame? = nil
local progressTween: Tween? = nil

local function getEffectsFolder(): Folder
    if effectsFolder then
        return effectsFolder
    end
    local folder = Instance.new("Folder")
    folder.Name = "MeteorEffects"
    folder.Parent = Workspace
    effectsFolder = folder
    return folder
end

local function makeEffectPart(props: {
    name: string,
    size: Vector3,
    cframe: CFrame,
    color: Color3,
    transparency: number,
    shape: Enum.PartType?,
}): Part
    local part = Instance.new("Part")
    part.Name = props.name
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Size = props.size
    part.CFrame = props.cframe
    part.Color = props.color
    part.Transparency = props.transparency
    if props.shape then
        part.Shape = props.shape
    end
    part.Parent = getEffectsFolder()
    return part
end

local function distanceToPlayer(position: Vector3): number
    local character = Players.LocalPlayer.Character
    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
    return if root and root:IsA("BasePart") then (root.Position - position).Magnitude else math.huge
end

-- Sacudida de cámara que se apaga con la distancia al punto.
local function shakeAt(position: Vector3, shake: MeteorFx.Shake)
    local falloff = 1 - distanceToPlayer(position) / shake.range
    if falloff > 0 then
        Effects.Shake(shake.strength * falloff, shake.duration)
    end
end

-- Marcador físico del impacto: disco en el suelo, haz de luz desde el cielo, anillos que
-- laten y cuenta atrás. Su tamaño depende del nivel del meteorito.
local function createMarker(
    position: Vector3,
    meteorType: MeteorsConfig.MeteorType,
    tier: MeteorFx.Tier
): (Model, TextLabel)
    local marker = Instance.new("Model")
    marker.Name = "ImpactMarker"
    local radius = meteorType.radius

    local ground = Vector3.new(position.X, 0.2, position.Z)
    local ring = makeEffectPart({
        name = "Ring",
        size = Vector3.new(0.2, radius * 2 + 4, radius * 2 + 4),
        cframe = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90)),
        color = MARKER_COLOR,
        transparency = 0.5,
        shape = Enum.PartType.Cylinder,
    })
    ring.Parent = marker

    -- Haz desde el cielo: un núcleo fino y brillante dentro de un halo del color del meteorito,
    -- que late para que se vea desde lejos.
    local beamCFrame = CFrame.new(ground + Vector3.new(0, tier.beamHeight / 2, 0))
        * CFrame.Angles(0, 0, math.rad(90))
    local core = makeEffectPart({
        name = "BeamCore",
        size = Vector3.new(tier.beamHeight, tier.beamWidth * 0.4, tier.beamWidth * 0.4),
        cframe = beamCFrame,
        color = Color3.new(1, 1, 1),
        transparency = 0.2,
        shape = Enum.PartType.Cylinder,
    })
    core.Parent = marker
    local beam = makeEffectPart({
        name = "Beam",
        size = Vector3.new(tier.beamHeight, tier.beamWidth, tier.beamWidth),
        cframe = beamCFrame,
        color = meteorType.glowColor,
        transparency = 0.55,
        shape = Enum.PartType.Cylinder,
    })
    beam.Parent = marker
    TweenService
        :Create(
            beam,
            TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {
                Size = Vector3.new(tier.beamHeight, tier.beamWidth * 1.8, tier.beamWidth * 1.8),
                Transparency = 0.8,
            }
        )
        :Play()

    local billboard = Instance.new("BillboardGui")
    -- Los textos ya salen en el idioma elegido: sin traducción automática de Roblox.
    billboard.AutoLocalize = false
    billboard.Adornee = ring
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    -- Tamaño en studs para que se vea más pequeño a lo lejos.
    billboard.Size = UDim2.fromScale(24, 6)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, radius * 2 + 6, 0)
    billboard.MaxDistance = math.huge
    billboard.Parent = ring

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Font = Enum.Font.GothamBlack
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0
    label.Parent = billboard

    -- Anillos del color del meteorito que crecen desde el centro una y otra vez.
    for index = 1, tier.pulseRings do
        local pulse = makeEffectPart({
            name = "Pulse",
            size = Vector3.new(0.25, 2, 2),
            cframe = CFrame.new(ground + Vector3.new(0, 0.1, 0))
                * CFrame.Angles(0, 0, math.rad(90)),
            color = meteorType.glowColor,
            transparency = 0.25,
            shape = Enum.PartType.Cylinder,
        })
        pulse.Parent = marker
        local diameter = radius * 2 + 14
        TweenService:Create(
            pulse,
            TweenInfo.new(
                MeteorFx.PulseSeconds,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out,
                -1,
                false,
                (index - 1) * MeteorFx.PulseSeconds / tier.pulseRings
            ),
            { Size = Vector3.new(0.25, diameter, diameter), Transparency = 1 }
        ):Play()
    end

    marker.Parent = getEffectsFolder()
    return marker, label
end

-- Ráfaga de partículas en un punto (polvo del impacto, chispas del pico).
local function burst(position: Vector3, color: Color3, count: number, speed: number, size: number)
    local holder = makeEffectPart({
        name = "Burst",
        size = Vector3.one,
        cframe = CFrame.new(position),
        color = color,
        transparency = 1,
    })
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(color)
    emitter.Size = NumberSequence.new(size, 0)
    emitter.Speed = NumberRange.new(speed * 0.5, speed)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Lifetime = NumberRange.new(0.4, 1)
    emitter.Rate = 0
    emitter.Parent = holder
    emitter:Emit(Quality.Count(count))
    task.delay(1.5, function()
        holder:Destroy()
    end)
end

-- Impacto: ondas expansivas, polvo, chispas, rocas despedidas, destello de luz, sonido y
-- sacudida, todo a la medida del nivel del meteorito.
local function playImpact(position: Vector3, meteorType: MeteorsConfig.MeteorType)
    local tier = MeteorFx.GetTier(meteorType.id)
    local radius = meteorType.radius
    local ground = Vector3.new(position.X, 0.4, position.Z)
    local distance = distanceToPlayer(position)

    burst(position, DUST_COLOR, math.floor(radius * 8), radius * 6, radius)
    -- Polvo que se queda flotando tras el golpe y se disipa despacio.
    Effects.Dust({
        position = ground,
        color = DUST_COLOR,
        count = math.floor(6 + radius * 1.5),
        size = radius * 1.4,
        ignoreDistance = tier.isEvent,
    })
    Effects.Burst({
        position = position,
        color = meteorType.glowColor,
        count = math.floor(radius * 5),
        speed = radius * 9,
        size = radius * 0.35,
        lifetime = 1,
        ignoreDistance = true,
    })
    for index = 1, tier.shockwaves do
        task.delay((index - 1) * 0.15, Effects.Shockwave, {
            position = ground,
            radius = radius * tier.shockwaveScale * (1 + (index - 1) * 0.5),
            color = if index == 1 then meteorType.glowColor else Color3.new(1, 1, 1),
            duration = 0.6 + index * 0.2,
            ignoreDistance = true,
        })
    end
    Effects.Fragments({
        position = position,
        direction = Vector3.yAxis,
        color = meteorType.color,
        count = tier.debris,
        size = radius * 0.22,
        speed = 30 + radius * 2,
    })

    -- Destello de luz que se apaga enseguida.
    local flash = Effects.Anchor(position, 0.9)
    local light = Instance.new("PointLight")
    light.Color = meteorType.glowColor
    light.Range = math.min(radius * 8, 60)
    light.Brightness = 6
    light.Shadows = false
    light.Parent = flash
    TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()

    -- Los discretos se apagan con la distancia; los grandes se oyen en todo el servidor.
    local volume = if tier.globalSound
        then 1
        else math.clamp(1 - distance / MeteorFx.HearRange, 0, 1)
    if volume > 0.05 then
        Sound.Play(tier.impactSound, { volume = volume, duck = tier.globalSound })
    end
    shakeAt(position, tier.shake)
    if tier.screenFlash > 0 and (tier.isEvent or distance <= FLASH_RANGE) then
        Effects.Flash(meteorType.glowColor, tier.screenFlash, 0.9)
    end
end

-- Segundos que dura la entrada de un meteorito.
local function fallDuration(tier: MeteorFx.Tier): number
    return MeteorsConfig.FallDuration * tier.fallMultiplier
end

-- Punto del cielo desde el que entra un meteorito.
local function fallStart(position: Vector3, tier: MeteorFx.Tier): Vector3
    local height = MeteorsConfig.FallHeight * tier.fallMultiplier
    return position + Vector3.new(height * 0.45, height, height * 0.15)
end

-- Entrada: bola incandescente del color del meteorito, con estela y ascuas, que cae en diagonal.
-- Cuanto mayor el nivel, desde más lejos y más despacio entra.
local function playFall(position: Vector3, meteorType: MeteorsConfig.MeteorType)
    local tier = MeteorFx.GetTier(meteorType.id)
    local radius = meteorType.radius
    local duration = fallDuration(tier)
    local start = fallStart(position, tier)
    local fireball = makeEffectPart({
        name = "Fireball",
        size = Vector3.one * radius * 2,
        cframe = CFrame.lookAt(start, position),
        color = FIREBALL_COLOR:Lerp(meteorType.glowColor, 0.6),
        transparency = 0,
        shape = Enum.PartType.Ball,
    })

    -- Estela: dos puntos a los lados de la bola, perpendiculares a la dirección de caída.
    local top = Instance.new("Attachment")
    top.Position = Vector3.new(0, radius, 0)
    top.Parent = fireball
    local bottom = Instance.new("Attachment")
    bottom.Position = Vector3.new(0, -radius, 0)
    bottom.Parent = fireball
    local trail = Instance.new("Trail")
    trail.Attachment0 = top
    trail.Attachment1 = bottom
    trail.Lifetime = 0.4 + tier.fallMultiplier * 0.2
    trail.LightEmission = 1
    trail.FaceCamera = true
    trail.Color = ColorSequence.new(Color3.new(1, 1, 1), meteorType.glowColor)
    trail.Transparency = NumberSequence.new(0.1, 1)
    trail.WidthScale = NumberSequence.new(1, 0.2)
    trail.Parent = fireball

    local embers = Instance.new("ParticleEmitter")
    embers.Color = ColorSequence.new(meteorType.glowColor)
    embers.Size = NumberSequence.new(radius * 0.5, 0)
    embers.Transparency = NumberSequence.new(0.2, 1)
    embers.Lifetime = NumberRange.new(0.3, 0.7)
    embers.Speed = NumberRange.new(radius, radius * 3)
    embers.SpreadAngle = Vector2.new(180, 180)
    embers.LightEmission = 1
    embers.Rate = tier.emberRate * Quality.Scales[Quality.Get()]
    embers.Parent = fireball

    -- Humo oscuro que deja detrás: la bola parece arder al atravesar el aire.
    if not Quality.IsLow() then
        local smoke = Instance.new("ParticleEmitter")
        smoke.Color = ColorSequence.new(SMOKE_COLOR)
        smoke.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, radius * 0.8),
            NumberSequenceKeypoint.new(1, radius * 2.2),
        })
        smoke.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(1, 1),
        })
        smoke.Lifetime = NumberRange.new(0.6, 1.1)
        smoke.Speed = NumberRange.new(0, radius * 0.5)
        smoke.SpreadAngle = Vector2.new(30, 30)
        smoke.Rotation = NumberRange.new(0, 360)
        smoke.RotSpeed = NumberRange.new(-40, 40)
        smoke.Rate = tier.emberRate * 0.5 * Quality.Scales[Quality.Get()]
        smoke.Parent = fireball
    end

    local light = Instance.new("PointLight")
    light.Color = meteorType.glowColor
    light.Range = math.min(radius * 6, 60)
    light.Brightness = 3
    light.Shadows = false
    light.Parent = fireball

    -- Sombra en el punto de impacto, que crece y se oscurece según se acerca.
    local shadow = makeEffectPart({
        name = "FallShadow",
        size = Vector3.new(0.05, radius * 0.6, radius * 0.6),
        cframe = CFrame.new(position.X, 0.27, position.Z) * CFrame.Angles(0, 0, math.rad(90)),
        color = Color3.new(0, 0, 0),
        transparency = 0.85,
        shape = Enum.PartType.Cylinder,
    })
    shadow.Material = Enum.Material.SmoothPlastic
    local fall = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    TweenService
        :Create(
            shadow,
            fall,
            { Size = Vector3.new(0.05, radius * 3, radius * 3), Transparency = 0.35 }
        )
        :Play()

    -- Meteoritos de evento: ondas en el aire a su paso, a un tercio y a dos tercios de la caída.
    if tier.isEvent then
        for step = 1, 2 do
            task.delay(duration * math.sqrt(step / 3), function()
                Effects.Shockwave({
                    position = start:Lerp(position, step / 3),
                    radius = radius * 4,
                    color = meteorType.glowColor,
                    duration = 0.9,
                    ignoreDistance = true,
                })
            end)
        end
    end

    local tween = TweenService:Create(
        fireball,
        fall,
        { CFrame = CFrame.lookAt(position, position + (position - start)) }
    )
    tween.Completed:Connect(function()
        fireball:Destroy()
        shadow:Destroy()
        playImpact(position, meteorType)
    end)
    tween:Play()
end

-- Evento del gigante -----------------------------------------------------------------
-- Mientras hay un meteorito de evento anunciado o en el suelo: rayos en el cielo y música de
-- evento. Las piezas de los rayos se reutilizan.
local eventPending = 0
local eventPosition = Vector3.zero
local eventRunning = false
local boltPool: { Part } = {}
local countdownLabel: TextLabel? = nil

local function strikeLightning()
    local config = MeteorFx.Lightning
    local angle = math.random() * math.pi * 2
    local distance = math.random() * config.spread
    local point = eventPosition
        + Vector3.new(math.cos(angle) * distance, config.height, math.sin(angle) * distance)
    local step = config.height * config.reach / config.segments

    local segments: { Part } = {}
    for _ = 1, config.segments do
        local nextPoint = point
            + Vector3.new(
                (math.random() - 0.5) * 2 * config.jitter,
                -step,
                (math.random() - 0.5) * 2 * config.jitter
            )
        local segment = table.remove(boltPool)
        if segment == nil then
            segment = makeEffectPart({
                name = "Lightning",
                size = Vector3.one,
                cframe = CFrame.identity,
                color = config.color,
                transparency = 0.1,
            })
        end
        segment.Size = Vector3.new(config.width, config.width, (nextPoint - point).Magnitude)
        segment.CFrame = CFrame.lookAt((point + nextPoint) / 2, nextPoint)
        segment.Parent = getEffectsFolder()
        table.insert(segments, segment)
        point = nextPoint
    end
    Sound.Play("Lightning")
    task.delay(config.seconds, function()
        for _, segment in segments do
            segment.Parent = nil
            table.insert(boltPool, segment)
        end
    end)
end

local function isEventActive(): boolean
    return eventPending > 0 or Workspace:GetAttribute("GiantActive") == true
end

-- Rayos y música mientras dure el evento; se para solo cuando ya no queda ninguno.
local function runEvent()
    if eventRunning then
        return
    end
    eventRunning = true
    Sound.SetEventMusic(true)
    task.spawn(function()
        local config = MeteorFx.Lightning
        while isEventActive() do
            strikeLightning()
            task.wait(config.minWait + math.random() * (config.maxWait - config.minWait))
        end
        eventRunning = false
        Sound.SetEventMusic(false)
    end)
end

-- Cuenta atrás grande en pantalla para los meteoritos de evento.
local function getCountdownLabel(): TextLabel
    if countdownLabel then
        return countdownLabel
    end
    local gui = Instance.new("ScreenGui")
    -- Los textos ya salen en el idioma elegido: sin traducción automática de Roblox.
    gui.AutoLocalize = false
    gui.Name = "MeteorCountdown"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 8
    local label = Instance.new("TextLabel")
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.fromScale(0.5, 0.22)
    label.Size = UDim2.fromScale(0.5, 0.08)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextStrokeTransparency = 0.2
    label.Visible = false
    label.Parent = gui
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    countdownLabel = label
    return label
end

-- Anuncio de un meteorito de evento: aviso grande, cielo que empieza a teñirse, rayos y música.
local function announceEvent(position: Vector3, meteorType: MeteorsConfig.MeteorType)
    eventPending += 1
    eventPosition = position
    AmbienceController.SetOverride("giantIncoming", true)
    Banner.Show({
        heading = Strings.Meteor.GiantDetected,
        title = Strings.Meteor.GiantTitle,
        subtitle = Strings.Meteor.GiantSubtitle,
        color = meteorType.glowColor,
        sound = "GiantWarning",
    })
    runEvent()
end

-- Antes de que entre un meteorito de evento: un sonido lejano, una luz en el cielo en el
-- punto del que vendrá y temblores cada vez más fuertes hasta que empieza a caer.
local function buildUp(
    position: Vector3,
    meteorType: MeteorsConfig.MeteorType,
    tier: MeteorFx.Tier,
    fallAt: number
)
    Sound.Play("GiantRumble")
    local star = makeEffectPart({
        name = "IncomingStar",
        size = Vector3.one * meteorType.radius,
        cframe = CFrame.new(fallStart(position, tier)),
        color = meteorType.glowColor,
        transparency = 0.1,
        shape = Enum.PartType.Ball,
    })
    TweenService:Create(
        star,
        TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Size = Vector3.one * meteorType.radius * 2.2 }
    ):Play()
    task.spawn(function()
        local startedAt = Workspace:GetServerTimeNow()
        while Workspace:GetServerTimeNow() < fallAt do
            local progress = math.clamp(
                (Workspace:GetServerTimeNow() - startedAt) / math.max(fallAt - startedAt, 1),
                0,
                1
            )
            Effects.Shake(
                MeteorFx.RumbleStart + (MeteorFx.RumbleEnd - MeteorFx.RumbleStart) * progress,
                0.5
            )
            task.wait(MeteorFx.RumbleSeconds)
        end
        star:Destroy()
    end)
end

local function onMeteorIncoming(id: any, typeId: any, position: any, impactAt: any)
    if
        type(id) ~= "number"
        or type(typeId) ~= "string"
        or typeof(position) ~= "Vector3"
        or type(impactAt) ~= "number"
    then
        return
    end
    local meteorType = MeteorsConfig.Types[typeId]
    if meteorType == nil then
        return
    end
    local tier = MeteorFx.GetTier(typeId)

    local marker, label = createMarker(position, meteorType, tier)
    local fallSeconds = fallDuration(tier)
    local screenLabel: TextLabel? = nil
    if tier.isEvent then
        announceEvent(position, meteorType)
        buildUp(position, meteorType, tier, impactAt - fallSeconds)
        screenLabel = getCountdownLabel()
        screenLabel.TextColor3 = meteorType.glowColor
        screenLabel.Visible = true
    else
        Sound.Play(tier.warningSound)
    end

    local fallStarted = false
    local connection: RBXScriptConnection? = nil
    connection = RunService.RenderStepped:Connect(function()
        local remaining = impactAt - Workspace:GetServerTimeNow()
        local seconds = math.max(math.ceil(remaining), 0)
        label.Text = string.format(Strings.Meteor.ImpactLabel, seconds)
        if screenLabel then
            screenLabel.Text = string.format(Strings.Meteor.GiantCountdown, seconds)
        end

        if not fallStarted and remaining <= fallSeconds then
            fallStarted = true
            playFall(position, meteorType)
        end
        if remaining <= 0 then
            if connection then
                connection:Disconnect()
            end
            marker:Destroy()
            if tier.isEvent then
                -- A partir de aquí manda el atributo GiantActive, que pone el servidor al caer.
                if screenLabel then
                    screenLabel.Visible = false
                end
                task.delay(2, function()
                    eventPending -= 1
                    if eventPending <= 0 then
                        AmbienceController.SetOverride("giantIncoming", false)
                    end
                end)
            end
        end
    end)
end

local function findMeteorInstance(meteorId: number): PVInstance?
    local folder = Workspace:FindFirstChild("Meteors")
    if folder == nil then
        return nil
    end
    for _, child in folder:GetChildren() do
        if child:GetAttribute("MeteorId") == meteorId and child:IsA("PVInstance") then
            return child
        end
    end
    return nil
end

local function getProgressGui(): (BillboardGui, Frame)
    if progressGui and progressFill then
        return progressGui, progressFill
    end

    local billboard = Instance.new("BillboardGui")
    -- Los textos ya salen en el idioma elegido: sin traducción automática de Roblox.
    billboard.AutoLocalize = false
    billboard.Name = "MiningProgress"
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.Size = UDim2.fromScale(6, 1)
    billboard.Enabled = false
    billboard.ResetOnSpawn = false

    local background = Instance.new("Frame")
    background.Size = UDim2.fromScale(1, 1)
    background.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    background.BackgroundTransparency = 0.3
    background.BorderSizePixel = 0
    background.Parent = billboard
    local backgroundCorner = Instance.new("UICorner")
    backgroundCorner.CornerRadius = UDim.new(0.5, 0)
    backgroundCorner.Parent = background

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = PROGRESS_COLOR
    fill.BorderSizePixel = 0
    fill.Parent = background
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0.5, 0)
    fillCorner.Parent = fill

    billboard.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    progressGui = billboard
    progressFill = fill
    return billboard, fill
end

local function onMineState(state: any, meteorId: any, duration: any)
    local billboard, fill = getProgressGui()
    if progressTween then
        progressTween:Cancel()
        progressTween = nil
    end

    if state ~= "start" or type(meteorId) ~= "number" or type(duration) ~= "number" then
        billboard.Enabled = false
        return
    end
    local meteor = findMeteorInstance(meteorId)
    if meteor == nil then
        billboard.Enabled = false
        return
    end

    local radius = meteor:GetAttribute("Radius")
    -- Un BillboardGui se engancha a una parte: en un modelo, a su parte principal.
    local adornee: Instance = meteor
    if meteor:IsA("Model") then
        adornee = meteor.PrimaryPart or meteor:FindFirstChildWhichIsA("BasePart", true) or meteor
    end
    -- Cada "start" después del primero significa que se completó un golpe.
    if billboard.Enabled and billboard.Adornee == adornee then
        local character = Players.LocalPlayer.Character
        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
        local origin = meteor:GetPivot().Position
        local toward = if root and root:IsA("BasePart")
            then (root.Position - origin).Unit
            else Vector3.yAxis
        local meteorRadius = if type(radius) == "number" then radius else 4
        local surface = origin + toward * meteorRadius
        local meteorType = MeteorsConfig.Types[meteor:GetAttribute("MeteorType") :: any]
        burst(surface, SPARK_COLOR, 12, 12, 0.4)
        Effects.Sparks({
            position = surface,
            direction = toward,
            color = SPARK_COLOR,
            count = 4,
            length = 2.5,
        })
        Effects.Fragments({
            position = surface,
            direction = toward,
            color = if meteorType then meteorType.color else DUST_COLOR,
            count = 3,
            size = 0.5,
            speed = 22,
        })
        -- Cuanto más grande el meteorito, más grave suena el golpe.
        Sound.Play("MineHit", { pitch = math.clamp(1.15 - meteorRadius * 0.03, 0.75, 1.1) })
        Effects.Shake(0.12, 0.12)
    end
    billboard.Adornee = adornee
    billboard.StudsOffsetWorldSpace =
        Vector3.new(0, (if type(radius) == "number" then radius else 4) + 2, 0)
    billboard.Enabled = true
    fill.Size = UDim2.fromScale(0, 1)
    -- Cada golpe nuevo empieza con un destello blanco que vuelve al dorado.
    fill.BackgroundColor3 = Color3.new(1, 1, 1)
    TweenService:Create(fill, TweenInfo.new(0.25), { BackgroundColor3 = PROGRESS_COLOR }):Play()
    local tween = TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Size = UDim2.fromScale(1, 1),
    })
    tween:Play()
    progressTween = tween
end

-- Devuelve el id y la posición del meteorito activo más cercano cuya superficie está a
-- `range` studs o menos.
function MeteorController.GetNearestMeteor(position: Vector3, range: number): (number?, Vector3?)
    local folder = Workspace:FindFirstChild("Meteors")
    if folder == nil then
        return nil
    end
    local bestId: number? = nil
    local bestPosition: Vector3? = nil
    local bestDistance = math.huge
    for _, child in folder:GetChildren() do
        local id = child:GetAttribute("MeteorId")
        local radius = child:GetAttribute("Radius")
        if type(id) == "number" and type(radius) == "number" and child:IsA("PVInstance") then
            local meteorPosition = child:GetPivot().Position
            local distance = (meteorPosition - position).Magnitude - radius
            if distance <= range and distance < bestDistance then
                bestId = id
                bestPosition = meteorPosition
                bestDistance = distance
            end
        end
    end
    return bestId, bestPosition
end

-- Texto flotante con el mineral conseguido, del color de su mutación o de su rareza.
local lastRewardAt = 0

local function onMineReward(position: any, radius: any, mineralId: any, mutationId: any)
    if
        typeof(position) ~= "Vector3"
        or type(radius) ~= "number"
        or type(mineralId) ~= "string"
        or type(mutationId) ~= "string"
    then
        return
    end
    local mineral = Minerals.ById[mineralId]
    if mineral == nil then
        return
    end
    local mutation = Mutations.ById[mutationId]
    local mutationColor = if mutation then mutation.color else nil
    local color = mutationColor or Minerals.Rarities[mineral.rarity].color
    local rank = Minerals.GetRank(mineralId)

    local character = Players.LocalPlayer.Character
    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
    local toward = if root and root:IsA("BasePart")
        then (root.Position - position).Unit
        else Vector3.yAxis
    local origin = position + toward * radius + Vector3.new(0, 2, 0)

    -- Segundo mineral del mismo golpe: sale un poco más arriba y con su propio aviso.
    local now = os.clock()
    local isDouble = now - lastRewardAt < DOUBLE_WINDOW
    lastRewardAt = now
    if isDouble then
        origin += Vector3.new(0, 2.2, 0)
        Sound.Play("DoubleMineral")
        Effects.Popup({
            position = origin + Vector3.new(0, 1.8, 0),
            text = Strings.Mining.Double,
            color = SPARK_COLOR,
            height = 1.3,
        })
    end

    burst(origin, mineral.color, 10 + rank * 3, 10, 0.5)
    Sound.Play("MineralObtained")
    Effects.Popup({
        position = origin,
        text = string.format(Strings.Mining.Obtained, RarityStyle.Text(mineralId, mutationId)),
        color = color,
        -- Cuanto más raro, más grande el texto.
        height = 1.4 + rank * 0.18,
        duration = POPUP_DURATION,
        rise = POPUP_RISE,
    })

    -- Mutación: su propia secuencia de descubrimiento (texto, ráfaga, ondas, rayos y sonido).
    if mutation and mutation.id ~= Mutations.NoneId then
        MutationFxController.Reveal(origin, mutation.id, true)
    end
    -- Momento de descubrimiento, a la medida de la rareza: de un sonido para un Raro al
    -- momento cinematográfico de un Mítico.
    DiscoveryMoment.Play(mineralId, mutationId, origin)
end

-- Meteoritos en el suelo: energía que late y crece según se gastan, y su final.
local tracked: { [Instance]: Tracked } = {}
local craters = 0

-- Cráter temporal: una marca quemada con un rescoldo del color del meteorito que se va
-- apagando. Hay un máximo a la vez.
local function leaveCrater(position: Vector3, meteorType: MeteorsConfig.MeteorType)
    if craters >= MeteorFx.MaxCraters then
        return
    end
    craters += 1
    local radius = meteorType.radius
    local ground = Vector3.new(position.X, 0.3, position.Z)
    local seconds = MeteorFx.CraterSeconds
    local scar = makeEffectPart({
        name = "Crater",
        size = Vector3.new(0.05, radius * 3.4, radius * 3.4),
        cframe = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90)),
        color = CRATER_COLOR,
        transparency = 0.15,
        shape = Enum.PartType.Cylinder,
    })
    scar.Material = Enum.Material.Slate
    local embers = makeEffectPart({
        name = "CraterGlow",
        size = Vector3.new(0.06, radius * 1.4, radius * 1.4),
        cframe = CFrame.new(ground + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        color = meteorType.glowColor,
        transparency = 0.45,
        shape = Enum.PartType.Cylinder,
    })
    local fade = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    TweenService:Create(scar, fade, { Transparency = 1 }):Play()
    TweenService:Create(embers, TweenInfo.new(seconds * 0.3), { Transparency = 1 }):Play()
    task.delay(seconds, function()
        craters -= 1
        scar:Destroy()
        embers:Destroy()
    end)
end

-- Secuencia final. Si se ha minado entero revienta: ráfaga, fragmentos, onda, destello,
-- sonido y recompensas que suben flotando. Si se le acaba el tiempo, se apaga sin más.
local function playBreak(meteor: Instance)
    local state = tracked[meteor]
    tracked[meteor] = nil
    if state == nil then
        return
    end
    local meteorType, tier, position = state.meteorType, state.tier, state.position
    local radius = meteorType.radius
    local ground = Vector3.new(position.X, 0.3, position.Z)
    leaveCrater(position, meteorType)
    Effects.Dust({
        position = ground,
        color = DUST_COLOR,
        count = math.floor(4 + radius),
        size = radius,
        ignoreDistance = tier.isEvent,
    })

    if state.hitsLeft > 1 then
        Effects.Burst({
            position = position,
            color = DUST_COLOR,
            count = math.floor(radius * 4),
            speed = radius * 3,
            size = radius * 0.3,
        })
        return
    end

    Effects.Burst({
        position = position,
        color = meteorType.glowColor,
        count = math.floor(radius * 7),
        speed = radius * 5,
        size = radius * 0.3,
        lifetime = 1.1,
        ignoreDistance = tier.isEvent,
    })
    Effects.Fragments({
        position = position,
        direction = Vector3.yAxis,
        color = meteorType.color,
        count = tier.breakFragments,
        size = radius * 0.25,
        speed = 30,
    })
    Effects.Shockwave({
        position = ground,
        radius = radius * 3,
        color = meteorType.glowColor,
        ignoreDistance = tier.isEvent,
    })

    local distance = distanceToPlayer(position)
    if tier.isEvent or distance <= MeteorFx.HearRange then
        Sound.Play(tier.breakSound, { duck = tier.isEvent })
    end
    if tier.breakFlash > 0 and (tier.isEvent or distance <= FLASH_RANGE) then
        Effects.Flash(meteorType.glowColor, tier.breakFlash, 0.8)
    end
    if tier.breakShake then
        shakeAt(position, tier.breakShake)
    end

    -- Recompensas flotando: destellos con los colores de las rarezas que suben desde los restos.
    for index = 1, tier.rewardPopups do
        task.delay(index * 0.08, function()
            local mineral = Minerals.List[math.random(1, #Minerals.List)]
            local angle = math.random() * math.pi * 2
            Effects.Popup({
                position = position
                    + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * math.random(),
                text = "✦",
                color = Minerals.Rarities[mineral.rarity].color,
                height = 1.5 + radius * 0.12,
                duration = 1.6,
                rise = 6 + radius * 0.6,
            })
        end)
    end
end

-- Late la luz de cada meteorito y sube de intensidad a medida que se gasta; los grandes
-- tienen además un charco de energía en el suelo que respira.
local function updateEnergy()
    local pulse = math.sin(os.clock() * MeteorFx.EnergyPulseSpeed)
    for _, state in tracked do
        local spent = 1 - math.clamp(state.hitsLeft / state.meteorType.hits, 0, 1)
        local light = state.light
        if light then
            light.Brightness = state.baseBrightness
                * (1 + spent * MeteorFx.EnergyGrowth)
                * (1 + pulse * MeteorFx.EnergyPulseAmount)
        end
        local pool = state.pool
        if pool then
            pool.Transparency = 0.72 - spent * 0.2 + pulse * 0.1
        end
    end
end

-- Registra un meteorito recién caído: su energía, sus fragmentos al golpearlo y su barra con
-- los golpes que le quedan, visible para todos.
local function attachHitsBar(meteor: Instance)
    local typeId = meteor:GetAttribute("MeteorType")
    local radius = meteor:GetAttribute("Radius")
    local meteorType = if type(typeId) == "string" then MeteorsConfig.Types[typeId] else nil
    if
        meteorType == nil
        or type(radius) ~= "number"
        or not meteor:IsA("PVInstance")
        -- Si ya ha desaparecido no se registra: su estado se quedaría colgado para siempre.
        or meteor.Parent == nil
        or tracked[meteor]
    then
        return
    end
    local tier = MeteorFx.GetTier(meteorType.id)
    local position = meteor:GetPivot().Position
    local primary = if meteor:IsA("Model") then meteor.PrimaryPart else nil
    local light = if primary then primary:FindFirstChildOfClass("PointLight") else nil

    local pool: BasePart? = nil
    if tier.energyPool then
        local created = makeEffectPart({
            name = "EnergyPool",
            size = Vector3.new(0.12, radius * 3.6, radius * 3.6),
            cframe = CFrame.new(position.X, 0.34, position.Z) * CFrame.Angles(0, 0, math.rad(90)),
            color = meteorType.glowColor,
            transparency = 0.72,
            shape = Enum.PartType.Cylinder,
        })
        -- Dentro del meteorito: desaparece con él.
        created.Parent = meteor
        pool = created
    end

    -- Energía que se escapa del interior: nada al principio, cada vez más según se gasta.
    local leak: ParticleEmitter? = nil
    if primary then
        local created = Instance.new("ParticleEmitter")
        created.Name = "EnergyLeak"
        created.Color = ColorSequence.new(Color3.new(1, 1, 1), meteorType.glowColor)
        created.Size = NumberSequence.new(radius * 0.22, 0)
        created.Transparency = NumberSequence.new(0.2, 1)
        created.Lifetime = NumberRange.new(0.6, 1.2)
        created.Speed = NumberRange.new(radius * 1.2, radius * 2.4)
        created.SpreadAngle = Vector2.new(180, 180)
        created.LightEmission = 1
        created.Rate = 0
        created.Parent = primary
        leak = created
    end

    local state: Tracked = {
        meteorType = meteorType,
        tier = tier,
        position = position,
        hitsLeft = meteorType.hits,
        light = light,
        baseBrightness = if light then light.Brightness else 0,
        pool = pool,
    }
    tracked[meteor] = state

    local billboard = Instance.new("BillboardGui")
    -- Los textos ya salen en el idioma elegido: sin traducción automática de Roblox.
    billboard.AutoLocalize = false
    billboard.Name = "HitsBar"
    billboard.LightInfluence = 0
    billboard.Size = UDim2.fromScale(math.max(radius * 1.6, 6), 1.3)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, radius + 4, 0)
    billboard.MaxDistance = 250

    local background = Instance.new("Frame")
    background.Size = UDim2.fromScale(1, 1)
    background.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    background.BackgroundTransparency = 0.25
    background.BorderSizePixel = 0
    background.Parent = billboard
    local backgroundCorner = Instance.new("UICorner")
    backgroundCorner.CornerRadius = UDim.new(0.4, 0)
    backgroundCorner.Parent = background
    -- Borde del color del meteorito que se enciende a medida que se gasta.
    local glow = Instance.new("UIStroke")
    glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    glow.Color = meteorType.glowColor
    glow.Thickness = 2
    glow.Transparency = 1
    glow.Parent = background
    -- Salto pequeño de la barra con cada golpe.
    local punch = Instance.new("UIScale")
    punch.Parent = background

    -- Rastro blanco del daño reciente, detrás de la barra de color.
    local trail = Instance.new("Frame")
    trail.Name = "DamageTrail"
    trail.BackgroundColor3 = Color3.new(1, 1, 1)
    trail.BackgroundTransparency = 0.25
    trail.BorderSizePixel = 0
    trail.Size = UDim2.fromScale(1, 1)
    trail.Parent = background
    local trailCorner = Instance.new("UICorner")
    trailCorner.CornerRadius = UDim.new(0.4, 0)
    trailCorner.Parent = trail

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = HITS_BAR_COLOR
    fill.BorderSizePixel = 0
    fill.Size = UDim2.fromScale(1, 1)
    fill.Parent = background
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0.4, 0)
    fillCorner.Parent = fill

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.3
    label.Parent = background

    local function update()
        local hitsLeft = meteor:GetAttribute("HitsLeft")
        local left = if type(hitsLeft) == "number" then hitsLeft else meteorType.hits
        local fraction = math.clamp(left / meteorType.hits, 0, 1)
        local size = UDim2.fromScale(fraction, 1)
        local color = HITS_BAR_COLOR:Lerp(HITS_BAR_LOW_COLOR, 1 - fraction)
        label.Text = string.format(Strings.Mining.HitsLeft, left, meteorType.hits)
        glow.Transparency = 0.2 + fraction * 0.8
        if left < state.hitsLeft then
            TweenService:Create(fill, HITS_BAR_TWEEN, { Size = size, BackgroundColor3 = color })
                :Play()
            TweenService:Create(trail, HITS_TRAIL_TWEEN, { Size = size }):Play()
            punch.Scale = 1.12
            TweenService:Create(punch, HITS_PUNCH, { Scale = 1 }):Play()
        else
            fill.Size = size
            fill.BackgroundColor3 = color
            trail.Size = size
        end

        -- Cada golpe, lo dé quien lo dé, hace saltar un par de fragmentos en un punto al azar.
        if left < state.hitsLeft then
            local direction =
                Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5).Unit
            Effects.Fragments({
                position = position + direction * radius,
                direction = direction,
                color = meteorType.color,
                count = 2,
                size = 0.45,
                speed = 18,
            })
        end
        state.hitsLeft = left
        if leak then
            leak.Rate = (1 - math.clamp(left / meteorType.hits, 0, 1)) * tier.leakRate
        end
    end
    meteor:GetAttributeChangedSignal("HitsLeft"):Connect(update)
    update()

    -- Dentro del meteorito: desaparece con él. En un modelo se engancha a su parte principal.
    if meteor:IsA("Model") then
        billboard.Adornee = meteor.PrimaryPart or meteor:FindFirstChildWhichIsA("BasePart", true)
    end
    billboard.Parent = meteor
end

function MeteorController.Init()
    Remotes.MeteorIncoming.OnClientEvent:Connect(onMeteorIncoming)
    Remotes.MineState.OnClientEvent:Connect(onMineState)
    Remotes.MineReward.OnClientEvent:Connect(onMineReward)
end

-- Recoger del suelo un mineral que soltó otro jugador: feedback según su rareza. Lo que se
-- acaba de minar ya tiene su propio momento, así que se ignora.
local function watchPickups()
    local known: { [string]: boolean } = {}
    CarryController.OnChanged(function(items)
        local best: { id: string, mineral: string, mutation: string }? = nil
        local current: { [string]: boolean } = {}
        for _, item in items do
            current[item.id] = true
            if
                not known[item.id]
                and (best == nil or Minerals.GetRank(item.mineral) > Minerals.GetRank(best.mineral))
            then
                best = item
            end
        end
        known = current
        local picked = best
        if picked == nil then
            return
        end
        -- El aviso de lo minado llega justo después que el cambio de mochila: se espera un
        -- instante para saber si era eso.
        task.delay(PICKUP_CHECK_SECONDS, function()
            if os.clock() - lastRewardAt < PICKUP_CHECK_SECONDS * 3 then
                return
            end
            local character = Players.LocalPlayer.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            if root and root:IsA("BasePart") then
                DiscoveryMoment.Pickup(picked.mineral, picked.mutation, root.Position)
            end
        end)
    end)
end

function MeteorController.Start()
    watchPickups()
    task.spawn(function()
        local folder = Workspace:WaitForChild("Meteors")
        folder.ChildAdded:Connect(function(child)
            -- Se espera un instante a que lleguen sus atributos y sus partes.
            task.defer(attachHitsBar, child)
        end)
        folder.ChildRemoved:Connect(playBreak)
        for _, child in folder:GetChildren() do
            attachHitsBar(child)
        end
        RunService.Heartbeat:Connect(updateEnergy)
        -- Si se entra con un gigante ya en el suelo, sus rayos y su música empiezan igual.
        Workspace:GetAttributeChangedSignal("GiantActive"):Connect(function()
            if isEventActive() then
                runEvent()
            end
        end)
        if isEventActive() then
            runEvent()
        end
    end)
end

return MeteorController
