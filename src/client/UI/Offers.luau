--!strict

-- Ofertas de Robux en pantalla:
--   · Oferta de bienvenida (Pack Inicial): sale en grande al entrar mientras no se haya
--     comprado. Al cerrarla se encoge hasta un botón en el lateral derecho, desde el que se
--     vuelve a abrir. Desaparece al comprarla (el servidor marca `offers.starterPack`).
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
-- Segundos tras entrar hasta que sale la oferta de bienvenida (que primero se vea el juego).
local WELCOME_DELAY = 3
-- Dónde queda el botón de la oferta minimizada y la tarjeta de esquina.
local MINI_POSITION = UDim2.fromScale(0.988, 0.46)
local CORNER_POSITION_DESKTOP = UDim2.fromScale(0.988, 0.93)
-- En pantallas táctiles la esquina de abajo es del botón de saltar: la tarjeta sube.
local CORNER_POSITION_TOUCH = UDim2.fromScale(0.988, 0.6)
local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SHRINK = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local SLIDE = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

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

-- Oferta de bienvenida ---------------------------------------------------------------------

local function mountWelcome(gui: ScreenGui)
    local offer = findOffer(ShopConfig.StarterPackKey)
    local product = ShopConfig.ProductsByKey[ShopConfig.StarterPackKey]
    if offer == nil or product == nil then
        return
    end

    -- Tarjeta grande ---------------------------------------------------------------------
    local card, cardStroke = Components.Glass({
        size = UDim2.fromScale(0.42, 0.56),
        position = UDim2.fromScale(0.5, 0.5),
        anchor = Vector2.new(0.5, 0.5),
        accent = GOLD,
        radius = Theme.Radius.Window,
        parent = gui,
    })
    card.Name = "WelcomeOffer"
    card.Visible = false
    card.ZIndex = 20
    -- Tapa los clics para que no lleguen al juego.
    card.Active = true
    card.BackgroundTransparency = 0.06
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1.25
    aspect.Parent = card
    cardStroke.Thickness = Theme.Stroke.Focus
    Components.SpinBorder(cardStroke, GOLD)
    local cardScale = Instance.new("UIScale")
    cardScale.Parent = card

    local heading = Components.Label({
        text = function(): string
            return Strings.Offers.WelcomeHeading
        end,
        size = UDim2.fromScale(0.56, 0.08),
        position = UDim2.fromScale(0.22, 0.05),
        color = Theme.Colors.TextDark,
        heading = true,
        parent = card,
    })
    heading.BackgroundColor3 = GOLD
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
        text = "🎁",
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
            return Strings.Offers.WelcomeTitle
        end,
        size = UDim2.fromScale(0.6, 0.11),
        position = UDim2.fromScale(0.36, 0.17),
        alignment = Enum.TextXAlignment.Left,
        color = GOLD,
        heading = true,
        parent = card,
    })

    -- Lo que incluye: una línea por cosa. Las monedas dependen de los rebirths del jugador.
    local list = Instance.new("Frame")
    list.BackgroundTransparency = 1
    list.Size = UDim2.fromScale(0.6, 0.36)
    list.Position = UDim2.fromScale(0.36, 0.3)
    list.Parent = card
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0.03, 0)
    listLayout.Parent = list
    local coinsLine = Components.Label({
        text = "",
        size = UDim2.fromScale(1, 0.22),
        alignment = Enum.TextXAlignment.Left,
        layoutOrder = 1,
        parent = list,
    })
    for order, key in { "WelcomeLuck", "WelcomeShield", "WelcomeTrail" } do
        Components.Label({
            text = function(): string
                return Strings.Offers[key]
            end,
            size = UDim2.fromScale(1, 0.22),
            alignment = Enum.TextXAlignment.Left,
            layoutOrder = order + 1,
            parent = list,
        })
    end

    Components.Label({
        text = function(): string
            return Strings.Offers.WelcomeOnce
        end,
        size = UDim2.fromScale(0.9, 0.06),
        position = UDim2.fromScale(0.05, 0.69),
        color = Theme.Colors.Muted,
        parent = card,
    })

    local buyButton = Components.Button({
        text = priceText(offer),
        size = UDim2.fromScale(0.5, 0.15),
        position = UDim2.fromScale(0.06, 0.79),
        color = if offer.id == 0 then Theme.Colors.Disabled else Theme.Colors.Success,
        parent = card,
        onClick = function()
            prompt(offer)
        end,
    })
    buyButton.ZIndex = 21

    -- Botón minimizado ---------------------------------------------------------------------
    local mini, miniStroke = Components.Glass({
        size = UDim2.fromScale(0.085, 0.085),
        position = MINI_POSITION,
        anchor = Vector2.new(1, 0.5),
        accent = GOLD,
        radius = 0.25,
        parent = gui,
    })
    mini.Name = "WelcomeOfferMini"
    mini.Visible = false
    local miniAspect = Instance.new("UIAspectRatioConstraint")
    miniAspect.AspectRatio = 1
    miniAspect.Parent = mini
    Components.SpinBorder(miniStroke, GOLD)
    local miniIcon = Components.Label({
        text = "🎁",
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
        color = GOLD,
        heading = true,
        parent = mini,
    })
    local miniButton = Instance.new("TextButton")
    miniButton.Text = ""
    miniButton.BackgroundTransparency = 1
    miniButton.Size = UDim2.fromScale(1, 1)
    miniButton.Parent = mini

    local bought = false
    local open: () -> ()
    local function minimize()
        if not card.Visible then
            return
        end
        Sound.Play(Theme.Sounds.close)
        -- La tarjeta se encoge hacia el botón del lateral.
        local shrink = TweenService:Create(card, SHRINK, {
            Position = MINI_POSITION - UDim2.fromScale(0.035, 0),
        })
        TweenService:Create(cardScale, SHRINK, { Scale = 0.1 }):Play()
        shrink.Completed:Connect(function()
            card.Visible = false
            card.Position = UDim2.fromScale(0.5, 0.5)
            if not bought then
                mini.Visible = true
                Components.Punch(mini, 0.25)
            end
        end)
        shrink:Play()
    end
    open = function()
        if bought then
            return
        end
        mini.Visible = false
        card.Visible = true
        card.Position = UDim2.fromScale(0.5, 0.5)
        cardScale.Scale = 0.6
        TweenService:Create(cardScale, POP, { Scale = 1 }):Play()
        Sound.Play(Theme.Sounds.open)
        local data = DataController.GetData()
        coinsLine.Text = string.format(
            Strings.Offers.WelcomeCoins,
            Format.Number(if data then PlayerStats.GetCoinPackAmount(data, product) else 0)
        )
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
    }).ZIndex =
        21
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
    miniButton.Activated:Connect(open)

    -- Comprado: se quita de la pantalla para siempre.
    local function checkBought()
        local data = DataController.GetData()
        if data and data.offers[ShopConfig.StarterPackKey] then
            bought = true
            card.Visible = false
            mini.Visible = false
        end
    end
    DataController.OnChanged("offers", checkBought)
    checkBought()
    if not bought then
        task.delay(WELCOME_DELAY, open)
    end
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

-- Monta las ofertas en el HUD.
function Offers.Mount(gui: ScreenGui)
    mountWelcome(gui)
    local welcome = gui:FindFirstChild("WelcomeOffer")
    mountCorner(gui, function(): boolean
        return welcome ~= nil and welcome:IsA("GuiObject") and welcome.Visible
    end)
end

return Offers
