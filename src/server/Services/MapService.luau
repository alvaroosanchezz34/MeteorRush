--!strict

-- Genera el mapa completo con Parts al arrancar: suelo, zona de impacto y parcelas.
-- Solo construye la geometría; la propiedad de las parcelas la gestiona PlotService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Util.Assets)
local MapConfig = require(Shared.Config.Map)

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

local function makeSignPlaceholder(): Instance
    local board = Instance.new("Part")
    board.Name = "Sign"
    board.Anchored = true
    board.Size = MapConfig.SignSize
    board.Color = MapConfig.SignColor
    board.Material = Enum.Material.SmoothPlastic

    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 40
    gui.Parent = board

    local label = Instance.new("TextLabel")
    label.Name = "OwnerText"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Parent = gui

    return board
end

local function makePedestalPlaceholder(): Instance
    local pedestal = Instance.new("Part")
    pedestal.Anchored = true
    pedestal.Size = MapConfig.PedestalSize
    pedestal.Color = MapConfig.PedestalColor
    pedestal.Material = Enum.Material.Marble
    return pedestal
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

    folder.Parent = Workspace
    mapFolder = folder
end

return MapService
