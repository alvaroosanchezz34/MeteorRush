--!strict

-- Crea la representación visual de un mineral: el modelo de ReplicatedStorage/Assets/Mineral_<id>
-- o, si no existe, un modelo generado con Parts con la forma y el color propios del mineral.
-- La mutación cambia el material y el color, y añade destellos.

local Assets = require(script.Parent.Assets)
local Minerals = require(script.Parent.Parent.Config.Minerals)
local Mutations = require(script.Parent.Parent.Config.Mutations)

local MineralVisual = {}

type PartSpec = {
    shape: Enum.PartType,
    -- Tamaño y posición en unidades del tamaño total del mineral (1 = `size`).
    size: Vector3,
    cframe: CFrame,
    material: Enum.Material,
    -- Color fijo; si es nil se usa el color del mineral.
    color: Color3?,
    -- Mezcla del color con blanco (0-1), para núcleos brillantes.
    lighten: number?,
    -- Mezcla del color con negro (0-1), para dar variedad de tono.
    darken: number?,
    transparency: number?,
    reflectance: number?,
}

type SpecOptions = {
    color: Color3?,
    lighten: number?,
    darken: number?,
    transparency: number?,
    reflectance: number?,
}

local BLOCK = Enum.PartType.Block
local BALL = Enum.PartType.Ball
local CYLINDER = Enum.PartType.Cylinder
local WEDGE = Enum.PartType.Wedge

local SLATE = Enum.Material.Slate
local METAL = Enum.Material.Metal
local GLASS = Enum.Material.Glass
local NEON = Enum.Material.Neon

local FALLBACK_COLOR = Color3.fromRGB(128, 128, 128)
local FALLBACK_SHAPE = "stone"
local HOST_ROCK = Color3.fromRGB(70, 68, 78)
local PATINA = Color3.fromRGB(70, 170, 150)
local VOID = Color3.fromRGB(12, 8, 20)

local function at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
    return CFrame.new(x, y, z) * CFrame.Angles(rx or 0, ry or 0, rz or 0)
end

local function cube(side: number): Vector3
    return Vector3.one * side
end

local function spec(
    shape: Enum.PartType,
    size: Vector3,
    cframe: CFrame,
    material: Enum.Material,
    options: SpecOptions?
): PartSpec
    local extra: SpecOptions = options or {}
    return {
        shape = shape,
        size = size,
        cframe = cframe,
        material = material,
        color = extra.color,
        lighten = extra.lighten,
        darken = extra.darken,
        transparency = extra.transparency,
        reflectance = extra.reflectance,
    }
end

-- Añade un cristal con punta (prisma + cuña) que crece desde `base` hacia su +Y.
local function addCrystal(list: { PartSpec }, base: CFrame, height: number, width: number)
    local shaft = height * 0.72
    local tip = height - shaft
    local options = { transparency = 0.2 }
    table.insert(
        list,
        spec(
            BLOCK,
            Vector3.new(width, shaft, width),
            base * CFrame.new(0, shaft / 2, 0),
            GLASS,
            options
        )
    )
    table.insert(
        list,
        spec(
            WEDGE,
            Vector3.new(width, tip, width),
            base * CFrame.new(0, shaft + tip / 2, 0),
            GLASS,
            options
        )
    )
end

-- La primera parte de cada forma es la principal: va centrada y sin girar.
local SHAPES: { [string]: { PartSpec } } = {
    -- Roca: trozos angulosos de dos tonos.
    stone = {
        spec(BALL, cube(0.7), CFrame.identity, SLATE),
        spec(BLOCK, Vector3.new(0.55, 0.4, 0.5), at(0.18, 0.05, -0.1, 0.5, 0.7, 0.2), SLATE, {
            darken = 0.15,
        }),
        spec(WEDGE, Vector3.new(0.45, 0.35, 0.45), at(-0.2, 0.12, 0.12, 0.3, 2.1, 0.4), SLATE),
        spec(BLOCK, Vector3.new(0.38, 0.3, 0.42), at(-0.12, -0.2, -0.18, 1.1, 0.3, 0.8), SLATE, {
            darken = 0.25,
        }),
        spec(WEDGE, Vector3.new(0.4, 0.3, 0.35), at(0.12, -0.2, 0.2, 2.2, 1, 0.2), SLATE, {
            darken = 0.1,
        }),
    },
    -- Hierro: roca oscura con pepitas de metal brillante incrustadas.
    iron = {
        spec(BLOCK, Vector3.new(0.7, 0.5, 0.6), CFrame.identity, SLATE, { color = HOST_ROCK }),
        spec(WEDGE, Vector3.new(0.5, 0.4, 0.5), at(0.12, 0.28, 0, 0, 0.6, 0), SLATE, {
            color = HOST_ROCK,
        }),
        spec(BLOCK, cube(0.3), at(-0.25, 0.15, 0.2, 0.6, 0.4, 0.3), METAL, { reflectance = 0.3 }),
        spec(BLOCK, Vector3.new(0.28, 0.22, 0.3), at(0.3, -0.05, 0.22, 0.2, 1, 0.5), METAL, {
            reflectance = 0.3,
        }),
        spec(BLOCK, Vector3.new(0.22, 0.3, 0.22), at(0.05, 0.1, -0.32, 0.9, 0.2, 0.1), METAL, {
            reflectance = 0.3,
        }),
        spec(BLOCK, cube(0.2), at(-0.3, -0.15, -0.15, 0.4, 0.9, 0.7), METAL, {
            reflectance = 0.3,
        }),
    },
    -- Cobre: racimo de pepitas redondas con motas de pátina verde.
    copper = {
        spec(BALL, cube(0.62), CFrame.identity, METAL),
        spec(BALL, cube(0.48), at(0.24, -0.08, 0.1), METAL, { darken = 0.1 }),
        spec(BALL, cube(0.42), at(-0.1, 0.24, -0.12), METAL),
        spec(BALL, cube(0.36), at(-0.22, -0.15, 0.14), METAL, { darken = 0.15 }),
        spec(BALL, cube(0.3), at(0.1, 0.12, 0.26), METAL, { lighten = 0.15 }),
        spec(BALL, cube(0.2), at(0.16, 0.28, 0.02), Enum.Material.SmoothPlastic, {
            color = PATINA,
        }),
        spec(BALL, cube(0.16), at(-0.3, 0.05, 0.12), Enum.Material.SmoothPlastic, {
            color = PATINA,
        }),
    },
    -- Cristal: se completa más abajo con cristales con punta sobre una base de roca.
    crystal = {},
    -- Plasma: núcleo brillante dentro de una esfera, con dos anillos y chispas orbitando.
    plasma = {
        spec(BALL, cube(0.45), CFrame.identity, NEON, { lighten = 0.5 }),
        spec(BALL, cube(0.9), CFrame.identity, GLASS, { transparency = 0.6 }),
        spec(
            CYLINDER,
            Vector3.new(0.03, 1, 1),
            at(0, 0, 0, 0.5, 0, 0) * CFrame.Angles(0, 0, math.pi / 2),
            NEON,
            { transparency = 0.5 }
        ),
        spec(
            CYLINDER,
            Vector3.new(0.03, 1, 1),
            at(0, 0, 0, -0.6, 0, 0.9) * CFrame.Angles(0, 0, math.pi / 2),
            NEON,
            { transparency = 0.5 }
        ),
        spec(BALL, cube(0.12), at(0.45, 0.08, 0), NEON, { lighten = 0.6 }),
        spec(BALL, cube(0.12), at(-0.3, -0.1, 0.34), NEON, { lighten = 0.6 }),
        spec(BALL, cube(0.12), at(-0.12, 0.2, -0.4), NEON, { lighten = 0.6 }),
    },
    -- Gema: dos cubos de cristal cruzados con un núcleo y esquirlas flotando alrededor.
    nebula = {
        spec(BALL, cube(0.32), CFrame.identity, NEON, { lighten = 0.6 }),
        spec(BLOCK, cube(0.56), at(0, 0, 0, math.pi / 4, 0, math.pi / 4), GLASS, {
            transparency = 0.3,
        }),
        spec(BLOCK, cube(0.56), at(0, 0, 0, 0, math.pi / 4, math.pi / 4), GLASS, {
            transparency = 0.3,
        }),
        spec(BLOCK, cube(0.14), at(0.44, 0.2, 0, 0.6, 0.6, 0.2), NEON, { lighten = 0.3 }),
        spec(BLOCK, cube(0.12), at(-0.42, -0.15, 0.15, 0.2, 1, 0.7), NEON, { lighten = 0.3 }),
        spec(BLOCK, cube(0.13), at(0, 0.34, -0.4, 1, 0.3, 0.4), NEON, { lighten = 0.3 }),
        spec(BLOCK, cube(0.11), at(0.1, -0.4, 0.32, 0.5, 0.2, 1.1), NEON, { lighten = 0.3 }),
    },
    -- Materia oscura: esfera negra con dos anillos cruzados y fragmentos orbitando.
    darkmatter = {
        spec(BALL, cube(0.62), CFrame.identity, Enum.Material.SmoothPlastic, {
            color = VOID,
            reflectance = 0.3,
        }),
        -- El eje del cilindro es X: se tumba y se inclina para formar un anillo.
        spec(
            CYLINDER,
            Vector3.new(0.05, 1, 1),
            at(0, 0, 0, 0.4, 0, 0) * CFrame.Angles(0, 0, math.pi / 2),
            NEON,
            { transparency = 0.2 }
        ),
        spec(
            CYLINDER,
            Vector3.new(0.04, 0.84, 0.84),
            at(0, 0, 0, -0.9, 0, 0.7) * CFrame.Angles(0, 0, math.pi / 2),
            NEON,
            { transparency = 0.45, lighten = 0.3 }
        ),
        spec(BLOCK, cube(0.13), at(0.4, 0.25, 0.1, 0.5, 0.5, 0.5), Enum.Material.SmoothPlastic, {
            color = VOID,
            reflectance = 0.3,
        }),
        spec(BLOCK, cube(0.11), at(-0.38, -0.2, 0.22, 0.2, 1, 0.3), Enum.Material.SmoothPlastic, {
            color = VOID,
            reflectance = 0.3,
        }),
        spec(BLOCK, cube(0.12), at(-0.1, 0.3, -0.4, 1, 0.2, 0.6), Enum.Material.SmoothPlastic, {
            color = VOID,
            reflectance = 0.3,
        }),
    },
    -- Corazón de estrella: núcleo con púas en todas direcciones dentro de un halo.
    starheart = {
        spec(BALL, cube(0.44), CFrame.identity, NEON, { lighten = 0.4 }),
        spec(BLOCK, Vector3.new(1, 0.12, 0.12), at(0, 0, 0, math.pi / 4, 0, 0), NEON),
        spec(BLOCK, Vector3.new(0.12, 1, 0.12), at(0, 0, 0, 0, math.pi / 4, 0), NEON),
        spec(BLOCK, Vector3.new(0.12, 0.12, 1), at(0, 0, 0, 0, 0, math.pi / 4), NEON),
        spec(
            BLOCK,
            Vector3.new(0.72, 0.08, 0.08),
            at(0, 0, 0, 0, math.pi / 4, math.pi / 4),
            NEON,
            {
                lighten = 0.3,
            }
        ),
        spec(
            BLOCK,
            Vector3.new(0.72, 0.08, 0.08),
            at(0, 0, 0, 0, -math.pi / 4, math.pi / 4),
            NEON,
            {
                lighten = 0.3,
            }
        ),
        spec(
            BLOCK,
            Vector3.new(0.72, 0.08, 0.08),
            at(0, 0, 0, 0, math.pi / 4, -math.pi / 4),
            NEON,
            {
                lighten = 0.3,
            }
        ),
        spec(
            BLOCK,
            Vector3.new(0.72, 0.08, 0.08),
            at(0, 0, 0, 0, -math.pi / 4, -math.pi / 4),
            NEON,
            { lighten = 0.3 }
        ),
        spec(BALL, cube(0.72), CFrame.identity, GLASS, { transparency = 0.75 }),
    },
}

do
    local crystal = SHAPES.crystal
    addCrystal(crystal, CFrame.new(0, -0.3, 0), 0.82, 0.24)
    -- El prisma central es la parte principal: se recoloca centrado y sin girar.
    crystal[1].cframe = CFrame.identity
    crystal[2].cframe = CFrame.new(0, 0.3 + 0.115, 0)
    addCrystal(crystal, at(0.12, -0.3, 0.06, 0, 0.7, -0.55), 0.6, 0.18)
    addCrystal(crystal, at(-0.12, -0.3, -0.05, 0.35, 0.3, 0.55), 0.52, 0.17)
    addCrystal(crystal, at(0.02, -0.3, -0.12, -0.6, 1.2, 0.1), 0.44, 0.15)
    addCrystal(crystal, at(-0.03, -0.3, 0.13, 0.6, 2, -0.1), 0.38, 0.14)
    table.insert(
        crystal,
        spec(BLOCK, Vector3.new(0.6, 0.2, 0.6), at(0, -0.38, 0, 0, 0.5, 0), SLATE, {
            color = HOST_ROCK,
        })
    )
end

local RAINBOW_SEQUENCE = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.8, 1)),
    ColorSequenceKeypoint.new(0.25, Color3.fromHSV(0.2, 0.8, 1)),
    ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.45, 0.8, 1)),
    ColorSequenceKeypoint.new(0.75, Color3.fromHSV(0.7, 0.8, 1)),
    ColorSequenceKeypoint.new(1, Color3.fromHSV(0.9, 0.8, 1)),
})

local function addSparkles(parent: Instance, name: string, color: ColorSequence, size: number)
    local sparkles = Instance.new("ParticleEmitter")
    sparkles.Name = name
    sparkles.Color = color
    sparkles.LightEmission = 1
    sparkles.Rate = 6
    sparkles.Lifetime = NumberRange.new(0.6, 1)
    sparkles.Speed = NumberRange.new(size * 0.5, size)
    sparkles.SpreadAngle = Vector2.new(180, 180)
    sparkles.Size = NumberSequence.new(size * 0.3, 0)
    sparkles.Parent = parent
end

local function makePlaceholder(mineralId: string, size: number): Model
    local mineral = Minerals.ById[mineralId]
    local baseColor = if mineral then mineral.color else FALLBACK_COLOR
    local specs = SHAPES[mineralId] or SHAPES[FALLBACK_SHAPE]

    local model = Instance.new("Model")
    local primary: BasePart? = nil
    for _, partSpec in specs do
        local part = Instance.new("Part")
        part.Shape = partSpec.shape
        part.Size = partSpec.size * size
        part.CFrame = CFrame.new(partSpec.cframe.Position * size) * partSpec.cframe.Rotation
        part.Material = partSpec.material
        part.Color = (partSpec.color or baseColor)
            :Lerp(Color3.new(1, 1, 1), partSpec.lighten or 0)
            :Lerp(Color3.new(0, 0, 0), partSpec.darken or 0)
        part.Transparency = partSpec.transparency or 0
        part.Reflectance = partSpec.reflectance or 0
        part.TopSurface = Enum.SurfaceType.Smooth
        part.BottomSurface = Enum.SurfaceType.Smooth
        part.CastShadow = false
        part.Parent = model

        if primary then
            -- Mantiene el modelo unido cuando se suelda a un personaje.
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = primary
            weld.Part1 = part
            weld.Parent = part
        else
            primary = part
        end
    end
    model.PrimaryPart = primary

    local rank = Minerals.GetRank(mineralId)
    if primary and mineral and rank >= Minerals.RareRank then
        local light = Instance.new("PointLight")
        light.Color = baseColor
        light.Brightness = 1
        light.Range = size * 4
        light.Shadows = false
        light.Parent = primary
    end
    if primary and mineral and rank >= Minerals.AnnounceRank then
        addSparkles(primary, "RaritySparkles", ColorSequence.new(baseColor), size)
    end
    return model
end

local function getParts(root: Instance): { BasePart }
    local parts: { BasePart } = {}
    if root:IsA("BasePart") then
        table.insert(parts, root)
    end
    for _, descendant in root:GetDescendants() do
        if descendant:IsA("BasePart") then
            table.insert(parts, descendant)
        end
    end
    return parts
end

local function configureParts(parts: { BasePart })
    for _, part in parts do
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Massless = true
    end
end

local function applyMutation(parts: { BasePart }, mutation: Mutations.Mutation, size: number)
    local color = mutation.color
    local main = parts[1]
    if color == nil or main == nil then
        return
    end

    for index, part in parts do
        if mutation.style == "metal" then
            part.Material = Enum.Material.Metal
            part.Color = color
            part.Reflectance = 0.35
        elseif mutation.style == "rainbow" then
            part.Material = Enum.Material.Neon
            part.Color = Color3.fromHSV((index - 1) / #parts, 0.75, 1)
        else
            part.Material = Enum.Material.Neon
            part.Color = color
        end
    end

    addSparkles(
        main,
        "MutationSparkles",
        if mutation.style == "rainbow" then RAINBOW_SEQUENCE else ColorSequence.new(color),
        size
    )

    local light = Instance.new("PointLight")
    light.Name = "MutationLight"
    light.Color = color
    light.Brightness = 1.5
    light.Range = size * 5
    light.Shadows = false
    light.Parent = main
end

-- Devuelve un Model o BasePart anclado, sin colisión, listo para colocar con Assets.PlaceAt.
-- `size` solo se aplica al modelo generado.
function MineralVisual.Create(mineralId: string, mutationId: string, size: number): Instance
    local visual = Assets.Clone(`Mineral_{mineralId}`) or makePlaceholder(mineralId, size)
    local parts = getParts(visual)
    configureParts(parts)

    local mutation = Mutations.ById[mutationId]
    if mutation then
        applyMutation(parts, mutation, size)
    end

    visual:SetAttribute("Mineral", mineralId)
    visual:SetAttribute("Mutation", mutationId)
    return visual
end

return MineralVisual
