--!strict

-- Mensajes cortos en la parte superior de la pantalla que desaparecen solos.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local VISIBLE_SECONDS = 3
local FADE_SECONDS = 0.4
local MAX_VISIBLE = 5

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
    frame.Position = UDim2.fromScale(0.5, 0.1)
    frame.Size = UDim2.fromScale(0.6, 0.3)
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

local order = 0

-- Muestra un mensaje durante unos segundos.
function Notifications.Show(text: string, color: Color3?)
    local frame = getContainer()

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
    label.Size = UDim2.fromScale(1, 0.18)
    label.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    label.BackgroundTransparency = 0.35
    label.TextColor3 = color or Color3.new(1, 1, 1)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Text = text

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.3, 0)
    corner.Parent = label

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0.15, 0)
    padding.PaddingBottom = UDim.new(0.15, 0)
    padding.Parent = label

    label.Parent = frame

    task.delay(VISIBLE_SECONDS, function()
        if label.Parent == nil then
            return
        end
        local tween = TweenService:Create(
            label,
            TweenInfo.new(FADE_SECONDS),
            { TextTransparency = 1, BackgroundTransparency = 1 }
        )
        tween.Completed:Connect(function()
            label:Destroy()
        end)
        tween:Play()
    end)
end

return Notifications
