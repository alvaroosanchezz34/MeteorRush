--!strict

-- Construye los NPCs ambientales de Config/Npcs y su decorado. Solo los crea: son figuras
-- ancladas y sin colisión, así que no bloquean caminos ni estorban a nada. Los anima cada
-- cliente (NpcController) y las frases también son del cliente.
-- Cada parte lleva los atributos `Joint` (a qué articulación pertenece) y `Offset` (su
-- posición respecto a esa articulación), que es lo que usa el cliente para moverla.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Parent.Builders.Kit)
local MapService = require(script.Parent.MapService)

local Shared = ReplicatedStorage.Shared
local MapConfig = require(Shared.Config.Map)
local NpcsConfig = require(Shared.Config.Npcs)
local Strings = require(Shared.Strings)

local METAL = Color3.fromRGB(70, 75, 95)
local SCREEN = Color3.fromRGB(90, 220, 255)
local WOOD = Color3.fromRGB(110, 80, 50)

-- Posición de cada articulación respecto a los pies del NPC, en reposo.
local JOINTS: { [string]: CFrame } = {
    root = CFrame.identity,
    head = CFrame.new(0, 4.6, 0),
    rightArm = CFrame.new(1.5, 4, 0),
    leftArm = CFrame.new(-1.5, 4, 0),
}

local NpcService = {}

local function ghost(root: Instance)
    for _, descendant in root:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanQuery = false
            descendant.CanTouch = false
        end
    end
end

-- Punto del suelo donde está el NPC, mirando al centro del mapa o hacia fuera.
local function baseCFrame(npc: NpcsConfig.Npc): CFrame
    local sector = math.pi * 2 / MapConfig.PlotCount
    local angle = (npc.gap - 1) * sector + sector / 2
    local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * npc.radius
    local toCenter = CFrame.lookAt(position, Vector3.zero)
    local cframe = toCenter * CFrame.new(npc.offset, 0, 0)
    return if npc.faceCenter then cframe else cframe * CFrame.Angles(0, math.pi, 0)
end

local function buildFigure(npc: NpcsConfig.Npc, base: CFrame, parent: Instance)
    local model = Instance.new("Model")
    model.Name = npc.id

    local function add(
        name: string,
        joint: string,
        offset: CFrame,
        size: Vector3,
        color: Color3,
        material: Enum.Material?,
        shape: Enum.PartType?
    ): Part
        local part = Kit.Part({
            name = name,
            size = size,
            cframe = base * JOINTS[joint] * offset,
            color = color,
            material = material,
            shape = shape,
            castShadow = false,
            parent = model,
        })
        part:SetAttribute("Joint", joint)
        part:SetAttribute("Offset", offset)
        return part
    end

    -- Raíz invisible a la altura del pecho: de ella cuelgan el nombre y la opción de hablar.
    local root = add("Root", "root", CFrame.new(0, 3, 0), Vector3.new(2, 2, 1), npc.shirt)
    root.Transparency = 1
    model.PrimaryPart = root

    add("Torso", "root", CFrame.new(0, 3, 0), Vector3.new(2, 2, 1), npc.shirt)
    add("LeftLeg", "root", CFrame.new(-0.5, 1, 0), Vector3.new(1, 2, 1), npc.pants)
    add("RightLeg", "root", CFrame.new(0.5, 1, 0), Vector3.new(1, 2, 1), npc.pants)
    add("Head", "head", CFrame.identity, Vector3.new(1.3, 1.3, 1.3), npc.skin)
    -- Ojos, en la cara que mira hacia delante (-Z).
    for _, side in { -1, 1 } do
        add(
            "Eye",
            "head",
            CFrame.new(side * 0.3, 0.1, -0.66),
            Vector3.new(0.2, 0.3, 0.05),
            Color3.fromRGB(25, 25, 30)
        )
    end
    add(
        "Hat",
        "head",
        CFrame.new(0, 0.8, 0),
        Vector3.new(1.5, 0.4, 1.5),
        npc.hat,
        Enum.Material.Metal
    )
    add("LeftArm", "leftArm", CFrame.new(0, -1, 0), Vector3.new(1, 2, 1), npc.shirt)
    add("RightArm", "rightArm", CFrame.new(0, -1, 0), Vector3.new(1, 2, 1), npc.shirt)
    if npc.animation == "mine" then
        -- Pico en la mano derecha.
        add(
            "PickHandle",
            "rightArm",
            CFrame.new(0, -2, -1.2) * CFrame.Angles(math.pi / 2, 0, 0),
            Vector3.new(0.3, 3, 0.3),
            WOOD,
            Enum.Material.Wood
        )
        add(
            "PickHead",
            "rightArm",
            CFrame.new(0, -2, -2.6),
            Vector3.new(2.2, 0.4, 0.4),
            METAL,
            Enum.Material.Metal
        )
    end
    ghost(model)

    model:SetAttribute("NpcId", npc.id)
    model:SetAttribute("Base", base)

    local name = Strings.Npcs.Names[npc.id] or npc.id
    local tag = Instance.new("BillboardGui")
    tag.Name = "NameTag"
    tag.Size = UDim2.fromScale(7, 1.1)
    tag.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
    tag.MaxDistance = 70
    tag.LightInfluence = 0
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = npc.hat
    label.TextScaled = true
    label.TextStrokeTransparency = 0.3
    label.Font = Enum.Font.GothamBold
    label.Parent = tag
    tag.Parent = root

    -- Hablar es opcional: una opción de proximidad, que funciona igual en PC, móvil y mando.
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = Strings.Npcs.Talk
    prompt.ObjectText = name
    prompt.MaxActivationDistance = NpcsConfig.TalkDistance
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    -- En mando, X ya es golpear: hablar va en Y.
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
    prompt.Parent = root

    model.Parent = parent
    model:AddTag(NpcsConfig.Tag)
end

-- Decorado de cada NPC, delante o al lado de él. Tampoco tiene colisión.
local function buildProps(npc: NpcsConfig.Npc, base: CFrame, parent: Instance)
    local folder = Instance.new("Folder")
    folder.Name = npc.id .. "Props"
    folder.Parent = parent
    local function part(
        name: string,
        offset: CFrame,
        size: Vector3,
        color: Color3,
        material: Enum.Material?,
        shape: Enum.PartType?
    ): Part
        return Kit.Part({
            name = name,
            size = size,
            cframe = base * offset,
            color = color,
            material = material,
            shape = shape,
            castShadow = false,
            parent = folder,
        })
    end

    if npc.props == "station" then
        -- Estación meteorológica: trípode con antena, una luz que late (AmbientController) y
        -- una consola.
        part("Tripod", CFrame.new(4, 3, -1), Vector3.new(0.5, 6, 0.5), METAL, Enum.Material.Metal)
        part(
            "Dish",
            CFrame.new(4, 6.4, -1) * CFrame.Angles(-0.6, 0, 0),
            Vector3.new(3, 0.3, 3),
            Color3.fromRGB(200, 205, 220),
            Enum.Material.Metal
        )
        local beacon = part(
            "Beacon",
            CFrame.new(4, 7.2, -1),
            Vector3.one * 0.7,
            Color3.fromRGB(255, 90, 60),
            Enum.Material.Neon,
            Enum.PartType.Ball
        )
        Kit.Light(beacon, Color3.fromRGB(255, 90, 60), 12, 1.5)
        part(
            "Console",
            CFrame.new(-3.5, 1.5, -1),
            Vector3.new(3, 3, 1.5),
            METAL,
            Enum.Material.Metal
        )
        part(
            "ConsoleScreen",
            CFrame.new(-3.5, 2.6, -1.8) * CFrame.Angles(-0.4, 0, 0),
            Vector3.new(2.4, 1.2, 0.1),
            SCREEN,
            Enum.Material.Neon
        )
    elseif npc.props == "lab" then
        -- Laboratorio: mesa con una pantalla y muestras de las tres mutaciones.
        part("Table", CFrame.new(0, 2.6, -4), Vector3.new(9, 0.4, 3), METAL, Enum.Material.Metal)
        for _, side in { -1, 1 } do
            part(
                "TableLeg",
                CFrame.new(side * 4, 1.2, -4),
                Vector3.new(0.5, 2.4, 2.4),
                METAL,
                Enum.Material.Metal
            )
        end
        part(
            "Monitor",
            CFrame.new(-3, 4, -4.6) * CFrame.Angles(0.15, 0, 0),
            Vector3.new(2.6, 1.8, 0.15),
            SCREEN,
            Enum.Material.Neon
        )
        local samples = {
            Color3.fromRGB(255, 205, 60),
            Color3.fromRGB(120, 255, 80),
            Color3.fromRGB(255, 120, 230),
        }
        for index, color in samples do
            local crystal = Kit.Crystal({
                cframe = base * CFrame.new(index * 1.4 - 1.2, 2.8, -4),
                height = 1.6,
                width = 0.5,
                color = color,
                canCollide = false,
                parent = folder,
            })
            if index == 2 then
                Kit.Light(crystal, color, 10, 1.2)
            end
        end
    elseif npc.props == "stall" then
        -- Puesto de intercambio: mostrador, toldo y un par de cajas.
        part("Counter", CFrame.new(0, 1.5, -3.5), Vector3.new(8, 3, 2), WOOD, Enum.Material.Wood)
        for _, side in { -1, 1 } do
            part(
                "Post",
                CFrame.new(side * 4.2, 4, -3.5),
                Vector3.new(0.5, 8, 0.5),
                METAL,
                Enum.Material.Metal
            )
        end
        part(
            "Canopy",
            CFrame.new(0, 8.2, -2.5) * CFrame.Angles(0.18, 0, 0),
            Vector3.new(10, 0.4, 6),
            npc.hat,
            Enum.Material.Fabric
        )
        part(
            "CanopyTrim",
            CFrame.new(0, 7.65, -5.4),
            Vector3.new(10, 0.25, 0.25),
            MapConfig.CollectPadColor,
            Enum.Material.Neon
        )
        part(
            "Crate",
            CFrame.new(5.5, 1.2, 0.5),
            Vector3.one * 2.4,
            MapConfig.CrateColor,
            Enum.Material.DiamondPlate
        )
        part(
            "CrateSmall",
            CFrame.new(5.2, 3.2, 0.3),
            Vector3.one * 1.6,
            MapConfig.CrateColor,
            Enum.Material.DiamondPlate
        )
    elseif npc.props == "rock" then
        -- La roca que pica el minero, con una veta que brilla.
        Kit.Rock({
            cframe = base * CFrame.new(0.6, 0, -4),
            size = 4.5,
            color = MapConfig.CraterColor,
            rng = Random.new(11),
            material = Enum.Material.Basalt,
            canCollide = false,
            parent = folder,
        })
        part(
            "Vein",
            CFrame.new(0.6, 1.6, -2.9) * CFrame.Angles(0.3, 0.4, 0.2),
            Vector3.new(1.4, 0.3, 0.3),
            Color3.fromRGB(255, 150, 60),
            Enum.Material.Neon
        )
    end
    ghost(folder)
end

function NpcService.Init()
    local folder = Instance.new("Folder")
    folder.Name = "Npcs"
    folder.Parent = MapService.GetMapFolder()
    for _, npc in NpcsConfig.List do
        local base = baseCFrame(npc)
        buildProps(npc, base, folder)
        buildFigure(npc, base, folder)
    end
end

return NpcService
