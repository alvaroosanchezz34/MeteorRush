--!strict

-- Construye el Outpost (la plaza de Config/Map.Hub) y los NPCs de Config/Npcs, cada uno en su
-- puesto alrededor de ella. Solo los crea: las figuras están ancladas y sin colisión, así que
-- no estorban a nada. Las anima cada cliente (NpcController), que también pone las frases y
-- abre el menú de los que tienen uno.
-- Cada parte de una figura lleva los atributos `Joint` (a qué articulación pertenece) y
-- `Offset` (su posición respecto a esa articulación): es lo que usa el cliente para moverla.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Parent.Builders.Kit)
local MapService = require(script.Parent.MapService)

local Shared = ReplicatedStorage.Shared
local EquipmentVisual = require(Shared.Util.EquipmentVisual)
local MapConfig = require(Shared.Config.Map)
local NpcsConfig = require(Shared.Config.Npcs)
local Locale = require(Shared.Locale)

local METAL = Color3.fromRGB(70, 75, 95)
local DARK = Color3.fromRGB(32, 33, 44)
local WHITE = Color3.fromRGB(245, 245, 250)
local SCREEN = Color3.fromRGB(90, 220, 255)
local WOOD = Color3.fromRGB(110, 80, 50)
local LEATHER = Color3.fromRGB(96, 64, 44)
local EMBER = Color3.fromRGB(255, 120, 40)
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

-- Posición de cada articulación respecto a los pies del NPC, en reposo. NpcController usa
-- las mismas medidas para animarlas.
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

-- Figuras -----------------------------------------------------------------------------------

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
    -- Cilindro de pie (el de Roblox va tumbado).
    local function cylinder(
        name: string,
        joint: string,
        offset: CFrame,
        height: number,
        diameter: number,
        color: Color3,
        material: Enum.Material?
    ): Part
        return add(
            name,
            joint,
            offset * UPRIGHT,
            Vector3.new(height, diameter, diameter),
            color,
            material,
            Enum.PartType.Cylinder
        )
    end

    local accent = npc.accent
    -- Raíz invisible a la altura del pecho: de ella cuelgan el nombre y la opción de hablar.
    local root = add("Root", "root", CFrame.new(0, 3, 0), Vector3.new(2, 2, 1), npc.shirt)
    root.Transparency = 1
    model.PrimaryPart = root

    -- Cuerpo: torso con cuello y cinturón, piernas con botas.
    add("Torso", "root", CFrame.new(0, 3, 0), Vector3.new(2, 2, 1), npc.shirt)
    add("Collar", "root", CFrame.new(0, 3.92, 0), Vector3.new(1.3, 0.2, 1.04), accent)
    add("Belt", "root", CFrame.new(0, 2.12, 0), Vector3.new(2.06, 0.3, 1.06), DARK)
    add(
        "Buckle",
        "root",
        CFrame.new(0, 2.12, -0.55),
        Vector3.new(0.42, 0.26, 0.06),
        accent,
        Enum.Material.Metal
    )
    cylinder("Neck", "root", CFrame.new(0, 4.1, 0), 0.3, 0.7, npc.skin)
    for _, side in { -1, 1 } do
        add("Leg", "root", CFrame.new(side * 0.5, 1.2, 0), Vector3.new(0.96, 1.6, 0.96), npc.pants)
        add("Boot", "root", CFrame.new(side * 0.5, 0.22, -0.13), Vector3.new(1, 0.44, 1.3), DARK)
    end

    -- Brazos: manga, hombrera del color de acento y mano.
    for joint, _ in { leftArm = true, rightArm = true } do
        add("Sleeve", joint, CFrame.new(0, -0.7, 0), Vector3.new(1, 1.4, 1), npc.shirt)
        add("Shoulder", joint, CFrame.new(0, 0.06, 0), Vector3.new(1.1, 0.3, 1.1), accent)
        add("Hand", joint, CFrame.new(0, -1.7, 0), Vector3.new(0.86, 0.6, 0.86), npc.skin)
    end

    -- Cabeza redondeada con pelo y cara: ojos con pupila, cejas y boca.
    cylinder("Head", "head", CFrame.identity, 1.3, 1.5, npc.skin)
    cylinder("Hair", "head", CFrame.new(0, 0.5, 0.05), 0.5, 1.58, npc.hair)
    add("HairBack", "head", CFrame.new(0, 0.05, 0.52), Vector3.new(1.3, 1, 0.5), npc.hair)
    for _, side in { -1, 1 } do
        add("Eye", "head", CFrame.new(side * 0.3, 0.1, -0.72), Vector3.new(0.34, 0.4, 0.08), WHITE)
        add(
            "Pupil",
            "head",
            CFrame.new(side * 0.3, 0.07, -0.76),
            Vector3.new(0.17, 0.22, 0.06),
            DARK
        )
        add(
            "Brow",
            "head",
            CFrame.new(side * 0.3, 0.4, -0.74) * CFrame.Angles(0, 0, side * -0.12),
            Vector3.new(0.38, 0.08, 0.06),
            npc.hair
        )
    end
    add("Mouth", "head", CFrame.new(0, -0.34, -0.74), Vector3.new(0.46, 0.09, 0.06), DARK)

    -- Lo que lleva en la cabeza.
    local headgear = npc.headgear
    if headgear == "cap" then
        cylinder("Cap", "head", CFrame.new(0, 0.78, 0), 0.5, 1.62, accent)
        add("Visor", "head", CFrame.new(0, 0.58, -0.95), Vector3.new(1.2, 0.12, 0.7), accent)
    elseif headgear == "hardhat" then
        cylinder("HardHat", "head", CFrame.new(0, 0.84, 0), 0.6, 1.7, accent)
        cylinder("HardHatBrim", "head", CFrame.new(0, 0.56, 0), 0.1, 2.05, accent)
        add(
            "HeadLamp",
            "head",
            CFrame.new(0, 0.84, -0.86),
            Vector3.new(0.36, 0.36, 0.16),
            Color3.fromRGB(255, 245, 200),
            Enum.Material.Neon
        )
    elseif headgear == "goggles" then
        cylinder("GoggleStrap", "head", CFrame.new(0, 0.12, 0), 0.3, 1.56, DARK)
        for _, side in { -1, 1 } do
            add(
                "Lens",
                "head",
                CFrame.new(side * 0.32, 0.12, -0.8),
                Vector3.new(0.46, 0.4, 0.12),
                accent,
                Enum.Material.Neon
            )
        end
    elseif headgear == "headset" then
        add("HeadBand", "head", CFrame.new(0, 0.76, 0), Vector3.new(1.72, 0.16, 0.3), DARK)
        for _, side in { -1, 1 } do
            add(
                "EarCup",
                "head",
                CFrame.new(side * 0.84, 0.1, 0),
                Vector3.new(0.26, 0.62, 0.62),
                accent
            )
        end
        add(
            "Antenna",
            "head",
            CFrame.new(0.84, 0.9, 0),
            Vector3.new(0.08, 1, 0.08),
            METAL,
            Enum.Material.Metal
        )
        add(
            "AntennaTip",
            "head",
            CFrame.new(0.84, 1.46, 0),
            Vector3.one * 0.24,
            Color3.fromRGB(255, 90, 60),
            Enum.Material.Neon,
            Enum.PartType.Ball
        )
    elseif headgear == "turban" then
        cylinder("Turban", "head", CFrame.new(0, 0.72, 0), 0.72, 1.78, accent, Enum.Material.Fabric)
        add(
            "Jewel",
            "head",
            CFrame.new(0, 0.78, -0.88),
            Vector3.one * 0.3,
            Color3.fromRGB(255, 215, 90),
            Enum.Material.Neon,
            Enum.PartType.Ball
        )
    elseif headgear == "tophat" then
        cylinder("HatBrim", "head", CFrame.new(0, 0.7, 0), 0.1, 2.1, DARK)
        cylinder("HatCrown", "head", CFrame.new(0, 1.25, 0), 1, 1.3, DARK)
        cylinder("HatBand", "head", CFrame.new(0, 0.86, 0), 0.2, 1.34, accent)
    elseif headgear == "helmet" then
        cylinder("Helmet", "head", CFrame.new(0, 0.42, 0), 0.8, 1.74, accent, Enum.Material.Metal)
        add(
            "HelmetVisor",
            "head",
            CFrame.new(0, 0.5, -0.82),
            Vector3.new(1.1, 0.26, 0.14),
            SCREEN,
            Enum.Material.Neon
        )
    else
        -- "bandana"
        cylinder("Bandana", "head", CFrame.new(0, 0.5, 0), 0.34, 1.62, accent, Enum.Material.Fabric)
        add("Knot", "head", CFrame.new(0.3, 0.45, 0.85), Vector3.one * 0.34, accent)
    end

    -- Lo que lleva puesto.
    local accessory = npc.accessory
    if accessory == "backpack" then
        add("Backpack", "root", CFrame.new(0, 3.05, 0.86), Vector3.new(1.6, 1.8, 0.7), LEATHER)
        add(
            "BedRoll",
            "root",
            CFrame.new(0, 4.15, 0.86),
            Vector3.new(1.7, 0.5, 0.5),
            accent,
            Enum.Material.Fabric,
            Enum.PartType.Cylinder
        )
    elseif accessory == "coat" then
        add("CoatBack", "root", CFrame.new(0, 1.55, 0.5), Vector3.new(2.05, 1.5, 0.12), npc.shirt)
        for _, side in { -1, 1 } do
            add(
                "CoatFlap",
                "root",
                CFrame.new(side * 0.75, 1.55, -0.5),
                Vector3.new(0.55, 1.5, 0.12),
                npc.shirt
            )
            add(
                "Lapel",
                "root",
                CFrame.new(side * 0.42, 3.45, -0.53) * CFrame.Angles(0, 0, side * 0.35),
                Vector3.new(0.3, 1, 0.06),
                accent
            )
        end
    elseif accessory == "apron" then
        add("Apron", "root", CFrame.new(0, 2.5, -0.55), Vector3.new(1.5, 2.4, 0.08), LEATHER)
        add("ApronPocket", "root", CFrame.new(0, 2.4, -0.61), Vector3.new(0.8, 0.5, 0.06), DARK)
    elseif accessory == "sash" then
        add(
            "Sash",
            "root",
            CFrame.new(0, 3, -0.54) * CFrame.Angles(0, 0, math.rad(40)),
            Vector3.new(0.42, 2.7, 0.08),
            accent,
            Enum.Material.Fabric
        )
    elseif accessory == "toolbelt" then
        for _, side in { -1, 1 } do
            add(
                "Pouch",
                "root",
                CFrame.new(side * 0.72, 1.92, -0.6),
                Vector3.new(0.5, 0.5, 0.3),
                LEATHER
            )
        end
        add(
            "Badge",
            "root",
            CFrame.new(-0.55, 3.5, -0.53),
            Vector3.new(0.36, 0.36, 0.06),
            accent,
            Enum.Material.Metal
        )
    end

    -- Lo que lleva en la mano.
    local item = npc.item
    if item == "pick" then
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
    elseif item == "hammer" then
        add(
            "HammerHandle",
            "rightArm",
            CFrame.new(0, -2, -0.8) * CFrame.Angles(math.pi / 2, 0, 0),
            Vector3.new(0.26, 2, 0.26),
            WOOD,
            Enum.Material.Wood
        )
        add(
            "HammerHead",
            "rightArm",
            CFrame.new(0, -2, -1.8),
            Vector3.new(0.7, 1.1, 0.7),
            METAL,
            Enum.Material.Metal
        )
    elseif item == "tablet" then
        add(
            "Tablet",
            "leftArm",
            CFrame.new(0.1, -1.95, -0.5) * CFrame.Angles(-0.5, 0, 0),
            Vector3.new(0.9, 0.08, 1.2),
            DARK
        )
        add(
            "TabletScreen",
            "leftArm",
            CFrame.new(0.1, -1.9, -0.52) * CFrame.Angles(-0.5, 0, 0),
            Vector3.new(0.74, 0.04, 1),
            SCREEN,
            Enum.Material.Neon
        )
    end
    ghost(model)

    model:SetAttribute("NpcId", npc.id)
    model:SetAttribute("Base", base)

    -- Cartel: nombre y, debajo, para qué sirve.
    local name = Locale.Ref(`Npcs.Names.{npc.id}`)
    local tag = Instance.new("BillboardGui")
    -- Los textos ya salen en el idioma elegido: sin traducción automática de Roblox.
    tag.AutoLocalize = false
    tag.Name = "NameTag"
    tag.Size = UDim2.fromScale(9, 2.2)
    tag.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
    tag.MaxDistance = NpcsConfig.NameDistance
    tag.LightInfluence = 0
    local function line(
        text: Locale.Message,
        color: Color3,
        y: number,
        height: number,
        font: Enum.Font
    )
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, height)
        label.Position = UDim2.fromScale(0, y)
        label.BackgroundTransparency = 1
        Locale.Tag(label, "Text", text)
        label.TextColor3 = color
        label.TextScaled = true
        label.TextStrokeTransparency = 0
        label.Font = font
        label.Parent = tag
    end
    line(name, accent, 0, 0.58, Enum.Font.GothamBlack)
    line(Locale.Ref(`Npcs.Roles.{npc.id}`), WHITE, 0.6, 0.4, Enum.Font.GothamBold)
    tag.Parent = root

    -- Hablar es opcional: una opción de proximidad, que funciona igual en PC, móvil y mando.
    local prompt = Instance.new("ProximityPrompt")
    -- Los que abren un menú dicen cuál; los demás, "Hablar".
    local actionKey = `Npcs.Actions.{npc.id}`
    Locale.Tag(
        prompt,
        "ActionText",
        Locale.Ref(if Locale.GetRaw(actionKey) ~= nil then actionKey else "Npcs.Talk")
    )
    Locale.Tag(prompt, "ObjectText", name)
    prompt.MaxActivationDistance = NpcsConfig.TalkDistance
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    -- En mando, X es golpear y Y la habilidad del arma: hablar va en la cruceta.
    prompt.GamepadKeyCode = Enum.KeyCode.DPadUp
    prompt.Parent = root

    model.Parent = parent
    model:AddTag(NpcsConfig.Tag)
end

-- Puestos -----------------------------------------------------------------------------------

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
    -- Mostrador con toldo del color del NPC: lo comparten varios puestos.
    local function counter(color: Color3)
        part("Counter", CFrame.new(0, 1.5, -3.5), Vector3.new(8, 3, 2), color, Enum.Material.Wood)
        part("CounterTop", CFrame.new(0, 3.1, -3.5), Vector3.new(8.4, 0.25, 2.4), DARK)
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
            npc.accent,
            Enum.Material.Fabric
        )
    end
    -- Modelo de equipamiento o de caja expuesto en el puesto.
    local function display(model: Model?, offset: CFrame)
        if model then
            model:PivotTo(base * offset)
            model.Parent = folder
        end
    end

    local props = npc.props
    if props == "station" then
        -- Estación meteorológica: trípode con antena, una luz que late y una consola.
        part("Tripod", CFrame.new(4, 3, -1), Vector3.new(0.5, 6, 0.5), METAL, Enum.Material.Metal)
        part(
            "Dish",
            CFrame.new(4, 6.4, -1) * CFrame.Angles(-0.6, 0, 0),
            Vector3.new(3, 0.3, 3),
            Color3.fromRGB(200, 205, 220),
            Enum.Material.Metal
        )
        part(
            "Beacon",
            CFrame.new(4, 7.2, -1),
            Vector3.one * 0.7,
            Color3.fromRGB(255, 90, 60),
            Enum.Material.Neon,
            Enum.PartType.Ball
        )
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
    elseif props == "lab" then
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
            Kit.Crystal({
                cframe = base * CFrame.new(index * 1.4 - 1.2, 2.8, -4),
                height = 1.6,
                width = 0.5,
                color = color,
                canCollide = false,
                parent = folder,
            })
        end
    elseif props == "stall" then
        -- Puesto de intercambio: mostrador, toldo y un par de cajas.
        counter(WOOD)
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
    elseif props == "rock" then
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
    elseif props == "crates" then
        -- Puesto de cajas: las de verdad, de la más corriente a la más valiosa.
        counter(Color3.fromRGB(70, 50, 90))
        display(EquipmentVisual.CreateCrate("basic"), CFrame.new(-5.6, 1.2, 0.4))
        display(
            EquipmentVisual.CreateCrate("rare"),
            CFrame.new(-5.2, 3.75, 0.2) * CFrame.Angles(0, 0.4, 0)
        )
        display(EquipmentVisual.CreateCrate("epic"), CFrame.new(5.6, 1.2, 0.4))
        display(
            EquipmentVisual.CreateCrate("legendary"),
            CFrame.new(0, 4.45, -3.5) * CFrame.Angles(0, 0.3, 0)
        )
    elseif props == "forge" then
        -- Fragua: yunque (donde golpea), horno con brasas y un par de piezas terminadas.
        part(
            "AnvilBase",
            CFrame.new(0.6, 0.7, -3),
            Vector3.new(1.4, 1.4, 1.4),
            DARK,
            Enum.Material.Metal
        )
        part(
            "Anvil",
            CFrame.new(0.6, 1.7, -3),
            Vector3.new(1.2, 0.6, 2.6),
            METAL,
            Enum.Material.Metal
        )
        part("Furnace", CFrame.new(-4.5, 2.5, -2), Vector3.new(4, 5, 4), DARK, Enum.Material.Basalt)
        part(
            "Embers",
            CFrame.new(-4.5, 1.6, -4.02),
            Vector3.new(2.4, 1.6, 0.1),
            EMBER,
            Enum.Material.Neon
        )
        part(
            "Chimney",
            CFrame.new(-4.5, 6.5, -2),
            Vector3.new(1.6, 3, 1.6),
            DARK,
            Enum.Material.Basalt
        )
        part("Rack", CFrame.new(5, 2.5, -1), Vector3.new(0.4, 5, 3.4), WOOD, Enum.Material.Wood)
        display(
            EquipmentVisual.Create("starforgePick"),
            CFrame.new(4.6, 2, -1.9) * CFrame.Angles(0, math.pi / 2, 0)
        )
        display(
            EquipmentVisual.Create("cometBlade"),
            CFrame.new(4.6, 1.4, -0.1) * CFrame.Angles(0, math.pi / 2, 0)
        )
    elseif props == "board" then
        -- Tablón de encargos: dos postes, el tablón y unas cuantas notas clavadas.
        for _, side in { -1, 1 } do
            part(
                "BoardPost",
                CFrame.new(side * 3.4, 3, -4),
                Vector3.new(0.5, 6, 0.5),
                WOOD,
                Enum.Material.Wood
            )
        end
        part("Board", CFrame.new(0, 4, -4), Vector3.new(6.6, 3.6, 0.3), LEATHER, Enum.Material.Wood)
        local notes = {
            { -2, 4.6, Color3.fromRGB(250, 240, 200) },
            { -0.3, 3.5, Color3.fromRGB(255, 200, 120) },
            { 1.5, 4.5, Color3.fromRGB(200, 235, 255) },
            { 2.2, 3.2, Color3.fromRGB(250, 240, 200) },
        }
        for index, note in notes do
            part(
                "Note",
                CFrame.new(note[1] :: number, note[2] :: number, -3.8)
                    * CFrame.Angles(0, 0, (index - 2.5) * 0.08),
                Vector3.new(1.2, 1.4, 0.06),
                note[3] :: Color3
            )
        end
    elseif props == "supply" then
        -- Suministros: cajas apiladas y un mástil con la bandera del puesto.
        part(
            "SupplyCrate",
            CFrame.new(-3.2, 1.3, -3),
            Vector3.one * 2.6,
            MapConfig.CrateColor,
            Enum.Material.WoodPlanks
        )
        part(
            "SupplyCrateTop",
            CFrame.new(-2.9, 3.5, -3.1),
            Vector3.one * 1.8,
            MapConfig.CrateColor,
            Enum.Material.WoodPlanks
        )
        part(
            "SupplyBox",
            CFrame.new(-0.4, 0.9, -3.4),
            Vector3.new(2.2, 1.8, 1.8),
            npc.accent,
            Enum.Material.Metal
        )
        part(
            "FlagPole",
            CFrame.new(4.2, 5, -2),
            Vector3.new(0.3, 10, 0.3),
            METAL,
            Enum.Material.Metal
        )
        part(
            "Flag",
            CFrame.new(5.8, 8.8, -2),
            Vector3.new(3, 1.8, 0.1),
            npc.accent,
            Enum.Material.Fabric
        )
    end
    ghost(folder)
end

-- Plaza -------------------------------------------------------------------------------------

-- La plaza del Outpost: plataforma redonda con losa central de llegada, anillo de borde,
-- farolas apagadas de más (solo cuatro luces suaves) y un cartel sobre el centro.
local function buildPlaza(center: CFrame, parent: Instance)
    local hub = MapConfig.Hub
    local diameter = hub.size * 2
    local function disc(
        name: string,
        radius: number,
        height: number,
        y: number,
        color: Color3,
        material: Enum.Material?
    ): Part
        local part = Kit.Part({
            name = name,
            size = Vector3.new(height, radius * 2, radius * 2),
            cframe = center * CFrame.new(0, y, 0) * UPRIGHT,
            color = color,
            material = material,
            shape = Enum.PartType.Cylinder,
            castShadow = false,
            parent = parent,
        })
        return part
    end
    -- La plataforma se pisa; lo de encima es solo dibujo.
    disc(
        "Plaza",
        hub.size,
        hub.height,
        hub.height / 2,
        MapConfig.PlotFloorColor,
        Enum.Material.Slate
    )
    local top = hub.height
    for _, ring in
        {
            { "PlazaInner", hub.size - 3, MapConfig.PlotTileColor },
            { "PlazaRing", hub.npcRadius - 8, MapConfig.PlotTileAltColor },
            { "PlazaCore", 9, MapConfig.PlotTileColor },
        }
    do
        local part = disc(ring[1] :: string, ring[2] :: number, 0.06, top + 0.03, ring[3] :: Color3)
        part.CanCollide = false
        part.CanQuery = false
        top += 0.02
    end
    local pad =
        disc("ArrivalPad", 5, 0.08, top + 0.06, MapConfig.PlotAccentColor, Enum.Material.Neon)
    pad.CanCollide = false
    pad.CanQuery = false
    pad.Transparency = 0.45

    -- Bordillo: tramos rectos alrededor.
    local segments = 28
    for index = 1, segments do
        local angle = index / segments * math.pi * 2
        Kit.Part({
            name = "PlazaCurb",
            size = Vector3.new(diameter * math.pi / segments + 0.4, 0.7, 1.4),
            cframe = center
                * CFrame.Angles(0, angle, 0)
                * CFrame.new(0, hub.height + 0.1, -(hub.size - 0.7)),
            color = MapConfig.PlotTrimColor,
            material = Enum.Material.Metal,
            canCollide = false,
            castShadow = false,
            parent = parent,
        })
    end

    -- Cuatro farolas, entre puesto y puesto.
    for index = 1, 4 do
        Kit.Lamp({
            cframe = center
                * CFrame.Angles(0, index * math.pi / 2, 0)
                * CFrame.new(0, hub.height, -(hub.size - 4)),
            height = 9,
            color = MapConfig.PlotAccentColor,
            postColor = MapConfig.PlotTrimColor,
            lit = true,
            parent = parent,
        })
    end

    -- Cartel flotante sobre el centro, para encontrar la plaza desde lejos.
    local anchor = Kit.Part({
        name = "OutpostSign",
        size = Vector3.one,
        cframe = center * CFrame.new(0, 16, 0),
        color = MapConfig.PlotAccentColor,
        transparency = 1,
        canCollide = false,
        parent = parent,
    })
    anchor.CanQuery = false
    local sign = Instance.new("BillboardGui")
    -- Los textos ya salen en el idioma elegido: sin traducción automática de Roblox.
    sign.AutoLocalize = false
    sign.Size = UDim2.fromScale(26, 5)
    sign.MaxDistance = 600
    sign.LightInfluence = 0
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    Locale.Tag(label, "Text", Locale.Msg("Npcs.OutpostSign"))
    label.TextColor3 = MapConfig.PlotAccentColor
    label.TextScaled = true
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBlack
    label.Parent = sign
    sign.Parent = anchor
end

function NpcService.Init()
    local folder = Instance.new("Folder")
    folder.Name = "Outpost"
    folder.Parent = MapService.GetMapFolder()

    local hub = MapConfig.Hub
    local center = MapConfig.GetHubCFrame()
    buildPlaza(center, folder)

    -- Los NPCs, repartidos en círculo y mirando al centro de la plaza. El medio paso de giro
    -- deja libre el lado que da al mapa, que es por donde se llega andando.
    local count = #NpcsConfig.List
    local middle = (center * CFrame.new(0, hub.height, 0)).Position
    for index, npc in NpcsConfig.List do
        local angle = (index - 0.5) / count * math.pi * 2
        local spot = (center * CFrame.Angles(0, angle, 0) * CFrame.new(
            0,
            hub.height,
            -hub.npcRadius
        )).Position
        local base = CFrame.lookAt(spot, middle)
        buildProps(npc, base, folder)
        buildFigure(npc, base, folder)
    end
end

return NpcService
