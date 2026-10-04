--!strict

-- Momento de descubrimiento: lo que pasa al conseguir un mineral, a la medida de su rareza
-- (Config/RarityFx.Discovery). Raro: un sonido y una ráfaga. Épico: además onda, rayos y un
-- destello leve. Legendario: todo más fuerte. Mítico: un momento cinematográfico de un par
-- de segundos, con la pantalla algo oscurecida y el mineral girando en el centro con su
-- rareza, su nombre y su mutación. No detiene el juego: el jugador sigue pudiendo moverse.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Components = require(script.Parent.Components)
local Effects = require(script.Parent.Effects)
local RarityStyle = require(script.Parent.RarityStyle)
local Sound = require(script.Parent.Sound)
local Theme = require(script.Parent.Theme)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MineralVisual = require(Shared:WaitForChild("Util"):WaitForChild("MineralVisual"))
local Minerals = require(Config:WaitForChild("Minerals"))
local Mutations = require(Config:WaitForChild("Mutations"))
local RarityFx = require(Config:WaitForChild("RarityFx"))
local Strings = require(Shared:WaitForChild("Strings"))

local MODEL_SIZE = 3
local SPIN_SPEED = 2.4
local SPARKS = 14
-- Rango desde el que recoger un mineral del suelo es un momento de descubrimiento completo.
local PICKUP_MOMENT_RANK = 5

local DiscoveryMoment = {}

local gui: ScreenGui? = nil
local playing = false

local function getGui(): ScreenGui
    if gui then
        return gui
    end
    local created = Instance.new("ScreenGui")
    created.Name = "DiscoveryMoment"
    created.ResetOnSpawn = false
    created.IgnoreGuiInset = true
    created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    created.DisplayOrder = 30
    created.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    gui = created
    return created
end

-- Momento cinematográfico: pantalla algo oscurecida y el mineral girando en el centro.
local function cinematic(mineral: Minerals.Mineral, mutation: Mutations.Mutation?, color: Color3)
    if playing then
        return
    end
    playing = true
    local screen = getGui()
    local seconds = RarityFx.CinematicSeconds

    local dim = Instance.new("Frame")
    dim.Size = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = Color3.new(0, 0, 0)
    dim.BackgroundTransparency = 1
    dim.BorderSizePixel = 0
    -- No tapa los clics: el juego sigue.
    dim.Active = false
    dim.Parent = screen
    TweenService
        :Create(dim, Theme.Motion.Fade, { BackgroundTransparency = 1 - RarityFx.CinematicDim })
        :Play()

    local holder = Instance.new("Frame")
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.fromScale(0.5, 0.45)
    holder.Size = UDim2.fromScale(0.5, 0.62)
    holder.BackgroundTransparency = 1
    holder.Parent = screen
    local scale = Instance.new("UIScale")
    scale.Scale = 0.3
    scale.Parent = holder
    TweenService:Create(scale, Theme.Motion.Open, { Scale = 1 }):Play()

    -- Aura: un disco de luz detrás del mineral que late.
    local aura = Instance.new("Frame")
    aura.AnchorPoint = Vector2.new(0.5, 0.5)
    aura.Position = UDim2.fromScale(0.5, 0.42)
    aura.Size = UDim2.fromScale(0.62, 0.62)
    aura.SizeConstraint = Enum.SizeConstraint.RelativeYY
    aura.BackgroundColor3 = color
    aura.BackgroundTransparency = 0.78
    aura.BorderSizePixel = 0
    local auraCorner = Instance.new("UICorner")
    auraCorner.CornerRadius = UDim.new(1, 0)
    auraCorner.Parent = aura
    local auraStroke = Instance.new("UIStroke")
    auraStroke.Color = color
    auraStroke.Thickness = 4
    auraStroke.Transparency = 0.2
    auraStroke.Parent = aura
    local auraScale = Instance.new("UIScale")
    auraScale.Parent = aura
    aura.Parent = holder
    TweenService:Create(
        auraScale,
        TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Scale = 1.12 }
    ):Play()

    -- El mineral, en 3D y girando.
    local viewport = Instance.new("ViewportFrame")
    viewport.AnchorPoint = Vector2.new(0.5, 0.5)
    viewport.Position = UDim2.fromScale(0.5, 0.42)
    viewport.Size = UDim2.fromScale(0.6, 0.6)
    viewport.SizeConstraint = Enum.SizeConstraint.RelativeYY
    viewport.BackgroundTransparency = 1
    viewport.Ambient = Color3.new(1, 1, 1)
    viewport.LightColor = Color3.new(1, 1, 1)
    local camera = Instance.new("Camera")
    camera.CFrame = CFrame.lookAt(Vector3.new(0, MODEL_SIZE * 0.5, MODEL_SIZE * 2.1), Vector3.zero)
    camera.Parent = viewport
    viewport.CurrentCamera = camera
    viewport.Parent = holder

    local spin: RBXScriptConnection? = nil
    local visual =
        MineralVisual.Create(mineral.id, if mutation then mutation.id else "none", MODEL_SIZE)
    if visual:IsA("PVInstance") then
        local model = visual :: PVInstance
        model:PivotTo(CFrame.new())
        model.Parent = viewport
        local angle = 0
        spin = RunService.RenderStepped:Connect(function(delta: number)
            angle += delta * SPIN_SPEED
            model:PivotTo(CFrame.Angles(0, angle, 0))
        end)
    else
        visual:Destroy()
    end

    -- Rareza, nombre y mutación.
    Components.Label({
        text = `{RarityStyle.Icons[Minerals.Rarities[mineral.rarity].rank] or ""} {string.upper(
            Strings.Rarities[mineral.rarity] or mineral.rarity
        )}`,
        size = UDim2.fromScale(1, 0.09),
        position = UDim2.fromScale(0, 0.02),
        color = Minerals.Rarities[mineral.rarity].color,
        heading = true,
        parent = holder,
    })
    Components.Label({
        text = string.upper(Strings.Minerals[mineral.id] or mineral.id),
        size = UDim2.fromScale(1, 0.14),
        position = UDim2.fromScale(0, 0.76),
        color = color,
        heading = true,
        parent = holder,
    })
    if mutation then
        Components.Label({
            text = Strings.MutationReveal[mutation.id] or mutation.id,
            size = UDim2.fromScale(1, 0.08),
            position = UDim2.fromScale(0, 0.91),
            color = mutation.color or color,
            parent = holder,
        })
    end

    -- Destellos que salen del mineral.
    for index = 1, SPARKS do
        local angle = index / SPARKS * math.pi * 2
        local spark = Components.Label({
            text = "✦",
            size = UDim2.fromScale(0.05, 0.06),
            position = UDim2.fromScale(0.5, 0.42),
            color = color,
            parent = holder,
        })
        spark.AnchorPoint = Vector2.new(0.5, 0.5)
        TweenService:Create(
            spark,
            TweenInfo.new(seconds * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                Position = UDim2.fromScale(
                    0.5 + math.cos(angle) * 0.42,
                    0.42 + math.sin(angle) * 0.42
                ),
                TextTransparency = 1,
                Rotation = 200,
            }
        ):Play()
    end

    task.delay(seconds, function()
        TweenService:Create(dim, Theme.Motion.Fade, { BackgroundTransparency = 1 }):Play()
        local out = TweenService:Create(scale, Theme.Motion.Close, { Scale = 0 })
        out:Play()
        out.Completed:Wait()
        if spin then
            spin:Disconnect()
        end
        holder:Destroy()
        task.wait(0.3)
        dim:Destroy()
        playing = false
    end)
end

-- Feedback al recoger un mineral del suelo (el que soltó otro jugador), según su rareza:
-- un sonido rápido para lo común, un destello para lo raro y, de Legendario para arriba, el
-- momento de descubrimiento completo.
function DiscoveryMoment.Pickup(mineralId: string, mutationId: string, position: Vector3)
    local mineral = Minerals.ById[mineralId]
    if mineral == nil then
        return
    end
    local rank = Minerals.Rarities[mineral.rarity].rank
    local mutation = Mutations.ById[mutationId]
    local color = (if mutation then mutation.color else nil)
        or Minerals.Rarities[mineral.rarity].color
    local audio = RarityFx.Audio[rank]
    if audio then
        Sound.Play(audio.pickup, { pitch = audio.pickupPitch })
    end
    if rank >= PICKUP_MOMENT_RANK then
        DiscoveryMoment.Play(mineralId, mutationId, position)
    elseif rank >= Minerals.RareRank then
        Effects.Burst({
            position = position,
            color = color,
            count = 6 + rank * 4,
            speed = 10,
            size = 0.5,
        })
        if rank > Minerals.RareRank then
            Effects.Shockwave({ position = position, radius = 5, color = color, duration = 0.5 })
        end
    end
end

-- Reproduce el momento de descubrimiento de ese mineral en ese punto del mundo.
function DiscoveryMoment.Play(mineralId: string, mutationId: string, origin: Vector3)
    local mineral = Minerals.ById[mineralId]
    if mineral == nil then
        return
    end
    local tier = RarityFx.Discovery[Minerals.Rarities[mineral.rarity].rank]
    if tier == nil then
        return
    end
    local mutation: Mutations.Mutation? = Mutations.ById[mutationId]
    if mutation and mutation.id == Mutations.NoneId then
        mutation = nil
    end
    local color = (if mutation then mutation.color else nil)
        or Minerals.Rarities[mineral.rarity].color

    Sound.Play(tier.sound, { duck = tier.cinematic or tier.flash >= 0.2 })
    Effects.Burst({
        position = origin,
        color = color,
        count = tier.burst,
        speed = 12 + tier.burst * 0.25,
        size = 0.7,
        lifetime = 1.1,
    })
    if tier.wave > 0 then
        Effects.Shockwave({ position = origin, radius = tier.wave, color = color, duration = 0.8 })
    end
    for index = 1, tier.rays do
        local angle = index / tier.rays * math.pi * 2
        Effects.Ray({
            position = origin,
            direction = Vector3.new(math.cos(angle), 0.4, math.sin(angle)).Unit,
            length = 5 + tier.rays * 0.4,
            color = color,
        })
    end
    if tier.flash > 0 then
        Effects.Flash(color, tier.flash, 0.8)
    end
    if tier.shake > 0 then
        Effects.Shake(tier.shake, 0.45)
    end
    if tier.cinematic then
        cinematic(mineral, mutation, color)
    end
end

return DiscoveryMoment
