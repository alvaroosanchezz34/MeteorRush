--!strict

-- Efectos de meteoritos en el cliente: marcador de impacto con cuenta atrás, caída,
-- explosión al impactar y barra de progreso del minado.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MeteorsConfig = require(Config:WaitForChild("Meteors"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local Sound = require(script.Parent.Parent.UI.Sound)

local MARKER_COLOR = Color3.fromRGB(255, 70, 50)
local BEAM_HEIGHT = 200
local FIREBALL_COLOR = Color3.fromRGB(255, 140, 40)
local DUST_COLOR = Color3.fromRGB(150, 120, 100)
local SPARK_COLOR = Color3.fromRGB(255, 220, 120)

local MeteorController = {}

local effectsFolder: Folder? = nil
local progressGui: BillboardGui? = nil
local progressFill: Frame? = nil
local progressTween: Tween? = nil

local function getEffectsFolder(): Folder
    if effectsFolder then
        return effectsFolder
    end
    local folder = Instance.new("Folder")
    folder.Name = "MeteorEffects"
    folder.Parent = Workspace
    effectsFolder = folder
    return folder
end

local function makeEffectPart(props: {
    name: string,
    size: Vector3,
    cframe: CFrame,
    color: Color3,
    transparency: number,
    shape: Enum.PartType?,
}): Part
    local part = Instance.new("Part")
    part.Name = props.name
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Size = props.size
    part.CFrame = props.cframe
    part.Color = props.color
    part.Transparency = props.transparency
    if props.shape then
        part.Shape = props.shape
    end
    part.Parent = getEffectsFolder()
    return part
end

local function createMarker(position: Vector3, radius: number): (Model, TextLabel)
    local marker = Instance.new("Model")
    marker.Name = "ImpactMarker"

    local ground = Vector3.new(position.X, 0.2, position.Z)
    local ring = makeEffectPart({
        name = "Ring",
        size = Vector3.new(0.2, radius * 2 + 4, radius * 2 + 4),
        cframe = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90)),
        color = MARKER_COLOR,
        transparency = 0.5,
        shape = Enum.PartType.Cylinder,
    })
    ring.Parent = marker

    local beam = makeEffectPart({
        name = "Beam",
        size = Vector3.new(BEAM_HEIGHT, 1.5, 1.5),
        cframe = CFrame.new(ground + Vector3.new(0, BEAM_HEIGHT / 2, 0))
            * CFrame.Angles(0, 0, math.rad(90)),
        color = MARKER_COLOR,
        transparency = 0.4,
        shape = Enum.PartType.Cylinder,
    })
    beam.Parent = marker

    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = ring
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    -- Tamaño en studs para que se vea más pequeño a lo lejos.
    billboard.Size = UDim2.fromScale(24, 6)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, radius * 2 + 6, 0)
    billboard.MaxDistance = math.huge
    billboard.Parent = ring

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Font = Enum.Font.GothamBlack
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0
    label.Parent = billboard

    marker.Parent = getEffectsFolder()
    return marker, label
end

-- Ráfaga de partículas en un punto (polvo del impacto, chispas del pico).
local function burst(position: Vector3, color: Color3, count: number, speed: number, size: number)
    local holder = makeEffectPart({
        name = "Burst",
        size = Vector3.one,
        cframe = CFrame.new(position),
        color = color,
        transparency = 1,
    })
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(color)
    emitter.Size = NumberSequence.new(size, 0)
    emitter.Speed = NumberRange.new(speed * 0.5, speed)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Lifetime = NumberRange.new(0.4, 1)
    emitter.Rate = 0
    emitter.Parent = holder
    emitter:Emit(count)
    task.delay(1.5, function()
        holder:Destroy()
    end)
end

local function playFall(position: Vector3, radius: number)
    local start = position
        + Vector3.new(MeteorsConfig.FallHeight * 0.4, MeteorsConfig.FallHeight, 0)
    local fireball = makeEffectPart({
        name = "Fireball",
        size = Vector3.one * radius * 2,
        cframe = CFrame.new(start),
        color = FIREBALL_COLOR,
        transparency = 0,
        shape = Enum.PartType.Ball,
    })
    local fire = Instance.new("Fire")
    fire.Size = radius * 3
    fire.Heat = 25
    fire.Parent = fireball

    local tween = TweenService:Create(
        fireball,
        TweenInfo.new(MeteorsConfig.FallDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { CFrame = CFrame.new(position) }
    )
    tween.Completed:Connect(function()
        fireball:Destroy()
        burst(position, DUST_COLOR, math.floor(radius * 10), radius * 6, radius)
        Sound.Play("MeteorImpact")
        local explosion = Instance.new("Explosion")
        explosion.Position = position
        explosion.BlastRadius = radius * 3
        -- Solo visual: no empuja ni rompe nada.
        explosion.BlastPressure = 0
        explosion.DestroyJointRadiusPercent = 0
        explosion.Parent = getEffectsFolder()
    end)
    tween:Play()
end

local function onMeteorIncoming(id: any, typeId: any, position: any, impactAt: any)
    if
        type(id) ~= "number"
        or type(typeId) ~= "string"
        or typeof(position) ~= "Vector3"
        or type(impactAt) ~= "number"
    then
        return
    end
    local meteorType = MeteorsConfig.Types[typeId]
    if meteorType == nil then
        return
    end

    local marker, label = createMarker(position, meteorType.radius)
    Sound.Play("MeteorWarning")
    local fallStarted = false
    local connection: RBXScriptConnection? = nil
    connection = RunService.RenderStepped:Connect(function()
        local remaining = impactAt - Workspace:GetServerTimeNow()
        label.Text = string.format(Strings.Meteor.ImpactLabel, math.max(math.ceil(remaining), 0))

        if not fallStarted and remaining <= MeteorsConfig.FallDuration then
            fallStarted = true
            playFall(position, meteorType.radius)
        end
        if remaining <= 0 then
            if connection then
                connection:Disconnect()
            end
            marker:Destroy()
        end
    end)
end

local function findMeteorInstance(meteorId: number): PVInstance?
    local folder = Workspace:FindFirstChild("Meteors")
    if folder == nil then
        return nil
    end
    for _, child in folder:GetChildren() do
        if child:GetAttribute("MeteorId") == meteorId and child:IsA("PVInstance") then
            return child
        end
    end
    return nil
end

local function getProgressGui(): (BillboardGui, Frame)
    if progressGui and progressFill then
        return progressGui, progressFill
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MiningProgress"
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.Size = UDim2.fromScale(6, 1)
    billboard.Enabled = false
    billboard.ResetOnSpawn = false

    local background = Instance.new("Frame")
    background.Size = UDim2.fromScale(1, 1)
    background.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    background.BackgroundTransparency = 0.3
    background.Parent = billboard

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
    fill.BorderSizePixel = 0
    fill.Parent = background

    billboard.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    progressGui = billboard
    progressFill = fill
    return billboard, fill
end

local function onMineState(state: any, meteorId: any, duration: any)
    local billboard, fill = getProgressGui()
    if progressTween then
        progressTween:Cancel()
        progressTween = nil
    end

    if state ~= "start" or type(meteorId) ~= "number" or type(duration) ~= "number" then
        billboard.Enabled = false
        return
    end
    local meteor = findMeteorInstance(meteorId)
    if meteor == nil then
        billboard.Enabled = false
        return
    end

    local radius = meteor:GetAttribute("Radius")
    -- Un BillboardGui se engancha a una parte: en un modelo, a su parte principal.
    local adornee: Instance = meteor
    if meteor:IsA("Model") then
        adornee = meteor.PrimaryPart or meteor:FindFirstChildWhichIsA("BasePart", true) or meteor
    end
    -- Cada "start" después del primero significa que se completó un golpe.
    if billboard.Enabled and billboard.Adornee == adornee then
        local character = Players.LocalPlayer.Character
        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
        local origin = meteor:GetPivot().Position
        local toward = if root and root:IsA("BasePart")
            then (root.Position - origin).Unit
            else Vector3.yAxis
        local surface = origin + toward * (if type(radius) == "number" then radius else 4)
        burst(surface, SPARK_COLOR, 12, 12, 0.4)
        Sound.Play("MineHit")
    end
    billboard.Adornee = adornee
    billboard.StudsOffsetWorldSpace =
        Vector3.new(0, (if type(radius) == "number" then radius else 4) + 2, 0)
    billboard.Enabled = true
    fill.Size = UDim2.fromScale(0, 1)
    local tween = TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Size = UDim2.fromScale(1, 1),
    })
    tween:Play()
    progressTween = tween
end

-- Devuelve el id y la posición del meteorito activo más cercano cuya superficie está a
-- `range` studs o menos.
function MeteorController.GetNearestMeteor(position: Vector3, range: number): (number?, Vector3?)
    local folder = Workspace:FindFirstChild("Meteors")
    if folder == nil then
        return nil
    end
    local bestId: number? = nil
    local bestPosition: Vector3? = nil
    local bestDistance = math.huge
    for _, child in folder:GetChildren() do
        local id = child:GetAttribute("MeteorId")
        local radius = child:GetAttribute("Radius")
        if type(id) == "number" and type(radius) == "number" and child:IsA("PVInstance") then
            local meteorPosition = child:GetPivot().Position
            local distance = (meteorPosition - position).Magnitude - radius
            if distance <= range and distance < bestDistance then
                bestId = id
                bestPosition = meteorPosition
                bestDistance = distance
            end
        end
    end
    return bestId, bestPosition
end

function MeteorController.Init()
    Remotes.MeteorIncoming.OnClientEvent:Connect(onMeteorIncoming)
    Remotes.MineState.OnClientEvent:Connect(onMineState)
end

return MeteorController
