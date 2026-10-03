--!strict

-- Intercambio de minerales del inventario de la base entre dos jugadores del mismo servidor.
-- Flujo: solicitud -> aceptar -> ofertas -> doble confirmación -> cuenta atrás de 5 s -> ejecución.
-- Cambiar una oferta quita las confirmaciones y reinicia la cuenta atrás.
-- La ejecución vuelve a validar todo y aplica los dos lados sin ceder el hilo: o ambos o ninguno.
--
-- Estado enviado al cliente por TradeState:
--   ("request", deJugador)                       solicitud recibida
--   ("open", partner, miOferta, suOferta, yoConfirmé, élConfirmó, finCuentaAtrás?)
--   ("closed")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)

local Shared = ReplicatedStorage.Shared
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local TradeConfig = require(Shared.Config.Trade)
local Types = require(Shared.Types)

type Trade = {
    a: Player,
    b: Player,
    offers: { [Player]: { string } },
    confirmed: { [Player]: boolean },
    -- Cambia cada vez que se modifica el intercambio; invalida cuentas atrás antiguas.
    version: number,
    countdownEndsAt: number?,
}

local TradeService = {}

local trades: { [Player]: Trade } = {}
-- requests[destinatario][remitente] = hora de caducidad
local requests: { [Player]: { [Player]: number } } = {}

local limiters = {
    request = RateLimiter.new(Network.RateLimits.TradeRequest),
    respond = RateLimiter.new(Network.RateLimits.TradeRespond),
    offer = RateLimiter.new(Network.RateLimits.TradeUpdateOffer),
    confirm = RateLimiter.new(Network.RateLimits.TradeConfirm),
    cancel = RateLimiter.new(Network.RateLimits.TradeCancel),
}

local function isPlayer(value: unknown): boolean
    return typeof(value) == "Instance" and (value :: Instance):IsA("Player")
end

local function partnerOf(trade: Trade, player: Player): Player
    return if trade.a == player then trade.b else trade.a
end

local function getOfferItems(player: Player, itemIds: { string }): { Types.InventoryItem }
    local data = DataService.GetData(player)
    local items: { Types.InventoryItem } = {}
    if data == nil then
        return items
    end
    for _, itemId in itemIds do
        local item = PlayerStats.FindItem(data, itemId)
        if item then
            table.insert(items, item)
        end
    end
    return items
end

local function sendState(trade: Trade)
    for _, player in { trade.a, trade.b } do
        local partner = partnerOf(trade, player)
        Remotes.TradeState:FireClient(
            player,
            "open",
            partner,
            getOfferItems(player, trade.offers[player]),
            getOfferItems(partner, trade.offers[partner]),
            trade.confirmed[player] == true,
            trade.confirmed[partner] == true,
            trade.countdownEndsAt
        )
    end
end

local function closeTrade(trade: Trade, message: string?)
    for _, player in { trade.a, trade.b } do
        if trades[player] == trade then
            trades[player] = nil
        end
        if player.Parent == Players then
            Remotes.TradeState:FireClient(player, "closed")
            if message then
                Remotes.Notify:FireClient(player, message)
            end
        end
    end
end

-- Comprueba que todos los objetos siguen en el inventario y no están en un pedestal.
local function isOfferValid(player: Player, itemIds: { string }): boolean
    local data = DataService.GetData(player)
    if data == nil then
        return false
    end
    for _, itemId in itemIds do
        if PlayerStats.FindItem(data, itemId) == nil or PlayerStats.GetPedestalOf(data, itemId) then
            return false
        end
    end
    return true
end

local function transfer(from: Player, to: Player, itemIds: { string })
    local fromData = DataService.GetData(from)
    if fromData == nil or #itemIds == 0 then
        return
    end
    local moved: { Types.InventoryItem } = {}
    DataService.Update(from, "inventory", function(inventory: { Types.InventoryItem })
        for _, itemId in itemIds do
            for index, item in inventory do
                if item.id == itemId then
                    table.insert(moved, table.remove(inventory, index) :: Types.InventoryItem)
                    break
                end
            end
        end
        return inventory
    end)
    DataService.Update(to, "inventory", function(inventory: { Types.InventoryItem })
        for _, item in moved do
            table.insert(inventory, item)
        end
        return inventory
    end)
    for _, item in moved do
        IndexService.Register(to, item.mineral, item.mutation)
    end
end

local function execute(trade: Trade)
    local offerA = trade.offers[trade.a]
    local offerB = trade.offers[trade.b]
    if not (isOfferValid(trade.a, offerA) and isOfferValid(trade.b, offerB)) then
        closeTrade(trade, Strings.Trade.Failed)
        return
    end
    -- Se saca de la lista antes de transferir para que los avisos de cambio de inventario
    -- no traten de reiniciar las ofertas a mitad de la ejecución.
    trades[trade.a] = nil
    trades[trade.b] = nil
    -- Sin yields entre las dos transferencias: nadie puede cambiar los inventarios en medio.
    transfer(trade.a, trade.b, offerA)
    transfer(trade.b, trade.a, offerB)
    closeTrade(trade, Strings.Trade.Completed)
end

local function changed(trade: Trade)
    trade.version += 1
    trade.countdownEndsAt = nil
    sendState(trade)
end

local function onRequest(player: Player, target: unknown)
    if not limiters.request.Check(player) or not isPlayer(target) then
        return
    end
    local other = target :: Player
    if other == player or other.Parent ~= Players then
        return
    end
    if DataService.GetData(player) == nil or DataService.GetData(other) == nil then
        return
    end
    if trades[player] or trades[other] then
        Remotes.Notify:FireClient(player, Strings.Trade.Busy)
        return
    end

    local pending = requests[other]
    if pending == nil then
        pending = {}
        requests[other] = pending
    end
    pending[player] = os.clock() + TradeConfig.RequestTimeout

    Remotes.Notify:FireClient(player, string.format(Strings.Trade.RequestSent, other.DisplayName))
    Remotes.Notify:FireClient(
        other,
        string.format(Strings.Trade.RequestReceived, player.DisplayName)
    )
    Remotes.TradeState:FireClient(other, "request", player)
end

local function onRespond(player: Player, requester: unknown, accept: unknown)
    if
        not limiters.respond.Check(player)
        or not isPlayer(requester)
        or type(accept) ~= "boolean"
    then
        return
    end
    local other = requester :: Player
    local pending = requests[player]
    local expiresAt = if pending then pending[other] else nil
    if pending == nil or expiresAt == nil then
        return
    end
    pending[other] = nil
    if os.clock() > expiresAt or other.Parent ~= Players then
        return
    end

    if not accept then
        Remotes.Notify:FireClient(other, string.format(Strings.Trade.Declined, player.DisplayName))
        return
    end
    if trades[player] or trades[other] then
        Remotes.Notify:FireClient(player, Strings.Trade.Busy)
        return
    end

    local trade: Trade = {
        a = other,
        b = player,
        offers = { [other] = {}, [player] = {} },
        confirmed = {},
        version = 0,
        countdownEndsAt = nil,
    }
    trades[other] = trade
    trades[player] = trade
    requests[player] = nil
    requests[other] = nil
    sendState(trade)
end

local function onUpdateOffer(player: Player, itemIds: unknown)
    if not limiters.offer.Check(player) then
        return
    end
    local trade = trades[player]
    if trade == nil or type(itemIds) ~= "table" then
        return
    end

    local offer: { string } = {}
    local seen: { [string]: boolean } = {}
    for _, itemId in itemIds :: { any } do
        if type(itemId) ~= "string" or seen[itemId] or #offer >= TradeConfig.MaxOfferItems then
            return
        end
        seen[itemId] = true
        table.insert(offer, itemId)
    end
    if not isOfferValid(player, offer) then
        return
    end

    trade.offers[player] = offer
    trade.confirmed = {}
    changed(trade)
end

local function onConfirm(player: Player)
    if not limiters.confirm.Check(player) then
        return
    end
    local trade = trades[player]
    if trade == nil or trade.confirmed[player] then
        return
    end
    trade.confirmed[player] = true

    if trade.confirmed[trade.a] and trade.confirmed[trade.b] then
        trade.version += 1
        local version = trade.version
        trade.countdownEndsAt = Workspace:GetServerTimeNow() + TradeConfig.CountdownSeconds
        sendState(trade)
        task.delay(TradeConfig.CountdownSeconds, function()
            if trades[trade.a] == trade and trade.version == version then
                execute(trade)
            end
        end)
    else
        sendState(trade)
    end
end

local function onCancel(player: Player)
    if not limiters.cancel.Check(player) then
        return
    end
    local trade = trades[player]
    if trade then
        closeTrade(trade, Strings.Trade.Cancelled)
    end
end

function TradeService.Init()
    Remotes.TradeRequest.OnServerEvent:Connect(onRequest)
    Remotes.TradeRespond.OnServerEvent:Connect(onRespond)
    Remotes.TradeUpdateOffer.OnServerEvent:Connect(onUpdateOffer)
    Remotes.TradeConfirm.OnServerEvent:Connect(onConfirm)
    Remotes.TradeCancel.OnServerEvent:Connect(onCancel)

    -- Si un objeto ofrecido se coloca en un pedestal o desaparece, la oferta deja de ser válida:
    -- se quitan las confirmaciones para que nadie confirme algo que ya no se puede entregar.
    for _, key in { "inventory", "pedestals" } do
        DataService.OnFieldChanged(key, function(player: Player)
            local trade = trades[player]
            if trade and not isOfferValid(player, trade.offers[player]) then
                trade.offers[player] = {}
                trade.confirmed = {}
                changed(trade)
            end
        end)
    end
end

function TradeService.Start()
    Players.PlayerRemoving:Connect(function(player: Player)
        local trade = trades[player]
        if trade then
            closeTrade(trade, Strings.Trade.Cancelled)
        end
        requests[player] = nil
        for _, pending in requests do
            pending[player] = nil
        end
    end)
end

return TradeService
