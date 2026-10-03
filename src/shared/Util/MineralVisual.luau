--!strict

-- Crea la representación visual de un mineral: el modelo de ReplicatedStorage/Assets/Mineral_<id>
-- o, si no existe, un bloque del color de su rareza. La mutación se marca con un contorno de color.

local Assets = require(script.Parent.Assets)
local Minerals = require(script.Parent.Parent.Config.Minerals)
local Mutations = require(script.Parent.Parent.Config.Mutations)

local MineralVisual = {}

local function makePlaceholder(mineralId: string, size: number): BasePart
    local part = Instance.new("Part")
    part.Size = Vector3.one * size
    part.Material = Enum.Material.Glass
    part.Reflectance = 0.1
    local mineral = Minerals.ById[mineralId]
    part.Color = if mineral
        then Minerals.Rarities[mineral.rarity].color
        else Color3.fromRGB(128, 128, 128)
    return part
end

local function configureParts(root: Instance)
    local parts: { BasePart } = {}
    if root:IsA("BasePart") then
        table.insert(parts, root)
    end
    for _, descendant in root:GetDescendants() do
        if descendant:IsA("BasePart") then
            table.insert(parts, descendant)
        end
    end
    for _, part in parts do
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Massless = true
    end
end

-- Devuelve un Model o BasePart anclado, sin colisión, listo para colocar con Assets.PlaceAt.
-- `size` solo se aplica al placeholder.
function MineralVisual.Create(mineralId: string, mutationId: string, size: number): Instance
    local visual = Assets.Clone(`Mineral_{mineralId}`) or makePlaceholder(mineralId, size)
    configureParts(visual)

    local mutation = Mutations.ById[mutationId]
    if mutation and mutation.color then
        local box = Instance.new("SelectionBox")
        box.Adornee = visual :: any
        box.Color3 = mutation.color
        box.LineThickness = 0.08
        box.SurfaceTransparency = 0.7
        box.SurfaceColor3 = mutation.color
        box.Parent = visual
    end

    visual:SetAttribute("Mineral", mineralId)
    visual:SetAttribute("Mutation", mutationId)
    return visual
end

return MineralVisual
