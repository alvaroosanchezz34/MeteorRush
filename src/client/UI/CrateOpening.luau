--!strict

-- Apertura de una caja. Cuando esto empieza el servidor ya ha decidido y guardado el
-- resultado: aquí solo se presenta. Por eso saltarla (SKIP) no cambia nada.
--
-- Secuencia: la caja aparece en el centro → respira → acumula energía → vibra → efectos de
-- la rareza del premio → se abre la tapa → destello → aparece el objeto, girando → nombre,
-- rareza, estadísticas y NEW / DUPLICATE. Cuanto más raro es el premio, más larga y más
-- cargada es: Común es casi inmediata; Legendaria y Mítica son un momento.
--
-- Todo es interfaz 2D más visores, sin tocar la cámara ni congelar al jugador. Cada
-- apertura crea un marco propio y, al cerrarse, se destruye entero con sus tweens y
-- conexiones.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local AudioManager = require(script.Parent.AudioManager)
local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local Effects = require(script.Parent.Effects)
local GearView = require(script.Parent.GearView)
local Theme = require(script.Parent.Theme)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Equipment = require(Config:WaitForChild("Equipment"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

export type Result = {
    crateId: string,
    kind: string,
    id: string,
    rarity: string,
    isNew: boolean,
    dust: number,
    -- Prueba de administración: no se ha dado nada.
    preview: boolean,
}

-- Presentación de cada rareza (por rango): segundos de cada fase, rayos, chispas y sonido.
type Tier = {
    breathe: number,
    charge: number,
    shake: number,
    rays: number,
    sparks: number,
    sound: string,
    cinematic: boolean,
}
local TIERS: { Tier } = {
    {
        breathe = 0.35,
        charge = 0.3,
        shake = 0.3,
        rays = 0,
        sparks = 6,
        sound = "RevealCommon",
        cinematic = false,
    },
    {
        breathe = 0.4,
        charge = 0.45,
        shake = 0.4,
        rays = 0,
        sparks = 10,
        sound = "RevealCommon",
        cinematic = false,
    },
    {
        breathe = 0.45,
        charge = 0.6,
        shake = 0.5,
        rays = 6,
        sparks = 14,
        sound = "RevealRare",
        cinematic = false,
    },
    {
        breathe = 0.5,
        charge = 0.8,
        shake = 0.7,
        rays = 10,
        sparks = 20,
        sound = "RevealEpic",
        cinematic = false,
    },
    {
        breathe = 0.6,
        charge = 1.1,
        shake = 0.9,
        rays = 14,
        sparks = 28,
        sound = "RevealLegendary",
        cinematic = true,
    },
    {
        breathe = 0.7,
        charge = 1.5,
        shake = 1.2,
        rays = 20,
        sparks = 40,
        sound = "RevealMythic",
        cinematic = true,
    },
}
local WHITE = Color3.new(1, 1, 1)
local OUT = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local CrateOpening = {}

local gui: ScreenGui? = nil
-- Apertura en pantalla: su marco y la función que la salta.
local current: Frame? = nil
local skipCurrent: (() -> ())? = nil

local function getGui(): ScreenGui
    if gui then
        return gui
    end
    local created = Instance.new("ScreenGui")
    created.Name = "CrateOpening"
    created.ResetOnSpawn = false
    created.IgnoreGuiInset = true
    created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    created.DisplayOrder = 30
    created.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    gui = created
    return created
end

local function close()
    local frame = current
    current = nil
    skipCurrent = nil
    if frame then
        local selected = GuiService.SelectedObject
        if selected and selected:IsDescendantOf(frame) then
            GuiService.SelectedObject = nil
        end
        -- Destruir el marco se lleva los visores (y sus giros), los tweens y las conexiones
        -- que cuelgan de él.
        frame:Destroy()
    end
end

local function circle(parent: Instance, color: Color3, zIndex: number): Frame
    local glow = Instance.new("Frame")
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.Position = UDim2.fromScale(0.5, 0.45)
    glow.Size = UDim2.fromScale(0, 0)
    glow.BackgroundColor3 = color
    glow.BackgroundTransparency = 0.55
    glow.BorderSizePixel = 0
    glow.ZIndex = zIndex
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = glow
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.Parent = glow
    local gradient = Instance.new("UIGradient")
    gradient.Transparency = NumberSequence.new(0, 1)
    gradient.Rotation = 90
    gradient.Parent = glow
    glow.Parent = parent
    return glow
end

-- Rayos que salen del centro y giran despacio.
local function rays(parent: Instance, color: Color3, count: number): Frame
    local holder = Instance.new("Frame")
    holder.Name = "Rays"
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.fromScale(0.5, 0.45)
    holder.Size = UDim2.fromScale(0.9, 0.9)
    holder.BackgroundTransparency = 1
    holder.ZIndex = 2
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.Parent = holder
    for index = 1, count do
        local ray = Instance.new("Frame")
        ray.AnchorPoint = Vector2.new(0.5, 0.5)
        ray.Position = UDim2.fromScale(0.5, 0.5)
        ray.Size = UDim2.fromScale(0.012, 1)
        ray.Rotation = (index - 1) * 180 / count
        ray.BackgroundColor3 = color
        ray.BackgroundTransparency = 1
        ray.BorderSizePixel = 0
        ray.ZIndex = 2
        local gradient = Instance.new("UIGradient")
        gradient.Rotation = 90
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        gradient.Parent = ray
        ray.Parent = holder
    end
    holder.Parent = parent
    TweenService:Create(
        holder,
        TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
        { Rotation = 360 }
    ):Play()
    return holder
end

-- Chispas que salen disparadas del centro y se apagan.
local function sparks(parent: Instance, color: Color3, count: number)
    local random = Random.new()
    for _ = 1, count do
        local spark = Instance.new("Frame")
        spark.AnchorPoint = Vector2.new(0.5, 0.5)
        spark.Position = UDim2.fromScale(0.5, 0.45)
        spark.Size = UDim2.fromScale(0.012, 0.012)
        spark.BackgroundColor3 = if random:NextNumber() < 0.4 then WHITE else color
        spark.BorderSizePixel = 0
        spark.ZIndex = 6
        local aspect = Instance.new("UIAspectRatioConstraint")
        aspect.Parent = spark
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = spark
        spark.Parent = parent
        local angle = random:NextNumber() * math.pi * 2
        local distance = random:NextNumber(0.15, 0.45)
        local tween = TweenService:Create(
            spark,
            TweenInfo.new(
                random:NextNumber(0.5, 1),
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            ),
            {
                Position = UDim2.fromScale(
                    0.5 + math.cos(angle) * distance * 0.6,
                    0.45 + math.sin(angle) * distance
                ),
                BackgroundTransparency = 1,
            }
        )
        tween.Completed:Connect(function()
            spark:Destroy()
        end)
        tween:Play()
    end
end

-- Presenta el resultado de una apertura. Si ya había una en pantalla, la sustituye.
function CrateOpening.Play(result: Result)
    close()
    local rarity = Equipment.Rarities[result.rarity] or Equipment.Rarities.common
    local tier = TIERS[rarity.rank] or TIERS[1]
    local color = rarity.color

    local root = Instance.new("Frame")
    root.Name = "Opening"
    root.Size = UDim2.fromScale(1, 1)
    root.BackgroundColor3 = Color3.new(0, 0, 0)
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    -- Tapa los clics del juego mientras dura.
    root.Active = true
    root.Parent = getGui()
    current = root
    TweenService:Create(root, Theme.Motion.Fade, { BackgroundTransparency = 0.35 }):Play()

    local skipped = false
    local revealed = false
    -- Espera esos segundos; devuelve false si la apertura se ha saltado o cerrado.
    local function pause(seconds: number): boolean
        local elapsed = 0
        while elapsed < seconds and not skipped and current == root do
            elapsed += task.wait()
        end
        return not skipped and current == root
    end

    local glow = circle(root, color, 1)
    local stage = Instance.new("Frame")
    stage.Name = "Stage"
    stage.AnchorPoint = Vector2.new(0.5, 0.5)
    stage.Position = UDim2.fromScale(0.5, 0.45)
    stage.Size = UDim2.fromScale(0.42, 0.42)
    stage.BackgroundTransparency = 1
    stage.ZIndex = 4
    local stageAspect = Instance.new("UIAspectRatioConstraint")
    stageAspect.Parent = stage
    local stageScale = Instance.new("UIScale")
    stageScale.Scale = 0
    stageScale.Parent = stage
    stage.Parent = root

    local crateView, crateModel = GearView.Create({
        kind = "crate",
        id = result.crateId,
        size = UDim2.fromScale(1, 1),
        spin = false,
        parent = stage,
    })
    crateView.ZIndex = 4

    local skipButton = Components.Button({
        text = Strings.Crates.Skip,
        size = UDim2.fromScale(0.14, 0.07),
        position = UDim2.fromScale(0.83, 0.88),
        color = Components.Colors.PanelRaised,
        parent = root,
        onClick = function()
            skipped = true
        end,
    })
    skipButton.ZIndex = 8

    -- Estado final: el objeto, sus textos y los botones. Se llega aquí al terminar la
    -- secuencia o al saltarla.
    local function reveal(withFlourish: boolean)
        if revealed or current ~= root then
            return
        end
        revealed = true
        skipButton:Destroy()
        crateView:Destroy()
        stage.Position = UDim2.fromScale(0.5, 0.4)
        stageScale.Scale = if withFlourish then 0.2 else 1
        TweenService:Create(
            glow,
            TweenInfo.new(0.25),
            { Size = UDim2.fromScale(0.75, 0.75), BackgroundTransparency = 0.6 }
        ):Play()

        if withFlourish then
            local flash = Instance.new("Frame")
            flash.Size = UDim2.fromScale(1, 1)
            flash.BackgroundColor3 = WHITE:Lerp(color, 0.25)
            flash.BorderSizePixel = 0
            flash.ZIndex = 9
            flash.Parent = root
            local fade = TweenService:Create(
                flash,
                TweenInfo.new(0.5 + rarity.rank * 0.08),
                { BackgroundTransparency = 1 }
            )
            fade.Completed:Connect(function()
                flash:Destroy()
            end)
            fade:Play()
            sparks(root, color, tier.sparks)
            AudioManager.Play("CrateOpen")
            if tier.cinematic then
                Effects.Shake(0.5 + (rarity.rank - 5) * 0.4, 0.5)
            end
        end
        AudioManager.Play(tier.sound, { duck = tier.cinematic })
        if tier.rays > 0 and root:FindFirstChild("Rays") == nil then
            local holder = rays(root, color, tier.rays)
            for _, ray in holder:GetChildren() do
                if ray:IsA("Frame") then
                    ray.BackgroundTransparency = 0.5
                end
            end
        end

        local itemView = GearView.Create({
            kind = result.kind,
            id = result.id,
            size = UDim2.fromScale(1, 1),
            parent = stage,
        })
        itemView.ZIndex = 5
        if result.kind == "cosmetic" then
            itemView.AnchorPoint = Vector2.new(0.5, 0.5)
            itemView.Position = UDim2.fromScale(0.5, 0.5)
            itemView.Size = UDim2.fromScale(0.5, 0.5)
        end
        TweenService:Create(stageScale, OUT, { Scale = 1 }):Play()
        -- El objeto flota arriba y abajo.
        TweenService:Create(
            stage,
            TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Position = UDim2.fromScale(0.5, 0.385) }
        ):Play()

        local item = Equipment.ById[result.id]
        local lines: { string } = if item and result.kind ~= "cosmetic"
            then GearView.Stats(item)
            else {}
        local ability = if item and item.ability
            then Strings.Equipment.Abilities[item.ability]
            else nil
        if ability then
            table.insert(lines, `★ {ability.name}`)
        end

        local tag = Components.Label({
            text = if result.preview
                then Strings.Equipment.Preview
                elseif result.isNew then Strings.Equipment.New
                else string.format(Strings.Equipment.Duplicate, result.dust),
            size = UDim2.fromScale(0.5, 0.045),
            position = UDim2.fromScale(0.25, 0.63),
            color = if result.isNew then Components.Colors.Success else Components.Colors.Gold,
            heading = true,
            parent = root,
        })
        tag.ZIndex = 7
        local name = Components.Label({
            text = GearView.Name(result.kind, result.id),
            size = UDim2.fromScale(0.7, 0.075),
            position = UDim2.fromScale(0.15, 0.68),
            color = color,
            heading = true,
            parent = root,
        })
        name.ZIndex = 7
        local rarityLabel = Components.Label({
            text = `{string.upper(Strings.Equipment.Rarities[result.rarity] or result.rarity)} {string.upper(
                Strings.Equipment.KindNames[result.kind] or ""
            )}`,
            size = UDim2.fromScale(0.5, 0.04),
            position = UDim2.fromScale(0.25, 0.755),
            color = Components.Colors.Muted,
            parent = root,
        })
        rarityLabel.ZIndex = 7
        local stats = Components.Label({
            text = table.concat(lines, "   ·   "),
            size = UDim2.fromScale(0.8, 0.04),
            position = UDim2.fromScale(0.1, 0.8),
            parent = root,
        })
        stats.ZIndex = 7
        -- Los textos entran de uno en uno; el nombre de un Mítico, además, con rebote.
        for index, label in { tag, name, rarityLabel, stats } do
            label.TextTransparency = 1
            TweenService:Create(
                label,
                TweenInfo.new(
                    0.3,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out,
                    0,
                    false,
                    index * 0.08
                ),
                { TextTransparency = 0 }
            ):Play()
        end
        if rarity.rank >= 6 then
            local nameScale = Instance.new("UIScale")
            nameScale.Scale = 1.6
            nameScale.Parent = name
            TweenService:Create(
                nameScale,
                TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
                { Scale = 1 }
            ):Play()
        end

        local data = DataController.GetData()
        local remaining = if data then data.equipment.crates[result.crateId] or 0 else 0
        local canRepeat = remaining > 0 and not result.preview
        local closeButton = Components.Button({
            text = Strings.Crates.Close,
            size = UDim2.fromScale(0.18, 0.08),
            position = UDim2.fromScale(if canRepeat then 0.31 else 0.41, 0.87),
            color = Components.Colors.PanelRaised,
            parent = root,
            onClick = close,
        })
        closeButton.ZIndex = 8
        if canRepeat then
            local again = Components.Button({
                text = Strings.Crates.OpenAnother,
                size = UDim2.fromScale(0.18, 0.08),
                position = UDim2.fromScale(0.51, 0.87),
                color = Components.Colors.Success,
                parent = root,
                onClick = function()
                    Remotes.OpenCrate:FireServer(result.crateId)
                end,
            })
            again.ZIndex = 8
        end
        if string.sub(UserInputService:GetLastInputType().Name, 1, 7) == "Gamepad" then
            GuiService.SelectedObject = closeButton
        end
    end

    skipCurrent = function()
        skipped = true
    end

    task.spawn(function()
        -- 1 · La caja aparece en el centro.
        AudioManager.Play("CrateAppear")
        TweenService:Create(stageScale, OUT, { Scale = 1 }):Play()
        if not pause(0.4) then
            return reveal(false)
        end

        -- 2 · Respira.
        local breathing = TweenService:Create(
            stageScale,
            TweenInfo.new(
                tier.breathe / 2,
                Enum.EasingStyle.Sine,
                Enum.EasingDirection.InOut,
                -1,
                true
            ),
            { Scale = 1.06 }
        )
        breathing:Play()
        if not pause(tier.breathe) then
            breathing:Cancel()
            return reveal(false)
        end

        -- 3 · Acumula energía: el resplandor crece y, en las raras, aparecen los rayos.
        AudioManager.Play("CrateCharge")
        TweenService:Create(
            glow,
            TweenInfo.new(tier.charge, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Size = UDim2.fromScale(0.55, 0.55), BackgroundTransparency = 0.35 }
        ):Play()
        if tier.rays > 0 then
            local holder = rays(root, color, tier.rays)
            for _, ray in holder:GetChildren() do
                if ray:IsA("Frame") then
                    TweenService
                        :Create(ray, TweenInfo.new(tier.charge), { BackgroundTransparency = 0.5 })
                        :Play()
                end
            end
        end
        -- Las más raras oscurecen el resto de la pantalla.
        if tier.cinematic then
            TweenService:Create(root, TweenInfo.new(tier.charge), { BackgroundTransparency = 0.12 })
                :Play()
        end
        if not pause(tier.charge) then
            breathing:Cancel()
            return reveal(false)
        end
        breathing:Cancel()
        stageScale.Scale = 1

        -- 4 y 5 · Vibra cada vez más, soltando chispas del color de lo que viene dentro.
        AudioManager.Play("CrateShake")
        local started = os.clock()
        local random = Random.new()
        local shaking = RunService.RenderStepped:Connect(function()
            local strength = math.min((os.clock() - started) / tier.shake, 1) * 0.012
            stage.Position = UDim2.fromScale(
                0.5 + random:NextNumber(-strength, strength),
                0.45 + random:NextNumber(-strength, strength)
            )
            stage.Rotation = random:NextNumber(-strength, strength) * 300
        end)
        root.Destroying:Connect(function()
            shaking:Disconnect()
        end)
        sparks(root, color, math.ceil(tier.sparks / 3))
        local shook = pause(tier.shake)
        shaking:Disconnect()
        stage.Position = UDim2.fromScale(0.5, 0.45)
        stage.Rotation = 0
        if not shook then
            return reveal(false)
        end

        -- 6 · Se abre: la tapa sale hacia arriba.
        local lid = if crateModel then crateModel:FindFirstChild("Lid") else nil
        if lid and lid:IsA("BasePart") then
            TweenService
                :Create(lid, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    CFrame = lid.CFrame
                        * CFrame.new(0, 2.4, 0.6)
                        * CFrame.Angles(math.rad(-35), 0, 0),
                })
                :Play()
        end
        -- Un instante de silencio antes de un Mítico: lo justo para que se note.
        if not pause(if rarity.rank >= 6 then 0.55 else 0.22) then
            return reveal(false)
        end

        -- 7 a 10 · Destello, objeto y textos.
        reveal(true)
    end)
end

-- Salta la presentación que haya en pantalla (va directa al resultado).
function CrateOpening.Skip()
    local skip = skipCurrent
    if skip then
        skip()
    end
end

return CrateOpening
