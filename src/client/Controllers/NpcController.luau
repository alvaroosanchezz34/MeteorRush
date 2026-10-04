--!strict

-- Anima a los NPCs ambientales y muestra sus frases. Todo es local:
--   * respiran y balancean los brazos (o pican, el minero), solo si están cerca de la cámara
--   * giran la cabeza, y el cuerpo si su configuración lo permite, hacia el jugador más cercano
--   * al usar la opción de hablar dicen la siguiente frase en un bocadillo sobre la cabeza
--   * de vez en cuando sueltan un comentario si el jugador está cerca
-- Las figuras las crea el servidor (NpcService); cada parte trae los atributos `Joint` y
-- `Offset`, que es lo que se usa aquí para colocarla en cada fotograma.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent.Parent.UI.Effects)
local NpcDialogue = require(script.Parent.Parent.UI.NpcDialogue)
local Sound = require(script.Parent.Parent.UI.Sound)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NpcsConfig = require(Shared:WaitForChild("Config"):WaitForChild("Npcs"))

local BUBBLE_COLOR = Color3.fromRGB(24, 24, 34)
local SPARK_COLOR = Color3.fromRGB(255, 220, 120)
-- Radianes por segundo a los que gira hacia el jugador y giro máximo de la cabeza.
local TURN_SPEED = 3
local HEAD_TURN_LIMIT = 1
-- Picar: segundos por golpe, ángulo con el brazo levantado y bajado.
local MINE_PERIOD = 0.9
local MINE_RAISED = 2.3
local MINE_LOWERED = 0.7
local TRACK_ATTEMPTS = 10

type Piece = { part: BasePart, joint: string, offset: CFrame }

type Npc = {
    config: NpcsConfig.Npc,
    model: Model,
    base: CFrame,
    pieces: { Piece },
    bodyYaw: number,
    headYaw: number,
    phase: number,
    lastSwing: number,
    lineIndex: number,
    talkingUntil: number,
    nextIdleLine: number,
    bubble: BillboardGui?,
    bubbleLabel: TextLabel?,
}

local NpcController = {}

local npcs: { [Instance]: Npc } = {}
local random = Random.new()

local function getBubble(npc: Npc): (BillboardGui?, TextLabel?)
    if npc.bubble and npc.bubbleLabel then
        return npc.bubble, npc.bubbleLabel
    end
    local root = npc.model.PrimaryPart
    if root == nil then
        return nil, nil
    end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SpeechBubble"
    billboard.Size = UDim2.fromScale(15, 3.6)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 6.4, 0)
    billboard.MaxDistance = 70
    billboard.LightInfluence = 0
    billboard.Enabled = false
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = BUBBLE_COLOR
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Parent = billboard
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.25, 0)
    corner.Parent = frame
    local stroke = Instance.new("UIStroke")
    stroke.Color = npc.config.hat
    stroke.Thickness = 2
    stroke.Parent = frame
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(0.92, 0.8)
    label.Position = UDim2.fromScale(0.04, 0.1)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = true
    label.TextWrapped = true
    label.Font = Enum.Font.GothamBold
    label.Parent = frame
    billboard.Parent = root
    npc.bubble = billboard
    npc.bubbleLabel = label
    return billboard, label
end

-- Muestra una frase en el bocadillo del NPC durante unos segundos.
local function say(npc: Npc, text: string)
    local bubble, label = getBubble(npc)
    if bubble == nil or label == nil then
        return
    end
    label.Text = text
    bubble.Enabled = true
    local hideAt = os.clock() + NpcsConfig.BubbleSeconds
    npc.talkingUntil = hideAt
    task.delay(NpcsConfig.BubbleSeconds, function()
        -- Si entre tanto ha dicho otra cosa, esa frase tiene su propio temporizador.
        if npc.talkingUntil == hideAt then
            bubble.Enabled = false
        end
    end)
end

local function scheduleIdleLine(npc: Npc)
    npc.nextIdleLine = os.clock()
        + random:NextNumber(NpcsConfig.IdleLineMinWait, NpcsConfig.IdleLineMaxWait)
end

local function localPosition(): Vector3?
    local character = Players.LocalPlayer.Character
    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
    return if root and root:IsA("BasePart") then root.Position else nil
end

-- Posición del jugador más cercano al NPC dentro de la distancia a la que se gira.
local function nearestPlayer(position: Vector3): Vector3?
    local best: Vector3? = nil
    local bestDistance = NpcsConfig.TurnDistance
    for _, player in Players:GetPlayers() do
        local character = player.Character
        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
        if root and root:IsA("BasePart") then
            local distance = (root.Position - position).Magnitude
            if distance <= bestDistance then
                best = root.Position
                bestDistance = distance
            end
        end
    end
    return best
end

-- Acerca un ángulo a su objetivo sin pasarse.
local function approach(current: number, target: number, step: number): number
    return current + math.clamp(target - current, -step, step)
end

local function animate(npc: Npc, now: number, delta: number)
    local config = npc.config
    local base = npc.base
    local talking = now < npc.talkingUntil

    -- Hacia dónde mirar: al jugador cercano o, si no hay nadie, al frente.
    local target = nearestPlayer(base.Position)
    local targetYaw = 0
    if target then
        local point = base:PointToObjectSpace(target)
        targetYaw = math.atan2(-point.X, -point.Z)
    end
    local step = TURN_SPEED * delta
    if config.turnBody then
        npc.bodyYaw = approach(npc.bodyYaw, targetYaw, step)
        npc.headYaw = approach(npc.headYaw, 0, step)
    else
        npc.headYaw =
            approach(npc.headYaw, math.clamp(targetYaw, -HEAD_TURN_LIMIT, HEAD_TURN_LIMIT), step)
    end

    local time = now + npc.phase
    local breathe = math.sin(time * 1.6) * 0.04
    local sway = math.sin(time * 1.3) * 0.08
    local rightArm = sway
    local leftArm = -sway
    if config.animation == "mine" then
        -- Baja rápido para golpear y sube más despacio.
        local cycle = (time / MINE_PERIOD) % 1
        if cycle < 0.3 then
            local progress = cycle / 0.3
            rightArm = MINE_RAISED + (MINE_LOWERED - MINE_RAISED) * progress * progress
        else
            local progress = (cycle - 0.3) / 0.7
            rightArm = MINE_LOWERED + (MINE_RAISED - MINE_LOWERED) * progress
        end
        -- Chispas en la roca al acabar cada golpe.
        local swing = math.floor(time / MINE_PERIOD - 0.3)
        if swing ~= npc.lastSwing then
            npc.lastSwing = swing
            Effects.Burst({
                position = (base * CFrame.new(0.6, 2, -3)).Position,
                color = SPARK_COLOR,
                count = 6,
                speed = 9,
                size = 0.3,
                lifetime = 0.5,
            })
        end
    elseif talking then
        -- Gesticula con el brazo izquierdo mientras habla.
        leftArm = 1 + math.sin(time * 7) * 0.2
    end

    local root = base * CFrame.Angles(0, npc.bodyYaw, 0) * CFrame.new(0, breathe, 0)
    local joints: { [string]: CFrame } = {
        root = root,
        head = root
            * CFrame.new(0, 4.6, 0)
            * CFrame.Angles(math.sin(time * 0.7) * 0.05, npc.headYaw, 0),
        rightArm = root * CFrame.new(1.5, 4, 0) * CFrame.Angles(rightArm, 0, 0),
        leftArm = root * CFrame.new(-1.5, 4, 0) * CFrame.Angles(leftArm, 0, 0),
    }
    for _, piece in npc.pieces do
        piece.part.CFrame = (joints[piece.joint] or root) * piece.offset
    end

    -- Comentario espontáneo si el jugador local está cerca.
    if now >= npc.nextIdleLine then
        scheduleIdleLine(npc)
        local position = localPosition()
        local lines = NpcDialogue.GetIdleLines(config.id)
        if
            not talking
            and position
            and #lines > 0
            and (position - base.Position).Magnitude <= NpcsConfig.IdleLineDistance
        then
            say(npc, lines[random:NextInteger(1, #lines)])
        end
    end
end

-- Empieza a seguir un NPC. Devuelve false si aún no han llegado sus partes.
local function track(model: Instance): boolean
    if npcs[model] then
        return true
    end
    local id = model:GetAttribute("NpcId")
    local base = model:GetAttribute("Base")
    local config = if type(id) == "string" then NpcsConfig.ById[id] else nil
    if not model:IsA("Model") or config == nil or typeof(base) ~= "CFrame" then
        return true
    end
    local root = model.PrimaryPart
    local prompt = if root then root:FindFirstChildOfClass("ProximityPrompt") else nil
    local pieces: { Piece } = {}
    for _, child in model:GetChildren() do
        local joint = child:GetAttribute("Joint")
        local offset = child:GetAttribute("Offset")
        if child:IsA("BasePart") and type(joint) == "string" and typeof(offset) == "CFrame" then
            table.insert(pieces, { part = child, joint = joint, offset = offset })
        end
    end
    if root == nil or prompt == nil or #pieces < 8 then
        return false
    end

    local npc: Npc = {
        config = config,
        model = model,
        base = base,
        pieces = pieces,
        bodyYaw = 0,
        headYaw = 0,
        phase = random:NextNumber(0, 10),
        lastSwing = 0,
        lineIndex = 0,
        talkingUntil = 0,
        nextIdleLine = 0,
    }
    scheduleIdleLine(npc)
    npcs[model] = npc

    -- Hablar: cada vez dice la frase siguiente, empezando por lo que esté pasando ahora.
    prompt.Triggered:Connect(function()
        local lines = NpcDialogue.GetLines(config.id)
        if #lines == 0 then
            return
        end
        npc.lineIndex = npc.lineIndex % #lines + 1
        say(npc, lines[npc.lineIndex])
        Sound.Play("UiClick")
    end)
    return true
end

local function trackWhenReady(model: Instance)
    for _ = 1, TRACK_ATTEMPTS do
        if model.Parent == nil or track(model) then
            return
        end
        task.wait(0.5)
    end
end

function NpcController.Start()
    for _, model in CollectionService:GetTagged(NpcsConfig.Tag) do
        task.spawn(trackWhenReady, model)
    end
    CollectionService:GetInstanceAddedSignal(NpcsConfig.Tag):Connect(function(model)
        task.spawn(trackWhenReady, model)
    end)
    CollectionService:GetInstanceRemovedSignal(NpcsConfig.Tag):Connect(function(model)
        npcs[model] = nil
    end)

    RunService.RenderStepped:Connect(function(delta: number)
        local camera = Workspace.CurrentCamera
        if camera == nil then
            return
        end
        local focus = camera.CFrame.Position
        local now = os.clock()
        for _, npc in npcs do
            -- Lejos de la cámara no se animan.
            if (npc.base.Position - focus).Magnitude <= NpcsConfig.AnimateDistance then
                animate(npc, now, delta)
            end
        end
    end)
end

return NpcController
