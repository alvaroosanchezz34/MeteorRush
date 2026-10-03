--!strict

-- Hace girar y flotar los minerales expuestos en los pedestales. Es solo visual y local:
-- el servidor los deja quietos y cada cliente anima los que tiene cerca.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("Config"):WaitForChild("Map"))

local DisplayController = {}

-- Posición original de cada modelo y un desfase para que no giren todos a la vez.
-- El origen se lee cuando la parte principal ya ha llegado al cliente.
local displays: { [Model]: { origin: CFrame?, phase: number } } = {}

local function track(instance: Instance)
    if instance:IsA("Model") and displays[instance] == nil then
        displays[instance] = { origin = nil, phase = math.random() * math.pi * 2 }
    end
end

local function update()
    local camera = Workspace.CurrentCamera
    if camera == nil then
        return
    end
    local focus = camera.CFrame.Position
    local turn = os.clock() / MapConfig.SpinPeriod * math.pi * 2
    for model, display in displays do
        local origin = display.origin
        if origin == nil and model.PrimaryPart then
            origin = model:GetPivot()
            display.origin = origin
        end
        if origin and (origin.Position - focus).Magnitude <= MapConfig.SpinMaxDistance then
            local angle = turn + display.phase
            model:PivotTo(
                origin
                    * CFrame.new(0, math.sin(angle * 2) * MapConfig.SpinBobHeight, 0)
                    * CFrame.Angles(0, angle, 0)
            )
        end
    end
end

function DisplayController.Start()
    for _, instance in CollectionService:GetTagged(MapConfig.SpinTag) do
        track(instance)
    end
    CollectionService:GetInstanceAddedSignal(MapConfig.SpinTag):Connect(track)
    CollectionService:GetInstanceRemovedSignal(MapConfig.SpinTag):Connect(function(instance)
        if instance:IsA("Model") then
            displays[instance] = nil
        end
    end)
    RunService.RenderStepped:Connect(update)
end

return DisplayController
