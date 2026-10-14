--!strict

-- Efectos de los títulos sobre la cabeza. El servidor pone el cartel (TitleTag, con el atributo
-- TitleId) y cada cliente lo decora según Config/Titles: degradado animado (arcoíris, brillo
-- que pasa o latido) y destellos alrededor de la cabeza. Todo es local y se apaga lejos de la
-- cámara o con gráficos bajos (los destellos).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Quality = require(script.Parent.Parent.UI.Quality)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TitlesConfig = require(Shared:WaitForChild("Config"):WaitForChild("Titles"))

local TITLE_TAG = "TitleTag"
-- Más lejos de esto no se anima (el cartel se ve igual, quieto).
local ANIMATE_DISTANCE = 120
local SPARKLES_NAME = "TitleSparkles"

type Entry = {
    billboard: BillboardGui,
    label: TextLabel,
    gradient: UIGradient,
    style: TitlesConfig.Style,
    phase: number,
}

local TitleController = {}

local entries: { [BillboardGui]: Entry } = {}

-- Secuencia de colores de un arcoíris desplazado `shift` (0-1) a lo largo del texto.
local function rainbow(colors: { Color3 }, shift: number): ColorSequence
    local count = #colors - 1
    local points: { ColorSequenceKeypoint } = {}
    for index = 0, 6 do
        local position = index / 6
        local at = ((position + shift) % 1) * count
        local low = math.floor(at)
        local color = colors[low + 1]:Lerp(colors[math.min(low + 2, #colors)], at - low)
        table.insert(points, ColorSequenceKeypoint.new(position, color))
    end
    return ColorSequence.new(points)
end

-- Degradado con una franja blanca en el centro, para el brillo que pasa.
local function shineSequence(colors: { Color3 }): ColorSequence
    local first = colors[1]
    local last = colors[#colors]
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, first),
        ColorSequenceKeypoint.new(0.42, first:Lerp(last, 0.5)),
        ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(0.58, first:Lerp(last, 0.5)),
        ColorSequenceKeypoint.new(1, last),
    })
end

local function addSparkles(head: BasePart, style: TitlesConfig.Style)
    if head:FindFirstChild(SPARKLES_NAME) or Quality.IsLow() then
        return
    end
    local colors = style.colors or { style.color }
    local attachment = Instance.new("Attachment")
    attachment.Name = SPARKLES_NAME
    attachment.Position = Vector3.new(0, 0.6, 0)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(colors[1], colors[#colors])
    emitter.LightEmission = 1
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.3, 0.22),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Transparency = NumberSequence.new(0.1, 1)
    emitter.Lifetime = NumberRange.new(0.8, 1.4)
    emitter.Speed = NumberRange.new(0.5, 1.5)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Acceleration = Vector3.new(0, 1.2, 0)
    emitter.Rate = 6 * Quality.Scales[Quality.Get()]
    emitter.Shape = Enum.ParticleEmitterShape.Sphere
    emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
    emitter.Parent = attachment
    attachment.Parent = head
end

local function removeSparkles(head: Instance?)
    local sparkles = if head then head:FindFirstChild(SPARKLES_NAME) else nil
    if sparkles then
        sparkles:Destroy()
    end
end

-- Decora un cartel de título recién puesto.
local function decorate(billboard: BillboardGui)
    local titleId = billboard:GetAttribute("TitleId")
    local label = billboard:FindFirstChildOfClass("TextLabel")
    if type(titleId) ~= "string" or label == nil or entries[billboard] then
        return
    end
    local style = TitlesConfig.GetStyle(titleId)
    local head = billboard.Parent
    if style.sparkles and head and head:IsA("BasePart") then
        addSparkles(head, style)
    end
    local colors = style.colors
    if colors == nil then
        return
    end
    -- El degradado tiñe el texto blanco; el contorno lo oscurece para que se lea.
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    local gradient = Instance.new("UIGradient")
    gradient.Color = if style.effect == "shine"
        then shineSequence(colors)
        elseif style.effect == "rainbow" then rainbow(colors, 0)
        else ColorSequence.new(colors[1], colors[#colors])
    gradient.Parent = label
    entries[billboard] = {
        billboard = billboard,
        label = label,
        gradient = gradient,
        style = style,
        phase = math.random(),
    }
    billboard.Destroying:Connect(function()
        entries[billboard] = nil
        removeSparkles(head)
    end)
end

local function update()
    local camera = Workspace.CurrentCamera
    if camera == nil then
        return
    end
    local focus = camera.CFrame.Position
    local now = os.clock()
    for billboard, entry in entries do
        local head = billboard.Parent
        if head == nil then
            entries[billboard] = nil
        elseif head:IsA("BasePart") and (head.Position - focus).Magnitude <= ANIMATE_DISTANCE then
            local progress = ((now / TitlesConfig.EffectSeconds) + entry.phase) % 1
            local effect = entry.style.effect
            local colors = entry.style.colors or { entry.style.color }
            if effect == "rainbow" then
                entry.gradient.Color = rainbow(colors, progress)
            elseif effect == "shine" then
                -- La franja blanca cruza el texto y espera un poco antes de volver a pasar.
                entry.gradient.Offset = Vector2.new(progress * 3 - 1.5, 0)
            elseif effect == "pulse" then
                local beat = (math.sin(progress * math.pi * 2) + 1) / 2
                entry.label.TextStrokeColor3 = Color3.new(0, 0, 0):Lerp(colors[1], beat * 0.8)
                entry.label.TextStrokeTransparency = 0.4 - beat * 0.4
            end
        end
    end
end

local function watchCharacter(character: Model)
    local head = character:WaitForChild("Head", 10)
    if head == nil then
        return
    end
    local existing = head:FindFirstChild(TITLE_TAG)
    if existing and existing:IsA("BillboardGui") then
        task.defer(decorate, existing)
    end
    head.ChildAdded:Connect(function(child)
        if child.Name == TITLE_TAG and child:IsA("BillboardGui") then
            -- Se espera a que lleguen su texto y sus atributos.
            task.defer(decorate, child)
        end
    end)
end

local function watchPlayer(player: Player)
    if player.Character then
        task.spawn(watchCharacter, player.Character)
    end
    player.CharacterAdded:Connect(watchCharacter)
end

function TitleController.Start()
    for _, player in Players:GetPlayers() do
        watchPlayer(player)
    end
    Players.PlayerAdded:Connect(watchPlayer)
    RunService.RenderStepped:Connect(update)
end

return TitleController
