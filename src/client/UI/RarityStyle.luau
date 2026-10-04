--!strict

-- Estilo de rareza en la interfaz: cómo se escribe el nombre de un mineral para que su
-- rareza se reconozca antes de leerlo. Cada rango tiene su icono, su color, su tipografía,
-- su contorno luminoso y, los más altos, un brillo que recorre el texto. Las mutaciones
-- ponen su color, y el Arcoíris un degradado que se mueve.
-- Es el único sitio donde se decide ese aspecto; los menús solo llaman a Apply.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Minerals = require(Config:WaitForChild("Minerals"))
local Mutations = require(Config:WaitForChild("Mutations"))
local Strings = require(Shared:WaitForChild("Strings"))

-- Rango desde el que el nombre usa la tipografía de títulos, lleva contorno luminoso y lleva
-- el brillo que recorre el texto.
local HEADING_RANK = 4
local GLOW_RANK = 3
local SHIMMER_RANK = 5
local SHIMMER_SECONDS = 2.2
local RAINBOW = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.7, 1)),
    ColorSequenceKeypoint.new(0.25, Color3.fromHSV(0.2, 0.7, 1)),
    ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.45, 0.7, 1)),
    ColorSequenceKeypoint.new(0.75, Color3.fromHSV(0.7, 0.7, 1)),
    ColorSequenceKeypoint.new(1, Color3.fromHSV(0.9, 0.7, 1)),
})

local RarityStyle = {}

-- Icono de cada rango, de Común a Mítico.
RarityStyle.Icons = { "·", "◇", "◆", "✦", "★", "✹" }

local function getMutation(mutationId: string): Mutations.Mutation?
    local mutation = Mutations.ById[mutationId]
    return if mutation and mutation.id ~= Mutations.NoneId then mutation else nil
end

-- Color con el que se escribe ese mineral: el de su mutación o, sin ella, el de su rareza.
function RarityStyle.Color(mineralId: string, mutationId: string): Color3
    local mineral = Minerals.ById[mineralId]
    local mutation = getMutation(mutationId)
    return (if mutation then mutation.color else nil)
        or (if mineral then Minerals.Rarities[mineral.rarity].color else Theme.Colors.Text)
end

-- Nombre del mineral con el icono de su rareza delante.
function RarityStyle.Text(mineralId: string, mutationId: string): string
    local icon = RarityStyle.Icons[Minerals.GetRank(mineralId)] or ""
    return `{icon} {Strings.MineralName(mineralId, mutationId)}`
end

-- Da a una etiqueta el aspecto de ese mineral: color, tipografía, contorno y brillo.
function RarityStyle.Apply(label: TextLabel, mineralId: string, mutationId: string)
    local rank = Minerals.GetRank(mineralId)
    local mutation = getMutation(mutationId)
    local color = RarityStyle.Color(mineralId, mutationId)
    local isRainbow = mutation ~= nil and mutation.style == "rainbow"
    label.TextColor3 = color
    if rank >= HEADING_RANK then
        label.Font = Theme.Fonts.Heading
    end

    -- Contorno luminoso, más marcado cuanto más raro.
    if rank >= GLOW_RANK or mutation then
        local glow = Instance.new("UIStroke")
        glow.Color = color
        glow.Thickness = 1 + rank * 0.25
        glow.Transparency = math.clamp(0.85 - rank * 0.08, 0.3, 0.8)
        glow.Parent = label
    end

    -- Brillo que recorre el texto (lo anima TweenService: no cuesta nada por fotograma).
    if rank >= SHIMMER_RANK or isRainbow then
        label.TextColor3 = Color3.new(1, 1, 1)
        local shimmer = Instance.new("UIGradient")
        shimmer.Color = if isRainbow
            then RAINBOW
            else ColorSequence.new({
                ColorSequenceKeypoint.new(0, color),
                ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, color),
            })
        shimmer.Offset = Vector2.new(-0.6, 0)
        shimmer.Parent = label
        TweenService:Create(
            shimmer,
            TweenInfo.new(
                SHIMMER_SECONDS,
                Enum.EasingStyle.Sine,
                Enum.EasingDirection.InOut,
                -1,
                true
            ),
            { Offset = Vector2.new(0.6, 0) }
        ):Play()
    end
end

return RarityStyle
