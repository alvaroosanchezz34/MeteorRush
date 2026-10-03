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
    transparency: number?,
    reflectance: number?,
}

local BLOCK = Enum.PartType.Block
local BALL = Enum.PartType.Ball
local CYLINDER = Enum.PartType.Cylinder
local WEDGE = Enum.PartType.Wedge

local FALLBACK_COLOR = Color3.fromRGB(128, 128, 128)
local FALLBACK_SHAPE = "stone"

local function at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
    return CFrame.new(x, y, z) * CFrame.Angles(rx or 0, ry or 0, rz or 0)
end

-- La primera parte de cada forma es la principal: va centrada y sin girar.
local SHAPES: { [string]: { PartSpec } } = {
    stone = {
        {
            shape = BALL,
            size = Vector3.one * 0.8,
            cframe = CFrame.identity,
            material = Enum.Material.Slate,
        },
        {
            shape = BLOCK,
            size = Vector3.one * 0.55,
            cframe = at(0.15, 0.1, -0.1, 0.5, 0.7, 0.2),
            material = Enum.Material.Slate,
        },
        {
            shape = BLOCK,
            size = Vector3.one * 0.45,
            cframe = at(-0.2, -0.12, 0.15, 1.1, 0.3, 0.8),
            material = Enum.Material.Slate,
        },
    },
    iron = {
        {
            shape = BLOCK,
            size = Vector3.new(0.75, 0.5, 0.6),
            cframe = CFrame.identity,
            material = Enum.Material.Metal,
            reflectance = 0.15,
        },
        {
            shape = WEDGE,
            size = Vector3.new(0.5, 0.4, 0.5),
            cframe = at(0.1, 0.3, 0, 0, 0.6, 0),
            material = Enum.Material.Metal,
            reflectance = 0.15,
        },
        {
            shape = BLOCK,
            size = Vector3.one * 0.4,
            cframe = at(-0.22, -0.12, 0.2, 0.6, 0.4, 0.3),
            material = Enum.Material.Metal,
            reflectance = 0.15,
        },
    },
    copper = {
        {
            shape = BALL,
            size = Vector3.one * 0.6,
            cframe = CFrame.identity,
            material = Enum.Material.Metal,
        },
        {
            shape = BALL,
            size = Vector3.one * 0.5,
            cframe = at(0.24, -0.08, 0.1),
            material = Enum.Material.Metal,
        },
        {
            shape = BALL,
            size = Vector3.one * 0.42,
            cframe = at(-0.1, 0.24, -0.12),
            material = Enum.Material.Metal,
        },
        {
            shape = BALL,
            size = Vector3.one * 0.38,
            cframe = at(-0.22, -0.15, 0.12),
            material = Enum.Material.Metal,
        },
    },
    crystal = {
        {
            shape = BLOCK,
            size = Vector3.new(0.28, 1, 0.28),
            cframe = CFrame.identity,
            material = Enum.Material.Glass,
            transparency = 0.25,
        },
        {
            shape = BLOCK,
            size = Vector3.new(0.22, 0.7, 0.22),
            cframe = at(0.2, -0.14, 0.08, 0, 0.7, -0.5),
            material = Enum.Material.Glass,
            transparency = 0.25,
        },
        {
            shape = BLOCK,
            size = Vector3.new(0.2, 0.6, 0.2),
            cframe = at(-0.18, -0.18, -0.08, 0.35, 0.3, 0.5),
            material = Enum.Material.Glass,
            transparency = 0.25,
        },
    },
    plasma = {
        {
            shape = BALL,
            size = Vector3.one * 0.5,
            cframe = CFrame.identity,
            material = Enum.Material.Neon,
            lighten = 0.5,
        },
        {
            shape = BALL,
            size = Vector3.one * 0.95,
            cframe = CFrame.identity,
            material = Enum.Material.Glass,
            transparency = 0.6,
        },
    },
    nebula = {
        {
            shape = BALL,
            size = Vector3.one * 0.35,
            cframe = CFrame.identity,
            material = Enum.Material.Neon,
            lighten = 0.6,
        },
        {
            shape = BLOCK,
            size = Vector3.one * 0.6,
            cframe = at(0, 0, 0, math.pi / 4, 0, math.pi / 4),
            material = Enum.Material.Glass,
            transparency = 0.3,
        },
        {
            shape = BLOCK,
            size = Vector3.one * 0.6,
            cframe = at(0, 0, 0, 0, math.pi / 4, math.pi / 4),
            material = Enum.Material.Glass,
            transparency = 0.3,
        },
    },
    darkmatter = {
        {
            shape = BALL,
            size = Vector3.one * 0.7,
            cframe = CFrame.identity,
            material = Enum.Material.SmoothPlastic,
            color = Color3.fromRGB(12, 8, 20),
            reflectance = 0.3,
        },
        {
            -- El eje del cilindro es X: se tumba y se inclina para formar un anillo.
            shape = CYLINDER,
            size = Vector3.new(0.05, 1, 1),
            cframe = at(0, 0, 0, 0.4, 0, 0) * CFrame.Angles(0, 0, math.pi / 2),
            material = Enum.Material.Neon,
            transparency = 0.2,
        },
    },
    starheart = {
        {
            shape = BALL,
            size = Vector3.one * 0.5,
            cframe = CFrame.identity,
            material = Enum.Material.Neon,
            lighten = 0.3,
        },
        {
            shape = BLOCK,
            size = Vector3.new(1, 0.14, 0.14),
            cframe = at(0, 0, 0, math.pi / 4, 0, 0),
            material = Enum.Material.Neon,
        },
        {
            shape = BLOCK,
            size = Vector3.new(0.14, 1, 0.14),
            cframe = at(0, 0, 0, 0, math.pi / 4, 0),
            material = Enum.Material.Neon,
        },
        {
            shape = BLOCK,
            size = Vector3.new(0.14, 0.14, 1),
            cframe = at(0, 0, 0, 0, 0, math.pi / 4),
            material = Enum.Material.Neon,
        },
    },
}

local RAINBOW_SEQUENCE = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.8, 1)),
    ColorSequenceKeypoint.new(0.25, Color3.fromHSV(0.2, 0.8, 1)),
    ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.45, 0.8, 1)),
    ColorSequenceKeypoint.new(0.75, Color3.fromHSV(0.7, 0.8, 1)),
    ColorSequenceKeypoint.new(1, Color3.fromHSV(0.9, 0.8, 1)),
})

local function makePlaceholder(mineralId: string, size: number): Model
    local mineral = Minerals.ById[mineralId]
    local baseColor = if mineral then mineral.color else FALLBACK_COLOR
    local specs = SHAPES[mineralId] or SHAPES[FALLBACK_SHAPE]

    local model = Instance.new("Model")
    local primary: BasePart? = nil
    for _, spec in specs do
        local part = Instance.new("Part")
        part.Shape = spec.shape
        part.Size = spec.size * size
        part.CFrame = CFrame.new(spec.cframe.Position * size) * spec.cframe.Rotation
        part.Material = spec.material
        part.Color = (spec.color or baseColor):Lerp(Color3.new(1, 1, 1), spec.lighten or 0)
        part.Transparency = spec.transparency or 0
        part.Reflectance = spec.reflectance or 0
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

    if primary and mineral and Minerals.GetRank(mineralId) >= Minerals.RareRank then
        local light = Instance.new("PointLight")
        light.Color = baseColor
        light.Brightness = 1
        light.Range = size * 4
        light.Shadows = false
        light.Parent = primary
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

    local sparkles = Instance.new("ParticleEmitter")
    sparkles.Name = "MutationSparkles"
    sparkles.Color = if mutation.style == "rainbow"
        then RAINBOW_SEQUENCE
        else ColorSequence.new(color)
    sparkles.LightEmission = 1
    sparkles.Rate = 6
    sparkles.Lifetime = NumberRange.new(0.6, 1)
    sparkles.Speed = NumberRange.new(size * 0.5, size)
    sparkles.SpreadAngle = Vector2.new(180, 180)
    sparkles.Size = NumberSequence.new(size * 0.3, 0)
    sparkles.Parent = main

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
