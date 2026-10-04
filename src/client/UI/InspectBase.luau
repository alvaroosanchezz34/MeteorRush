--!strict

-- Ventana "🏠 INSPECT BASE": el perfil visible del dueño de una base (título, rebirths,
-- índice, mejor mineral, pedestales, decoración, visitas y likes), con el botón de dar like
-- y el de visitarla. Se abre desde el cartel de una base o desde la lista de jugadores.
-- Lo que muestra sale de atributos del jugador que publica el servidor; el like lo valida
-- el servidor.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local RarityStyle = require(script.Parent.RarityStyle)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Minerals = require(Config:WaitForChild("Minerals"))
local Mutations = require(Config:WaitForChild("Mutations"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local PROMPT_NAME = "InspectBase"
local LIKE_COLOR = Color3.fromRGB(235, 80, 110)
-- Filas de la ventana, en orden.
local ROWS = { "title", "rebirths", "index", "best", "pedestals", "decor", "visits", "likes" }

local InspectBase = {}

local gui: ScreenGui? = nil
local panel: Frame
local nameLabel: TextLabel
local valueLabels: { [string]: TextLabel } = {}
local likeButton: TextButton
local visitButton: TextButton
local target: Player? = nil

local function numberAttribute(player: Player, name: string): number
    local value = player:GetAttribute(name)
    return if type(value) == "number" then value else 0
end

local function refresh()
    local player = target
    if player == nil or player.Parent ~= Players then
        panel.Visible = false
        target = nil
        return
    end
    local isOwn = player == Players.LocalPlayer
    nameLabel.Text = string.format(Strings.Inspect.Owner, player.DisplayName)

    local title = player:GetAttribute("Title")
    valueLabels.title.Text = if type(title) == "string" then title else Strings.Profile.NoTitle
    valueLabels.rebirths.Text = Format.Number(numberAttribute(player, "Rebirths"))
    valueLabels.index.Text = string.format(
        Strings.Quests.Progress,
        numberAttribute(player, "IndexCount"),
        #Minerals.List * #Mutations.List
    )

    -- Mejor mineral: "mineral:mutación", con el color de su mutación o de su rareza.
    local best = player:GetAttribute("BestMineral")
    local mineralId, mutationId = "", ""
    if type(best) == "string" then
        mineralId, mutationId = string.match(best, "^(.-):(.*)$")
    end
    local mineral = Minerals.ById[mineralId]
    local mutation = Mutations.ById[mutationId]
    if mineral then
        valueLabels.best.Text = RarityStyle.Text(mineralId, mutationId)
        valueLabels.best.TextColor3 = (if mutation then mutation.color else nil)
            or Minerals.Rarities[mineral.rarity].color
    else
        valueLabels.best.Text = Strings.Inspect.NoMineral
        valueLabels.best.TextColor3 = Components.Colors.Muted
    end

    valueLabels.pedestals.Text = string.format(
        Strings.Quests.Progress,
        numberAttribute(player, "PedestalsUsed"),
        numberAttribute(player, "PedestalCount")
    )
    local effect = player:GetAttribute("BaseEffect")
    local effectName = if type(effect) == "string" then Strings.Decor.EffectNames[effect] else nil
    valueLabels.decor.Text = if effectName
        then string.format(
            Strings.Inspect.DecorEffect,
            numberAttribute(player, "DecorCount"),
            effectName
        )
        else string.format(Strings.Inspect.Decor, numberAttribute(player, "DecorCount"))
    valueLabels.visits.Text = Format.Number(numberAttribute(player, "BaseVisits"))
    valueLabels.likes.Text = Format.Number(numberAttribute(player, "BaseLikes"))

    -- A la propia base no se le puede dar like ni hace falta visitarla.
    local data = DataController.GetData()
    local liked = data ~= nil and data.social.liked[tostring(player.UserId)] == true
    likeButton.Visible = not isOwn
    visitButton.Visible = not isOwn
    likeButton.Text = if liked then Strings.Inspect.Liked else Strings.Inspect.Like
    likeButton.BackgroundColor3 = if liked then Components.Colors.Disabled else LIKE_COLOR
end

-- Abre la ventana con la base de ese jugador.
function InspectBase.Open(player: Player)
    if gui == nil then
        return
    end
    target = player
    panel.Visible = true
    refresh()
    -- Se mantiene al día mientras está abierta (visitas y likes cambian en directo).
    task.spawn(function()
        while panel.Visible and target == player do
            task.wait(1)
            if panel.Visible and target == player then
                refresh()
            end
        end
    end)
end

function InspectBase.Mount()
    local screen = Instance.new("ScreenGui")
    screen.Name = "InspectBase"
    screen.ResetOnSpawn = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.DisplayOrder = 6
    gui = screen

    panel = Components.Panel({
        size = UDim2.fromScale(0.36, 0.6),
        position = UDim2.fromScale(0.5, 0.5),
        color = Components.Colors.Background,
        parent = screen,
    })
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Visible = false

    Components.Label({
        text = Strings.Inspect.Title,
        size = UDim2.fromScale(0.78, 0.09),
        position = UDim2.fromScale(0.04, 0.03),
        alignment = Enum.TextXAlignment.Left,
        color = Components.Colors.Gold,
        parent = panel,
    })
    local close = Components.Button({
        text = Strings.Hud.Close,
        size = UDim2.fromScale(0.1, 0.09),
        position = UDim2.fromScale(0.86, 0.03),
        color = Components.Colors.Danger,
        parent = panel,
        onClick = function()
            panel.Visible = false
            target = nil
        end,
    })
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1
    aspect.Parent = close

    nameLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.92, 0.09),
        position = UDim2.fromScale(0.04, 0.13),
        alignment = Enum.TextXAlignment.Left,
        parent = panel,
    })

    local rowHeight = 0.52 / #ROWS
    for index, key in ROWS do
        local y = 0.24 + (index - 1) * rowHeight
        Components.Label({
            text = Strings.Inspect.Rows[key] or key,
            size = UDim2.fromScale(0.42, rowHeight * 0.8),
            position = UDim2.fromScale(0.04, y),
            alignment = Enum.TextXAlignment.Left,
            color = Components.Colors.Muted,
            parent = panel,
        })
        valueLabels[key] = Components.Label({
            text = "",
            size = UDim2.fromScale(0.48, rowHeight * 0.8),
            position = UDim2.fromScale(0.48, y),
            alignment = Enum.TextXAlignment.Right,
            parent = panel,
        })
    end

    likeButton = Components.Button({
        text = Strings.Inspect.Like,
        size = UDim2.fromScale(0.44, 0.13),
        position = UDim2.fromScale(0.04, 0.82),
        color = LIKE_COLOR,
        parent = panel,
        onClick = function()
            local player = target
            if player then
                Remotes.LikeBase:FireServer(player)
            end
        end,
    })
    visitButton = Components.Button({
        text = Strings.Visit.Button,
        size = UDim2.fromScale(0.44, 0.13),
        position = UDim2.fromScale(0.52, 0.82),
        color = Components.Colors.Success,
        parent = panel,
        onClick = function()
            local player = target
            if player then
                Remotes.VisitBase:FireServer(player)
                panel.Visible = false
                target = nil
            end
        end,
    })

    -- El like llega por los datos propios: la ventana se actualiza en cuanto se confirma.
    DataController.OnChanged("social", function()
        if panel.Visible then
            refresh()
        end
    end)

    -- Opción de proximidad en el cartel de cada base: abre la ventana de su dueño.
    ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
        if prompt.Name ~= PROMPT_NAME then
            return
        end
        local plot = prompt:FindFirstAncestorWhichIsA("Model")
        while plot and plot:GetAttribute("PlotIndex") == nil do
            plot = plot:FindFirstAncestorWhichIsA("Model")
        end
        local ownerId = if plot then plot:GetAttribute("OwnerUserId") else nil
        local owner = if type(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
        if owner then
            InspectBase.Open(owner)
        end
    end)

    screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return InspectBase
