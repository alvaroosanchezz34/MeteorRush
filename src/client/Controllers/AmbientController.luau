--!strict

-- Vida ambiental del mapa, solo visual y solo en el cliente:
--   * sucesos corrientes al azar: meteoritos pequeños que se queman en el cielo, satélites y
--     naves lejanas (uno cada cierto tiempo, nunca varios a la vez)
--   * sucesos raros que elige el servidor para todos: lluvia de estrellas, cometa, eclipse,
--     anomalía espacial y portal temporal
--   * luces del decorado que laten (solo las cercanas) y polvo espacial alrededor de la cámara
-- Las estrellas fugaces, las nebulosas, el planeta y las rocas flotantes los lleva SkyController.
-- Todo son unas pocas piezas de vida corta; en móvil las cantidades se reducen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AmbienceController = require(script.Parent.AmbienceController)
local Effects = require(script.Parent.Parent.UI.Effects)
local Notifications = require(script.Parent.Parent.UI.Notifications)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AmbientConfig = require(Config:WaitForChild("Ambient"))
local MapConfig = require(Config:WaitForChild("Map"))
local Strings = require(Shared:WaitForChild("Strings"))
local WeightedRandom = require(Shared:WaitForChild("Util"):WaitForChild("WeightedRandom"))

local HINT_COLOR = Color3.fromRGB(190, 200, 255)
local STAR_COLOR = Color3.fromRGB(200, 225, 255)
local METEOR_COLOR = Color3.fromRGB(255, 150, 70)
local COMET_COLOR = Color3.fromRGB(150, 220, 255)
local ANOMALY_COLOR = Color3.fromRGB(170, 90, 255)
local PORTAL_COLOR = Color3.fromRGB(80, 230, 255)
local ECLIPSE_HALO = Color3.fromRGB(255, 150, 80)
local LINEAR = Enum.EasingStyle.Linear

type PulseLight = { light: PointLight, base: number, position: Vector3, phase: number }

local AmbientController = {}

local random = Random.new()
local folder: Folder? = nil
-- En móvil se dibuja menos de todo.
local scale = 1

local function getFolder(): Folder
    if folder then
        return folder
    end
    local created = Instance.new("Folder")
    created.Name = "AmbientEffects"
    created.Parent = Workspace
    folder = created
    return created
end

local function isEnabled(): boolean
    return Workspace:GetAttribute("Feature_ambient") ~= false
end

local function skyPart(name: string, size: Vector3, cframe: CFrame, color: Color3): Part
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
    return part
end

-- Estela detrás de una pieza que se mueve.
local function addTrail(part: BasePart, width: number, lifetime: number, color: Color3)
    local top = Instance.new("Attachment")
    top.Position = Vector3.new(0, width / 2, 0)
    top.Parent = part
    local bottom = Instance.new("Attachment")
    bottom.Position = Vector3.new(0, -width / 2, 0)
    bottom.Parent = part
    local trail = Instance.new("Trail")
    trail.Attachment0 = top
    trail.Attachment1 = bottom
    trail.Lifetime = lifetime
    trail.LightEmission = 1
    trail.FaceCamera = true
    trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
    trail.Transparency = NumberSequence.new(0.1, 1)
    trail.WidthScale = NumberSequence.new(1, 0)
    trail.Parent = part
end

-- Mueve una pieza en línea recta y la destruye al llegar (con todo lo que lleve dentro).
local function fly(part: BasePart, target: Vector3, seconds: number, fade: boolean?)
    local goal: { [string]: any } =
        { CFrame = CFrame.lookAt(target, target + (target - part.Position)) }
    if fade then
        goal.Transparency = 1
    end
    local tween = TweenService:Create(part, TweenInfo.new(seconds, LINEAR), goal)
    tween.Completed:Connect(function()
        part:Destroy()
    end)
    tween:Play()
end

local function polar(angle: number, radius: number, height: number): Vector3
    return Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
end

-- Sucesos corrientes ---------------------------------------------------------------------

-- Estrella fugaz en una dirección dada (las sueltas las lanza SkyController).
local function star(rng: Random, direction: Vector3)
    local start =
        Vector3.new(rng:NextNumber(-900, 900), rng:NextNumber(450, 720), rng:NextNumber(-900, 900))
    local part = skyPart("Star", Vector3.one * 3, CFrame.new(start), Color3.new(1, 1, 1))
    part.Shape = Enum.PartType.Ball
    addTrail(part, 2.4, 0.5, STAR_COLOR)
    fly(part, start + direction * 700, rng:NextNumber(0.9, 1.5), true)
end

-- Meteorito pequeño que entra en la atmósfera y se quema antes de llegar al suelo.
local function skyMeteor()
    local start = polar(
        random:NextNumber(0, math.pi * 2),
        random:NextNumber(350, 900),
        random:NextNumber(480, 650)
    )
    local direction = Vector3.new(random:NextNumber(-1, 1), -0.7, random:NextNumber(-1, 1)).Unit
    local part = skyPart("SkyMeteor", Vector3.one * 5, CFrame.new(start), METEOR_COLOR)
    part.Shape = Enum.PartType.Ball
    addTrail(part, 4, 0.7, METEOR_COLOR)
    local embers = Instance.new("ParticleEmitter")
    embers.Color = ColorSequence.new(METEOR_COLOR)
    embers.Size = NumberSequence.new(2, 0)
    embers.Lifetime = NumberRange.new(0.3, 0.6)
    embers.Speed = NumberRange.new(4, 10)
    embers.SpreadAngle = Vector2.new(180, 180)
    embers.LightEmission = 1
    embers.Rate = 14
    embers.Parent = part
    fly(part, start + direction * 420, random:NextNumber(1.8, 2.6), true)
end

-- Satélite: cruza el cielo muy despacio, con una luz que parpadea.
local function satellite()
    local angle = random:NextNumber(0, math.pi * 2)
    local height = random:NextNumber(380, 520)
    local start = polar(angle, 1000, height)
    local target = polar(angle + math.pi + random:NextNumber(-0.6, 0.6), 1000, height)
    local body = skyPart(
        "Satellite",
        Vector3.new(3, 3, 7),
        CFrame.lookAt(start, target),
        Color3.fromRGB(150, 155, 170)
    )
    body.Material = Enum.Material.Metal
    local panel =
        skyPart("Panel", Vector3.new(16, 0.3, 4), body.CFrame, Color3.fromRGB(50, 90, 180))
    panel.Material = Enum.Material.Glass
    local light = skyPart(
        "Blink",
        Vector3.one * 2.5,
        body.CFrame * CFrame.new(0, 2.5, 0),
        Color3.fromRGB(255, 80, 80)
    )
    light.Shape = Enum.PartType.Ball
    TweenService:Create(
        light,
        TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Transparency = 1 }
    ):Play()
    -- Las otras dos piezas van soldadas al cuerpo: basta con mover (y destruir) el cuerpo.
    for _, piece in { panel, light } do
        piece.Anchored = false
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = body
        weld.Part1 = piece
        weld.Parent = piece
        piece.Parent = body
    end
    fly(body, target, random:NextNumber(40, 55))
end

-- Nave lejana: silueta con un motor encendido que cruza a lo lejos. Devuelve la nave.
local function ship(start: Vector3, target: Vector3, seconds: number)
    local body = skyPart(
        "Ship",
        Vector3.new(10, 4, 26),
        CFrame.lookAt(start, target),
        Color3.fromRGB(90, 95, 115)
    )
    body.Material = Enum.Material.Metal
    local wings = skyPart(
        "Wings",
        Vector3.new(30, 1, 10),
        body.CFrame * CFrame.new(0, 0, 4),
        Color3.fromRGB(70, 75, 95)
    )
    wings.Material = Enum.Material.Metal
    local engine =
        skyPart("Engine", Vector3.new(5, 3, 2), body.CFrame * CFrame.new(0, 0, 14), PORTAL_COLOR)
    for _, piece in { wings, engine } do
        piece.Anchored = false
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = body
        weld.Part1 = piece
        weld.Parent = piece
        piece.Parent = body
    end
    addTrail(body, 5, 1.2, PORTAL_COLOR)
    fly(body, target, seconds)
end

local function distantShip()
    local angle = random:NextNumber(0, math.pi * 2)
    local height = random:NextNumber(230, 380)
    ship(
        polar(angle, 1100, height),
        polar(
            angle + math.pi * random:NextNumber(0.55, 0.85),
            1100,
            height + random:NextNumber(-60, 60)
        ),
        random:NextNumber(26, 36)
    )
end

local COMMON: { [string]: () -> () } = {
    skyMeteor = skyMeteor,
    satellite = satellite,
    ship = distantShip,
}

-- Sucesos raros --------------------------------------------------------------------------
-- Reciben un generador con la semilla del servidor (para que todos vean lo mismo) y los
-- segundos que quedan.

-- Lluvia de estrellas: muchas estrellas fugaces en la misma dirección.
local function starShower(rng: Random, seconds: number)
    local direction = Vector3.new(rng:NextNumber(-1, 1), -0.3, rng:NextNumber(-1, 1)).Unit
    local count = math.max(math.floor(AmbientConfig.StarShowerCount * scale), 6)
    for _ = 1, count do
        task.delay(rng:NextNumber(0, seconds * 0.85), star, rng, direction)
    end
end

-- Cometa: una cabeza brillante con una cola larga que cruza todo el cielo.
local function comet(rng: Random, seconds: number)
    local angle = rng:NextNumber(0, math.pi * 2)
    local start = polar(angle, 1500, rng:NextNumber(520, 700))
    local target =
        polar(angle + math.pi + rng:NextNumber(-0.4, 0.4), 1500, rng:NextNumber(420, 560))
    local head =
        skyPart("Comet", Vector3.one * 22, CFrame.lookAt(start, target), Color3.new(1, 1, 1))
    head.Shape = Enum.PartType.Ball
    addTrail(head, 20, 4, COMET_COLOR)
    local tail = Instance.new("ParticleEmitter")
    tail.Color = ColorSequence.new(COMET_COLOR)
    tail.Size = NumberSequence.new(9, 0)
    tail.Transparency = NumberSequence.new(0.3, 1)
    tail.Lifetime = NumberRange.new(1.5, 2.5)
    tail.Speed = NumberRange.new(2, 8)
    tail.SpreadAngle = Vector2.new(180, 180)
    tail.LightEmission = 1
    tail.Rate = 16 * scale
    tail.Parent = head
    fly(head, target, seconds)
end

-- Eclipse: un cuerpo oscuro con un halo encendido aparece en el cielo y el mapa se oscurece.
local function eclipse(rng: Random, seconds: number)
    local position = polar(rng:NextNumber(0, math.pi * 2), 1300, 900)
    local toMap = CFrame.lookAt(position, Vector3.zero)
    local body = skyPart("Eclipse", Vector3.one * 260, CFrame.new(position), Color3.new(0, 0, 0))
    body.Shape = Enum.PartType.Ball
    body.Material = Enum.Material.SmoothPlastic
    body.Transparency = 1
    -- Halo: un disco luminoso detrás del cuerpo oscuro, de cara al mapa.
    local halo = skyPart(
        "EclipseHalo",
        Vector3.new(4, 330, 330),
        toMap * CFrame.new(0, 0, 30) * CFrame.Angles(0, math.pi / 2, 0),
        ECLIPSE_HALO
    )
    halo.Shape = Enum.PartType.Cylinder
    halo.Transparency = 1

    local fadeSeconds = math.min(5, seconds / 3)
    local fade = TweenInfo.new(fadeSeconds, Enum.EasingStyle.Sine)
    TweenService:Create(body, fade, { Transparency = 0 }):Play()
    TweenService:Create(halo, fade, { Transparency = 0.25 }):Play()
    AmbienceController.SetOverride("eclipse", true)
    task.delay(math.max(seconds - fadeSeconds, 0), function()
        AmbienceController.SetOverride("eclipse", false)
        TweenService:Create(body, fade, { Transparency = 1 }):Play()
        TweenService:Create(halo, fade, { Transparency = 1 }):Play()
        task.wait(fadeSeconds)
        body:Destroy()
        halo:Destroy()
    end)
end

-- Gira unas piezas alrededor de un punto durante unos segundos y luego avisa.
local function spin(parts: { BasePart }, center: CFrame, seconds: number, onDone: () -> ())
    local origins: { CFrame } = {}
    for index, part in parts do
        origins[index] = center:ToObjectSpace(part.CFrame)
    end
    local started = os.clock()
    local connection: RBXScriptConnection? = nil
    connection = RunService.Heartbeat:Connect(function()
        local elapsed = os.clock() - started
        if elapsed >= seconds then
            if connection then
                connection:Disconnect()
            end
            onDone()
            return
        end
        for index, part in parts do
            local direction = if index % 2 == 0 then -1 else 1
            part.CFrame = center
                * CFrame.Angles(0, elapsed * 0.9 * direction, elapsed * 0.4 * direction)
                * origins[index]
        end
    end)
end

-- Anomalía espacial: una esfera inestable con anillos girando sobre el borde del mapa, que
-- acaba colapsando con un destello.
local function anomaly(rng: Random, seconds: number)
    local position = polar(rng:NextNumber(0, math.pi * 2), MapConfig.ImpactZoneRadius + 40, 120)
    local center = CFrame.new(position)
    local core = skyPart("Anomaly", Vector3.one * 12, center, ANOMALY_COLOR)
    core.Shape = Enum.PartType.Ball
    core.Transparency = 0.2
    TweenService:Create(
        core,
        TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Size = Vector3.one * 16 }
    ):Play()
    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(ANOMALY_COLOR, Color3.new(1, 1, 1))
    particles.Size = NumberSequence.new(1.4, 0)
    particles.Lifetime = NumberRange.new(1, 1.8)
    particles.Speed = NumberRange.new(6, 12)
    particles.SpreadAngle = Vector2.new(180, 180)
    particles.LightEmission = 1
    particles.Rate = 12 * scale
    particles.Parent = core

    local rings: { BasePart } = {}
    for index = 1, 2 do
        local ring = skyPart(
            "AnomalyRing",
            Vector3.new(0.5, 30 + index * 8, 30 + index * 8),
            center * CFrame.Angles(index * 1.1, 0, index * 0.7),
            ANOMALY_COLOR:Lerp(Color3.new(1, 1, 1), 0.3)
        )
        ring.Shape = Enum.PartType.Cylinder
        ring.Transparency = 0.75
        table.insert(rings, ring)
    end
    spin(rings, center, seconds, function()
        Effects.Burst({
            position = position,
            color = ANOMALY_COLOR,
            count = 50,
            speed = 40,
            size = 2,
            lifetime = 1.2,
            ignoreDistance = true,
        })
        core:Destroy()
        for _, ring in rings do
            ring:Destroy()
        end
    end)
end

-- Portal temporal: un disco de energía se abre en el cielo, sale una nave y se cierra.
local function portal(rng: Random, seconds: number)
    local angle = rng:NextNumber(0, math.pi * 2)
    local position = polar(angle, MapConfig.PlotRingRadius + 160, 150)
    -- De cara al centro del mapa (el eje del cilindro es X).
    local facing = CFrame.lookAt(position, Vector3.new(0, 150, 0))
        * CFrame.Angles(0, math.pi / 2, 0)
    local disc = skyPart("Portal", Vector3.new(1, 2, 2), facing, PORTAL_COLOR)
    disc.Shape = Enum.PartType.Cylinder
    disc.Transparency = 0.35
    local heart =
        skyPart("PortalHeart", Vector3.new(1.4, 1.5, 1.5), facing, Color3.fromRGB(20, 30, 70))
    heart.Shape = Enum.PartType.Cylinder
    local sparks = Instance.new("ParticleEmitter")
    sparks.Color = ColorSequence.new(PORTAL_COLOR, Color3.new(1, 1, 1))
    sparks.Size = NumberSequence.new(2, 0)
    sparks.Lifetime = NumberRange.new(0.8, 1.4)
    sparks.Speed = NumberRange.new(10, 20)
    sparks.SpreadAngle = Vector2.new(180, 180)
    sparks.LightEmission = 1
    sparks.Rate = 14 * scale
    sparks.Parent = disc

    local open =
        TweenInfo.new(math.min(3, seconds / 4), Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    TweenService:Create(disc, open, { Size = Vector3.new(1, 70, 70) }):Play()
    TweenService:Create(heart, open, { Size = Vector3.new(1.4, 56, 56) }):Play()

    -- A media vida sale una nave hacia el otro lado del cielo.
    task.delay(seconds * 0.4, function()
        ship(position, polar(angle + math.pi, 1300, 330), math.max(seconds * 0.55, 8))
    end)
    task.delay(math.max(seconds - 3, 0), function()
        local close = TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        sparks.Enabled = false
        TweenService:Create(disc, close, { Size = Vector3.new(1, 1, 1), Transparency = 1 }):Play()
        TweenService:Create(heart, close, { Size = Vector3.new(1.4, 1, 1), Transparency = 1 })
            :Play()
        task.wait(2.6)
        disc:Destroy()
        heart:Destroy()
    end)
end

local RARE: { [string]: (rng: Random, seconds: number) -> () } = {
    starShower = starShower,
    comet = comet,
    eclipse = eclipse,
    anomaly = anomaly,
    portal = portal,
}

local lastRareStart = 0

-- Dibuja el suceso raro que marca el servidor. Si se entra con uno a medias, se ve lo que queda.
local function onRareEvent()
    local id = Workspace:GetAttribute("AmbientEvent")
    local startedAt = Workspace:GetAttribute("AmbientEventStart")
    local seed = Workspace:GetAttribute("AmbientEventSeed")
    if type(id) ~= "string" or type(startedAt) ~= "number" or type(seed) ~= "number" then
        return
    end
    local event = AmbientConfig.RareById[id]
    local play = RARE[id]
    if event == nil or play == nil or startedAt == lastRareStart or not isEnabled() then
        return
    end
    local remaining = event.duration - (Workspace:GetServerTimeNow() - startedAt)
    if remaining < 4 then
        return
    end
    lastRareStart = startedAt
    local hint = Strings.Ambient[id]
    if hint then
        Notifications.Show(hint, HINT_COLOR)
    end
    play(Random.new(seed), remaining)
end

-- Luces que laten y polvo espacial --------------------------------------------------------

local function startPulsingLights(roots: { Instance })
    local lights: { PulseLight } = {}
    for _, root in roots do
        for _, descendant in root:GetDescendants() do
            local parent = descendant.Parent
            if descendant:IsA("PointLight") and parent and parent:IsA("BasePart") then
                table.insert(lights, {
                    light = descendant,
                    base = descendant.Brightness,
                    position = parent.Position,
                    phase = random:NextNumber(0, math.pi * 2),
                })
            end
        end
    end

    local nearby: { PulseLight } = {}
    local limit = math.max(math.floor(AmbientConfig.PulseMaxLights * scale), 4)
    -- Cada segundo se eligen las luces cercanas; las que dejan de serlo vuelven a su brillo.
    task.spawn(function()
        while true do
            local camera = Workspace.CurrentCamera
            local selected: { PulseLight } = {}
            if camera then
                local focus = camera.CFrame.Position
                for _, entry in lights do
                    if
                        #selected < limit
                        and (entry.position - focus).Magnitude <= AmbientConfig.PulseDistance
                    then
                        table.insert(selected, entry)
                    end
                end
            end
            for _, entry in nearby do
                if not table.find(selected, entry) then
                    entry.light.Brightness = entry.base
                end
            end
            nearby = selected
            task.wait(1)
        end
    end)
    task.spawn(function()
        while true do
            local now = os.clock()
            for _, entry in nearby do
                entry.light.Brightness = entry.base
                    * (1 + math.sin(now * 1.7 + entry.phase) * AmbientConfig.PulseAmount)
            end
            task.wait(1 / AmbientConfig.PulseRate)
        end
    end)
end

-- Motas de polvo alrededor de la cámara: un solo emisor que la sigue.
local function startDust()
    local holder =
        skyPart("SpaceDust", Vector3.new(80, 30, 80), CFrame.identity, Color3.new(1, 1, 1))
    holder.Transparency = 1
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(STAR_COLOR)
    emitter.Size = NumberSequence.new(0.22, 0)
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.25, 0.35),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Lifetime = NumberRange.new(5, 8)
    emitter.Speed = NumberRange.new(0.3, 1.2)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.LightEmission = 0.8
    emitter.Rate = AmbientConfig.DustRate * scale
    emitter.Parent = holder
    task.spawn(function()
        while true do
            local camera = Workspace.CurrentCamera
            if camera then
                holder.CFrame = CFrame.new(camera.CFrame.Position)
            end
            emitter.Enabled = isEnabled()
            task.wait(0.25)
        end
    end)
end

function AmbientController.Start()
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        scale = AmbientConfig.MobileScale
    end

    -- Sucesos corrientes: uno cada cierto tiempo, elegido por peso.
    local names: { string } = {}
    for name in COMMON do
        table.insert(names, name)
    end
    table.sort(names)
    task.spawn(function()
        while true do
            task.wait(random:NextNumber(AmbientConfig.CommonMinWait, AmbientConfig.CommonMaxWait))
            local name = WeightedRandom.Pick(names, function(candidate: string): number
                return AmbientConfig.CommonWeights[candidate] or 0
            end, random)
            if name and isEnabled() then
                COMMON[name]()
            end
        end
    end)

    Workspace:GetAttributeChangedSignal("AmbientEvent"):Connect(onRareEvent)
    onRareEvent()

    startDust()
    task.spawn(function()
        -- Luces del decorado y de los puestos de los NPCs.
        local map = Workspace:WaitForChild("Map")
        local roots: { Instance } = { map:WaitForChild("Scenery") }
        local npcs = map:FindFirstChild("Npcs")
        if npcs then
            table.insert(roots, npcs)
        end
        startPulsingLights(roots)
    end)
end

return AmbientController
