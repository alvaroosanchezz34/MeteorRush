--!strict

-- Personalización de la base: coloca las decoraciones elegidas en sus huecos, el efecto de
-- partículas y luz, y el panel de exposición de la colección en el muro del fondo.
-- Todo es estético y sin colisión. Se reconstruye entero cada vez que cambia algo, que es
-- poco a menudo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Kit = require(script.Parent.Parent.Builders.Kit)

local Shared = ReplicatedStorage.Shared
local AchievementsConfig = require(Shared.Config.Achievements)
local DecorConfig = require(Shared.Config.Decor)
local IndexConfig = require(Shared.Config.Index)
local Log = require(Shared.Util.Log)
local MapConfig = require(Shared.Config.Map)
local Minerals = require(Shared.Config.Minerals)
local Mutations = require(Shared.Config.Mutations)
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)

-- Campos del perfil que cambian lo que se ve en la base.
local FIELDS = { "decor", "index", "rebirths", "achievements" }
local BOARD_COLOR = Color3.fromRGB(24, 24, 34)
local UNDISCOVERED_COLOR = Color3.fromRGB(50, 50, 64)

local DecorService = {}

local decorationLimiter = RateLimiter.new(Network.RateLimits.SetDecoration)
local effectLimiter = RateLimiter.new(Network.RateLimits.SetBaseEffect)
local folders: { [Player]: Folder } = {}

local function buildDecoration(
    decoration: DecorConfig.Decoration,
    cframe: CFrame,
    slot: number,
    parent: Instance
)
    local rng = Random.new(slot)
    if decoration.kind == "crystal" then
        Kit.CrystalCluster({
            cframe = cframe,
            height = decoration.size,
            count = 4,
            color = decoration.color,
            rockColor = MapConfig.PlotTrimColor,
            rng = rng,
            parent = parent,
        })
    elseif decoration.kind == "lamp" then
        Kit.Lamp({
            cframe = cframe,
            height = decoration.size,
            color = decoration.color,
            postColor = MapConfig.PlotTrimColor,
            lit = false,
            parent = parent,
        })
    elseif decoration.kind == "rock" then
        Kit.Rock({
            cframe = cframe,
            size = decoration.size,
            color = decoration.color,
            rng = rng,
            parent = parent,
        })
    else
        -- Trofeo: peana, columna y una esfera brillante.
        local height = decoration.size
        Kit.Part({
            name = "TrophyBase",
            size = Vector3.new(2.6, 0.6, 2.6),
            cframe = cframe * CFrame.new(0, 0.3, 0),
            color = MapConfig.PlotTrimColor,
            material = Enum.Material.Metal,
            parent = parent,
        })
        Kit.Part({
            name = "TrophyColumn",
            size = Vector3.new(0.9, height - 2.2, 0.9),
            cframe = cframe * CFrame.new(0, 0.6 + (height - 2.2) / 2, 0),
            color = decoration.color,
            material = Enum.Material.Metal,
            parent = parent,
        })
        Kit.Part({
            name = "TrophyOrb",
            size = Vector3.one * 1.8,
            cframe = cframe * CFrame.new(0, height - 0.9, 0),
            color = decoration.color,
            material = Enum.Material.Neon,
            shape = Enum.PartType.Ball,
            parent = parent,
        })
    end
end

local function buildEffect(effect: DecorConfig.Effect, plotCFrame: CFrame, parent: Instance)
    local size = MapConfig.PlotSize - 8
    local holder = Kit.Part({
        name = "BaseEffect",
        size = Vector3.new(size, 0.5, size),
        cframe = plotCFrame * CFrame.new(0, 0.5, 0),
        color = effect.colors[1],
        transparency = 1,
        castShadow = false,
        parent = parent,
    })

    local keypoints: { ColorSequenceKeypoint } = {}
    for index, color in effect.colors do
        local time = if #effect.colors == 1 then 0 else (index - 1) / (#effect.colors - 1)
        table.insert(keypoints, ColorSequenceKeypoint.new(time, color))
    end
    if #keypoints == 1 then
        table.insert(keypoints, ColorSequenceKeypoint.new(1, effect.colors[1]))
    end

    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(keypoints)
    emitter.Size = NumberSequence.new(0.35, 0)
    emitter.Transparency = NumberSequence.new(0.2, 1)
    emitter.Lifetime = NumberRange.new(4, 7)
    emitter.Speed = NumberRange.new(1, 2.5)
    emitter.EmissionDirection = Enum.NormalId.Top
    emitter.SpreadAngle = Vector2.new(15, 15)
    emitter.LightEmission = 1
    emitter.Rate = DecorConfig.EffectRate
    emitter.Parent = holder

    local attachment = Instance.new("Attachment")
    attachment.Position = Vector3.new(0, 6, 0)
    attachment.Parent = holder
    Kit.Light(attachment, effect.colors[1], DecorConfig.EffectLightRange, 1)
end

-- Panel con las 32 combinaciones del índice (una columna por mineral, una fila por mutación),
-- iluminadas las descubiertas, para que cualquiera que visite la base vea la colección.
local function buildBoard(player: Player, data: Types.Profile, plotCFrame: CFrame, parent: Instance)
    local board = Kit.Part({
        name = "CollectionBoard",
        size = DecorConfig.BoardSize,
        cframe = plotCFrame * CFrame.new(DecorConfig.BoardOffset),
        color = BOARD_COLOR,
        castShadow = false,
        parent = parent,
    })
    -- Marco luminoso alrededor del panel.
    Kit.Part({
        name = "CollectionBoardFrame",
        size = DecorConfig.BoardSize + Vector3.new(0.6, 0.6, -0.1),
        cframe = plotCFrame * CFrame.new(DecorConfig.BoardOffset + Vector3.new(0, 0, 0.12)),
        color = MapConfig.PlotAccentColor,
        material = Enum.Material.Neon,
        castShadow = false,
        parent = parent,
    })

    local gui = Instance.new("SurfaceGui")
    -- Los textos ya salen en el idioma elegido: sin traducción automática de Roblox.
    gui.AutoLocalize = false
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 30
    gui.LightInfluence = 0
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = board

    local background = Instance.new("Frame")
    background.Size = UDim2.fromScale(1, 1)
    background.BackgroundColor3 = BOARD_COLOR
    background.BorderSizePixel = 0
    background.Parent = gui
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.6, 0.6, 0.8))
    gradient.Parent = background

    local function label(text: Locale.Message, size: UDim2, position: UDim2, color: Color3)
        local instance = Instance.new("TextLabel")
        instance.Size = size
        instance.Position = position
        instance.BackgroundTransparency = 1
        -- Cada jugador lo lee en su idioma.
        Locale.Tag(instance, "Text", text)
        instance.TextColor3 = color
        instance.TextScaled = true
        instance.Font = Enum.Font.GothamBold
        instance.TextStrokeTransparency = 0.5
        instance.ZIndex = 2
        instance.Parent = gui
    end

    local grid = Instance.new("Frame")
    grid.BackgroundTransparency = 1
    grid.Size = UDim2.fromScale(0.94, 0.56)
    grid.Position = UDim2.fromScale(0.03, 0.24)
    grid.ZIndex = 2
    grid.Parent = gui
    local layout = Instance.new("UIGridLayout")
    layout.CellSize = UDim2.fromScale(1 / #Minerals.List - 0.01, 1 / #Mutations.List - 0.03)
    layout.CellPadding = UDim2.fromScale(0.01, 0.03)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = grid

    local discovered = 0
    local order = 0
    for _, mutation in Mutations.List do
        for _, mineral in Minerals.List do
            order += 1
            local found = data.index[IndexConfig.Key(mineral.id, mutation.id)] == true
            if found then
                discovered += 1
            end
            local cell = Instance.new("Frame")
            cell.LayoutOrder = order
            cell.BorderSizePixel = 0
            cell.BackgroundColor3 = if found
                then mutation.color or mineral.color
                else UNDISCOVERED_COLOR
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.25, 0)
            corner.Parent = cell
            cell.Parent = grid
        end
    end

    local unlocked = 0
    for _ in data.achievements do
        unlocked += 1
    end
    label(
        Locale.Msg(
            "Decor.BoardTitle",
            player.DisplayName,
            discovered,
            #Minerals.List * #Mutations.List
        ),
        UDim2.fromScale(0.94, 0.18),
        UDim2.fromScale(0.03, 0.03),
        Color3.new(1, 1, 1)
    )
    label(
        Locale.Msg("Decor.BoardFooter", data.rebirths, unlocked, #AchievementsConfig.List),
        UDim2.fromScale(0.94, 0.13),
        UDim2.fromScale(0.03, 0.84),
        Color3.fromRGB(255, 200, 60)
    )
end

local function clear(player: Player)
    local folder = folders[player]
    if folder then
        folder:Destroy()
        folders[player] = nil
    end
end

-- Reconstruye todo lo personalizable de la base del jugador.
local function refresh(player: Player)
    clear(player)
    local data = DataService.GetData(player)
    local plot = PlotService.GetPlot(player)
    if data == nil or plot == nil then
        return
    end
    local folder = Instance.new("Folder")
    folder.Name = "Decor"
    folders[player] = folder

    for slot, position in DecorConfig.Slots do
        local decoration = DecorConfig.DecorationsById[data.decor.slots[tostring(slot)]]
        if decoration and PlayerStats.IsUnlocked(data, decoration.unlock) then
            -- Girada hacia el interior de la parcela.
            local cframe = plot.cframe
                * CFrame.new(position)
                * CFrame.Angles(0, if position.X < 0 then -math.pi / 2 else math.pi / 2, 0)
            buildDecoration(decoration, cframe, slot, folder)
        end
    end
    local effect = DecorConfig.EffectsById[data.decor.effect]
    if effect and PlayerStats.IsUnlocked(data, effect.unlock) then
        buildEffect(effect, plot.cframe, folder)
    end
    buildBoard(player, data, plot.cframe, folder)

    -- Nada de esto estorba: sin colisión y sin contar para raycasts ni toques.
    for _, descendant in folder:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.CanCollide = false
            descendant.CanQuery = false
            descendant.CanTouch = false
        end
    end
    folder.Parent = plot.model
end

local function onSetDecoration(player: Player, slot: unknown, decorationId: unknown)
    if not decorationLimiter.Check(player) then
        return
    end
    if
        type(slot) ~= "number"
        or slot % 1 ~= 0
        or slot < 1
        or slot > #DecorConfig.Slots
        or type(decorationId) ~= "string"
        or #decorationId > 32
    then
        Log.Suspicious(player, "SetDecoration", "tipo inválido")
        return
    end
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    -- La cadena vacía deja el hueco libre.
    local value: string? = nil
    if decorationId ~= "" then
        local decoration = DecorConfig.DecorationsById[decorationId]
        if decoration == nil or not PlayerStats.IsUnlocked(data, decoration.unlock) then
            return
        end
        value = decorationId
    end
    DataService.Update(player, "decor", function(decor: Types.DecorData)
        decor.slots[tostring(slot)] = value
        return decor
    end)
end

local function onSetBaseEffect(player: Player, effectId: unknown)
    if not effectLimiter.Check(player) then
        return
    end
    if type(effectId) ~= "string" or #effectId > 32 then
        Log.Suspicious(player, "SetBaseEffect", "tipo inválido")
        return
    end
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    if effectId ~= "" then
        local effect = DecorConfig.EffectsById[effectId]
        if effect == nil or not PlayerStats.IsUnlocked(data, effect.unlock) then
            return
        end
    end
    DataService.Update(player, "decor", function(decor: Types.DecorData)
        decor.effect = effectId
        return decor
    end)
end

function DecorService.Init()
    Remotes.SetDecoration.OnServerEvent:Connect(onSetDecoration)
    Remotes.SetBaseEffect.OnServerEvent:Connect(onSetBaseEffect)
    DataService.OnProfileLoaded(refresh)
    for _, field in FIELDS do
        DataService.OnFieldChanged(field, refresh)
    end
end

function DecorService.Start()
    Players.PlayerRemoving:Connect(clear)
end

return DecorService
