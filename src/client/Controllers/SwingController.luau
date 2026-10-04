--!strict

-- Animación de picar: mueve el brazo derecho de cualquier personaje que esté minando.
-- El servidor marca el personaje con el atributo "Mining" y cada cliente anima a todos los
-- que ve, así no hacen falta animaciones subidas a Roblox.
-- Cada pico se mueve a su ritmo (los más rápidos pican más deprisa, según su estadística de
-- velocidad) y `PlayHit` da el golpe de arma: un movimiento corto y seco.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared:WaitForChild("Config"):WaitForChild("Equipment"))
local MeteorsConfig = require(Shared:WaitForChild("Config"):WaitForChild("Meteors"))

-- Segundos que dura el movimiento de un golpe de arma.
local HIT_SECONDS = 0.32
-- Cuánto acelera el ritmo de picar la estadística de velocidad del pico (solo visual).
local SPEED_VISUAL = 2

local SwingController = {}

-- Golpes de arma en curso: personaje y cuándo empezó.
local hits: { [Model]: number } = {}

-- Devuelve la articulación del hombro derecho y si el personaje es R6.
local function getShoulder(character: Model): (Motor6D?, boolean)
    local upperArm = character:FindFirstChild("RightUpperArm")
    local shoulder = if upperArm then upperArm:FindFirstChild("RightShoulder") else nil
    if shoulder and shoulder:IsA("Motor6D") then
        return shoulder, false
    end
    local torso = character:FindFirstChild("Torso")
    shoulder = if torso then torso:FindFirstChild("Right Shoulder") else nil
    if shoulder and shoulder:IsA("Motor6D") then
        return shoulder, true
    end
    return nil, false
end

-- Ángulo del brazo (radianes hacia delante desde la posición colgando) en un punto del ciclo:
-- baja rápido para golpear y sube más despacio.
local function swingAngle(phase: number): number
    local raised = MeteorsConfig.SwingRaisedAngle
    local lowered = MeteorsConfig.SwingLoweredAngle
    local chop = MeteorsConfig.SwingChopFraction
    if phase < chop then
        local progress = phase / chop
        return raised + (lowered - raised) * progress * progress
    end
    local progress = (phase - chop) / (1 - chop)
    return lowered + (raised - lowered) * (1 - (1 - progress) * (1 - progress))
end

local function setArm(character: Model, angle: number)
    local shoulder, isR6 = getShoulder(character)
    if shoulder then
        -- En R6 el hombro está girado y el brazo se levanta rotando en Z.
        shoulder.Transform = if isR6 then CFrame.Angles(0, 0, angle) else CFrame.Angles(angle, 0, 0)
    end
end

local function update()
    local now = os.clock()
    -- Golpes de arma: el brazo sube de golpe y baja fuerte. Tienen prioridad sobre picar.
    for character, startedAt in hits do
        local progress = (now - startedAt) / HIT_SECONDS
        if progress >= 1 or character.Parent == nil then
            hits[character] = nil
        else
            local raised = MeteorsConfig.SwingRaisedAngle
            setArm(character, raised - (raised - 0.4) * progress * progress)
        end
    end
    for _, player in Players:GetPlayers() do
        local character = player.Character
        if character and character:GetAttribute("Mining") == true and hits[character] == nil then
            local pickaxeId = player:GetAttribute("Pickaxe")
            local pickaxe = if type(pickaxeId) == "string" then Equipment.ById[pickaxeId] else nil
            local speed = if pickaxe then Equipment.GetItemStat(pickaxe, "speed") else 0
            local period = MeteorsConfig.SwingPeriod * (1 - speed * SPEED_VISUAL)
            setArm(character, swingAngle((now / period) % 1))
        end
    end
end

-- Movimiento de golpe de arma en ese personaje (lo llama StealController).
function SwingController.PlayHit(character: Model)
    hits[character] = os.clock()
end

function SwingController.Start()
    -- Stepped va después de las animaciones del personaje, así que este giro las sustituye.
    RunService.Stepped:Connect(update)
end

return SwingController
