--!strict

-- Efectos visuales reutilizables del cliente: ráfagas de partículas, ondas expansivas,
-- fragmentos, textos flotantes, destello de pantalla y sacudida de cámara.
-- Todo es local, de corta duración y se limpia solo. Hay un tope de efectos simultáneos
-- para que una situación con mucha actividad (8 jugadores minando) no los amontone; el tope
-- y el número de partículas bajan en equipos modestos (UI/Quality). Las
-- piezas se reutilizan (pool) en vez de crearse y destruirse cada vez.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Quality = require(script.Parent.Quality)

-- Distancia a la cámara a partir de la cual no se crean efectos pequeños.
local MAX_DISTANCE = 220
-- Piezas guardadas para reutilizar, como mucho, de cada clase.
local POOL_SIZE = 40
local FRAGMENT_SECONDS = 1.2

local Effects = {}

local folder: Folder? = nil
local active = 0
local flashFrame: Frame? = nil
local anchorPool: { Part } = {}
local fragmentPool: { Part } = {}

local function newPart(): Part
    local part = Instance.new("Part")
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    return part
end

-- Devuelve una pieza al pool (o la destruye si ya está lleno).
local function release(pool: { Part }, part: Part)
    part:ClearAllChildren()
    part.Parent = nil
    if #pool < POOL_SIZE then
        table.insert(pool, part)
    else
        part:Destroy()
    end
end
local shakeToken = 0

local function getFolder(): Folder
    if folder then
        return folder
    end
    local created = Instance.new("Folder")
    created.Name = "Effects"
    created.Parent = Workspace
    folder = created
    return created
end

-- Indica si merece la pena crear un efecto en ese punto: hay hueco y está cerca de la cámara.
function Effects.CanSpawn(position: Vector3, ignoreDistance: boolean?): boolean
    if active >= Quality.MaxActive[Quality.Get()] then
        return false
    end
    local camera = Workspace.CurrentCamera
    if camera == nil then
        return false
    end
    return ignoreDistance == true or (camera.CFrame.Position - position).Magnitude <= MAX_DISTANCE
end

-- Parte invisible y sin física que sirve de soporte a un efecto. Sale del pool y vuelve a él
-- a los `lifetime` segundos, ya sin hijos; quien la use puede cambiarle forma, material y tamaño.
function Effects.Anchor(position: Vector3, lifetime: number): Part
    local part = table.remove(anchorPool) or newPart()
    part.Name = "Effect"
    part.Anchored = true
    part.Shape = Enum.PartType.Block
    part.Material = Enum.Material.SmoothPlastic
    part.Transparency = 1
    part.Size = Vector3.one
    part.CFrame = CFrame.new(position)
    part.Parent = getFolder()

    active += 1
    task.delay(lifetime, function()
        active -= 1
        release(anchorPool, part)
    end)
    return part
end

-- Ráfaga de partículas que salen en todas direcciones.
function Effects.Burst(props: {
    position: Vector3,
    color: Color3 | ColorSequence,
    count: number,
    speed: number,
    size: number,
    lifetime: number?,
    ignoreDistance: boolean?,
})
    if not Effects.CanSpawn(props.position, props.ignoreDistance) then
        return
    end
    local lifetime = props.lifetime or 0.8
    local holder = Effects.Anchor(props.position, lifetime + 0.5)
    local color = props.color
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = if typeof(color) == "ColorSequence" then color else ColorSequence.new(color)
    emitter.Size = NumberSequence.new(props.size, 0)
    emitter.Transparency = NumberSequence.new(0, 1)
    emitter.Speed = NumberRange.new(props.speed * 0.5, props.speed)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Lifetime = NumberRange.new(lifetime * 0.5, lifetime)
    emitter.Drag = 2
    emitter.LightEmission = 1
    emitter.Rate = 0
    emitter.Parent = holder
    emitter:Emit(Quality.Count(props.count))
end

-- Nube de polvo que se queda flotando un par de segundos y se disipa: da peso a un impacto.
-- En gráficos bajos no sale (la ráfaga y la onda ya cuentan lo que ha pasado).
function Effects.Dust(props: {
    position: Vector3,
    color: Color3,
    count: number,
    size: number,
    ignoreDistance: boolean?,
})
    if Quality.IsLow() or not Effects.CanSpawn(props.position, props.ignoreDistance) then
        return
    end
    local holder = Effects.Anchor(props.position, 3)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(props.color)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, props.size * 0.4),
        NumberSequenceKeypoint.new(1, props.size),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.45),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Speed = NumberRange.new(props.size * 0.6, props.size * 1.4)
    emitter.SpreadAngle = Vector2.new(180, 25)
    emitter.EmissionDirection = Enum.NormalId.Top
    emitter.Acceleration = Vector3.new(0, 1.5, 0)
    emitter.Lifetime = NumberRange.new(1.4, 2.4)
    emitter.Rotation = NumberRange.new(0, 360)
    emitter.RotSpeed = NumberRange.new(-30, 30)
    emitter.Drag = 1.5
    emitter.Rate = 0
    emitter.Parent = holder
    emitter:Emit(Quality.Count(props.count))
end

-- Onda expansiva: un anillo plano sobre el suelo que crece y se desvanece.
function Effects.Shockwave(props: {
    position: Vector3,
    radius: number,
    color: Color3,
    duration: number?,
    ignoreDistance: boolean?,
})
    if not Effects.CanSpawn(props.position, props.ignoreDistance) then
        return
    end
    local duration = props.duration or 0.6
    local ring = Effects.Anchor(props.position, duration + 0.1)
    ring.Shape = Enum.PartType.Cylinder
    ring.Material = Enum.Material.Neon
    ring.Color = props.color
    ring.Transparency = 0.35
    ring.Size = Vector3.new(0.3, 2, 2)
    -- El eje del cilindro es X; se gira para que quede tumbado.
    ring.CFrame = CFrame.new(props.position) * CFrame.Angles(0, 0, math.pi / 2)
    TweenService:Create(
        ring,
        TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = Vector3.new(0.3, props.radius * 2, props.radius * 2), Transparency = 1 }
    ):Play()
end

-- Fragmentos de roca que salen disparados y caen (con física local, sin colisión con jugadores).
function Effects.Fragments(props: {
    position: Vector3,
    direction: Vector3,
    color: Color3,
    count: number,
    size: number,
    speed: number,
})
    if not Effects.CanSpawn(props.position) then
        return
    end
    for _ = 1, Quality.Count(props.count) do
        local fragment = table.remove(fragmentPool) or newPart()
        fragment.Name = "Fragment"
        fragment.Anchored = false
        fragment.Size = Vector3.one * props.size * (0.6 + math.random() * 0.8)
        fragment.Color = props.color
        fragment.Material = Enum.Material.Basalt
        fragment.CFrame = CFrame.new(props.position)
            * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
        fragment.Parent = getFolder()
        local spread = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5)
        fragment.AssemblyLinearVelocity = (props.direction + spread).Unit * props.speed
        fragment.AssemblyAngularVelocity = Vector3.new(
            math.random() - 0.5,
            math.random() - 0.5,
            math.random() - 0.5
        ) * 20
        task.delay(FRAGMENT_SECONDS, function()
            fragment.Anchored = true
            release(fragmentPool, fragment)
        end)
    end
end

-- Rayo fino que sale de un punto, se estira en una dirección y se apaga.
function Effects.Ray(props: {
    position: Vector3,
    direction: Vector3,
    length: number,
    color: Color3,
})
    if not Effects.CanSpawn(props.position) then
        return
    end
    local seconds = 0.35
    local origin, direction = props.position, props.direction
    local part = Effects.Anchor(origin, seconds + 0.05)
    part.Material = Enum.Material.Neon
    part.Color = props.color
    part.Transparency = 0.1
    part.Size = Vector3.new(0.14, 0.14, 0.4)
    part.CFrame = CFrame.lookAt(origin, origin + direction)
    TweenService
        :Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(0.05, 0.05, props.length),
            CFrame = CFrame.lookAt(
                origin + direction * props.length / 2,
                origin + direction * props.length
            ),
            Transparency = 1,
        })
        :Play()
end

-- Texto que sube y se desvanece en un punto del mundo.
function Effects.Popup(
    props: {
        position: Vector3,
        text: string,
        color: Color3,
        -- Altura del texto en studs (por defecto 1,6).
        height: number?,
        duration: number?,
        rise: number?,
    }
)
    if not Effects.CanSpawn(props.position) then
        return
    end
    local duration = props.duration or 1.4
    local height = props.height or 1.6
    local anchor = Effects.Anchor(props.position, duration + 0.1)

    local billboard = Instance.new("BillboardGui")
    -- Los textos ya salen en el idioma elegido: sin traducción automática de Roblox.
    billboard.AutoLocalize = false
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.Size = UDim2.fromScale(height * 8, height)
    billboard.Parent = anchor
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = props.color
    label.TextStrokeTransparency = 0.2
    label.Text = props.text
    label.Parent = billboard
    -- Aparece pasándose un poco de tamaño y se asienta.
    local scale = Instance.new("UIScale")
    scale.Scale = 0.4
    scale.Parent = label
    TweenService:Create(
        scale,
        TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    ):Play()

    local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(
        anchor,
        info,
        { CFrame = CFrame.new(props.position + Vector3.new(0, props.rise or 5, 0)) }
    ):Play()
    TweenService:Create(
        label,
        TweenInfo.new(
            duration * 0.5,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.In,
            0,
            false,
            duration * 0.5
        ),
        { TextTransparency = 1, TextStrokeTransparency = 1 }
    ):Play()
end

-- Chispas: varios rayos finos que salen de un punto hacia un lado (golpe de pico).
function Effects.Sparks(props: {
    position: Vector3,
    direction: Vector3,
    color: Color3,
    count: number,
    length: number,
})
    for _ = 1, Quality.Count(props.count) do
        local spread = Vector3.new(math.random() - 0.5, math.random() - 0.2, math.random() - 0.5)
        Effects.Ray({
            position = props.position,
            direction = (props.direction + spread * 1.6).Unit,
            length = props.length * (0.6 + math.random() * 0.6),
            color = props.color,
        })
    end
end

-- Destello de un color a pantalla completa que se apaga solo. `strength` (0-1) es cuánto tapa.
function Effects.Flash(color: Color3, strength: number, duration: number)
    local frame = flashFrame
    if frame == nil then
        local gui = Instance.new("ScreenGui")
        -- Los textos ya salen en el idioma elegido: sin traducción automática de Roblox.
        gui.AutoLocalize = false
        gui.Name = "ScreenFlash"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 4
        local created = Instance.new("Frame")
        created.Size = UDim2.fromScale(1, 1)
        created.BackgroundTransparency = 1
        created.BorderSizePixel = 0
        created.Active = false
        created.Parent = gui
        gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
        flashFrame = created
        frame = created
    end
    frame.BackgroundColor3 = color
    frame.BackgroundTransparency = 1 - math.clamp(strength, 0, 0.7)
    TweenService:Create(frame, TweenInfo.new(duration), { BackgroundTransparency = 1 }):Play()
end

-- Sacudida de cámara que se va apagando. Una sacudida nueva sustituye a la anterior.
function Effects.Shake(strength: number, duration: number)
    local character = Players.LocalPlayer.Character
    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
    if humanoid == nil or strength <= 0.02 then
        return
    end
    shakeToken += 1
    local token = shakeToken
    local started = os.clock()
    local connection: RBXScriptConnection? = nil
    connection = RunService.RenderStepped:Connect(function()
        local progress = (os.clock() - started) / duration
        if progress >= 1 or humanoid.Parent == nil or token ~= shakeToken then
            if token == shakeToken then
                humanoid.CameraOffset = Vector3.zero
            end
            if connection then
                connection:Disconnect()
            end
            return
        end
        local amount = math.min(strength, 2) * (1 - progress)
        humanoid.CameraOffset = Vector3.new(
            (math.random() - 0.5) * amount,
            (math.random() - 0.5) * amount,
            (math.random() - 0.5) * amount
        )
    end)
end

return Effects
