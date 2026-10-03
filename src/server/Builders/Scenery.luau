--!strict

-- Decorado del mapa: montañas de terreno alrededor, caminos iluminados hasta la zona de
-- impacto, rocas, cristales, estructuras entre las parcelas, charcos de lava y cuerpos en el
-- cielo. Nada de esto afecta a las reglas del juego. Usa una semilla fija para que el mapa
-- sea siempre el mismo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.Kit)
local MapConfig = require(ReplicatedStorage.Shared.Config.Map)

local Config = MapConfig.Scenery

local Scenery = {}

local function polar(angle: number, radius: number, height: number?): Vector3
    return Vector3.new(math.cos(angle) * radius, height or 0, math.sin(angle) * radius)
end

-- CFrame apoyado en el suelo en ese punto, con -Z mirando al centro del mapa.
local function facingCenter(angle: number, radius: number): CFrame
    return CFrame.lookAt(polar(angle, radius), Vector3.zero)
end

local function plotAngle(index: number): number
    return (index - 1) / MapConfig.PlotCount * math.pi * 2
end

-- Indica si un punto cae sobre una parcela o su camino (para no poner rocas encima).
local function isReserved(angle: number, radius: number): boolean
    if radius > MapConfig.PlotRingRadius + MapConfig.PlotSize then
        return false
    end
    local sector = math.pi * 2 / MapConfig.PlotCount
    local offset = (angle + sector / 2) % sector - sector / 2
    return math.abs(offset) < Config.PlotClearAngle
end

-- Cilindro vertical apoyado en `cframe` (el eje de los cilindros de Roblox es X).
local function verticalCylinder(props: {
    name: string,
    cframe: CFrame,
    height: number,
    diameter: number,
    color: Color3,
    material: Enum.Material?,
    canCollide: boolean?,
    transparency: number?,
    parent: Instance,
}): Part
    return Kit.Part({
        name = props.name,
        shape = Enum.PartType.Cylinder,
        size = Vector3.new(props.height, props.diameter, props.diameter),
        cframe = props.cframe
            * CFrame.new(0, props.height / 2, 0)
            * CFrame.Angles(0, 0, math.pi / 2),
        color = props.color,
        material = props.material,
        canCollide = props.canCollide,
        transparency = props.transparency,
        parent = props.parent,
    })
end

local function buildMountains(rng: Random)
    local terrain = Workspace.Terrain
    terrain:SetMaterialColor(Enum.Material.Rock, Config.MountainColor)
    terrain:SetMaterialColor(Enum.Material.Basalt, Config.MountainColor:Lerp(Color3.new(), 0.35))

    for index = 1, Config.MountainCount do
        local angle = index / Config.MountainCount * math.pi * 2 + rng:NextNumber(-0.03, 0.03)
        local radius = rng:NextNumber(Config.MountainMinSize, Config.MountainMaxSize)
        local distance = Config.MountainRingRadius + rng:NextNumber(0, 50)
        local center = polar(angle, distance, radius * rng:NextNumber(-0.2, 0.3))
        terrain:FillBall(center, radius, Enum.Material.Rock)

        -- Pico más pequeño encima para que la silueta no sea una cúpula lisa.
        local peak = radius * rng:NextNumber(0.4, 0.6)
        terrain:FillBall(
            center
                + Vector3.new(rng:NextNumber(-0.4, 0.4), 0.75, rng:NextNumber(-0.4, 0.4))
                    * radius,
            peak,
            Enum.Material.Basalt
        )

        if index % Config.LavaEvery == 0 then
            -- Veta de lava en la cara que mira al mapa.
            local inward = -polar(angle, 1)
            terrain:FillBall(
                center + inward * radius * 0.85 + Vector3.new(0, radius * 0.25, 0),
                radius * 0.22,
                Enum.Material.CrackedLava
            )
        end
    end
end

local function buildPaths(parent: Instance)
    local inner = MapConfig.ImpactZoneRadius + 2
    local outer = MapConfig.PlotRingRadius - MapConfig.PlotSize / 2
    local length = outer - inner
    local width = Config.PathWidth

    for index = 1, MapConfig.PlotCount do
        local base = facingCenter(plotAngle(index), (inner + outer) / 2)
        Kit.Part({
            name = "Path",
            size = Vector3.new(width, 0.2, length),
            cframe = base * CFrame.new(0, 0.1, 0),
            color = Config.PathColor,
            material = Enum.Material.DiamondPlate,
            parent = parent,
        })
        for _, side in { -1, 1 } do
            Kit.Part({
                name = "PathEdge",
                size = Vector3.new(0.5, 0.3, length),
                cframe = base * CFrame.new(side * width / 2, 0.15, 0),
                color = MapConfig.PlotAccentColor,
                material = Enum.Material.Neon,
                canCollide = false,
                castShadow = false,
                parent = parent,
            })
            for step = -1, 1 do
                Kit.Lamp({
                    cframe = base * CFrame.new(side * (width / 2 + 1.5), 0, step * length * 0.38),
                    height = 7,
                    color = MapConfig.PlotAccentColor,
                    postColor = MapConfig.PlotTrimColor,
                    lit = step == 0,
                    parent = parent,
                })
            end
        end
    end
end

-- Torre de radar: cuatro patas con travesaños, plataforma, antena parabólica y baliza roja.
local function buildRadarTower(cframe: CFrame, parent: Instance)
    local model = Instance.new("Model")
    model.Name = "RadarTower"
    local height = 26
    local half = 3
    local metal = MapConfig.PlotTrimColor

    for _, x in { -1, 1 } do
        for _, z in { -1, 1 } do
            Kit.Part({
                name = "Leg",
                size = Vector3.new(0.8, height, 0.8),
                cframe = cframe * CFrame.new(x * half, height / 2, z * half),
                color = metal,
                material = Enum.Material.Metal,
                parent = model,
            })
        end
    end
    for level = 1, 3 do
        local y = height * level / 4
        for _, side in { -1, 1 } do
            Kit.Part({
                name = "Brace",
                size = Vector3.new(half * 2, 0.4, 0.4),
                cframe = cframe * CFrame.new(0, y, side * half),
                color = metal,
                material = Enum.Material.Metal,
                parent = model,
            })
            Kit.Part({
                name = "Brace",
                size = Vector3.new(0.4, 0.4, half * 2),
                cframe = cframe * CFrame.new(side * half, y, 0),
                color = metal,
                material = Enum.Material.Metal,
                parent = model,
            })
        end
    end
    Kit.Part({
        name = "Platform",
        size = Vector3.new(half * 2 + 2, 0.6, half * 2 + 2),
        cframe = cframe * CFrame.new(0, height, 0),
        color = metal,
        material = Enum.Material.DiamondPlate,
        parent = model,
    })
    Kit.Part({
        name = "Mast",
        size = Vector3.new(0.6, 6, 0.6),
        cframe = cframe * CFrame.new(0, height + 3, 0),
        color = metal,
        material = Enum.Material.Metal,
        parent = model,
    })
    Kit.Part({
        name = "Dish",
        shape = Enum.PartType.Cylinder,
        size = Vector3.new(0.6, 10, 10),
        cframe = cframe * CFrame.new(0, height + 5, -1.2) * CFrame.Angles(0, math.pi / 2, 0.5),
        color = Color3.fromRGB(200, 205, 215),
        material = Enum.Material.Metal,
        parent = model,
    })
    local beacon = Kit.Part({
        name = "Beacon",
        shape = Enum.PartType.Ball,
        size = Vector3.one * 1.4,
        cframe = cframe * CFrame.new(0, height + 6.6, 0),
        color = Color3.fromRGB(255, 60, 60),
        material = Enum.Material.Neon,
        canCollide = false,
        parent = model,
    })
    Kit.Light(beacon, Color3.fromRGB(255, 60, 60), 30, 2)
    model.Parent = parent
end

-- Cápsula estrellada: casco inclinado medio enterrado, morro, aletas, ventana y humo.
local function buildCrashedPod(cframe: CFrame, rng: Random, parent: Instance)
    local model = Instance.new("Model")
    model.Name = "CrashedPod"
    local hull = cframe * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, 0.45)

    local body = Kit.Part({
        name = "Hull",
        shape = Enum.PartType.Cylinder,
        size = Vector3.new(18, 8, 8),
        cframe = hull,
        color = Color3.fromRGB(205, 205, 215),
        material = Enum.Material.Metal,
        parent = model,
    })
    Kit.Part({
        name = "Nose",
        shape = Enum.PartType.Ball,
        size = Vector3.one * 8,
        cframe = hull * CFrame.new(9, 0, 0),
        color = Color3.fromRGB(220, 80, 60),
        material = Enum.Material.Metal,
        parent = model,
    })
    Kit.Part({
        name = "Stripe",
        shape = Enum.PartType.Cylinder,
        size = Vector3.new(1.5, 8.2, 8.2),
        cframe = hull * CFrame.new(3, 0, 0),
        color = Color3.fromRGB(220, 80, 60),
        material = Enum.Material.Metal,
        canCollide = false,
        parent = model,
    })
    Kit.Part({
        name = "Window",
        shape = Enum.PartType.Ball,
        size = Vector3.one * 3,
        cframe = hull * CFrame.new(5, 0, -3.2),
        color = MapConfig.PlotAccentColor,
        material = Enum.Material.Neon,
        canCollide = false,
        parent = model,
    })
    for index = 0, 2 do
        Kit.Part({
            name = "Fin",
            shape = Enum.PartType.Wedge,
            size = Vector3.new(0.6, 5, 6),
            cframe = hull
                * CFrame.Angles(index * math.pi * 2 / 3, 0, 0)
                * CFrame.new(-7, 6, 0)
                * CFrame.Angles(0, math.pi / 2, 0),
            color = Color3.fromRGB(220, 80, 60),
            material = Enum.Material.Metal,
            parent = model,
        })
    end
    Kit.Part({
        name = "Scorch",
        shape = Enum.PartType.Cylinder,
        size = Vector3.new(0.1, 30, 30),
        cframe = cframe * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2),
        color = Color3.fromRGB(20, 16, 16),
        material = Enum.Material.Slate,
        canCollide = false,
        castShadow = false,
        parent = model,
    })
    for _ = 1, 4 do
        Kit.Rock({
            cframe = cframe * CFrame.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12)),
            size = rng:NextNumber(2, 4),
            color = Config.RockColor,
            rng = rng,
            parent = model,
        })
    end

    local smoke = Instance.new("ParticleEmitter")
    smoke.Name = "Smoke"
    smoke.Color = ColorSequence.new(Color3.fromRGB(60, 60, 70))
    smoke.Transparency = NumberSequence.new(0.5, 1)
    smoke.Size = NumberSequence.new(2, 7)
    smoke.Lifetime = NumberRange.new(4, 6)
    smoke.Rate = 4
    smoke.Speed = NumberRange.new(3, 5)
    smoke.SpreadAngle = Vector2.new(15, 15)
    smoke.EmissionDirection = Enum.NormalId.Right
    smoke.Parent = body
    Kit.Light(body, Color3.fromRGB(255, 140, 60), 26, 1.2)
    model.Parent = parent
end

-- Depósito de combustible: tres tanques con bandas luminosas sobre una losa, unidos por un tubo.
local function buildFuelDepot(cframe: CFrame, parent: Instance)
    local model = Instance.new("Model")
    model.Name = "FuelDepot"
    Kit.Part({
        name = "Slab",
        size = Vector3.new(30, 0.6, 14),
        cframe = cframe * CFrame.new(0, 0.3, 0),
        color = MapConfig.PlotTrimColor,
        material = Enum.Material.Concrete,
        parent = model,
    })
    local heights = { 12, 17, 10 }
    for index, height in heights do
        local base = cframe * CFrame.new((index - 2) * 9.5, 0.6, 0)
        verticalCylinder({
            name = "Tank",
            cframe = base,
            height = height,
            diameter = 7.5,
            color = Color3.fromRGB(190, 195, 205),
            material = Enum.Material.Metal,
            parent = model,
        })
        Kit.Part({
            name = "Cap",
            shape = Enum.PartType.Ball,
            size = Vector3.one * 7.5,
            cframe = base * CFrame.new(0, height, 0),
            color = Color3.fromRGB(190, 195, 205),
            material = Enum.Material.Metal,
            parent = model,
        })
        local band = verticalCylinder({
            name = "Band",
            cframe = base * CFrame.new(0, height * 0.6, 0),
            height = 0.8,
            diameter = 7.8,
            color = Config.FuelColor,
            material = Enum.Material.Neon,
            canCollide = false,
            parent = model,
        })
        if index == 2 then
            Kit.Light(band, Config.FuelColor, 28, 1.5)
        end
    end
    Kit.Part({
        name = "Pipe",
        shape = Enum.PartType.Cylinder,
        size = Vector3.new(20, 1, 1),
        cframe = cframe * CFrame.new(0, 3, 3.6),
        color = MapConfig.PlotTrimColor,
        material = Enum.Material.Metal,
        parent = model,
    })
    model.Parent = parent
end

-- Entre cada dos parcelas: una formación de cristales grande y una estructura.
local function buildLandmarks(rng: Random, parent: Instance)
    local sector = math.pi * 2 / MapConfig.PlotCount
    for index = 1, MapConfig.PlotCount do
        local angle = plotAngle(index) + sector / 2
        local crystalColor = Config.CrystalColors[(index - 1) % #Config.CrystalColors + 1]

        Kit.CrystalCluster({
            cframe = facingCenter(angle + rng:NextNumber(-0.08, 0.08), rng:NextNumber(335, 365)),
            height = rng:NextNumber(18, 30),
            count = rng:NextInteger(5, 8),
            color = crystalColor,
            rockColor = Config.RockColor,
            rng = rng,
            parent = parent,
        })

        local spot = facingCenter(angle + rng:NextNumber(-0.05, 0.05), rng:NextNumber(400, 430))
            * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
        local kind = index % 3
        if kind == 0 then
            buildRadarTower(spot, parent)
        elseif kind == 1 then
            buildCrashedPod(spot, rng, parent)
        else
            buildFuelDepot(spot, parent)
        end
    end
end

-- Rocas y cristales pequeños repartidos por el anillo exterior.
local function buildScatter(rng: Random, parent: Instance)
    local minRadius = MapConfig.ImpactZoneRadius + 12
    local maxRadius = Config.MountainRingRadius - Config.MountainMaxSize

    local function randomSpot(): CFrame?
        for _ = 1, 8 do
            local angle = rng:NextNumber(0, math.pi * 2)
            local radius = rng:NextNumber(minRadius, maxRadius)
            if not isReserved(angle, radius) then
                return CFrame.new(polar(angle, radius))
                    * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
            end
        end
        return nil
    end

    for _ = 1, Config.RockCount do
        local spot = randomSpot()
        if spot then
            Kit.Rock({
                cframe = spot,
                size = rng:NextNumber(3, 11),
                color = Config.RockColor,
                rng = rng,
                parent = parent,
            })
        end
    end
    for index = 1, Config.SmallCrystalCount do
        local spot = randomSpot()
        if spot then
            Kit.CrystalCluster({
                cframe = spot,
                height = rng:NextNumber(4, 9),
                count = rng:NextInteger(3, 5),
                color = Config.CrystalColors[(index - 1) % #Config.CrystalColors + 1],
                rockColor = Config.RockColor,
                rng = rng,
                parent = parent,
            })
        end
    end
end

-- Charcos de lava dentro de la zona de impacto: planos y sin colisión, para no estorbar a
-- los meteoritos.
local function buildLavaPools(rng: Random, parent: Instance)
    for _ = 1, Config.LavaPoolCount do
        local radius = rng:NextNumber(4, 10)
        local distance = (MapConfig.ImpactZoneRadius - radius - 10) * math.sqrt(rng:NextNumber())
        local position = polar(rng:NextNumber(0, math.pi * 2), distance, 0.22)
        local pool = Kit.Part({
            name = "LavaPool",
            shape = Enum.PartType.Cylinder,
            size = Vector3.new(0.06, radius * 2, radius * 2),
            cframe = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
            color = Config.LavaColor,
            material = Enum.Material.CrackedLava,
            canCollide = false,
            castShadow = false,
            parent = parent,
        })
        pool.CanQuery = false
    end
end

-- Planeta con anillo, luna y asteroides flotando sobre el mapa.
local function buildSky(rng: Random, parent: Instance)
    local planetPosition = Config.PlanetPosition
    local planet = Kit.Part({
        name = "Planet",
        shape = Enum.PartType.Ball,
        size = Vector3.one * Config.PlanetSize,
        cframe = CFrame.new(planetPosition),
        color = Config.PlanetColor,
        material = Enum.Material.Sand,
        canCollide = false,
        castShadow = false,
        parent = parent,
    })
    planet.CanQuery = false
    local ring = Kit.Part({
        name = "PlanetRing",
        shape = Enum.PartType.Cylinder,
        size = Vector3.new(3, Config.PlanetSize * 1.9, Config.PlanetSize * 1.9),
        cframe = CFrame.new(planetPosition) * CFrame.Angles(0.5, 0, math.pi / 2 + 0.25),
        color = Config.PlanetColor:Lerp(Color3.new(1, 1, 1), 0.5),
        material = Enum.Material.Neon,
        transparency = 0.6,
        canCollide = false,
        castShadow = false,
        parent = parent,
    })
    ring.CanQuery = false

    for _ = 1, Config.AsteroidCount do
        local position = polar(
            rng:NextNumber(0, math.pi * 2),
            rng:NextNumber(380, 720),
            rng:NextNumber(130, 330)
        )
        local asteroid = Kit.Rock({
            cframe = CFrame.new(position)
                * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)),
            size = rng:NextNumber(10, 38),
            color = Config.RockColor,
            rng = rng,
            canCollide = false,
            parent = parent,
        })
        for _, part in asteroid:GetChildren() do
            if part:IsA("BasePart") then
                part.CanQuery = false
                part.CastShadow = false
            end
        end
    end
end

-- Construye todo el decorado dentro de `parent`.
function Scenery.Build(parent: Instance)
    local rng = Random.new(Config.Seed)
    local folder = Instance.new("Folder")
    folder.Name = "Scenery"

    buildPaths(folder)
    buildLandmarks(rng, folder)
    buildScatter(rng, folder)
    buildLavaPools(rng, folder)
    buildSky(rng, folder)
    folder.Parent = parent

    buildMountains(rng)
end

return Scenery
