--!strict

-- Anuncio global: una franja en la parte de arriba de la pantalla con un mensaje que envía
-- un administrador a todo el servidor. El texto llega ya filtrado por el servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AudioManager = require(script.Parent.AudioManager)
local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)

local Strings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Strings"))

local MIN_SECONDS = 2
local MAX_SECONDS = 15
local SLIDE = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HIDE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local SHOWN = UDim2.fromScale(0.5, 0.12)
local HIDDEN = UDim2.fromScale(0.5, -0.2)
-- Color de cada estilo de anuncio.
local STYLES: { [string]: Color3 } = {
    info = Theme.Colors.Accent,
    success = Theme.Colors.Success,
    warning = Theme.Colors.Danger,
    event = Theme.Colors.Gold,
}

local Announcement = {}

local gui: ScreenGui? = nil
-- Cambia con cada anuncio: el anterior no oculta al nuevo cuando le llega su hora.
local current = 0

local function getGui(): ScreenGui
    if gui then
        return gui
    end
    local created = Instance.new("ScreenGui")
    created.Name = "Announcement"
    created.ResetOnSpawn = false
    created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    created.DisplayOrder = 25
    created.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    gui = created
    return created
end

-- Muestra el anuncio. Los argumentos llegan del servidor y se comprueban igualmente.
function Announcement.Show(message: any, seconds: any, style: any, withSound: any)
    if type(message) ~= "string" or message == "" then
        return
    end
    local duration =
        math.clamp(if type(seconds) == "number" then seconds else 5, MIN_SECONDS, MAX_SECONDS)
    local color = STYLES[if type(style) == "string" then style else "info"] or STYLES.info

    local screen = getGui()
    Components.Clear(screen)
    current += 1
    local id = current

    local panel = Components.Panel({
        size = UDim2.fromScale(0.5, 0.13),
        position = HIDDEN,
        color = Theme.Colors.Background,
        transparency = 0.08,
        parent = screen,
    })
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    local stroke = panel:FindFirstChildOfClass("UIStroke")
    if stroke then
        stroke.Color = color
        stroke.Transparency = 0.2
    end
    Components.Label({
        text = Strings.Admin.Announcement,
        size = UDim2.fromScale(0.92, 0.26),
        position = UDim2.fromScale(0.04, 0.08),
        color = color,
        heading = true,
        parent = panel,
    })
    Components.Label({
        text = message,
        size = UDim2.fromScale(0.92, 0.5),
        position = UDim2.fromScale(0.04, 0.4),
        parent = panel,
    })

    if withSound == true then
        AudioManager.Play("Banner")
    end
    TweenService:Create(panel, SLIDE, { Position = SHOWN }):Play()
    task.delay(duration, function()
        if current ~= id or panel.Parent == nil then
            return
        end
        local tween = TweenService:Create(panel, HIDE, { Position = HIDDEN })
        tween.Completed:Connect(function()
            panel:Destroy()
        end)
        tween:Play()
    end)
end

return Announcement
