--!strict

-- Colocar y quitar minerales de los pedestales de la base, y dibujarlos encima.
-- Un mineral colocado sigue en `inventory`; `pedestals` solo guarda en qué pedestal está.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local TutorialService = require(script.Parent.TutorialService)

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Util.Assets)
local Format = require(Shared.Util.Format)
local MapConfig = require(Shared.Config.Map)
local MineralVisual = require(Shared.Util.MineralVisual)
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)

local DISPLAY_SIZE = 2

type Display = {
    itemId: string,
    instance: Instance,
    label: TextLabel,
}

local PedestalService = {}

local displays: { [Player]: { [number]: Display } } = {}
local placeLimiter = RateLimiter.new(Network.RateLimits.PlaceMineral)
local removeLimiter = RateLimiter.new(Network.RateLimits.RemoveMineral)
local placeBestLimiter = RateLimiter.new(Network.RateLimits.PlaceBest)

local function clearDisplays(player: Player)
    local playerDisplays = displays[player]
    if playerDisplays == nil then
        return
    end
    for _, display in playerDisplays do
        display.instance:Destroy()
    end
    displays[player] = nil
end

local function createDisplay(plotPedestal: Instance, item: Types.InventoryItem): Display
    local visual = MineralVisual.Create(item.mineral, item.mutation, DISPLAY_SIZE)
    local pivot = if plotPedestal:IsA("PVInstance")
        then plotPedestal:GetPivot()
        else CFrame.identity
    Assets.PlaceAt(
        visual,
        pivot * CFrame.new(0, MapConfig.PedestalSize.Y / 2 + DISPLAY_SIZE / 2 + 0.3, 0)
    )

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.fromScale(5, 1.5)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, DISPLAY_SIZE + 0.5, 0)
    billboard.LightInfluence = 0
    billboard.MaxDistance = 80
    billboard.Parent = visual
    if visual:IsA("Model") then
        billboard.Adornee = visual.PrimaryPart
    end
    -- El cliente hace girar y flotar los minerales expuestos (DisplayController).
    visual:AddTag(MapConfig.SpinTag)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.3
    label.Parent = billboard

    return { itemId = item.id, instance = visual, label = label }
end

-- Sincroniza los pedestales visibles y los minerales dibujados con los datos del jugador.
local function refresh(player: Player)
    local data = DataService.GetData(player)
    local plot = PlotService.GetPlot(player)
    if data == nil or plot == nil then
        return
    end

    local unlocked = math.min(PlayerStats.GetPedestalCount(data), MapConfig.MaxPedestals)
    PlotService.SetUnlockedPedestals(player, unlocked)

    local playerDisplays = displays[player]
    if playerDisplays == nil then
        playerDisplays = {}
        displays[player] = playerDisplays
    end

    local multiplier = PlayerStats.GetIncomeMultiplier(data)
    for number = 1, MapConfig.MaxPedestals do
        local itemId = if number <= unlocked then data.pedestals[tostring(number)] else nil
        local item = if itemId then PlayerStats.FindItem(data, itemId) else nil
        local current: Display? = playerDisplays[number]

        if current and (item == nil or current.itemId ~= item.id) then
            current.instance:Destroy()
            playerDisplays[number] = nil
            current = nil
        end
        if item and current == nil then
            local display = createDisplay(plot.pedestals[number], item)
            display.instance.Parent = plot.pedestalFolder
            playerDisplays[number] = display
            current = display
        end
        if item and current then
            local income = PlayerStats.GetItemBaseIncome(item) * multiplier
            current.label.Text = string.format(Strings.Pedestal.PerSecond, Format.Number(income))
        end
    end
end

local function findFreePedestal(data: Types.Profile): number?
    local unlocked = math.min(PlayerStats.GetPedestalCount(data), MapConfig.MaxPedestals)
    for number = 1, unlocked do
        if data.pedestals[tostring(number)] == nil then
            return number
        end
    end
    return nil
end

local function onPlaceMineral(player: Player, itemId: unknown, pedestalNumber: unknown)
    if not placeLimiter.Check(player) then
        return
    end
    if type(itemId) ~= "string" or #itemId > 64 then
        return
    end
    if pedestalNumber ~= nil and (type(pedestalNumber) ~= "number" or pedestalNumber % 1 ~= 0) then
        return
    end
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    local item = PlayerStats.FindItem(data, itemId)
    if item == nil or PlayerStats.GetPedestalOf(data, itemId) ~= nil then
        return
    end

    local number: number? = pedestalNumber :: number?
    if number == nil then
        number = findFreePedestal(data)
        if number == nil then
            Remotes.Notify:FireClient(player, Strings.Pedestal.NoFreePedestal)
            return
        end
    end
    local unlocked = math.min(PlayerStats.GetPedestalCount(data), MapConfig.MaxPedestals)
    if number < 1 or number > unlocked or data.pedestals[tostring(number)] ~= nil then
        return
    end

    local key = tostring(number)
    DataService.Update(player, "pedestals", function(pedestals: { [string]: string })
        pedestals[key] = itemId
        return pedestals
    end)
    Remotes.Notify:FireClient(
        player,
        string.format(Strings.Pedestal.Placed, Strings.MineralName(item.mineral, item.mutation))
    )
    TutorialService.Advance(player, 3)
end

local function onRemoveMineral(player: Player, pedestalNumber: unknown)
    if not removeLimiter.Check(player) then
        return
    end
    if type(pedestalNumber) ~= "number" or pedestalNumber % 1 ~= 0 then
        return
    end
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    local key = tostring(pedestalNumber)
    local itemId = data.pedestals[key]
    if itemId == nil then
        return
    end
    local item = PlayerStats.FindItem(data, itemId)

    DataService.Update(player, "pedestals", function(pedestals: { [string]: string })
        pedestals[key] = nil
        return pedestals
    end)
    if item then
        Remotes.Notify:FireClient(
            player,
            string.format(
                Strings.Pedestal.Removed,
                Strings.MineralName(item.mineral, item.mutation)
            )
        )
    end
end

-- Recoloca todo: los minerales que más generan ocupan los pedestales disponibles.
local function onPlaceBest(player: Player)
    if not placeBestLimiter.Check(player) then
        return
    end
    local data = DataService.GetData(player)
    if data == nil or #data.inventory == 0 then
        return
    end

    local items = table.clone(data.inventory)
    table.sort(items, function(a: Types.InventoryItem, b: Types.InventoryItem): boolean
        return PlayerStats.GetItemBaseIncome(a) > PlayerStats.GetItemBaseIncome(b)
    end)
    local unlocked = math.min(PlayerStats.GetPedestalCount(data), MapConfig.MaxPedestals)
    local pedestals: { [string]: string } = {}
    for number = 1, math.min(unlocked, #items) do
        pedestals[tostring(number)] = items[number].id
    end

    DataService.Set(player, "pedestals", pedestals)
    Remotes.Notify:FireClient(player, Strings.Pedestal.PlacedBest)
    TutorialService.Advance(player, 3)
end

-- Quita de los pedestales los objetos que ya no están en el inventario (tras un intercambio, por ejemplo).
function PedestalService.CleanUp(player: Player)
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    local stale: { string } = {}
    for key, itemId in data.pedestals do
        if PlayerStats.FindItem(data, itemId) == nil then
            table.insert(stale, key)
        end
    end
    if #stale > 0 then
        DataService.Update(player, "pedestals", function(pedestals: { [string]: string })
            for _, key in stale do
                pedestals[key] = nil
            end
            return pedestals
        end)
    end
end

function PedestalService.Init()
    Remotes.PlaceMineral.OnServerEvent:Connect(onPlaceMineral)
    Remotes.RemoveMineral.OnServerEvent:Connect(onRemoveMineral)
    Remotes.PlaceBest.OnServerEvent:Connect(onPlaceBest)

    DataService.OnProfileLoaded(refresh)
    for _, key in { "pedestals", "inventory", "upgrades", "passes", "rebirths" } do
        DataService.OnFieldChanged(key, refresh)
    end
end

function PedestalService.Start()
    Players.PlayerRemoving:Connect(clearDisplays)
end

return PedestalService
