--!strict

-- Colocar y quitar minerales de los pedestales de la base, y dibujarlos encima.
-- Un mineral colocado sigue en `inventory`; `pedestals` solo guarda en qué pedestal está.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local TutorialService = require(script.Parent.TutorialService)

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Util.Log)
local Assets = require(Shared.Util.Assets)
local MapConfig = require(Shared.Config.Map)
local MineralVisual = require(Shared.Util.MineralVisual)
local Minerals = require(Shared.Config.Minerals)
local Mutations = require(Shared.Config.Mutations)
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)

local DISPLAY_SIZE = 2

type Display = {
    itemId: string,
    instance: Instance,
    -- Línea de ingresos del cartel.
    label: TextLabel?,
}

local PedestalService = {}

local displays: { [Player]: { [number]: Display } } = {}
local placeLimiter = RateLimiter.new(Network.RateLimits.PlaceMineral)
local removeLimiter = RateLimiter.new(Network.RateLimits.RemoveMineral)
local placeBestLimiter = RateLimiter.new(Network.RateLimits.PlaceBest)

local function destroyDisplay(display: Display)
    display.instance:Destroy()
end

local function clearDisplays(player: Player)
    local playerDisplays = displays[player]
    if playerDisplays == nil then
        return
    end
    for _, display in playerDisplays do
        destroyDisplay(display)
    end
    displays[player] = nil
end

-- Mineral expuesto: más grande cuanto más raro y con mejor mutación, con su cartel apilado
-- (mutación, nombre, rareza e ingresos).
local function createDisplay(plotPedestal: Instance, item: Types.InventoryItem): Display
    local size = DISPLAY_SIZE * MineralVisual.GetDisplayScale(item.mineral, item.mutation)
    local visual = MineralVisual.Create(item.mineral, item.mutation, size)
    local pivot = if plotPedestal:IsA("PVInstance")
        then plotPedestal:GetPivot()
        else CFrame.identity
    local cframe = pivot * CFrame.new(0, MapConfig.PedestalSize.Y / 2 + size / 2 + 0.3, 0)
    Assets.PlaceAt(visual, cframe)

    local label = MineralVisual.AddSign(visual, item.mineral, item.mutation, size, true)
    -- El cliente hace girar y flotar los minerales expuestos (DisplayController).
    visual:AddTag(MapConfig.SpinTag)

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

    -- Sin boosts temporales: estos carteles no se repintan cuando un boost se acaba.
    local multiplier = PlayerStats.GetIncomeMultiplier(data, math.huge)
    -- Lo más raro que hay expuesto: da "presencia" a la base (BaseController tiñe su baliza).
    local prestige = 0
    local prestigeMutation: string? = nil
    for number = 1, MapConfig.MaxPedestals do
        local itemId = if number <= unlocked then data.pedestals[tostring(number)] else nil
        local item = if itemId then PlayerStats.FindItem(data, itemId) else nil
        local current: Display? = playerDisplays[number]

        if current and (item == nil or current.itemId ~= item.id) then
            destroyDisplay(current)
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
            if current.label then
                Locale.Tag(
                    current.label,
                    "Text",
                    Locale.Msg("Pedestal.PerSecond", Locale.Num(income))
                )
            end
            local rank = Minerals.GetRank(item.mineral)
            if rank > prestige then
                prestige = rank
                prestigeMutation = if item.mutation ~= Mutations.NoneId then item.mutation else nil
            end
        end
    end
    plot.model:SetAttribute("Prestige", prestige)
    plot.model:SetAttribute("PrestigeMutation", prestigeMutation)
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
        Log.Suspicious(player, "PlaceMineral", "tipo inválido")
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
            Remotes.Notify:FireClient(player, Locale.Msg("Pedestal.NoFreePedestal"))
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
        Locale.Msg("Pedestal.Placed", Locale.Mineral(item.mineral, item.mutation))
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
            Locale.Msg("Pedestal.Removed", Locale.Mineral(item.mineral, item.mutation))
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
    Remotes.Notify:FireClient(player, Locale.Msg("Pedestal.PlacedBest"))
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
