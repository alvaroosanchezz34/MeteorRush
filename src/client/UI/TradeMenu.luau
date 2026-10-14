--!strict

-- Intercambio. Sin intercambio activo muestra las solicitudes recibidas y la lista de jugadores.
-- Con intercambio activo muestra las dos ofertas, tus minerales para añadir o quitar,
-- y los botones de confirmar y cancelar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared:WaitForChild("Config"):WaitForChild("Equipment"))
local Minerals = require(Shared:WaitForChild("Config"):WaitForChild("Minerals"))
local PlayerStats = require(Shared:WaitForChild("Util"):WaitForChild("PlayerStats"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local TradeConfig = require(Shared:WaitForChild("Config"):WaitForChild("Trade"))
local Types = require(Shared:WaitForChild("Types"))

type TradeState = {
    partner: Player,
    myOffer: { Types.InventoryItem },
    theirOffer: { Types.InventoryItem },
    myConfirmed: boolean,
    theirConfirmed: boolean,
    countdownEndsAt: number?,
}

local TradeMenu = {}

-- Prefijo de los picos y armas en una oferta (el mismo que usa TradeService).
local GEAR_PREFIX = "gear:"

local function itemName(item: Types.InventoryItem): string
    local gear = item.gear
    if gear then
        return `⚒ {Strings.Equipment.Names[gear] or gear}`
    end
    return Strings.MineralName(item.mineral, item.mutation)
end

local function itemColor(item: Types.InventoryItem): Color3
    local gear = if item.gear then Equipment.ById[item.gear] else nil
    if gear then
        return Equipment.Rarities[gear.rarity].color
    end
    local mineral = Minerals.ById[item.mineral]
    return if mineral then Minerals.Rarities[mineral.rarity].color else Components.Colors.Text
end

function TradeMenu.Mount(window: Components.Window)
    local state: TradeState? = nil
    local incoming: { Player } = {}
    local root = window.content

    local function itemList(
        parent: Instance,
        items: { Types.InventoryItem },
        onClick: ((item: Types.InventoryItem) -> ())?
    )
        for order, item in items do
            Components.Button({
                text = itemName(item),
                size = UDim2.new(),
                color = Components.Colors.Panel,
                layoutOrder = order,
                parent = parent,
                onClick = if onClick
                    then function()
                        onClick(item)
                    end
                    else nil,
            }).TextColor3 =
                itemColor(item)
        end
    end

    local function renderIdle()
        local list = Components.ScrollList({
            size = UDim2.fromScale(1, 1),
            cellSize = UDim2.fromScale(0.98, 0.14),
            parent = root,
        })
        local order = 0
        for _, requester in incoming do
            if requester.Parent == Players then
                order += 1
                local row =
                    Components.Panel({ size = UDim2.new(), layoutOrder = order, parent = list })
                Components.Label({
                    text = string.format(Strings.Trade.Incoming, requester.DisplayName),
                    size = UDim2.fromScale(0.5, 0.8),
                    position = UDim2.fromScale(0.03, 0.1),
                    alignment = Enum.TextXAlignment.Left,
                    color = Components.Colors.Gold,
                    parent = row,
                })
                Components.Button({
                    text = Strings.Trade.Accept,
                    size = UDim2.fromScale(0.2, 0.7),
                    position = UDim2.fromScale(0.55, 0.15),
                    color = Components.Colors.Success,
                    parent = row,
                    onClick = function()
                        Remotes.TradeRespond:FireServer(requester, true)
                    end,
                })
                Components.Button({
                    text = Strings.Trade.Decline,
                    size = UDim2.fromScale(0.2, 0.7),
                    position = UDim2.fromScale(0.77, 0.15),
                    color = Components.Colors.Danger,
                    parent = row,
                    onClick = function()
                        local index = table.find(incoming, requester)
                        if index then
                            table.remove(incoming, index)
                        end
                        Remotes.TradeRespond:FireServer(requester, false)
                    end,
                })
            end
        end

        local others = 0
        for _, player in Players:GetPlayers() do
            if player ~= Players.LocalPlayer then
                others += 1
                order += 1
                local row =
                    Components.Panel({ size = UDim2.new(), layoutOrder = order, parent = list })
                Components.Label({
                    text = player.DisplayName,
                    size = UDim2.fromScale(0.6, 0.8),
                    position = UDim2.fromScale(0.03, 0.1),
                    alignment = Enum.TextXAlignment.Left,
                    parent = row,
                })
                Components.Button({
                    text = Strings.Trade.Request,
                    size = UDim2.fromScale(0.25, 0.7),
                    position = UDim2.fromScale(0.72, 0.15),
                    parent = row,
                    onClick = function()
                        Remotes.TradeRequest:FireServer(player)
                    end,
                })
            end
        end
        if others == 0 then
            Components.Label({
                text = Strings.Trade.NoPlayers,
                size = UDim2.new(),
                color = Components.Colors.Muted,
                layoutOrder = order + 1,
                parent = list,
            })
        end
    end

    local function renderTrade(current: TradeState)
        Components.Label({
            text = Strings.Trade.YourOffer .. (if current.myConfirmed then " ✓" else ""),
            size = UDim2.fromScale(0.48, 0.06),
            alignment = Enum.TextXAlignment.Left,
            parent = root,
        })
        Components.Label({
            text = string.format(Strings.Trade.TheirOffer, current.partner.DisplayName)
                .. (if current.theirConfirmed then " ✓" else ""),
            size = UDim2.fromScale(0.48, 0.06),
            position = UDim2.fromScale(0.52, 0),
            alignment = Enum.TextXAlignment.Left,
            parent = root,
        })

        local myOfferIds: { string } = {}
        for _, item in current.myOffer do
            table.insert(myOfferIds, item.id)
        end
        local function toggle(item: Types.InventoryItem)
            local ids = table.clone(myOfferIds)
            local index = table.find(ids, item.id)
            if index then
                table.remove(ids, index)
            else
                table.insert(ids, item.id)
            end
            Remotes.TradeUpdateOffer:FireServer(ids)
        end

        local mine = Components.ScrollList({
            size = UDim2.fromScale(0.48, 0.34),
            position = UDim2.fromScale(0, 0.07),
            cellSize = UDim2.fromScale(0.96, 0.2),
            parent = root,
        })
        itemList(mine, current.myOffer, toggle)
        local theirs = Components.ScrollList({
            size = UDim2.fromScale(0.48, 0.34),
            position = UDim2.fromScale(0.52, 0.07),
            cellSize = UDim2.fromScale(0.96, 0.2),
            parent = root,
        })
        itemList(theirs, current.theirOffer, nil)

        Components.Label({
            text = Strings.Trade.YourItems,
            size = UDim2.fromScale(1, 0.05),
            position = UDim2.fromScale(0, 0.43),
            alignment = Enum.TextXAlignment.Left,
            color = Components.Colors.Muted,
            parent = root,
        })
        local available: { Types.InventoryItem } = {}
        local data = DataController.GetData()
        if data then
            for _, item in data.inventory do
                if
                    PlayerStats.GetPedestalOf(data, item.id) == nil
                    and not table.find(myOfferIds, item.id)
                then
                    table.insert(available, item)
                end
            end
            -- Picos y armas que se pueden ofrecer: los que no lleva puestos ni son iniciales
            -- y que el otro jugador puede recibir lo decide el servidor al añadirlos.
            for _, gear in Equipment.List do
                local id = GEAR_PREFIX .. gear.id
                if
                    Equipment.Owns(data, gear.id)
                    and Equipment.IsTradeable(gear)
                    and Equipment.GetEquipped(data, gear.kind).id ~= gear.id
                    and not table.find(myOfferIds, id)
                then
                    table.insert(
                        available,
                        { id = id, mineral = "", mutation = "", gear = gear.id }
                    )
                end
            end
        end
        local inventory = Components.ScrollList({
            size = UDim2.fromScale(1, 0.32),
            position = UDim2.fromScale(0, 0.49),
            cellSize = UDim2.fromScale(0.32, 0.2),
            parent = root,
        })
        itemList(inventory, available, toggle)

        local countdown = Components.Label({
            text = "",
            size = UDim2.fromScale(0.3, 0.1),
            position = UDim2.fromScale(0.35, 0.86),
            color = Components.Colors.Gold,
            parent = root,
        })
        local endsAt = current.countdownEndsAt
        if endsAt then
            task.spawn(function()
                while countdown.Parent and state == current do
                    local remaining = math.max(math.ceil(endsAt - Workspace:GetServerTimeNow()), 0)
                    countdown.Text = string.format(Strings.Trade.Countdown, remaining)
                    task.wait(0.2)
                end
            end)
        end

        Components.Button({
            text = if current.myConfirmed then Strings.Trade.Confirmed else Strings.Trade.Confirm,
            size = UDim2.fromScale(0.3, 0.1),
            position = UDim2.fromScale(0.02, 0.86),
            color = if current.myConfirmed
                then Components.Colors.Disabled
                else Components.Colors.Success,
            parent = root,
            onClick = function()
                Remotes.TradeConfirm:FireServer()
            end,
        })
        Components.Button({
            text = Strings.Trade.Cancel,
            size = UDim2.fromScale(0.3, 0.1),
            position = UDim2.fromScale(0.68, 0.86),
            color = Components.Colors.Danger,
            parent = root,
            onClick = function()
                Remotes.TradeCancel:FireServer()
            end,
        })
    end

    local function refresh()
        if not window.IsOpen() then
            return
        end
        root:ClearAllChildren()
        local current = state
        if current then
            renderTrade(current)
        elseif
            TradeConfig.PolicyBlocksAllTrading
            and Players.LocalPlayer:GetAttribute("TradingAllowed") == false
        then
            -- El servidor lo bloquea igualmente; esto solo explica por qué.
            Components.Label({
                text = Strings.Trade.Restricted,
                size = UDim2.fromScale(0.9, 0.2),
                position = UDim2.fromScale(0.05, 0.35),
                color = Components.Colors.Muted,
                parent = root,
            })
        else
            renderIdle()
        end
    end

    Remotes.TradeState.OnClientEvent:Connect(function(kind: any, ...: any)
        if kind == "request" then
            local requester = ...
            if typeof(requester) == "Instance" and requester:IsA("Player") then
                if not table.find(incoming, requester) then
                    table.insert(incoming, requester)
                end
            end
        elseif kind == "open" then
            local partner, myOffer, theirOffer, myConfirmed, theirConfirmed, countdownEndsAt = ...
            if
                typeof(partner) ~= "Instance"
                or not partner:IsA("Player")
                or type(myOffer) ~= "table"
                or type(theirOffer) ~= "table"
            then
                return
            end
            local partnerPlayer = partner :: Player
            state = {
                partner = partnerPlayer,
                myOffer = myOffer,
                theirOffer = theirOffer,
                myConfirmed = myConfirmed == true,
                theirConfirmed = theirConfirmed == true,
                countdownEndsAt = if type(countdownEndsAt) == "number"
                    then countdownEndsAt
                    else nil,
            }
            local index = table.find(incoming, partnerPlayer)
            if index then
                table.remove(incoming, index)
            end
            if not window.IsOpen() then
                window.Open()
                return
            end
        elseif kind == "closed" then
            state = nil
        end
        refresh()
    end)

    window.OnOpened(refresh)
    DataController.OnChanged("inventory", refresh)
    DataController.OnChanged("equipment", refresh)
    Players.LocalPlayer:GetAttributeChangedSignal("TradingAllowed"):Connect(refresh)
    Players.PlayerAdded:Connect(refresh)
    Players.PlayerRemoving:Connect(function(player: Player)
        local index = table.find(incoming, player)
        if index then
            table.remove(incoming, index)
        end
        refresh()
    end)
end

return TradeMenu
