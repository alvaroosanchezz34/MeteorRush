--!strict

-- Animación de picar: mueve el brazo derecho de cualquier personaje que esté minando.
-- El servidor marca el personaje con el atributo "Mining" y cada cliente anima a todos los
-- que ve, así no hacen falta animaciones subidas a Roblox.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MeteorsConfig = require(Shared:WaitForChild("Config"):WaitForChild("Meteors"))

local SwingController = {}

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

local function update()
    local phase = (os.clock() / MeteorsConfig.SwingPeriod) % 1
    local angle = swingAngle(phase)
    for _, player in Players:GetPlayers() do
        local character = player.Character
        if character and character:GetAttribute("Mining") == true then
            local shoulder, isR6 = getShoulder(character)
            if shoulder then
                -- En R6 el hombro está girado y el brazo se levanta rotando en Z.
                shoulder.Transform = if isR6
                    then CFrame.Angles(0, 0, angle)
                    else CFrame.Angles(angle, 0, 0)
            end
        end
    end
end

function SwingController.Start()
    -- Stepped va después de las animaciones del personaje, así que este giro las sustituye.
    RunService.Stepped:Connect(update)
end

return SwingController
