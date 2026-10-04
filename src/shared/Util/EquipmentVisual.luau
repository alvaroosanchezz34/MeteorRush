--!strict

-- Modelos de los picos, las armas y las cajas, construidos con piezas a partir de su
-- definición (estilo, color, acento y rareza), sin assets externos. Los usan el servidor
-- (lo que lleva el personaje) y el cliente (vistas previas y apertura de cajas), así que un
-- objeto se ve igual en todas partes.
-- Cuanto más raro es un objeto, más detalle lleva: filo luminoso, núcleo de energía, luz,
-- partículas y, los Míticos, un anillo. Las piezas se crean ancladas; `Attach` las suelda a
-- un personaje.

local Equipment = require(script.Parent.Parent.Config.Equipment)
local Crates = require(script.Parent.Parent.Config.Crates)

local HANDLE_COLOR = Color3.fromRGB(96, 72, 50)
local DARK_METAL = Color3.fromRGB(50, 52, 62)

local EquipmentVisual = {}

local function part(
    model: Model,
    name: string,
    size: Vector3,
    cframe: CFrame,
    color: Color3,
    material: Enum.Material,
    shape: Enum.PartType?
): Part
    local instance = Instance.new("Part")
    instance.Name = name
    instance.Shape = shape or Enum.PartType.Block
    instance.Size = size
    instance.CFrame = cframe
    instance.Color = color
    instance.Material = material
    instance.Anchored = true
    instance.CanCollide = false
    instance.CanQuery = false
    instance.CanTouch = false
    instance.CastShadow = false
    instance.Massless = true
    instance.TopSurface = Enum.SurfaceType.Smooth
    instance.BottomSurface = Enum.SurfaceType.Smooth
    instance.Parent = model
    return instance
end

-- Un cilindro a lo largo del eje Y (el de Roblox va a lo largo de X).
local function rod(
    model: Model,
    name: string,
    length: number,
    width: number,
    cframe: CFrame,
    color: Color3,
    material: Enum.Material
): Part
    local instance = part(
        model,
        name,
        Vector3.new(length, width, width),
        cframe * CFrame.Angles(0, 0, math.pi / 2),
        color,
        material,
        Enum.PartType.Cylinder
    )
    -- El pivote se deja sin el giro, para que el modelo se coloque con +Y hacia la punta.
    instance.PivotOffset = CFrame.Angles(0, 0, -math.pi / 2)
    return instance
end

-- Luz y partículas de los objetos raros, colgadas de una pieza.
local function addEnergy(holder: BasePart, color: Color3, rank: number)
    if rank >= 4 then
        local light = Instance.new("PointLight")
        light.Name = "Glow"
        light.Color = color
        light.Range = 5 + rank
        light.Brightness = 0.6 + (rank - 4) * 0.4
        light.Shadows = false
        light.Parent = holder
    end
    if rank >= 5 then
        local sparks = Instance.new("ParticleEmitter")
        sparks.Name = "Sparks"
        sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
        sparks.Size = NumberSequence.new(0.16, 0)
        sparks.Transparency = NumberSequence.new(0.1, 1)
        sparks.Lifetime = NumberRange.new(0.4, 0.8)
        sparks.Speed = NumberRange.new(0.5, 1.6)
        sparks.SpreadAngle = Vector2.new(180, 180)
        sparks.LightEmission = 1
        sparks.Rate = if rank >= 6 then 9 else 4
        sparks.Parent = holder
    end
end

-- Pico: mango, cabeza y, según la rareza, puntas luminosas, núcleo y anillo.
local function buildPickaxe(model: Model, item: Equipment.Item, rank: number, color: Color3)
    local accent = item.accent or color
    local handle = part(
        model,
        "Handle",
        Vector3.new(0.3, 3, 0.3),
        CFrame.identity,
        if rank >= 4 then DARK_METAL else HANDLE_COLOR,
        if rank >= 4 then Enum.Material.Metal else Enum.Material.Wood
    )
    model.PrimaryPart = handle
    local head = part(
        model,
        "Head",
        Vector3.new(2.2, 0.4, 0.4),
        CFrame.new(0, 1.5, 0),
        color,
        if rank >= 3 then Enum.Material.Glass else Enum.Material.Metal
    )
    if rank >= 2 then
        -- Puntas en cuña a cada lado de la cabeza.
        for _, side in { -1, 1 } do
            part(
                model,
                "Tip",
                Vector3.new(0.34, 0.5, 0.36),
                CFrame.new(side * 1.28, 1.42, 0) * CFrame.Angles(0, 0, side * math.rad(-28)),
                if rank >= 3 then accent else color,
                if rank >= 3 then Enum.Material.Neon else Enum.Material.Metal
            )
        end
    end
    if rank >= 4 then
        part(
            model,
            "Core",
            Vector3.new(1.7, 0.14, 0.46),
            CFrame.new(0, 1.5, 0),
            accent,
            Enum.Material.Neon
        )
    end
    if rank >= 6 then
        local ring = part(
            model,
            "Ring",
            Vector3.new(0.08, 1.1, 1.1),
            CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.pi / 2, 0),
            accent,
            Enum.Material.Neon,
            Enum.PartType.Cylinder
        )
        ring.Transparency = 0.45
    end
    addEnergy(head, accent, rank)
end

-- Armas: una forma por estilo. El mango siempre es la pieza principal, con +Y hacia la punta.
local function buildWeapon(model: Model, item: Equipment.Item, rank: number)
    local color = item.color
    local accent = item.accent or color
    local style = item.style
    local handle = rod(model, "Handle", 1.1, 0.26, CFrame.identity, DARK_METAL, Enum.Material.Metal)
    model.PrimaryPart = handle
    local energy: BasePart = handle

    if style == "bat" then
        rod(model, "Body", 2.3, 0.5, CFrame.new(0, 1.6, 0), color, Enum.Material.Wood)
    elseif style == "club" then
        rod(model, "Body", 1.6, 0.4, CFrame.new(0, 1.3, 0), color, Enum.Material.Metal)
        part(
            model,
            "Weight",
            Vector3.new(0.8, 0.7, 0.8),
            CFrame.new(0, 2.2, 0),
            color,
            Enum.Material.DiamondPlate
        )
    elseif style == "stick" then
        rod(model, "Body", 2, 0.24, CFrame.new(0, 1.5, 0), color, Enum.Material.Metal)
        for _, side in { -1, 1 } do
            energy = part(
                model,
                "Prong",
                Vector3.new(0.12, 0.6, 0.12),
                CFrame.new(side * 0.16, 2.7, 0),
                accent,
                Enum.Material.Neon
            )
        end
    elseif style == "baton" then
        rod(model, "Body", 0.5, 0.36, CFrame.new(0, 0.75, 0), color, Enum.Material.Metal)
        energy = rod(model, "Blade", 2.2, 0.3, CFrame.new(0, 2.1, 0), accent, Enum.Material.Neon)
    elseif style == "hammer" then
        rod(model, "Body", 2.2, 0.3, CFrame.new(0, 1.6, 0), DARK_METAL, Enum.Material.Metal)
        part(
            model,
            "Head",
            Vector3.new(1.7, 1.1, 1.1),
            CFrame.new(0, 2.9, 0),
            color,
            Enum.Material.Metal
        )
        energy = part(
            model,
            "Core",
            Vector3.new(1.8, 0.5, 0.5),
            CFrame.new(0, 2.9, 0),
            accent,
            Enum.Material.Neon
        )
    elseif style == "blade" then
        part(
            model,
            "Guard",
            Vector3.new(1, 0.16, 0.34),
            CFrame.new(0, 0.62, 0),
            accent,
            Enum.Material.Metal
        )
        part(
            model,
            "Blade",
            Vector3.new(0.5, 3, 0.1),
            CFrame.new(0, 2.2, 0),
            color,
            Enum.Material.Metal
        )
        energy = part(
            model,
            "Edge",
            Vector3.new(0.14, 3.1, 0.14),
            CFrame.new(0.24, 2.2, 0),
            accent,
            Enum.Material.Neon
        )
    else
        -- "breaker": maza de vacío con un núcleo flotando entre dos garras.
        rod(model, "Body", 2, 0.3, CFrame.new(0, 1.5, 0), color, Enum.Material.Metal)
        for _, side in { -1, 1 } do
            part(
                model,
                "Claw",
                Vector3.new(0.3, 1.3, 0.5),
                CFrame.new(side * 0.55, 3, 0) * CFrame.Angles(0, 0, side * math.rad(-18)),
                color,
                Enum.Material.Metal
            )
        end
        energy = part(
            model,
            "Core",
            Vector3.one * 0.7,
            CFrame.new(0, 3.1, 0),
            accent,
            Enum.Material.Neon,
            Enum.PartType.Ball
        )
        local ring = part(
            model,
            "Ring",
            Vector3.new(0.08, 1.5, 1.5),
            CFrame.new(0, 3.1, 0) * CFrame.Angles(0, math.pi / 2, 0),
            accent,
            Enum.Material.Neon,
            Enum.PartType.Cylinder
        )
        ring.Transparency = 0.5
    end
    addEnergy(energy, accent, rank)
end

-- Modelo de un objeto de equipamiento. `colorOverride` cambia el color de la cabeza del
-- pico (los cosméticos de pico de la tienda). Devuelve nil si el objeto no existe.
function EquipmentVisual.Create(itemId: string, colorOverride: Color3?): Model?
    local item = Equipment.ById[itemId]
    if item == nil then
        return nil
    end
    local model = Instance.new("Model")
    model.Name = itemId
    local rank = Equipment.GetRank(item)
    if item.kind == "pickaxe" then
        buildPickaxe(model, item, rank, colorOverride or item.color)
    else
        buildWeapon(model, item, rank)
    end
    return model
end

-- Suelda el modelo a una pieza del personaje, con ese desplazamiento respecto a ella.
function EquipmentVisual.Attach(model: Model, to: BasePart, offset: CFrame)
    local handle = model.PrimaryPart
    if handle == nil then
        return
    end
    model:PivotTo(to.CFrame * offset)
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Anchored = false
            if descendant ~= handle then
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = handle
                weld.Part1 = descendant
                weld.Parent = descendant
            end
        end
    end
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = to
    weld.Part1 = handle
    weld.Parent = handle
end

-- Modelo de una caja: cuerpo, tapa (pieza "Lid", que la apertura levanta), refuerzos y, las
-- raras, cerradura luminosa y luz. Cuanto más rara, más se nota antes de abrirla.
function EquipmentVisual.CreateCrate(crateId: string): Model?
    local crate = Crates.ById[crateId]
    if crate == nil then
        return nil
    end
    local rarity = Equipment.Rarities[crate.rarity]
    local rank = rarity.rank
    local model = Instance.new("Model")
    model.Name = `Crate_{crateId}`

    local bodyColor = if rank >= 4 then Color3.fromRGB(34, 30, 48) else Color3.fromRGB(110, 86, 60)
    local material = if rank >= 4 then Enum.Material.Metal else Enum.Material.WoodPlanks
    local body = part(model, "Body", Vector3.new(4, 2.4, 3), CFrame.identity, bodyColor, material)
    model.PrimaryPart = body
    part(model, "Lid", Vector3.new(4.2, 0.7, 3.2), CFrame.new(0, 1.55, 0), bodyColor, material)
    -- Refuerzos del color de la rareza.
    for _, x in { -1.5, 1.5 } do
        part(
            model,
            "Band",
            Vector3.new(0.4, 2.5, 3.1),
            CFrame.new(x, 0, 0),
            rarity.color,
            if rank >= 3 then Enum.Material.Neon else Enum.Material.Metal
        )
    end
    local lock = part(
        model,
        "Lock",
        Vector3.new(0.7, 0.8, 0.3),
        CFrame.new(0, 0.9, -1.55),
        rarity.color,
        if rank >= 2 then Enum.Material.Neon else Enum.Material.Metal
    )
    if rank >= 5 then
        -- Esquinas de cristal en las cajas Legendaria y Mítica.
        for _, x in { -2, 2 } do
            for _, z in { -1.5, 1.5 } do
                part(
                    model,
                    "Corner",
                    Vector3.new(0.5, 2.9, 0.5),
                    CFrame.new(x, 0.15, z),
                    rarity.color,
                    Enum.Material.Neon
                ).Transparency =
                    0.25
            end
        end
    end
    addEnergy(lock, rarity.color, rank)
    return model
end

return EquipmentVisual
