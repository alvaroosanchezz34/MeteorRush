--!strict

-- Genera el mapa completo con Parts al arrancar: suelo, zona de impacto y parcelas.
-- Solo construye la geometría; la propiedad de las parcelas la gestiona PlotService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Util.Assets)
local MapConfig = require(Shared.Config.Map)
local Scenery = require(script.Parent.Parent.Builders.Scenery)
local Strings = require(Shared.Strings)

export type PlotLayout = {
    index: number,
    model: Model,
    -- Centro de la parcela a la altura de la superficie del suelo; -Z apunta al centro del mapa.
    cframe: CFrame,
    spawnLocation: SpawnLocation,
    depositZone: BasePart,
    collectPad: BasePart,
    collectLabel: TextLabel,
    floor: BasePart,
    signLabel: TextLabel?,
    pedestalFolder: Folder,
    -- Todos los pedestales posibles (MaxPedestals), desbloqueados o no.
    pedestals: { Instance },
}

local MapService = {}

local mapFolder: Folder? = nil
local plots: { PlotLayout } = {}

local function makePart(props: {
    name: string,
    size: Vector3,
    cframe: CFrame,
    color: Color3,
    material: Enum.Material?,
    canCollide: boolean?,
    transparency: number?,
    parent: Instance,
}): Part
    local part = Instance.new("Part")
    part.Name = props.name
    part.Anchored = true
    part.Size = props.size
    part.CFrame = props.cframe
    part.Color = props.color
    part.Material = props.material or Enum.Material.SmoothPlastic
    part.CanCollide = if props.canCollide == nil then true else props.canCollide
    part.Transparency = props.transparency or 0
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = props.parent
    return part
end

local function buildGround(parent: Instance)
    local size = MapConfig.GroundSize
    makePart({
        name = "Ground",
        size = Vector3.new(size, 2, size),
        cframe = CFrame.new(0, -1, 0),
        color = MapConfig.GroundColor,
        material = Enum.Material.Slate,
        parent = parent,
    })

    local diameter = MapConfig.ImpactZoneRadius * 2
    local impactZone = makePart({
        name = "ImpactZone",
        size = Vector3.new(0.2, diameter, diameter),
        -- El eje del cilindro es X; se gira para que quede vertical.
        cframe = CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
        color = MapConfig.ImpactZoneColor,
        material = Enum.Material.Basalt,
        parent = parent,
    })
    impactZone.Shape = Enum.PartType.Cylinder

    -- Borde luminoso: tramos rectos alrededor de la circunferencia.
    local segments = MapConfig.ImpactRingSegments
    local radius = MapConfig.ImpactZoneRadius
    local segmentLength = 2 * math.pi * radius / segments + 0.5
    for index = 1, segments do
        local angle = index / segments * math.pi * 2
        local position = Vector3.new(math.cos(angle) * radius, 0.3, math.sin(angle) * radius)
        makePart({
            name = "ImpactRing",
            size = Vector3.new(segmentLength, 0.3, 1.5),
            -- lookAt apunta -Z al centro, así que X queda tangente al círculo.
            cframe = CFrame.lookAt(position, Vector3.new(0, 0.3, 0)),
            color = MapConfig.ImpactRingColor,
            material = Enum.Material.Neon,
            canCollide = false,
            transparency = 0.3,
            parent = parent,
        })
    end

    -- Cráteres decorativos: discos planos sin colisión. Semilla fija para que el mapa no cambie.
    local craterRng = Random.new(7)
    for _ = 1, MapConfig.CraterCount do
        local craterRadius =
            craterRng:NextNumber(MapConfig.CraterMinRadius, MapConfig.CraterMaxRadius)
        local distance = (radius - craterRadius - 5) * math.sqrt(craterRng:NextNumber())
        local angle = craterRng:NextNumber() * math.pi * 2
        local crater = makePart({
            name = "Crater",
            size = Vector3.new(0.04, craterRadius * 2, craterRadius * 2),
            cframe = CFrame.new(math.cos(angle) * distance, 0.2, math.sin(angle) * distance)
                * CFrame.Angles(0, 0, math.rad(90)),
            color = MapConfig.CraterColor,
            material = Enum.Material.Slate,
            canCollide = false,
            parent = parent,
        })
        crater.Shape = Enum.PartType.Cylinder
        crater.CanQuery = false
    end

    -- Punto de aparición por defecto, solo para quien aún no tiene parcela.
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "DefaultSpawn"
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.Duration = 0
    spawn.Size = Vector3.new(8, 1, 8)
    spawn.CFrame = CFrame.new(0, 0.5, 0)
    spawn.Transparency = 1
    spawn.CanCollide = false
    spawn.Parent = parent
end

-- Cartel con dos postes hasta el suelo y un remate luminoso. La parte principal es el tablero.
local function makeSignPlaceholder(): Instance
    local model = Instance.new("Model")
    local size = MapConfig.SignSize

    local board = Instance.new("Part")
    board.Name = "Board"
    board.Anchored = true
    board.Size = size
    board.Color = MapConfig.SignColor
    board.Material = Enum.Material.SmoothPlastic
    board.Parent = model
    model.PrimaryPart = board

    local postHeight = MapConfig.SignHeight + size.Y / 2
    for _, side in { -1, 1 } do
        makePart({
            name = "Post",
            size = Vector3.new(0.8, postHeight, 0.8),
            cframe = CFrame.new(side * (size.X / 2 + 0.4), size.Y / 2 - postHeight / 2, 0),
            color = MapConfig.PlotTrimColor,
            material = Enum.Material.Metal,
            parent = model,
        })
    end
    makePart({
        name = "Trim",
        size = Vector3.new(size.X + 1.6, 0.3, size.Z + 0.2),
        cframe = CFrame.new(0, size.Y / 2 + 0.15, 0),
        color = MapConfig.PlotAccentColor,
        material = Enum.Material.Neon,
        canCollide = false,
        parent = model,
    })

    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 40
    gui.Parent = board

    gui.LightInfluence = 0
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Fondo con degradado y un marco del color de la base.
    local background = Instance.new("Frame")
    background.Size = UDim2.fromScale(1, 1)
    background.BackgroundColor3 = MapConfig.SignColor
    background.BorderSizePixel = 0
    background.Parent = gui
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.55, 0.55, 0.7))
    gradient.Parent = background
    local frame = Instance.new("UIStroke")
    frame.Color = MapConfig.PlotAccentColor
    frame.Thickness = 6
    frame.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    frame.Parent = background

    local label = Instance.new("TextLabel")
    label.Name = "OwnerText"
    label.Size = UDim2.fromScale(0.92, 0.84)
    label.Position = UDim2.fromScale(0.04, 0.08)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Parent = background
    local textStroke = Instance.new("UIStroke")
    textStroke.Color = Color3.new(0, 0, 0)
    textStroke.Thickness = 2
    textStroke.Transparency = 0.4
    textStroke.Parent = label

    return model
end

-- Base ancha, columna, plato superior y un filo luminoso. Ocupa en total PedestalSize y su
-- parte principal (la columna) está centrada, así que el pivote es el centro del pedestal.
local function makePedestalPlaceholder(): Instance
    local model = Instance.new("Model")
    local size = MapConfig.PedestalSize
    local slab = size.Y / 6

    local column = makePart({
        name = "Core",
        size = Vector3.new(size.X * 0.4, size.Y - slab * 2, size.Z * 0.4),
        cframe = CFrame.identity,
        color = MapConfig.PedestalBaseColor,
        material = Enum.Material.Marble,
        parent = model,
    })
    model.PrimaryPart = column
    -- Columna redonda alrededor del núcleo (el eje de los cilindros es X).
    local shaft = makePart({
        name = "Column",
        size = Vector3.new(size.Y - slab * 2, size.X * 0.68, size.Z * 0.68),
        cframe = CFrame.Angles(0, 0, math.rad(90)),
        color = MapConfig.PedestalColor,
        material = Enum.Material.Marble,
        parent = model,
    })
    shaft.Shape = Enum.PartType.Cylinder
    local ring = makePart({
        name = "Ring",
        size = Vector3.new(slab * 0.3, size.X * 0.74, size.Z * 0.74),
        cframe = CFrame.Angles(0, 0, math.rad(90)),
        color = MapConfig.PedestalAccentColor,
        material = Enum.Material.Neon,
        canCollide = false,
        parent = model,
    })
    ring.Shape = Enum.PartType.Cylinder
    makePart({
        name = "Base",
        size = Vector3.new(size.X, slab, size.Z),
        cframe = CFrame.new(0, -size.Y / 2 + slab / 2, 0),
        color = MapConfig.PedestalBaseColor,
        material = Enum.Material.Marble,
        parent = model,
    })
    makePart({
        name = "Top",
        size = Vector3.new(size.X * 0.9, slab, size.Z * 0.9),
        cframe = CFrame.new(0, size.Y / 2 - slab / 2, 0),
        color = MapConfig.PedestalBaseColor,
        material = Enum.Material.Marble,
        parent = model,
    })
    makePart({
        name = "Glow",
        size = Vector3.new(size.X * 0.94, slab * 0.25, size.Z * 0.94),
        cframe = CFrame.new(0, size.Y / 2 - slab, 0),
        color = MapConfig.PedestalAccentColor,
        material = Enum.Material.Neon,
        canCollide = false,
        parent = model,
    })
    return model
end

-- Bordillo, columnas con luz en las esquinas y arco sobre la zona de depósito.
local function buildPlotDecoration(cframe: CFrame, parent: Instance)
    local half = MapConfig.PlotSize / 2
    local trim = 1
    local trimHeight = 0.4
    local gateHalf = MapConfig.DepositZoneWidth / 2

    local function addTrim(centerX: number, centerZ: number, sizeX: number, sizeZ: number)
        makePart({
            name = "Trim",
            size = Vector3.new(sizeX, trimHeight, sizeZ),
            cframe = cframe * CFrame.new(centerX, trimHeight / 2, centerZ),
            color = MapConfig.PlotTrimColor,
            material = Enum.Material.Metal,
            parent = parent,
        })
    end
    local edge = half - trim / 2
    addTrim(-edge, 0, trim, MapConfig.PlotSize)
    addTrim(edge, 0, trim, MapConfig.PlotSize)
    addTrim(0, edge, MapConfig.PlotSize, trim)
    -- El lado de la entrada deja libre el hueco de la zona de depósito.
    local frontLength = half - gateHalf
    addTrim(-(gateHalf + frontLength / 2), -edge, frontLength, trim)
    addTrim(gateHalf + frontLength / 2, -edge, frontLength, trim)

    -- Borde de energía: una línea de luz a ras de suelo por dentro del bordillo. Cada jugador
    -- ve la de su propia base en verde (BaseController).
    local function addGlow(centerX: number, centerZ: number, sizeX: number, sizeZ: number)
        local glow = makePart({
            name = "EdgeGlow",
            size = Vector3.new(sizeX, 0.1, sizeZ),
            cframe = cframe * CFrame.new(centerX, 0.06, centerZ),
            color = MapConfig.PlotAccentColor,
            material = Enum.Material.Neon,
            canCollide = false,
            transparency = 0.6,
            parent = parent,
        })
        glow.CanQuery = false
        glow.CastShadow = false
    end
    local inner = half - trim - 0.5
    local glowLength = MapConfig.PlotSize - 2 * trim - 1
    addGlow(-inner, 0, 0.4, glowLength)
    addGlow(inner, 0, 0.4, glowLength)
    addGlow(0, inner, glowLength, 0.4)
    local frontGlow = frontLength - trim - 0.5
    addGlow(-(gateHalf + frontGlow / 2), -inner, frontGlow, 0.4)
    addGlow(gateHalf + frontGlow / 2, -inner, frontGlow, 0.4)

    local pillarHeight = MapConfig.PlotPillarHeight
    for _, x in { -1, 1 } do
        for _, z in { -1, 1 } do
            local base = cframe * CFrame.new(x * (half - 1), 0, z * (half - 1))
            makePart({
                name = "Pillar",
                size = Vector3.new(2, pillarHeight, 2),
                cframe = base * CFrame.new(0, pillarHeight / 2, 0),
                color = MapConfig.PlotTrimColor,
                material = Enum.Material.Metal,
                parent = parent,
            })
            local cap = makePart({
                name = "PillarLight",
                size = Vector3.new(2.4, 0.6, 2.4),
                cframe = base * CFrame.new(0, pillarHeight + 0.3, 0),
                color = MapConfig.PlotAccentColor,
                material = Enum.Material.Neon,
                canCollide = false,
                parent = parent,
            })
            local light = Instance.new("PointLight")
            light.Color = MapConfig.PlotAccentColor
            light.Range = 10
            light.Brightness = 0.4
            light.Shadows = false
            light.Parent = cap
        end
    end

    local gateHeight = MapConfig.PlotGateHeight
    for _, side in { -1, 1 } do
        makePart({
            name = "GatePost",
            size = Vector3.new(1, gateHeight, 1),
            cframe = cframe * CFrame.new(side * (gateHalf + 0.5), gateHeight / 2, -edge),
            color = MapConfig.PlotTrimColor,
            material = Enum.Material.Metal,
            parent = parent,
        })
    end
    makePart({
        name = "GateBeam",
        size = Vector3.new(MapConfig.DepositZoneWidth + 2, 0.8, 1),
        cframe = cframe * CFrame.new(0, gateHeight + 0.4, -edge),
        color = MapConfig.DepositZoneColor,
        material = Enum.Material.Neon,
        canCollide = false,
        parent = parent,
    })

    -- Rótulo sobre el arco, legible por las dos caras.
    local banner = makePart({
        name = "GateBanner",
        size = Vector3.new(MapConfig.DepositZoneWidth * 0.7, 2.6, 0.6),
        cframe = cframe * CFrame.new(0, gateHeight + 2.3, -edge),
        color = MapConfig.SignColor,
        canCollide = false,
        parent = parent,
    })
    for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
        local gui = Instance.new("SurfaceGui")
        gui.Face = face
        gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        gui.PixelsPerStud = 40
        gui.LightInfluence = 0
        gui.Parent = banner
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.TextColor3 = MapConfig.DepositZoneColor
        label.Text = Strings.Plot.Deposit
        label.Parent = gui
    end

    -- Pasillo central entre los pedestales, con dos líneas de luz.
    makePart({
        name = "Walkway",
        size = Vector3.new(3, 0.1, MapConfig.PlotSize - 4),
        cframe = cframe * CFrame.new(0, 0.05, 0),
        color = MapConfig.PlotTrimColor,
        material = Enum.Material.DiamondPlate,
        canCollide = false,
        parent = parent,
    })
    for _, side in { -1, 1 } do
        makePart({
            name = "WalkwayLight",
            size = Vector3.new(0.25, 0.14, MapConfig.PlotSize - 4),
            cframe = cframe * CFrame.new(side * 1.6, 0.07, 0),
            color = MapConfig.PlotAccentColor,
            material = Enum.Material.Neon,
            canCollide = false,
            parent = parent,
        })
    end

    -- Valla de energía en los lados: postes y paneles translúcidos que no bloquean el paso.
    local fenceSpan = (MapConfig.PlotSize - 6) / MapConfig.PlotFenceSegments
    for _, side in { -1, 1 } do
        for segment = 1, MapConfig.PlotFenceSegments do
            local z = -half + 3 + (segment - 0.5) * fenceSpan
            makePart({
                name = "FencePanel",
                size = Vector3.new(0.2, 3, fenceSpan - 1),
                cframe = cframe * CFrame.new(side * edge, 2.2, z),
                color = MapConfig.PlotAccentColor,
                material = Enum.Material.Neon,
                canCollide = false,
                transparency = 0.8,
                parent = parent,
            })
            if segment < MapConfig.PlotFenceSegments then
                makePart({
                    name = "FencePost",
                    size = Vector3.new(0.8, 4.2, 0.8),
                    cframe = cframe * CFrame.new(side * edge, 2.1, z + fenceSpan / 2),
                    color = MapConfig.PlotTrimColor,
                    material = Enum.Material.Metal,
                    parent = parent,
                })
            end
        end
    end

    -- Muro del fondo con ventanas luminosas y remate.
    local wallHeight = MapConfig.PlotWallHeight
    local wallWidth = MapConfig.PlotSize - 6
    makePart({
        name = "BackWall",
        size = Vector3.new(wallWidth, wallHeight, 1.5),
        cframe = cframe * CFrame.new(0, wallHeight / 2, half - 1.25),
        color = MapConfig.PlotTrimColor,
        material = Enum.Material.Metal,
        parent = parent,
    })
    makePart({
        name = "BackWallTop",
        size = Vector3.new(wallWidth + 1, 0.5, 2.2),
        cframe = cframe * CFrame.new(0, wallHeight + 0.25, half - 1.25),
        color = MapConfig.PlotAccentColor,
        material = Enum.Material.Neon,
        canCollide = false,
        parent = parent,
    })
    local windows = 5
    for index = 1, windows do
        local x = (index - (windows + 1) / 2) * (wallWidth / windows)
        makePart({
            name = "BackWallWindow",
            size = Vector3.new(wallWidth / windows * 0.6, wallHeight * 0.4, 0.3),
            cframe = cframe * CFrame.new(x, wallHeight * 0.6, half - 2.1),
            color = MapConfig.PlotAccentColor,
            material = Enum.Material.Neon,
            canCollide = false,
            transparency = 0.35,
            parent = parent,
        })
    end

    -- Baliza: haz de luz vertical que marca la base desde lejos.
    local beaconBase = cframe * CFrame.new(0, wallHeight + 0.5, half - 1.25)
    local emitter = makePart({
        name = "BeaconBase",
        size = Vector3.new(3, 1.5, 3),
        cframe = beaconBase * CFrame.new(0, 0.75, 0),
        color = MapConfig.PlotTrimColor,
        material = Enum.Material.Metal,
        parent = parent,
    })
    local beam = makePart({
        name = "Beacon",
        size = Vector3.new(MapConfig.PlotBeaconHeight, 1.6, 1.6),
        cframe = beaconBase
            * CFrame.new(0, 1.5 + MapConfig.PlotBeaconHeight / 2, 0)
            * CFrame.Angles(0, 0, math.rad(90)),
        color = MapConfig.PlotAccentColor,
        material = Enum.Material.Neon,
        canCollide = false,
        transparency = 0.55,
        parent = parent,
    })
    beam.Shape = Enum.PartType.Cylinder
    beam.CastShadow = false
    beam.CanQuery = false
    local beaconLight = Instance.new("PointLight")
    beaconLight.Color = MapConfig.PlotAccentColor
    beaconLight.Range = 14
    beaconLight.Brightness = 0.5
    beaconLight.Shadows = false
    beaconLight.Parent = emitter

    -- Cajas y barriles en la esquina del fondo opuesta a la placa de cobro.
    local crates = {
        { x = 22, z = 23, size = 4, y = 0 },
        { x = 17.5, z = 24, size = 3.2, y = 0 },
        { x = 21.5, z = 23.5, size = 3, y = 4 },
    }
    for _, crate in crates do
        local crateCFrame = cframe
            * CFrame.new(crate.x, crate.y + crate.size / 2, crate.z)
            * CFrame.Angles(0, crate.x * 0.3, 0)
        makePart({
            name = "Crate",
            size = Vector3.one * crate.size,
            cframe = crateCFrame,
            color = MapConfig.CrateColor,
            material = Enum.Material.DiamondPlate,
            parent = parent,
        })
        makePart({
            name = "CrateBand",
            size = Vector3.new(crate.size + 0.1, crate.size * 0.15, crate.size + 0.1),
            cframe = crateCFrame,
            color = MapConfig.CollectPadColor,
            material = Enum.Material.Neon,
            canCollide = false,
            parent = parent,
        })
    end
    for index = 1, 2 do
        local barrel = makePart({
            name = "Barrel",
            size = Vector3.new(4, 2.6, 2.6),
            cframe = cframe
                * CFrame.new(25.5, 2, 18.5 - index * 3.2)
                * CFrame.Angles(0, 0, math.rad(90)),
            color = MapConfig.PlotAccentColor:Lerp(Color3.new(0, 0, 0), 0.45),
            material = Enum.Material.Metal,
            parent = parent,
        })
        barrel.Shape = Enum.PartType.Cylinder
    end

    -- Marco de la placa de cobro.
    local padSize = MapConfig.CollectPadSize
    local padCenter = cframe * CFrame.new(MapConfig.CollectPadOffset)
    for _, side in { -1, 1 } do
        makePart({
            name = "PadFrame",
            size = Vector3.new(padSize + 1, 0.6, 0.5),
            cframe = padCenter * CFrame.new(0, 0.3, side * (padSize / 2 + 0.25)),
            color = MapConfig.PlotTrimColor,
            material = Enum.Material.Metal,
            canCollide = false,
            parent = parent,
        })
        makePart({
            name = "PadFrame",
            size = Vector3.new(0.5, 0.6, padSize + 1),
            cframe = padCenter * CFrame.new(side * (padSize / 2 + 0.25), 0.3, 0),
            color = MapConfig.PlotTrimColor,
            material = Enum.Material.Metal,
            canCollide = false,
            parent = parent,
        })
    end
end

local function pedestalCFrame(plotCFrame: CFrame, number: number): CFrame
    local columns = MapConfig.PedestalColumns
    local rows = math.ceil(MapConfig.MaxPedestals / columns)
    local spacing = MapConfig.PedestalSpacing
    local column = (number - 1) % columns
    local row = (number - 1) // columns

    local x = (column - (columns - 1) / 2) * spacing
    local z = MapConfig.PedestalGridCenterZ + (row - (rows - 1) / 2) * spacing
    -- Los primeros pedestales quedan en la fila más cercana a la entrada.
    return plotCFrame * CFrame.new(x, MapConfig.PedestalSize.Y / 2, z)
end

local function buildPlot(index: number, parent: Instance): PlotLayout
    local angle = (index - 1) / MapConfig.PlotCount * math.pi * 2
    local radius = MapConfig.PlotRingRadius
    local floorTop = MapConfig.PlotFloorThickness
    local center = Vector3.new(math.cos(angle) * radius, floorTop, math.sin(angle) * radius)
    local cframe = CFrame.lookAt(center, Vector3.new(0, floorTop, 0))
    local half = MapConfig.PlotSize / 2

    local model = Instance.new("Model")
    model.Name = `Plot{index}`
    model:SetAttribute("PlotIndex", index)

    local floor = makePart({
        name = "Floor",
        size = Vector3.new(MapConfig.PlotSize, MapConfig.PlotFloorThickness, MapConfig.PlotSize),
        cframe = cframe * CFrame.new(0, -MapConfig.PlotFloorThickness / 2, 0),
        color = MapConfig.PlotFloorColor,
        parent = model,
    })
    model.PrimaryPart = floor

    local decoration = Instance.new("Folder")
    decoration.Name = "Decoration"
    decoration.Parent = model

    -- Suelo de losas: grandes baldosas en dos tonos sobre el suelo, que hace de junta. Da
    -- cuerpo a la base sin una sola luz. No tienen colisión (se pisa el suelo de debajo).
    local tiles = MapConfig.PlotTiles
    local tileSize = MapConfig.PlotSize / tiles
    for row = 1, tiles do
        for column = 1, tiles do
            local tile = makePart({
                name = "Tile",
                size = Vector3.new(
                    tileSize - MapConfig.PlotTileGap,
                    MapConfig.PlotTileHeight,
                    tileSize - MapConfig.PlotTileGap
                ),
                cframe = cframe * CFrame.new(
                    -half + (column - 0.5) * tileSize,
                    MapConfig.PlotTileHeight / 2,
                    -half + (row - 0.5) * tileSize
                ),
                color = if (row + column) % 2 == 0
                    then MapConfig.PlotTileColor
                    else MapConfig.PlotTileAltColor,
                canCollide = false,
                parent = decoration,
            })
            tile.CanQuery = false
            tile.CastShadow = false
            -- Tacos: los que trae Roblox (solo se dibujan sobre plástico). Sin assets.
            if MapConfig.PlotTileStuds then
                tile.Material = Enum.Material.Plastic
                tile.TopSurface = Enum.SurfaceType.Studs
            end
        end
    end
    buildPlotDecoration(cframe, decoration)

    local depositZone = makePart({
        name = "DepositZone",
        size = Vector3.new(MapConfig.DepositZoneWidth, 0.2, MapConfig.DepositZoneDepth),
        cframe = cframe * CFrame.new(0, 0.1, -half + MapConfig.DepositZoneDepth / 2),
        color = MapConfig.DepositZoneColor,
        material = Enum.Material.Neon,
        canCollide = false,
        transparency = 0.4,
        parent = model,
    })

    local padSize = MapConfig.CollectPadSize
    local collectPad = makePart({
        name = "CollectPad",
        size = Vector3.new(padSize, 0.4, padSize),
        cframe = cframe * CFrame.new(MapConfig.CollectPadOffset + Vector3.new(0, 0.2, 0)),
        color = MapConfig.CollectPadColor,
        material = Enum.Material.Neon,
        canCollide = false,
        transparency = 0.2,
        parent = model,
    })
    local padGui = Instance.new("BillboardGui")
    padGui.Size = UDim2.fromScale(10, 4)
    padGui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
    padGui.LightInfluence = 0
    padGui.MaxDistance = 150
    padGui.Parent = collectPad
    local collectLabel = Instance.new("TextLabel")
    collectLabel.Name = "Amount"
    collectLabel.Size = UDim2.fromScale(1, 1)
    collectLabel.BackgroundTransparency = 1
    collectLabel.TextScaled = true
    collectLabel.Font = Enum.Font.GothamBlack
    collectLabel.TextColor3 = MapConfig.CollectPadColor
    collectLabel.TextStrokeTransparency = 0
    collectLabel.Parent = padGui

    local signCFrame = cframe
        * CFrame.new(MapConfig.SignOffsetX, MapConfig.SignHeight, -half + MapConfig.SignSize.Z)
    local sign = Assets.SpawnAt("Sign", signCFrame, makeSignPlaceholder)
    sign.Name = "Sign"
    sign.Parent = model
    local signLabel = sign:FindFirstChild("OwnerText", true)
    if signLabel and not signLabel:IsA("TextLabel") then
        signLabel = nil
    end
    if signLabel == nil then
        warn(`[MapService] El cartel de la parcela {index} no tiene un TextLabel "OwnerText"`)
    end

    local spawnLocation = Instance.new("SpawnLocation")
    spawnLocation.Name = "Spawn"
    spawnLocation.Anchored = true
    spawnLocation.Neutral = true
    -- Desactivado para que nadie aparezca aquí al azar; PlotService lleva a cada dueño a su parcela.
    spawnLocation.Enabled = false
    spawnLocation.Duration = 0
    spawnLocation.Size = Vector3.new(6, 0.2, 6)
    spawnLocation.CFrame = cframe * CFrame.new(0, 0.1, MapConfig.SpawnOffsetZ)
    spawnLocation.Transparency = 1
    spawnLocation.CanCollide = false
    spawnLocation.Parent = model

    local pedestalFolder = Instance.new("Folder")
    pedestalFolder.Name = "Pedestals"
    pedestalFolder.Parent = model

    local pedestals: { Instance } = {}
    for number = 1, MapConfig.MaxPedestals do
        local pedestal =
            Assets.SpawnAt("Pedestal", pedestalCFrame(cframe, number), makePedestalPlaceholder)
        pedestal.Name = `Pedestal{number}`
        pedestal:SetAttribute("PedestalNumber", number)
        pedestals[number] = pedestal
    end

    model.Parent = parent

    return {
        index = index,
        model = model,
        cframe = cframe,
        spawnLocation = spawnLocation,
        depositZone = depositZone,
        collectPad = collectPad,
        collectLabel = collectLabel,
        floor = floor,
        signLabel = signLabel :: TextLabel?,
        pedestalFolder = pedestalFolder,
        pedestals = pedestals,
    }
end

-- Devuelve las parcelas generadas, en orden de índice.
function MapService.GetPlots(): { PlotLayout }
    return plots
end

-- Devuelve la carpeta raíz del mapa en Workspace.
function MapService.GetMapFolder(): Folder
    assert(mapFolder, "[MapService] El mapa aún no se ha generado")
    return mapFolder
end

function MapService.Init()
    local folder = Instance.new("Folder")
    folder.Name = "Map"

    buildGround(folder)

    local plotFolder = Instance.new("Folder")
    plotFolder.Name = "Plots"
    plotFolder.Parent = folder

    for index = 1, MapConfig.PlotCount do
        table.insert(plots, buildPlot(index, plotFolder))
    end

    Scenery.Build(folder)

    folder.Parent = Workspace
    mapFolder = folder
end

return MapService
