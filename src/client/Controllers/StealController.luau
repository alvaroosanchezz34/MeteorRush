--!strict

-- Efectos del robo, para que se entienda qué ha pasado: chispas y un texto "-N" sobre el
-- jugador golpeado (lo ven todos) y, para la víctima, un destello rojo y una sacudida de cámara.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent.Parent.UI.Effects)
local Sound = require(script.Parent.Parent.UI.Sound)
local SwingController = require(script.Parent.SwingController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared:WaitForChild("Config"):WaitForChild("Equipment"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local HIT_COLOR = Color3.fromRGB(255, 70, 70)
local POPUP_DURATION = 1.4
local POPUP_RISE = 5
local FLASH_DURATION = 0.5
local FLASH_TRANSPARENCY = 0.55
local SHAKE_DURATION = 0.35
local SHAKE_STRENGTH = 0.8

local StealController = {}

local flash: Frame? = nil

-- Chispas y texto "-N" que sube y se desvanece en el punto del golpe.
local function showHit(position: Vector3, count: number)
    local anchor = Instance.new("Part")
    anchor.Name = "StealHit"
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.CanTouch = false
    anchor.Transparency = 1
    anchor.Size = Vector3.one
    anchor.CFrame = CFrame.new(position)
    anchor.Parent = Workspace

    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(HIT_COLOR)
    emitter.Size = NumberSequence.new(0.6, 0)
    emitter.Speed = NumberRange.new(8, 16)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Lifetime = NumberRange.new(0.3, 0.7)
    emitter.LightEmission = 1
    emitter.Rate = 0
    emitter.Parent = anchor
    emitter:Emit(24)

    local billboard = Instance.new("BillboardGui")
    -- Los textos ya salen en el idioma elegido: sin traducción automática de Roblox.
    billboard.AutoLocalize = false
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.Size = UDim2.fromScale(8, 2)
    billboard.Parent = anchor
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = HIT_COLOR
    label.TextStrokeTransparency = 0.2
    label.Text = string.format(Strings.Steal.Lost, count)
    label.Parent = billboard

    local info = TweenInfo.new(POPUP_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService
        :Create(anchor, info, { CFrame = CFrame.new(position + Vector3.new(0, POPUP_RISE, 0)) })
        :Play()
    TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
    task.delay(POPUP_DURATION, function()
        anchor:Destroy()
    end)
end

-- Destello rojo a pantalla completa.
local function flashScreen()
    local frame = flash
    if frame == nil then
        local gui = Instance.new("ScreenGui")
        -- Los textos ya salen en el idioma elegido: sin traducción automática de Roblox.
        gui.AutoLocalize = false
        gui.Name = "StealFlash"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 5
        local created = Instance.new("Frame")
        created.Size = UDim2.fromScale(1, 1)
        created.BackgroundColor3 = HIT_COLOR
        created.BackgroundTransparency = 1
        created.BorderSizePixel = 0
        created.Active = false
        created.Parent = gui
        gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
        flash = created
        frame = created
    end
    frame.BackgroundTransparency = FLASH_TRANSPARENCY
    TweenService:Create(frame, TweenInfo.new(FLASH_DURATION), { BackgroundTransparency = 1 }):Play()
end

local function shakeCamera()
    local character = Players.LocalPlayer.Character
    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
    if humanoid == nil then
        return
    end
    local started = os.clock()
    local connection: RBXScriptConnection? = nil
    connection = RunService.RenderStepped:Connect(function()
        local progress = (os.clock() - started) / SHAKE_DURATION
        if progress >= 1 or humanoid.Parent == nil then
            humanoid.CameraOffset = Vector3.zero
            if connection then
                connection:Disconnect()
            end
            return
        end
        local amount = SHAKE_STRENGTH * (1 - progress)
        humanoid.CameraOffset = Vector3.new(
            (math.random() - 0.5) * amount,
            (math.random() - 0.5) * amount,
            (math.random() - 0.5) * amount
        )
    end)
end

local function onStealHit(
    victim: any,
    position: any,
    count: any,
    attacker: any,
    weaponId: any,
    knockback: any,
    stunSeconds: any
)
    if typeof(victim) ~= "Instance" or typeof(position) ~= "Vector3" or type(count) ~= "number" then
        return
    end
    if count > 0 then
        showHit(position + Vector3.new(0, 3, 0), count)
    end

    -- El arma del atacante da su color y su fuerza al golpe.
    local weapon = if type(weaponId) == "string" then Equipment.ById[weaponId] else nil
    local push = if typeof(knockback) == "Vector3" then knockback else Vector3.zero
    local stun = if type(stunSeconds) == "number" then stunSeconds else 0
    if typeof(attacker) == "Instance" and attacker:IsA("Player") and attacker.Character then
        SwingController.PlayHit(attacker.Character)
    end
    if weapon then
        local color = weapon.accent or weapon.color
        local rank = Equipment.GetRank(weapon)
        if rank >= 3 then
            Effects.Burst({
                position = position + Vector3.new(0, 2, 0),
                color = color,
                count = 8 + rank * 4,
                speed = 14,
                size = 0.5,
            })
        end
        if push.Magnitude > 40 then
            Effects.Shockwave({ position = position, radius = 9, color = color, duration = 0.4 })
        end
    end
    if stun > 0 then
        Effects.Popup({
            position = position + Vector3.new(0, 5, 0),
            text = Strings.Steal.Stunned,
            color = Color3.fromRGB(120, 230, 255),
            height = 1.4,
            duration = math.max(stun, 0.6),
        })
    end

    if victim == Players.LocalPlayer then
        Sound.Play("Hit")
        flashScreen()
        shakeCamera()
        if stun > 0 then
            Sound.Play("Stun")
        end
        -- El empujón lo aplica el cliente de la víctima, que es quien mueve su personaje.
        local character = Players.LocalPlayer.Character
        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
        if root and root:IsA("BasePart") and push.Magnitude > 0 then
            root.AssemblyLinearVelocity = push
        end
    end
end

function StealController.Init()
    Remotes.StealHit.OnClientEvent:Connect(onStealHit)
end

return StealController
