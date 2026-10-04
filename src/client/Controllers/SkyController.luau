--!strict

-- Vida en el cielo y en la zona central, solo en el cliente y con muy pocas piezas:
--   * el planeta se desplaza muy despacio, su anillo gira y una luna lo orbita
--   * los asteroides derivan alrededor del mapa (unos pocos por fotograma, por turnos)
--   * las rocas flotantes de la zona central suben y bajan
--   * nebulosas lejanas (cinco emisores de muy pocas partículas) y alguna estrella fugaz
-- El decorado lo crea el servidor (Builders/Scenery); aquí solo se mueve.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("Config"):WaitForChild("Map"))

local Config = MapConfig.Scenery

-- Asteroides que se mueven en cada fotograma; el resto espera su turno.
local ASTEROIDS_PER_FRAME = 6
-- Radianes por segundo de la deriva de los asteroides alrededor del centro del mapa.
local ASTEROID_DRIFT = 0.004
local RING_SPIN = 0.01
local MOON_ORBIT = 0.03
-- Deriva del planeta: studs que se aleja de su sitio y velocidad (radianes por segundo).
local PLANET_DRIFT = Vector3.new(60, 25, 0)
local PLANET_DRIFT_SPEED = 0.008
local FLOAT_HEIGHT = 1.5
local FLOAT_PERIOD = 7
local NEBULA_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
-- Partículas por segundo de cada nebulosa (viven unos 18 s: unas 6 a la vez).
local NEBULA_RATE = 0.35
local NEBULAE = {
    { position = Vector3.new(1900, 700, 600), size = 1500, color = Color3.fromRGB(150, 80, 255) },
    { position = Vector3.new(-1500, 900, 1500), size = 1700, color = Color3.fromRGB(70, 150, 255) },
    { position = Vector3.new(600, 1100, -2100), size = 1400, color = Color3.fromRGB(255, 90, 170) },
    { position = Vector3.new(-2200, 600, -300), size = 1300, color = Color3.fromRGB(80, 230, 200) },
    { position = Vector3.new(300, 1500, 1900), size = 1800, color = Color3.fromRGB(120, 100, 255) },
}
local SHOOTING_STAR_MIN_WAIT = 7
local SHOOTING_STAR_MAX_WAIT = 18

type Floater = { model: PVInstance, origin: CFrame, phase: number }
type Asteroid = { model: PVInstance, origin: CFrame, spin: Vector3 }

local SkyController = {}

local random = Random.new()
local skyFolder: Folder? = nil

local function getSkyFolder(): Folder
    if skyFolder then
        return skyFolder
    end
    local folder = Instance.new("Folder")
    folder.Name = "SkyEffects"
    folder.Parent = Workspace
    skyFolder = folder
    return folder
end

local function skyPart(name: string, size: Vector3, cframe: CFrame, color: Color3): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Size = size
    part.CFrame = cframe
    part.Color = color
    part.Parent = getSkyFolder()
    return part
end

-- Nubes de color muy lejanas y muy transparentes, para dar profundidad al cielo. Cada una
-- son unas seis partículas enormes que aparecen y se apagan despacio, así que cambia de forma.
local function buildNebulae()
    for _, nebula in NEBULAE do
        local anchor = skyPart(
            "Nebula",
            Vector3.one * nebula.size * 0.3,
            CFrame.new(nebula.position),
            nebula.color
        )
        anchor.Transparency = 1
        local emitter = Instance.new("ParticleEmitter")
        emitter.Texture = NEBULA_TEXTURE
        emitter.Color = ColorSequence.new(nebula.color, nebula.color:Lerp(Color3.new(1, 1, 1), 0.3))
        emitter.Size = NumberSequence.new(nebula.size * 0.35, nebula.size * 0.5)
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.3, 0.8),
            NumberSequenceKeypoint.new(0.7, 0.8),
            NumberSequenceKeypoint.new(1, 1),
        })
        emitter.Lifetime = NumberRange.new(16, 20)
        emitter.Rate = NEBULA_RATE
        emitter.Speed = NumberRange.new(0, 4)
        emitter.SpreadAngle = Vector2.new(180, 180)
        emitter.Rotation = NumberRange.new(0, 360)
        emitter.RotSpeed = NumberRange.new(-2, 2)
        emitter.LightEmission = 0.6
        emitter.LightInfluence = 0
        emitter.Parent = anchor
    end
end

-- Punto de luz con estela que cruza el cielo en poco más de un segundo.
local function shootingStar()
    local start = Vector3.new(
        random:NextNumber(-900, 900),
        random:NextNumber(450, 700),
        random:NextNumber(-900, 900)
    )
    local direction = Vector3.new(random:NextNumber(-1, 1), -0.25, random:NextNumber(-1, 1)).Unit
    local star = skyPart("ShootingStar", Vector3.one * 3, CFrame.new(start), Color3.new(1, 1, 1))
    star.Material = Enum.Material.Neon
    star.Shape = Enum.PartType.Ball

    local front = Instance.new("Attachment")
    front.Position = Vector3.new(0, 1.2, 0)
    front.Parent = star
    local back = Instance.new("Attachment")
    back.Position = Vector3.new(0, -1.2, 0)
    back.Parent = star
    local trail = Instance.new("Trail")
    trail.Attachment0 = front
    trail.Attachment1 = back
    trail.Lifetime = 0.5
    trail.LightEmission = 1
    trail.Color = ColorSequence.new(Color3.fromRGB(200, 225, 255))
    trail.Transparency = NumberSequence.new(0.1, 1)
    trail.WidthScale = NumberSequence.new(1, 0)
    trail.Parent = star

    local duration = random:NextNumber(1, 1.6)
    local tween = TweenService:Create(
        star,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { CFrame = CFrame.new(start + direction * 700), Transparency = 1 }
    )
    tween.Completed:Connect(function()
        star:Destroy()
    end)
    tween:Play()
end

function SkyController.Start()
    buildNebulae()
    task.spawn(function()
        while true do
            task.wait(random:NextNumber(SHOOTING_STAR_MIN_WAIT, SHOOTING_STAR_MAX_WAIT))
            shootingStar()
        end
    end)

    task.spawn(function()
        local map = Workspace:WaitForChild("Map")
        local scenery = map:WaitForChild("Scenery")

        local planet = scenery:FindFirstChild("Planet")
        local planetOrigin = if planet and planet:IsA("BasePart") then planet.CFrame else nil
        local ring = scenery:FindFirstChild("PlanetRing")
        local ringOrigin = if ring and ring:IsA("BasePart") then ring.CFrame else nil
        local moon =
            skyPart("Moon", Vector3.one * 70, CFrame.new(Config.PlanetPosition), Config.RockColor)
        moon.Shape = Enum.PartType.Ball
        moon.Material = Enum.Material.Slate

        local asteroids: { Asteroid } = {}
        local asteroidFolder = scenery:FindFirstChild("Asteroids")
        if asteroidFolder then
            for _, child in asteroidFolder:GetChildren() do
                if child:IsA("PVInstance") then
                    table.insert(asteroids, {
                        model = child,
                        origin = child:GetPivot(),
                        spin = random:NextUnitVector() * random:NextNumber(0.02, 0.08),
                    })
                end
            end
        end

        local floaters: { Floater } = {}
        local floatFolder = scenery:FindFirstChild("FloatingRocks")
        if floatFolder then
            for _, child in floatFolder:GetChildren() do
                if child:IsA("PVInstance") then
                    table.insert(floaters, {
                        model = child,
                        origin = child:GetPivot(),
                        phase = random:NextNumber(0, math.pi * 2),
                    })
                end
            end
        end

        local nextAsteroid = 0
        RunService.Heartbeat:Connect(function()
            local now = os.clock()
            -- El planeta, su anillo y su luna se mueven juntos, muy despacio.
            local drift = Vector3.new(
                math.sin(now * PLANET_DRIFT_SPEED) * PLANET_DRIFT.X,
                math.sin(now * PLANET_DRIFT_SPEED * 0.6) * PLANET_DRIFT.Y,
                0
            )
            if planet and planet:IsA("BasePart") and planetOrigin then
                planet.CFrame = planetOrigin + drift
            end
            if ring and ring:IsA("BasePart") and ringOrigin then
                -- Gira sobre su propio eje (X, el del cilindro).
                ring.CFrame = (ringOrigin + drift) * CFrame.Angles(now * RING_SPIN, 0, 0)
            end
            local orbit = now * MOON_ORBIT
            moon.CFrame = CFrame.new(
                Config.PlanetPosition
                    + drift
                    + Vector3.new(math.cos(orbit), 0.25 * math.sin(orbit), math.sin(orbit))
                        * Config.PlanetSize
                        * 1.25
            )

            for _ = 1, math.min(ASTEROIDS_PER_FRAME, #asteroids) do
                nextAsteroid = nextAsteroid % #asteroids + 1
                local asteroid = asteroids[nextAsteroid]
                local spin = asteroid.spin * now
                asteroid.model:PivotTo(
                    CFrame.Angles(0, now * ASTEROID_DRIFT, 0)
                        * asteroid.origin
                        * CFrame.Angles(spin.X, spin.Y, spin.Z)
                )
            end

            for _, floater in floaters do
                local offset = math.sin(now / FLOAT_PERIOD * math.pi * 2 + floater.phase)
                floater.model:PivotTo(floater.origin * CFrame.new(0, offset * FLOAT_HEIGHT, 0))
            end
        end)
    end)
end

return SkyController
