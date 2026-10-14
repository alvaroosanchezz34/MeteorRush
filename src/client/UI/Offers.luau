--!strict

-- Ofertas de Robux en pantalla:
--   · Ofertas grandes (Shop.BigOffers: Pack Inicial y Mega Pack): al entrar, después de las
--     notas de versión (Offers.Start), salen una detrás de otra. Al cerrar cada una se encoge
--     hasta un botón en el lateral derecho (uno debajo de otro), desde el que se vuelve a abrir.
--     El Pack Inicial desaparece al comprarlo (el servidor marca `offers.starterPack`).
--   · Ofertas de esquina: una tarjeta pequeña que entra por la derecha en momentos concretos
--     (mochila llena, meteorito grande en camino o de vez en cuando) y se va sola. Cada una
--     sale como mucho una vez por sesión y nunca dos seguidas (Config/Shop).
-- Aquí solo se pide la compra a Roblox: lo que se entrega lo decide el servidor (ShopService).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local CarryController = require(script.Parent.Parent.Controllers.CarryController)
local Sound = require(script.Parent.Sound)
local Theme = require(script.Parent.Theme)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local MeteorsConfig = require(Shared:WaitForChild("Config"):WaitForChild("Meteors"))
local PlayerStats = require(Shared:WaitForChild("Util"):WaitForChild("PlayerStats"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShopConfig = require(Shared:WaitForChild("Config"):WaitForChild("Shop"))
local Strings = require(Shared:WaitForChild("Strings"))

local GOLD = Theme.Colors.Gold
-- Segundos entre cerrar una oferta grande y que salga la siguiente.
local NEXT_OFFER_DELAY = 0.6
-- Dónde quedan los botones de las ofertas minimizadas (el primero; los demás, debajo) y la
-- tarjeta de esquina.
local MINI_POSITION = UDim2.fromScale(0.988, 0.42)
local MINI_STEP = 0.11
local CORNER_POSITION_DESKTOP = UDim2.fromScale(0.988, 0.93)
-- En pantallas táctiles la esquina de abajo es del botón de saltar: la tarjeta sube.
local CORNER_POSITION_TOUCH = UDim2.fromScale(0.988, 0.6)
local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SHRINK = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local SLIDE = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
-- Icono y color de cada oferta grande.
local BIG_STYLES: { [string]: { icon: string, color: Color3 } } = {
    starterPack = { icon = "🎁", color = GOLD },
    megaPack = { icon = "🚀", color = Color3.fromRGB(170, 120, 255) },
}
-- Orden de los boosts en la lista de lo que incluye un paquete.
local BOOST_ORDER = { "luck", "coins2x", "magnet", "carryShield" }

type Offer = {
    key: string,
    price: number,
    id: number,
    isPass: boolean,
}

local Offers = {}

-- Pass o producto con esa clave, o nil si no existe o no se puede ofrecer todavía.
local function findOffer(key: string): Offer?
    local pass = ShopConfig.GamePassesByKey[key]
    local product = ShopConfig.ProductsByKey[key]
    local id = if pass then pass.id elseif product then product.id else nil
    if id == nil then
        return nil
    end
    if id == 0 and not (RunService:IsStudio() and ShopConfig.ShowUnreleasedOffersInStudio) then
        return nil
    end
    return {
        key = key,
        id = id,
        price = if pass then pass.price elseif product then product.price else 0,
        isPass = pass ~= nil,
    }
end

-- Pide a Roblox la compra de una oferta. Con id 0 (solo en Studio) no hace nada.
local function prompt(offer: Offer)
    if offer.id == 0 then
        return
    end
    local player = Players.LocalPlayer
    if offer.isPass then
        MarketplaceService:PromptGamePassPurchase(player, offer.id)
    else
        MarketplaceService:PromptProductPurchase(player, offer.id)
    end
end

local function priceText(offer: Offer): string
    return if offer.id == 0
        then Strings.Shop.ComingSoon
        else string.format(Strings.Offers.Buy, offer.price)
end

local function isTouch(): boolean
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Ofertas grandes ---------------------------------------------------------------------------

-- Texto de una duración: "1 hora", "2 horas" o "30 min".
local function durationText(seconds: number): string
    if seconds % 3600 == 0 then
        local hours = seconds // 3600
        return if hours == 1
            then Strings.Offers.OneHour
            else string.format(Strings.Offers.Hours, hours)
    end
    return string.format(Strings.Offers.Minutes, math.floor(seconds / 60))
end

-- Lo que incluye un paquete, una línea por cosa. Las monedas dependen de los rebirths.
local function contentLines(product: ShopConfig.Product): { string }
    local lines: { string } = {}
    local data = DataController.GetData()
    if (product.rebirthCostFraction or 0) > 0 then
        local amount = if data then PlayerStats.GetCoinPackAmount(data, product) else 0
        table.insert(lines, string.format(Strings.Offers.LineCoins, Format.Number(amount)))
    end
    local boosts = product.boosts or {}
    for _, boost in BOOST_ORDER do
        local duration = boosts[boost]
        if duration then
            table.insert(
                lines,
                string.format(
                    Strings.Offers.LineBoost,
                    Strings.Offers.Boosts[boost] or boost,
                    durationText(duration)
                )
            )
        end
    end
    for _, key in product.cosmetics or {} do
        table.insert(
            lines,
            string.format(Strings.Offers.LineExclusive, Strings.Shop.Names[key] or key)
        )
    end
    return lines
end

-- Lo que costaría comprar suelto lo que trae un paquete: el paquete de monedas con la misma
-- cantidad y cada boost con la misma duración. nil si alguna parte no se vende suelta o si no
-- sale más caro: entonces la oferta no presume de ahorro.
local function separatePrice(product: ShopConfig.Product): number?
    if product.cosmetics and #product.cosmetics > 0 then
        return nil
    end
    local total = 0
    local fraction = product.rebirthCostFraction or 0
    if fraction > 0 then
        local match: ShopConfig.Product? = nil
        for _, other in ShopConfig.Products do
            if other.kind == "coins" and other.rebirthCostFraction == fraction then
                match = other
            end
        end
        if match == nil then
            return nil
        end
        total += match.price
    end
    for boost, duration in product.boosts or {} do
        local match: ShopConfig.Product? = nil
        for _, other in ShopConfig.Products do
            if other.kind == "boost" and other.boost == boost and other.duration == duration then
                match = other
            end
        end
        if match == nil then
            return nil
        end
        total += match.price
    end
    return if total > product.price then total else nil
end

type BigOffer = {
    -- Se puede enseñar: existe y, si es de una sola vez, no se ha comprado.
    Available: () -> boolean,
    -- Abre la tarjeta. `onClosed` se llama una vez, cuando se cierre (para la siguiente).
    Open: (onClosed: (() -> ())?) -> (),
    IsOpen: () -> boolean,
    mini: Frame,
}

-- Tarjeta grande de una oferta (ShopConfig.BigOffers) y su botón minimizado del lateral.
local function createBigOffer(gui: ScreenGui, key: string, relayout: () -> ()): BigOffer?
    local offer = findOffer(key)
    local product = ShopConfig.ProductsByKey[key]
    if offer == nil or product == nil then
        return nil
    end
    local style = BIG_STYLES[key] or { icon = "🎁", color = GOLD }
    local color = style.color

    local card, cardStroke = Components.Glass({
        size = UDim2.fromScale(0.42, 0.56),
        position = UDim2.fromScale(0.5, 0.5),
        anchor = Vector2.new(0.5, 0.5),
        accent = color,
        radius = Theme.Radius.Window,
        parent = gui,
    })
    card.Name = `Offer_{key}`
    card.Visible = false
    card.ZIndex = 20
    -- Tapa los clics para que no lleguen al juego.
    card.Active = true
    card.BackgroundTransparency = 0.06
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1.25
    aspect.Parent = card
    cardStroke.Thickness = Theme.Stroke.Focus
    Components.SpinBorder(cardStroke, color)
    local cardScale = Instance.new("UIScale")
    cardScale.Parent = card

    local heading = Components.Label({
        text = function(): string
            return Strings.Offers.Headings[key] or ""
        end,
        size = UDim2.fromScale(0.56, 0.08),
        position = UDim2.fromScale(0.22, 0.05),
        color = Theme.TextOn(color),
        heading = true,
        parent = card,
    })
    heading.BackgroundColor3 = color
    heading.BackgroundTransparency = 0
    local headingCorner = Instance.new("UICorner")
    headingCorner.CornerRadius = UDim.new(0.5, 0)
    headingCorner.Parent = heading
    local headingPadding = Instance.new("UIPadding")
    headingPadding.PaddingTop = UDim.new(0.12, 0)
    headingPadding.PaddingBottom = UDim.new(0.12, 0)
    headingPadding.Parent = heading

    -- Icono grande que flota despacio.
    local icon = Components.Label({
        text = style.icon,
        size = UDim2.fromScale(0.3, 0.36),
        position = UDim2.fromScale(0.04, 0.2),
        parent = card,
    })
    TweenService:Create(
        icon,
        TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Position = UDim2.fromScale(0.04, 0.17), Rotation = 6 }
    ):Play()

    Components.Label({
        text = function(): string
            return Strings.Shop.Names[key] or key
        end,
        size = UDim2.fromScale(0.6, 0.11),
        position = UDim2.fromScale(0.36, 0.17),
        alignment = Enum.TextXAlignment.Left,
        color = color,
        heading = true,
        parent = card,
    })

    -- Contenido: se vuelve a pintar al abrir (las monedas cambian con los rebirths).
    local list = Instance.new("Frame")
    list.BackgroundTransparency = 1
    list.Size = UDim2.fromScale(0.6, 0.38)
    list.Position = UDim2.fromScale(0.36, 0.3)
    list.Parent = card
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0.02, 0)
    listLayout.Parent = list

    -- Una línea más pequeña debajo: "una vez por cuenta" o lo que costaría por separado.
    local separate = separatePrice(product)
    Components.Label({
        text = function(): string
            if product.oncePerAccount then
                return Strings.Offers.WelcomeOnce
            end
            return if separate then string.format(Strings.Offers.Separately, separate) else ""
        end,
        size = UDim2.fromScale(0.9, 0.06),
        position = UDim2.fromScale(0.05, 0.7),
        color = Theme.Colors.Muted,
        parent = card,
    })

    Components.Button({
        text = priceText(offer),
        size = UDim2.fromScale(0.5, 0.15),
        position = UDim2.fromScale(0.06, 0.79),
        color = if offer.id == 0 then Theme.Colors.Disabled else Theme.Colors.Success,
        parent = card,
        onClick = function()
            prompt(offer)
        end,
    })

    -- Botón minimizado del lateral derecho ------------------------------------------------
    local mini, miniStroke = Components.Glass({
        size = UDim2.fromScale(0.085, 0.085),
        position = MINI_POSITION,
        anchor = Vector2.new(1, 0.5),
        accent = color,
        radius = 0.25,
        parent = gui,
    })
    mini.Name = `OfferMini_{key}`
    mini.Visible = false
    local miniAspect = Instance.new("UIAspectRatioConstraint")
    miniAspect.AspectRatio = 1
    miniAspect.Parent = mini
    Components.SpinBorder(miniStroke, color)
    local miniIcon = Components.Label({
        text = style.icon,
        size = UDim2.fromScale(0.7, 0.58),
        position = UDim2.fromScale(0.15, 0.06),
        parent = mini,
    })
    TweenService:Create(
        miniIcon,
        TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Rotation = 10 }
    ):Play()
    Components.Label({
        text = function(): string
            return Strings.Offers.Mini
        end,
        size = UDim2.fromScale(0.9, 0.26),
        position = UDim2.fromScale(0.05, 0.68),
        color = color,
        heading = true,
        parent = mini,
    })
    local miniButton = Instance.new("TextButton")
    miniButton.Text = ""
    miniButton.BackgroundTransparency = 1
    miniButton.Size = UDim2.fromScale(1, 1)
    miniButton.Parent = mini

    local function isBought(): boolean
        local data = DataController.GetData()
        return product.oncePerAccount == true and data ~= nil and data.offers[key] == true
    end

    local pendingClosed: (() -> ())? = nil
    local function minimize()
        if not card.Visible then
            return
        end
        Sound.Play(Theme.Sounds.close)
        -- Se enseña ya el botón (invisible) para saber dónde acabará la tarjeta.
        local bought = isBought()
        mini.Visible = not bought
        relayout()
        local target = mini.Position
        mini.Visible = false
        local shrink = TweenService:Create(card, SHRINK, {
            Position = target - UDim2.fromScale(0.035, 0),
        })
        TweenService:Create(cardScale, SHRINK, { Scale = 0.1 }):Play()
        shrink.Completed:Connect(function()
            card.Visible = false
            card.Position = UDim2.fromScale(0.5, 0.5)
            if not isBought() then
                mini.Visible = true
                relayout()
                Components.Punch(mini, 0.25)
            end
            local callback = pendingClosed
            pendingClosed = nil
            if callback then
                callback()
            end
        end)
        shrink:Play()
    end

    local function open(onClosed: (() -> ())?)
        if isBought() then
            if onClosed then
                onClosed()
            end
            return
        end
        pendingClosed = onClosed
        mini.Visible = false
        relayout()
        Components.Clear(list)
        local lines = contentLines(product)
        -- Todas las líneas con el mismo tamaño de letra como mucho, para que no salga cada una
        -- de un tamaño (una línea corta crecería más que una larga).
        local listHeight = list.AbsoluteSize.Y / math.max(cardScale.Scale, 0.1)
        local maxTextSize = math.max(math.floor(listHeight / math.max(#lines, 4) * 0.8), 8)
        for order, line in lines do
            local label = Components.Label({
                text = line,
                size = UDim2.fromScale(1, math.min(0.98 / #lines - 0.02, 0.23)),
                alignment = Enum.TextXAlignment.Left,
                layoutOrder = order,
                parent = list,
            })
            local limit = Instance.new("UITextSizeConstraint")
            limit.MaxTextSize = maxTextSize
            limit.Parent = label
        end
        card.Visible = true
        card.Position = UDim2.fromScale(0.5, 0.5)
        cardScale.Scale = 0.6
        TweenService:Create(cardScale, POP, { Scale = 1 }):Play()
        Sound.Play(Theme.Sounds.open)
    end

    Components.Button({
        text = function(): string
            return Strings.Offers.Later
        end,
        size = UDim2.fromScale(0.34, 0.15),
        position = UDim2.fromScale(0.6, 0.79),
        color = Theme.Colors.PanelRaised,
        parent = card,
        onClick = minimize,
    })
    local close = Components.Button({
        text = Theme.Icons.close,
        size = UDim2.fromScale(0.08, 0.1),
        position = UDim2.fromScale(0.97, 0.03),
        color = Theme.Colors.Danger,
        parent = card,
        onClick = minimize,
    })
    close.AnchorPoint = Vector2.new(1, 0)
    local closeAspect = Instance.new("UIAspectRatioConstraint")
    closeAspect.AspectRatio = 1
    closeAspect.Parent = close
    miniButton.Activated:Connect(function()
        open(nil)
    end)

    -- Comprado (las de una sola vez): se quita de la pantalla para siempre.
    DataController.OnChanged("offers", function()
        if isBought() then
            card.Visible = false
            mini.Visible = false
            relayout()
            local callback = pendingClosed
            pendingClosed = nil
            if callback then
                callback()
            end
        end
    end)

    return {
        Available = function(): boolean
            return not isBought()
        end,
        Open = open,
        IsOpen = function(): boolean
            return card.Visible
        end,
        mini = mini,
    }
end

-- Ofertas de esquina -----------------------------------------------------------------------

local function mountCorner(gui: ScreenGui, isWelcomeOpen: () -> boolean)
    local card, stroke = Components.Glass({
        size = UDim2.fromScale(0.28, 0.16),
        position = CORNER_POSITION_DESKTOP,
        anchor = Vector2.new(1, 1),
        accent = GOLD,
        parent = gui,
    })
    card.Name = "CornerOffer"
    card.Visible = false
    card.Active = true
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 2.6
    aspect.Parent = card
    Components.SpinBorder(stroke, GOLD)

    local heading = Components.Label({
        text = function(): string
            return Strings.Offers.CornerHeading
        end,
        size = UDim2.fromScale(0.22, 0.2),
        position = UDim2.fromScale(0.04, 0.08),
        color = Theme.Colors.TextDark,
        heading = true,
        parent = card,
    })
    heading.BackgroundColor3 = GOLD
    heading.BackgroundTransparency = 0
    local headingCorner = Instance.new("UICorner")
    headingCorner.CornerRadius = UDim.new(0.5, 0)
    headingCorner.Parent = heading
    local name = Components.Label({
        text = "",
        size = UDim2.fromScale(0.6, 0.24),
        position = UDim2.fromScale(0.28, 0.06),
        alignment = Enum.TextXAlignment.Left,
        heading = true,
        parent = card,
    })
    local tagline = Components.Label({
        text = "",
        size = UDim2.fromScale(0.6, 0.5),
        position = UDim2.fromScale(0.04, 0.38),
        alignment = Enum.TextXAlignment.Left,
        color = Theme.Colors.Muted,
        parent = card,
    })
    local current: Offer? = nil
    local buy = Components.Button({
        text = "",
        size = UDim2.fromScale(0.3, 0.42),
        position = UDim2.fromScale(0.67, 0.42),
        color = Theme.Colors.Success,
        parent = card,
        onClick = function()
            if current then
                prompt(current)
            end
        end,
    })
    local hideToken = 0
    local function hide()
        if not card.Visible then
            return
        end
        hideToken += 1
        local position = card.Position
        local out = TweenService:Create(card, SLIDE, {
            Position = UDim2.fromScale(1.3, position.Y.Scale),
        })
        out.Completed:Connect(function()
            card.Visible = false
        end)
        out:Play()
    end
    local close = Components.Button({
        text = Theme.Icons.close,
        size = UDim2.fromScale(0.08, 0.24),
        position = UDim2.fromScale(0.97, 0.06),
        color = Theme.Colors.PanelRaised,
        parent = card,
        onClick = hide,
    })
    close.AnchorPoint = Vector2.new(1, 0)
    local closeAspect = Instance.new("UIAspectRatioConstraint")
    closeAspect.AspectRatio = 1
    closeAspect.Parent = close

    local shown: { [string]: boolean } = {}
    local lastShownAt = os.clock() - ShopConfig.CornerOfferGap + ShopConfig.CornerOfferDelay

    -- Primera oferta disponible para ese momento: no vista en esta sesión y, si es un pass,
    -- que no se tenga ya.
    local function pick(trigger: string): Offer?
        local data = DataController.GetData()
        if data == nil then
            return nil
        end
        for _, entry in ShopConfig.CornerOffers do
            if entry.trigger == trigger and not shown[entry.key] then
                local offer = findOffer(entry.key)
                if offer and not (offer.isPass and PlayerStats.HasPass(data, offer.key)) then
                    return offer
                end
            end
        end
        return nil
    end

    local function show(trigger: string)
        if card.Visible or isWelcomeOpen() then
            return
        end
        if os.clock() - lastShownAt < ShopConfig.CornerOfferGap then
            return
        end
        local offer = pick(trigger)
        if offer == nil then
            return
        end
        shown[offer.key] = true
        lastShownAt = os.clock()
        current = offer
        name.Text = Strings.Shop.Names[offer.key] or offer.key
        tagline.Text = Strings.Offers.Corner[offer.key] or ""
        buy.Text = priceText(offer)
        buy.BackgroundColor3 = if offer.id == 0 then Theme.Colors.Disabled else Theme.Colors.Success

        -- Entra deslizándose desde fuera de la pantalla.
        local target = if isTouch() then CORNER_POSITION_TOUCH else CORNER_POSITION_DESKTOP
        card.AnchorPoint = Vector2.new(1, if isTouch() then 0.5 else 1)
        card.Position = UDim2.fromScale(1.3, target.Y.Scale)
        card.Visible = true
        TweenService:Create(card, SLIDE, { Position = target }):Play()
        Sound.Play(Theme.Sounds.open)

        hideToken += 1
        local token = hideToken
        task.delay(ShopConfig.CornerOfferSeconds, function()
            if token == hideToken then
                hide()
            end
        end)
    end

    -- Mochila llena: justo cuando se llena.
    local wasFull = false
    CarryController.OnChanged(function(items)
        local capacity = CarryController.GetCapacity()
        local full = capacity > 0 and #items >= capacity
        if full and not wasFull then
            show("backpackFull")
        end
        wasFull = full
    end)
    -- Meteorito grande o de evento anunciado.
    Remotes.MeteorIncoming.OnClientEvent:Connect(function(_, typeId)
        local meteorType = if type(typeId) == "string" then MeteorsConfig.Types[typeId] else nil
        if meteorType and meteorType.id ~= "normal" then
            show("meteor")
        end
    end)
    -- De vez en cuando.
    task.spawn(function()
        while true do
            task.wait(15)
            show("timer")
        end
    end)
end

local bigOffers: { BigOffer } = {}

-- Coloca los botones minimizados visibles uno debajo de otro, en el orden de las ofertas.
local function relayout()
    local slot = 0
    for _, big in bigOffers do
        if big.mini.Visible then
            big.mini.Position = MINI_POSITION + UDim2.fromScale(0, slot * MINI_STEP)
            slot += 1
        end
    end
end

-- Monta las ofertas en el HUD (sin enseñar ninguna todavía).
function Offers.Mount(gui: ScreenGui)
    for _, key in ShopConfig.BigOffers do
        local big = createBigOffer(gui, key, relayout)
        if big then
            table.insert(bigOffers, big)
        end
    end
    mountCorner(gui, function(): boolean
        for _, big in bigOffers do
            if big.IsOpen() then
                return true
            end
        end
        return false
    end)
end

-- Enseña las ofertas grandes una detrás de otra, empezando por la primera disponible. Se
-- llama al cerrar las notas de versión (o al entrar, si no hay notas que enseñar).
function Offers.Start(from: number?)
    for index = from or 1, #bigOffers do
        local big = bigOffers[index]
        if big.Available() then
            big.Open(function()
                task.delay(NEXT_OFFER_DELAY, Offers.Start, index + 1)
            end)
            return
        end
    end
end

return Offers
