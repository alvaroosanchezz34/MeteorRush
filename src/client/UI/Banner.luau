--!strict

-- Aviso grande en el centro de la pantalla para los momentos especiales: una combinación
-- nueva del índice (con el mineral girando) o un logro desbloqueado. Si llegan varios
-- seguidos se muestran uno detrás de otro.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Components = require(script.Parent.Components)
local Sound = require(script.Parent.Sound)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MineralVisual = require(Shared:WaitForChild("Util"):WaitForChild("MineralVisual"))

export type Entry = {
    heading: string,
    title: string,
    subtitle: string?,
    color: Color3,
    -- Si se indica, se muestra el modelo del mineral girando.
    mineral: string?,
    mutation: string?,
    -- Sonido de AudioManager (por defecto, "Banner").
    sound: string?,
}

local VISIBLE_SECONDS = 2.8
local POP_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE_TWEEN = TweenInfo.new(0.3)
local MODEL_SIZE = 3
local SPIN_SPEED = 2
-- Destellos que salen disparados desde el aviso al aparecer.
local SPARK_COUNT = 10
local SPARK_TWEEN = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Banner = {}

local queue: { Entry } = {}
local showing = false
local gui: ScreenGui? = nil

local function getGui(): ScreenGui
    if gui then
        return gui
    end
    local created = Instance.new("ScreenGui")
    created.Name = "Banner"
    created.ResetOnSpawn = false
    created.DisplayOrder = 20
    created.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    gui = created
    return created
end

-- Visor con el modelo del mineral girando sobre sí mismo.
local function addMineral(parent: Instance, entry: Entry): RBXScriptConnection?
    local mineralId = entry.mineral
    if mineralId == nil then
        return nil
    end
    local viewport = Instance.new("ViewportFrame")
    viewport.Size = UDim2.fromScale(0.3, 0.9)
    viewport.Position = UDim2.fromScale(0.02, 0.05)
    viewport.BackgroundTransparency = 1
    viewport.Ambient = Color3.new(1, 1, 1)
    viewport.LightColor = Color3.new(1, 1, 1)
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1
    aspect.Parent = viewport
    local camera = Instance.new("Camera")
    camera.CFrame = CFrame.lookAt(Vector3.new(0, MODEL_SIZE * 0.6, MODEL_SIZE * 2.2), Vector3.zero)
    camera.Parent = viewport
    viewport.CurrentCamera = camera

    local visual = MineralVisual.Create(mineralId, entry.mutation or "none", MODEL_SIZE)
    if not visual:IsA("PVInstance") then
        visual:Destroy()
        return nil
    end
    local model = visual :: PVInstance
    model:PivotTo(CFrame.new())
    model.Parent = viewport
    viewport.Parent = parent

    local angle = 0
    return RunService.RenderStepped:Connect(function(delta: number)
        angle += delta * SPIN_SPEED
        model:PivotTo(CFrame.Angles(0, angle, 0))
    end)
end

-- Estrellitas que salen en todas direcciones desde el centro del aviso y se apagan.
local function sparkle(parent: Instance, color: Color3)
    for index = 1, SPARK_COUNT do
        local angle = index / SPARK_COUNT * math.pi * 2 + math.random() * 0.4
        local distance = 0.22 + math.random() * 0.1
        local spark = Components.Label({
            text = "✦",
            size = UDim2.fromScale(0.03, 0.05),
            position = UDim2.fromScale(0.5, 0.32),
            color = color,
            parent = parent,
        })
        spark.AnchorPoint = Vector2.new(0.5, 0.5)
        local tween = TweenService:Create(spark, SPARK_TWEEN, {
            Position = UDim2.fromScale(
                0.5 + math.cos(angle) * distance,
                0.32 + math.sin(angle) * distance * 1.3
            ),
            TextTransparency = 1,
            Rotation = 180,
        })
        tween.Completed:Connect(function()
            spark:Destroy()
        end)
        tween:Play()
    end
end

local function display(entry: Entry)
    local frame = Components.Panel({
        size = UDim2.fromScale(0.46, 0.2),
        position = UDim2.fromScale(0.5, 0.32),
        color = Components.Colors.Background,
        transparency = 0.1,
        parent = getGui(),
    })
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    -- El borde del panel, con el color del aviso.
    local stroke = frame:FindFirstChildOfClass("UIStroke")
    if stroke then
        stroke.Color = entry.color
        stroke.Thickness = 4
        stroke.Transparency = 0
    end
    local scale = Instance.new("UIScale")
    scale.Scale = 0.4
    scale.Parent = frame

    local spin = addMineral(frame, entry)
    local textX = if spin then 0.3 else 0.04
    local textWidth = 0.96 - textX
    Components.Label({
        text = entry.heading,
        size = UDim2.fromScale(textWidth, 0.26),
        position = UDim2.fromScale(textX, 0.08),
        color = Components.Colors.Gold,
        heading = true,
        parent = frame,
    })
    Components.Label({
        text = entry.title,
        size = UDim2.fromScale(textWidth, 0.36),
        position = UDim2.fromScale(textX, 0.34),
        color = entry.color,
        parent = frame,
    })
    Components.Label({
        text = entry.subtitle or "",
        size = UDim2.fromScale(textWidth, 0.2),
        position = UDim2.fromScale(textX, 0.72),
        color = Components.Colors.Muted,
        parent = frame,
    })

    Sound.Play(entry.sound or "Banner", { duck = true })
    TweenService:Create(scale, POP_TWEEN, { Scale = 1 }):Play()
    sparkle(getGui(), entry.color)
    task.wait(VISIBLE_SECONDS)
    local fade = TweenService:Create(scale, FADE_TWEEN, { Scale = 0 })
    fade:Play()
    fade.Completed:Wait()
    if spin then
        spin:Disconnect()
    end
    frame:Destroy()
end

-- Muestra un aviso, o lo pone a la cola si ya hay uno en pantalla.
function Banner.Show(entry: Entry)
    table.insert(queue, entry)
    if showing then
        return
    end
    showing = true
    task.spawn(function()
        while #queue > 0 do
            display(table.remove(queue, 1) :: Entry)
        end
        showing = false
    end)
end

return Banner
