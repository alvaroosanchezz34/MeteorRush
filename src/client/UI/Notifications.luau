--!strict

-- Mensajes cortos en la parte baja del centro de la pantalla (lejos de los contadores de
-- arriba y de los avisos grandes) que entran con un pequeño rebote y desaparecen solos.
-- Hay tres tipos, cada uno con su color, su icono y su sonido: información, éxito y error.
-- El servidor solo envía el texto, así que el tipo se deduce de palabras clave.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local AudioManager = require(script.Parent.AudioManager)
local Theme = require(script.Parent.Theme)

export type Kind = "info" | "success" | "error"

local VISIBLE_SECONDS = 3
local MAX_VISIBLE = 5

-- Palabras (en minúsculas) que delatan un error o un éxito en los textos del juego.
local ERROR_WORDS = {
    "not enough",
    "you need",
    "can't",
    "cannot",
    "already",
    "no free",
    "no common",
    "expired",
    "does not exist",
    "failed",
    "locked",
    "turned off",
    "is busy",
    "declined",
    "cancelled",
    "come back",
    "protected",
    "is safe",
    "is immune",
    "isn't carrying",
    "backpack full",
    "hit you",
    "play a little longer",
}
local SUCCESS_WORDS = {
    "+$",
    "complete",
    "unlocked",
    "claimed",
    "redeemed",
    "upgraded",
    "thank you",
    "liked",
    "deposited",
    "placed",
    "sold",
    "fused",
    "reward",
    "bonus",
}

local Notifications = {}

local container: Frame? = nil

local function getContainer(): Frame
    if container then
        return container
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "Notifications"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 10

    local frame = Instance.new("Frame")
    frame.Name = "Container"
    frame.AnchorPoint = Vector2.new(0.5, 0)
    frame.Position = UDim2.fromScale(0.5, 0.58)
    frame.Size = UDim2.fromScale(0.5, 0.28)
    frame.BackgroundTransparency = 1
    frame.Parent = gui

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0.02, 0)
    layout.Parent = frame

    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    container = frame
    return frame
end

-- Deduce el tipo de aviso de su texto.
function Notifications.Classify(text: string): Kind
    local lower = string.lower(text)
    for _, word in ERROR_WORDS do
        if string.find(lower, word, 1, true) then
            return "error"
        end
    end
    for _, word in SUCCESS_WORDS do
        if string.find(lower, word, 1, true) then
            return "success"
        end
    end
    return "info"
end

local order = 0

-- Muestra un mensaje durante unos segundos. Sin `kind`, se deduce del texto; `color` cambia
-- el color del texto (por defecto, el del tema).
function Notifications.Show(text: string, color: Color3?, kind: Kind?)
    local frame = getContainer()
    local resolved: Kind = kind or Notifications.Classify(text)
    local accent = Theme.Feedback[resolved]

    local labels = {}
    for _, child in frame:GetChildren() do
        if child:IsA("TextLabel") then
            table.insert(labels, child)
        end
    end
    if #labels >= MAX_VISIBLE then
        table.sort(labels, function(a: TextLabel, b: TextLabel): boolean
            return a.LayoutOrder < b.LayoutOrder
        end)
        labels[1]:Destroy()
    end

    order += 1
    local label = Instance.new("TextLabel")
    label.LayoutOrder = order
    label.Size = UDim2.fromScale(1, 0.17)
    label.BackgroundColor3 = Theme.Colors.Background
    label.BackgroundTransparency = 0.12
    label.TextColor3 = color or Theme.Colors.Text
    label.TextScaled = true
    label.Font = Theme.Fonts.Body
    label.Text = text

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(Theme.Radius.Button, 0)
    corner.Parent = label

    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = accent
    stroke.Thickness = Theme.Stroke.Button
    stroke.Transparency = 0.35
    stroke.Parent = label

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0.2, 0)
    padding.PaddingBottom = UDim.new(0.2, 0)
    padding.PaddingLeft = UDim.new(0.08, 0)
    padding.PaddingRight = UDim.new(0.04, 0)
    padding.Parent = label

    -- Icono del tipo de aviso, a la izquierda.
    local icon = Instance.new("TextLabel")
    icon.AnchorPoint = Vector2.new(1, 0.5)
    icon.Size = UDim2.fromScale(0.06, 1)
    icon.Position = UDim2.fromScale(-0.01, 0.5)
    icon.BackgroundTransparency = 1
    icon.Text = Theme.Icons[resolved] or ""
    icon.TextColor3 = accent
    icon.TextScaled = true
    icon.Font = Theme.Fonts.Body
    icon.Parent = label

    local scale = Instance.new("UIScale")
    scale.Scale = 0.7
    scale.Parent = label
    label.Parent = frame
    TweenService:Create(scale, Theme.Motion.Open, { Scale = 1 }):Play()
    if resolved ~= "info" then
        AudioManager.Play(Theme.Sounds[resolved])
    end

    task.delay(VISIBLE_SECONDS, function()
        if label.Parent == nil then
            return
        end
        TweenService:Create(stroke, Theme.Motion.Fade, { Transparency = 1 }):Play()
        TweenService:Create(icon, Theme.Motion.Fade, { TextTransparency = 1 }):Play()
        local tween = TweenService:Create(
            label,
            Theme.Motion.Fade,
            { TextTransparency = 1, BackgroundTransparency = 1 }
        )
        tween.Completed:Connect(function()
            label:Destroy()
        end)
        tween:Play()
    end)
end

return Notifications
