--!strict

-- Minerales expuestos en los pedestales: giran y flotan, y al colocarse aparecen creciendo
-- con un destello y un sonido. Es solo visual y local: el servidor los deja quietos y cada
-- cliente anima los que tiene cerca. Su aura, su luz y sus efectos según la rareza y la
-- mutación los pone RarityVisualController.
-- También anima los carteles flotantes de los minerales (los crea el servidor con colores
-- fijos): el arcoíris recorre el texto de la mutación Rainbow y un brillo el de las rarezas
-- más altas.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("Config"):WaitForChild("Map"))
local MineralVisual = require(Shared:WaitForChild("Util"):WaitForChild("MineralVisual"))
local Minerals = require(Shared:WaitForChild("Config"):WaitForChild("Minerals"))
local Mutations = require(Shared:WaitForChild("Config"):WaitForChild("Mutations"))
local RarityFx = require(Shared:WaitForChild("Config"):WaitForChild("RarityFx"))

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
    -- Cómo se mueve ese mineral (Config/RarityFx); se lee cuando llegan sus atributos.
    motion: RarityFx.Motion?,
}

local DEFAULT_MOTION: RarityFx.Motion = { spin = 1, bob = 1, orbit = 1, jitter = 0 }

local displays: { [Model]: Display } = {}
-- Segundos mínimos entre dos sonidos de colocar.
local PLACE_SOUND_GAP = 0.25
local lastPlaceSound = 0

local RAINBOW = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.75, 1)),
    ColorSequenceKeypoint.new(0.25, Color3.fromHSV(0.2, 0.75, 1)),
    ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.45, 0.75, 1)),
    ColorSequenceKeypoint.new(0.75, Color3.fromHSV(0.7, 0.75, 1)),
    ColorSequenceKeypoint.new(1, Color3.fromHSV(0.9, 0.75, 1)),
})
local SHIMMER = TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

-- Degradado que recorre el texto de una etiqueta. El tween es de TweenService (no cuesta
-- nada por fotograma) y desaparece con la etiqueta.
local function shimmer(label: TextLabel, colors: ColorSequence)
    label.TextColor3 = Color3.new(1, 1, 1)
    local gradient = Instance.new("UIGradient")
    gradient.Color = colors
    gradient.Offset = Vector2.new(-0.5, 0)
    gradient.Parent = label
    TweenService:Create(gradient, SHIMMER, { Offset = Vector2.new(0.5, 0) }):Play()
end

-- Anima el cartel de un mineral: arcoíris en la mutación Rainbow y brillo en las demás
-- mutaciones y en las rarezas más altas.
local function decorateSign(sign: Instance)
    if sign:GetAttribute("Decorated") then
        return
    end
    sign:SetAttribute("Decorated", true)
    local mutation = Mutations.ById[sign:GetAttribute("Mutation") :: any]
    local mineral = Minerals.ById[sign:GetAttribute("Mineral") :: any]
    local mutationLabel = sign:FindFirstChild("Mutation")
    local mutationColor = if mutation then mutation.color else nil
    if mutationLabel and mutationLabel:IsA("TextLabel") and mutation and mutationColor then
        shimmer(
            mutationLabel,
            if mutation.style == "rainbow"
                then RAINBOW
                else ColorSequence.new({
                    ColorSequenceKeypoint.new(0, mutationColor),
                    ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, mutationColor),
                })
        )
    end
    local rarityLabel = sign:FindFirstChild("Rarity")
    if
        mineral
        and rarityLabel
        and rarityLabel:IsA("TextLabel")
        and Minerals.GetRank(mineral.id) >= MineralVisual.SpecialRank
    then
        local color = Minerals.Rarities[mineral.rarity].color
        shimmer(
            rarityLabel,
            ColorSequence.new({
                ColorSequenceKeypoint.new(0, color),
                ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, color),
            })
        )
    end
end

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
        -- El sonido de colocar cambia con la rareza.
        local audio = RarityFx.Audio[Minerals.GetRank(model:GetAttribute("Mineral") :: any)]
        if audio then
            Sound.Play(audio.place, { parent = primary, pitch = audio.placePitch })
        else
            Sound.Play("Place", primary)
        end
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

            -- Cada mineral se mueve a su manera: el cristal gira despacio, el plasma rápido y
            -- con temblor, la materia oscura muy lento y al revés...
            local motion = display.motion
            if motion == nil then
                local identity = RarityFx.Identities[model:GetAttribute("Mineral") :: any]
                motion = if identity then identity.motion else DEFAULT_MOTION
                display.motion = motion
            end
            local time = now + display.phase
            model:PivotTo(
                origin
                    * CFrame.new(
                        math.noise(time * 9, display.phase) * motion.jitter,
                        math.sin(turn * 2 + display.phase) * MapConfig.SpinBobHeight * motion.bob,
                        math.noise(display.phase, time * 9) * motion.jitter
                    )
                    * CFrame.Angles(0, turn * motion.spin + display.phase, 0)
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

    -- Las etiquetas del cartel pueden llegar un instante después que el cartel.
    local function onSign(sign: Instance)
        task.defer(decorateSign, sign)
    end
    for _, sign in CollectionService:GetTagged(MineralVisual.SignTag) do
        onSign(sign)
    end
    CollectionService:GetInstanceAddedSignal(MineralVisual.SignTag):Connect(onSign)
end

return DisplayController
