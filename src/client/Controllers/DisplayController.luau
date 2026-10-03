--!strict

-- Minerales expuestos en los pedestales: giran y flotan, y al colocarse aparecen creciendo
-- con un destello y un sonido. Es solo visual y local: el servidor los deja quietos y cada
-- cliente anima los que tiene cerca.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("Config"):WaitForChild("Map"))

local Sound = require(script.Parent.Parent.UI.Sound)

local DisplayController = {}

type Display = {
    -- Se lee cuando la parte principal ya ha llegado al cliente.
    origin: CFrame?,
    -- Desfase para que no giren todos a la vez.
    phase: number,
    -- Momento en que se colocó (para la animación de aparición); nil si ya estaba al entrar.
    placedAt: number?,
    announced: boolean,
}

local displays: { [Model]: Display } = {}
-- Segundos mínimos entre dos sonidos de colocar.
local PLACE_SOUND_GAP = 0.25
local lastPlaceSound = 0

local function track(instance: Instance, isNew: boolean)
    if instance:IsA("Model") and displays[instance] == nil then
        displays[instance] = {
            origin = nil,
            phase = math.random() * math.pi * 2,
            placedAt = if isNew then os.clock() else nil,
            announced = not isNew,
        }
    end
end

-- Destello de partículas y sonido en el pedestal.
local function announce(model: Model, origin: CFrame)
    local primary = model.PrimaryPart
    if primary == nil then
        return
    end
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(MapConfig.PedestalAccentColor)
    emitter.LightEmission = 1
    emitter.Size = NumberSequence.new(0.6, 0)
    emitter.Speed = NumberRange.new(6, 12)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Lifetime = NumberRange.new(0.4, 0.8)
    emitter.Rate = 0
    emitter.Parent = primary
    emitter:Emit(MapConfig.PlaceBurstCount)
    task.delay(1.5, function()
        emitter:Destroy()
    end)

    -- Un solo sonido aunque se coloquen muchos a la vez (por ejemplo con "Place Best").
    local camera = Workspace.CurrentCamera
    local now = os.clock()
    if
        camera
        and now - lastPlaceSound >= PLACE_SOUND_GAP
        and (origin.Position - camera.CFrame.Position).Magnitude <= MapConfig.PlaceSoundDistance
    then
        lastPlaceSound = now
        Sound.Play("Place", primary)
    end
end

local function update()
    local camera = Workspace.CurrentCamera
    if camera == nil then
        return
    end
    local focus = camera.CFrame.Position
    local now = os.clock()
    local turn = now / MapConfig.SpinPeriod * math.pi * 2
    for model, display in displays do
        local origin = display.origin
        if origin == nil and model.PrimaryPart then
            origin = model:GetPivot()
            display.origin = origin
        end
        if origin and (origin.Position - focus).Magnitude <= MapConfig.SpinMaxDistance then
            if not display.announced then
                display.announced = true
                announce(model, origin)
            end

            -- Aparición: crece desde pequeño, pasándose un poco antes de asentarse.
            local placedAt = display.placedAt
            if placedAt then
                local progress = math.min((now - placedAt) / MapConfig.PlaceGrowSeconds, 1)
                local overshoot = math.sin(progress * math.pi) * 0.2
                model:ScaleTo(math.max(0.2 + 0.8 * progress + overshoot, 0.05))
                if progress >= 1 then
                    model:ScaleTo(1)
                    display.placedAt = nil
                end
            end

            local angle = turn + display.phase
            model:PivotTo(
                origin
                    * CFrame.new(0, math.sin(angle * 2) * MapConfig.SpinBobHeight, 0)
                    * CFrame.Angles(0, angle, 0)
            )
        elseif origin and display.placedAt then
            -- Lejos de la cámara no se anima: se deja ya a su tamaño.
            display.placedAt = nil
            display.announced = true
        end
    end
end

function DisplayController.Start()
    for _, instance in CollectionService:GetTagged(MapConfig.SpinTag) do
        track(instance, false)
    end
    CollectionService:GetInstanceAddedSignal(MapConfig.SpinTag):Connect(function(instance)
        track(instance, true)
    end)
    CollectionService:GetInstanceRemovedSignal(MapConfig.SpinTag):Connect(function(instance)
        if instance:IsA("Model") then
            displays[instance] = nil
        end
    end)
    RunService.RenderStepped:Connect(update)
end

return DisplayController
