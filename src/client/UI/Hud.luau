--!strict

-- HUD: monedas, ingresos por segundo, mochila, boosts activos, cuenta atrás del próximo
-- meteorito, flecha hacia el meteorito activo más cercano, botones laterales de los menús
-- (con aviso cuando hay algo que recoger), ofertas (UI/Offers) y texto del tutorial.
-- Estilo: paneles de cristal oscuro con borde y línea de luz del color de cada cosa
-- (Components.Glass), todo en escala para que encaje en móvil, PC y consola.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Banner = require(script.Parent.Banner)
local BasesMenu = require(script.Parent.BasesMenu)
local BaseController = require(script.Parent.Parent.Controllers.BaseController)
local CarryController = require(script.Parent.Parent.Controllers.CarryController)
local Components = require(script.Parent.Components)
local CratesMenu = require(script.Parent.CratesMenu)
local DailyMenu = require(script.Parent.DailyMenu)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local Effects = require(script.Parent.Effects)
local DecorMenu = require(script.Parent.DecorMenu)
local EquipmentMenu = require(script.Parent.EquipmentMenu)
local GearCollectionMenu = require(script.Parent.GearCollectionMenu)
local AchievementsMenu = require(script.Parent.AchievementsMenu)
local IndexMenu = require(script.Parent.IndexMenu)
local MenuBus = require(script.Parent.MenuBus)
local Offers = require(script.Parent.Offers)
local InventoryMenu = require(script.Parent.InventoryMenu)
local MeteorController = require(script.Parent.Parent.Controllers.MeteorController)
local PermanentMenu = require(script.Parent.PermanentMenu)
local PlayersMenu = require(script.Parent.PlayersMenu)
local ProfileMenu = require(script.Parent.ProfileMenu)
local QuestsMenu = require(script.Parent.QuestsMenu)
local RebirthMenu = require(script.Parent.RebirthMenu)
local SeasonMenu = require(script.Parent.SeasonMenu)
local SettingsMenu = require(script.Parent.SettingsMenu)
local ShopMenu = require(script.Parent.ShopMenu)
local Sound = require(script.Parent.Sound)
local TabbedMenu = require(script.Parent.TabbedMenu)
local Theme = require(script.Parent.Theme)
local TradeMenu = require(script.Parent.TradeMenu)
local UpgradesMenu = require(script.Parent.UpgradesMenu)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarryConfig = require(Shared:WaitForChild("Config"):WaitForChild("Carry"))
local DailyConfig = require(Shared:WaitForChild("Config"):WaitForChild("Daily"))
local QuestsConfig = require(Shared:WaitForChild("Config"):WaitForChild("Quests"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Locale = require(Shared:WaitForChild("Locale"))
local PlayerStats = require(Shared:WaitForChild("Util"):WaitForChild("PlayerStats"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local MENUS: { TabbedMenu.Tab } = {
    {
        key = "inventory",
        module = TabbedMenu.Create({
            { key = "minerals", module = InventoryMenu },
            { key = "equipment", module = EquipmentMenu },
            { key = "crates", module = CratesMenu },
            { key = "decor", module = DecorMenu },
        }),
    },
    { key = "upgrades", module = UpgradesMenu },
    { key = "shop", module = ShopMenu },
    -- Índice, logros y perfil, en pestañas.
    {
        key = "index",
        module = TabbedMenu.Create({
            { key = "index", module = IndexMenu },
            { key = "gear", module = GearCollectionMenu },
            { key = "achievements", module = AchievementsMenu },
            { key = "profile", module = ProfileMenu },
            { key = "players", module = PlayersMenu },
            { key = "bases", module = BasesMenu },
        }),
    },
    { key = "daily", module = DailyMenu },
    {
        key = "quests",
        module = TabbedMenu.Create({
            { key = "quests", module = QuestsMenu },
            { key = "season", module = SeasonMenu },
        }),
    },
    {
        key = "rebirth",
        module = TabbedMenu.Create({
            { key = "rebirth", module = RebirthMenu },
            { key = "tree", module = PermanentMenu },
        }),
    },
    { key = "trade", module = TradeMenu },
}

-- Icono de cada boost en el HUD (el nombre largo está en la tienda).
local BOOST_ICONS: { [string]: string } = {
    carryShield = "🛡️",
    magnet = "🧲",
    luck = "🍀",
    coins2x = "💰x2",
}
local BOOST_ORDER = { "luck", "coins2x", "magnet", "carryShield" }
-- Color de la barra de la mochila: vacía, casi llena y llena.
local BACKPACK_COLOR = Color3.fromRGB(70, 222, 160)
local BADGE_COLOR = Color3.fromRGB(255, 70, 80)

local Hud = {}

-- Fila del HUD con proporción fija (ancho / alto) dentro de una columna con UIListLayout.
local function row(
    parent: Instance,
    order: number,
    aspectRatio: number,
    accent: Color3
): (Frame, UIStroke)
    local frame, stroke = Components.Glass({
        size = UDim2.fromScale(1, 1),
        accent = accent,
        radius = 0.22,
        parent = parent,
    })
    frame.LayoutOrder = order
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = aspectRatio
    aspect.DominantAxis = Enum.DominantAxis.Width
    aspect.Parent = frame
    return frame, stroke
end

-- Punto rojo de aviso en la esquina de un botón ("hay algo que recoger").
local function addBadge(button: GuiObject): Frame
    local badge = Instance.new("Frame")
    badge.Name = "Badge"
    badge.AnchorPoint = Vector2.new(0.5, 0.5)
    badge.Position = UDim2.fromScale(0.92, 0.08)
    badge.Size = UDim2.fromScale(0.24, 0.24)
    badge.BackgroundColor3 = BADGE_COLOR
    badge.BorderSizePixel = 0
    badge.Visible = false
    badge.ZIndex = 4
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = badge
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Thickness = 2
    stroke.Parent = badge
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Text = "!"
    label.TextScaled = true
    label.Font = Theme.Fonts.Heading
    label.TextColor3 = Color3.new(1, 1, 1)
    label.ZIndex = 5
    label.Parent = badge
    -- Late para llamar la atención sin molestar.
    TweenService:Create(
        badge,
        TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Size = UDim2.fromScale(0.3, 0.3) }
    ):Play()
    badge.Parent = button
    return badge
end

function Hud.Mount()
    local gui = Instance.new("ScreenGui")
    -- Los textos ya salen en el idioma elegido: sin traducción automática de Roblox.
    gui.AutoLocalize = false
    gui.Name = "Hud"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Columna de arriba a la izquierda: monedas, mochila y boosts ---------------
    local column = Instance.new("Frame")
    column.Name = "Stats"
    column.BackgroundTransparency = 1
    column.Size = UDim2.fromScale(0.19, 0.3)
    column.Position = UDim2.fromScale(0.01, 0.02)
    column.Parent = gui
    local columnLayout = Instance.new("UIListLayout")
    columnLayout.SortOrder = Enum.SortOrder.LayoutOrder
    columnLayout.Padding = UDim.new(0.025, 0)
    columnLayout.Parent = column

    -- Monedas: icono, cantidad grande, ingresos por segundo y "+" que abre la tienda.
    local wallet = row(column, 1, 3.4, Components.Colors.Gold)
    wallet.Name = "Wallet"
    local coinIcon = Components.Label({
        text = Theme.Icons.coins,
        size = UDim2.fromScale(0.17, 0.6),
        position = UDim2.fromScale(0.03, 0.2),
        parent = wallet,
    })
    coinIcon.Name = "CoinIcon"
    local coinsLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.6, 0.48),
        position = UDim2.fromScale(0.22, 0.1),
        alignment = Enum.TextXAlignment.Left,
        color = Components.Colors.Gold,
        heading = true,
        parent = wallet,
    })
    local incomeLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.6, 0.3),
        position = UDim2.fromScale(0.22, 0.6),
        alignment = Enum.TextXAlignment.Left,
        color = Components.Colors.Success,
        parent = wallet,
    })
    local addCoins = Components.Button({
        text = "+",
        size = UDim2.fromScale(0.15, 0.56),
        position = UDim2.fromScale(0.97, 0.5),
        color = Components.Colors.Gold,
        parent = wallet,
        onClick = function()
            MenuBus.Open("shop", "coins")
        end,
    })
    addCoins.AnchorPoint = Vector2.new(1, 0.5)
    local addAspect = Instance.new("UIAspectRatioConstraint")
    addAspect.AspectRatio = 1
    addAspect.Parent = addCoins

    -- Mochila: recuento, barra de llenado y cuánto frena la carga.
    local backpackCard, backpackStroke = row(column, 2, 6, BACKPACK_COLOR)
    backpackCard.Name = "Backpack"
    Components.Label({
        text = "🎒",
        size = UDim2.fromScale(0.1, 0.7),
        position = UDim2.fromScale(0.02, 0.15),
        parent = backpackCard,
    })
    Components.Label({
        text = function(): string
            return Strings.Hud.BackpackTitle
        end,
        size = UDim2.fromScale(0.4, 0.4),
        position = UDim2.fromScale(0.14, 0.1),
        alignment = Enum.TextXAlignment.Left,
        color = Components.Colors.Muted,
        parent = backpackCard,
    })
    local backpackLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.42, 0.42),
        position = UDim2.fromScale(0.54, 0.08),
        alignment = Enum.TextXAlignment.Right,
        heading = true,
        parent = backpackCard,
    })
    local backpackBar = Instance.new("Frame")
    backpackBar.Size = UDim2.fromScale(0.82, 0.2)
    backpackBar.Position = UDim2.fromScale(0.14, 0.62)
    backpackBar.BackgroundColor3 = Components.Colors.Background
    backpackBar.BorderSizePixel = 0
    backpackBar.Parent = backpackCard
    local backpackBarCorner = Instance.new("UICorner")
    backpackBarCorner.CornerRadius = UDim.new(1, 0)
    backpackBarCorner.Parent = backpackBar
    local backpackFill = Instance.new("Frame")
    backpackFill.Size = UDim2.fromScale(0, 1)
    backpackFill.BackgroundColor3 = BACKPACK_COLOR
    backpackFill.BorderSizePixel = 0
    backpackFill.Parent = backpackBar
    local backpackFillCorner = Instance.new("UICorner")
    backpackFillCorner.CornerRadius = UDim.new(1, 0)
    backpackFillCorner.Parent = backpackFill
    local slowLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.4, 0.36),
        position = UDim2.fromScale(0.96, 0.62),
        alignment = Enum.TextXAlignment.Right,
        color = Components.Colors.Gold,
        parent = backpackCard,
    })
    slowLabel.AnchorPoint = Vector2.new(1, 0.5)
    slowLabel.Visible = false

    -- Boosts activos y bonus de amigos (se oculta si no hay ninguno).
    local boostsCard = row(column, 3, 8, Components.Colors.Accent)
    boostsCard.Name = "Boosts"
    boostsCard.Visible = false
    local boostsLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.92, 0.7),
        position = UDim2.fromScale(0.04, 0.15),
        alignment = Enum.TextXAlignment.Left,
        parent = boostsCard,
    })

    -- Próximo meteorito y flecha (arriba en el centro) ------------------------
    local nextMeteorPill = Components.Glass({
        size = UDim2.fromScale(0.17, 0.068),
        position = UDim2.fromScale(0.5, 0.012),
        anchor = Vector2.new(0.5, 0),
        accent = Color3.fromRGB(255, 110, 70),
        radius = 0.3,
        parent = gui,
    })
    Components.Label({
        text = function(): string
            return Strings.Hud.NextMeteorTitle
        end,
        size = UDim2.fromScale(0.9, 0.32),
        position = UDim2.fromScale(0.05, 0.1),
        color = Color3.fromRGB(255, 140, 100),
        parent = nextMeteorPill,
    })
    local nextMeteorLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.9, 0.48),
        position = UDim2.fromScale(0.05, 0.42),
        heading = true,
        parent = nextMeteorPill,
    })
    local arrow = Components.Label({
        text = "▲",
        size = UDim2.fromScale(0.04, 0.06),
        position = UDim2.fromScale(0.48, 0.09),
        color = Color3.fromRGB(255, 90, 60),
        parent = gui,
    })
    local arrowAspect = Instance.new("UIAspectRatioConstraint")
    arrowAspect.AspectRatio = 1
    arrowAspect.Parent = arrow
    local distanceLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.12, 0.03),
        position = UDim2.fromScale(0.44, 0.155),
        parent = gui,
    })
    distanceLabel.TextStrokeTransparency = 0.4

    -- Competición de servidor en curso (arriba, a la derecha del próximo meteorito).
    local competitionPill = Components.Glass({
        size = UDim2.fromScale(0.19, 0.05),
        position = UDim2.fromScale(0.6, 0.012),
        accent = Components.Colors.Gold,
        radius = 0.3,
        parent = gui,
    })
    competitionPill.Visible = false
    local competitionLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.92, 0.76),
        position = UDim2.fromScale(0.04, 0.12),
        color = Components.Colors.Gold,
        parent = competitionPill,
    })

    -- Evento global: cuenta atrás hasta que empieza y tiempo que le queda (debajo de la competición).
    local eventPill = Components.Glass({
        size = UDim2.fromScale(0.19, 0.05),
        position = UDim2.fromScale(0.6, 0.068),
        accent = Color3.fromRGB(255, 150, 90),
        radius = 0.3,
        parent = gui,
    })
    eventPill.Visible = false
    local eventLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.92, 0.76),
        position = UDim2.fromScale(0.04, 0.12),
        color = Color3.fromRGB(255, 150, 90),
        parent = eventPill,
    })

    -- Flecha de vuelta a la base: aparece al llevar minerales fuera de la base.
    local baseArrow = Components.Label({
        text = "▲",
        size = UDim2.fromScale(0.04, 0.06),
        position = UDim2.fromScale(0.6, 0.12),
        color = Components.Colors.Success,
        parent = gui,
    })
    baseArrow.Visible = false
    local baseArrowAspect = Instance.new("UIAspectRatioConstraint")
    baseArrowAspect.AspectRatio = 1
    baseArrowAspect.Parent = baseArrow
    local baseDistanceLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.16, 0.03),
        position = UDim2.fromScale(0.54, 0.185),
        color = Components.Colors.Success,
        parent = gui,
    })
    baseDistanceLabel.TextStrokeTransparency = 0.4
    baseDistanceLabel.Visible = false

    -- Aviso de zona segura: dentro de la base propia nadie puede robarte.
    local safeLabel = Components.Label({
        text = function()
            return Strings.Hud.SafeZone
        end,
        size = UDim2.fromScale(0.2, 0.04),
        position = UDim2.fromScale(0.4, 0.2),
        color = Components.Colors.Success,
        parent = gui,
    })
    safeLabel.TextStrokeTransparency = 0.3
    safeLabel.Visible = false

    -- Versión del juego (abajo a la derecha).
    local version = Workspace:GetAttribute("Version")
    Components.Label({
        text = if type(version) == "string" then `v{version}` else "",
        size = UDim2.fromScale(0.06, 0.022),
        position = UDim2.fromScale(0.935, 0.972),
        alignment = Enum.TextXAlignment.Right,
        color = Components.Colors.Muted,
        parent = gui,
    })

    -- Tutorial (abajo en el centro) --------------------------------------------
    local tutorialLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.54, 0.06),
        position = UDim2.fromScale(0.23, 0.8),
        color = Components.Colors.Gold,
        parent = gui,
    })
    tutorialLabel.BackgroundColor3 = Theme.Glass.Color
    tutorialLabel.BackgroundTransparency = Theme.Glass.Transparency
    local tutorialCorner = Instance.new("UICorner")
    tutorialCorner.CornerRadius = UDim.new(0.3, 0)
    tutorialCorner.Parent = tutorialLabel
    local tutorialStroke = Instance.new("UIStroke")
    tutorialStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    tutorialStroke.Color = Components.Colors.Gold
    tutorialStroke.Thickness = 2
    tutorialStroke.Parent = tutorialLabel

    -- Menús y botones laterales -----------------------------------------------
    local sideBar = Instance.new("Frame")
    sideBar.BackgroundTransparency = 1
    sideBar.Size = UDim2.fromScale(0.15, 0.5)
    sideBar.Position = UDim2.fromScale(0.01, 0.29)
    sideBar.Parent = gui
    -- Dos columnas de botones cuadrados: el marco mantiene la proporción 2 x 4.
    local sideAspect = Instance.new("UIAspectRatioConstraint")
    sideAspect.AspectRatio = 0.5
    sideAspect.Parent = sideBar
    local sideLayout = Instance.new("UIGridLayout")
    sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sideLayout.CellSize = UDim2.fromScale(0.47, 0.235)
    sideLayout.CellPadding = UDim2.fromScale(0.06, 0.02)
    sideLayout.Parent = sideBar

    local windows: { Components.Window } = {}
    local badges: { [string]: Frame } = {}
    for order, menu in MENUS do
        local window = Components.Window({
            title = function(): string
                return if menu.key == "inventory"
                    then Strings.Inventory.Title
                    else Strings.Hud.Buttons[menu.key]
            end,
            closeText = Strings.Hud.Close,
            parent = gui,
            accent = Theme.Accents[menu.key],
            icon = Theme.Icons[menu.key],
        })
        table.insert(windows, window)
        -- Solo una ventana abierta a la vez.
        window.OnOpened(function()
            for _, other in windows do
                if other ~= window and other.IsOpen() then
                    other.Close()
                end
            end
        end)
        menu.module.Mount(window)

        -- Botón de cristal con una franja del color del menú abajo.
        local accent = Theme.Accents[menu.key] or Components.Colors.Primary
        local button = Components.IconButton({
            icon = Theme.Icons[menu.key] or "",
            text = function(): string
                return Strings.Hud.Buttons[menu.key]
            end,
            layoutOrder = order,
            color = Theme.Glass.Color,
            parent = sideBar,
            onClick = function()
                window.Toggle()
            end,
        })
        button.BackgroundTransparency = Theme.Glass.Transparency
        local strip = Instance.new("Frame")
        strip.Name = "AccentStrip"
        strip.AnchorPoint = Vector2.new(0.5, 1)
        strip.Position = UDim2.fromScale(0.5, 0.97)
        strip.Size = UDim2.fromScale(0.6, 0.05)
        strip.BackgroundColor3 = accent
        strip.BorderSizePixel = 0
        local stripCorner = Instance.new("UICorner")
        stripCorner.CornerRadius = UDim.new(1, 0)
        stripCorner.Parent = strip
        strip.Parent = button
        local iconLabel = button:FindFirstChild("Icon")
        if iconLabel and iconLabel:IsA("TextLabel") then
            iconLabel.TextColor3 = accent
        end
        badges[menu.key] = addBadge(button)
    end

    -- Ajustes (idioma): fuera de la barra lateral, con un botón pequeño junto a los de viaje.
    local settingsWindow = Components.Window({
        title = function(): string
            return Strings.Settings.Title
        end,
        closeText = Strings.Hud.Close,
        parent = gui,
        icon = Theme.Icons.settings,
    })
    table.insert(windows, settingsWindow)
    settingsWindow.OnOpened(function()
        for _, other in windows do
            if other ~= settingsWindow and other.IsOpen() then
                other.Close()
            end
        end
    end)
    SettingsMenu.Mount(settingsWindow)
    local settingsButton = Components.Button({
        text = Theme.Icons.settings,
        size = UDim2.fromScale(0.045, 0.045),
        position = UDim2.fromScale(0.17, 0.8),
        color = Components.Colors.PanelRaised,
        parent = gui,
        onClick = function()
            settingsWindow.Toggle()
        end,
    })
    local settingsAspect = Instance.new("UIAspectRatioConstraint")
    settingsAspect.AspectRatio = 1
    settingsAspect.Parent = settingsButton

    -- Perfil y títulos: atajo a esa pestaña de la Colección.
    local profileButton = Components.Button({
        text = "👤",
        size = UDim2.fromScale(0.045, 0.045),
        position = UDim2.fromScale(0.198, 0.8),
        color = Components.Colors.PanelRaised,
        parent = gui,
        onClick = function()
            MenuBus.Open("index", "profile")
        end,
    })
    local profileAspect = Instance.new("UIAspectRatioConstraint")
    profileAspect.AspectRatio = 1
    profileAspect.Parent = profileButton

    -- Abrir un menú desde fuera del HUD (los NPCs del Outpost).
    MenuBus.SetHandler(function(key: string, tab: string?)
        for index, menu in MENUS do
            if menu.key == key then
                local selectTab = menu.module.Select
                if tab and selectTab then
                    selectTab(tab)
                end
                windows[index].Open()
            end
        end
    end)

    -- Teletransporte al Outpost y de vuelta a la base (el servidor decide si se puede).
    for index, destination in { "outpost", "home" } do
        Components.Button({
            text = function(): string
                return if destination == "outpost" then Strings.Hud.Outpost else Strings.Hud.Home
            end,
            size = UDim2.fromScale(0.075, 0.045),
            position = UDim2.fromScale(0.01 + (index - 1) * 0.08, 0.8),
            color = if destination == "outpost"
                then Components.Colors.Primary
                else Components.Colors.PanelRaised,
            parent = gui,
            onClick = function()
                Remotes.Teleport:FireServer(destination)
            end,
        })
    end

    -- Actualización de valores -------------------------------------------------
    -- Texto "+$X" que sube y se desvanece junto al panel cada vez que entran monedas.
    -- Monedas que vuelan desde el centro de la pantalla hasta el contador. Como mucho una
    -- vez cada COIN_FLY_GAP segundos, para que los ingresos automáticos no las repitan sin parar.
    -- Cuantas más monedas entran, más vuelan (de COIN_FLY_MIN a COIN_FLY_MAX).
    local COIN_FLY_GAP = 1.5
    local COIN_FLY_MIN = 4
    local COIN_FLY_MAX = 12
    local lastCoinFly = 0
    local function flyCoins(amount: number)
        local now = os.clock()
        if now - lastCoinFly < COIN_FLY_GAP then
            return
        end
        lastCoinFly = now
        local count = math.clamp(
            COIN_FLY_MIN + math.floor(math.log10(math.max(amount, 1)) * 1.5),
            COIN_FLY_MIN,
            COIN_FLY_MAX
        )
        for index = 1, count do
            local coin = Instance.new("Frame")
            coin.AnchorPoint = Vector2.new(0.5, 0.5)
            coin.Size = UDim2.fromScale(0.012, 0.012)
            coin.SizeConstraint = Enum.SizeConstraint.RelativeXX
            coin.Position = UDim2.fromScale(
                0.5 + (math.random() - 0.5) * 0.08,
                0.62 + (math.random() - 0.5) * 0.08
            )
            coin.BackgroundColor3 = Components.Colors.Gold
            coin.BorderSizePixel = 0
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = coin
            -- Borde oscuro y brillo arriba: se lee como una moneda y no como un punto.
            local rim = Instance.new("UIStroke")
            rim.Color = Color3.fromRGB(150, 100, 20)
            rim.Thickness = 1.5
            rim.Parent = coin
            local shine = Instance.new("UIGradient")
            shine.Rotation = 90
            shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
            shine.Parent = coin
            coin.Parent = gui
            local tween = TweenService:Create(
                coin,
                TweenInfo.new(
                    0.55,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.In,
                    0,
                    false,
                    (index - 1) * 0.04
                ),
                { Position = UDim2.fromScale(0.04, 0.06), BackgroundTransparency = 0.3 }
            )
            tween.Completed:Connect(function()
                coin:Destroy()
            end)
            tween:Play()
        end
        -- El contador se enciende y el panel da un pequeño salto cuando llegan.
        task.delay(0.55 + (count - 1) * 0.04, function()
            Components.Punch(coinsLabel, 0.15)
            Components.Punch(coinIcon, 0.25)
            coinsLabel.TextColor3 = Color3.new(1, 1, 1)
            TweenService
                :Create(coinsLabel, TweenInfo.new(0.4), { TextColor3 = Components.Colors.Gold })
                :Play()
        end)
    end

    local lastCoins: number? = nil
    local function showCoinGain(amount: number)
        local popup = Components.Label({
            text = string.format(Strings.Income.Collected, Format.Number(amount)),
            size = UDim2.fromScale(0.14, 0.04),
            position = UDim2.fromScale(0.24, 0.07),
            color = Components.Colors.Gold,
            alignment = Enum.TextXAlignment.Left,
            parent = gui,
        })
        popup.TextStrokeTransparency = 0.3
        local tween = TweenService:Create(
            popup,
            TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                Position = UDim2.fromScale(0.24, 0.02),
                TextTransparency = 1,
                TextStrokeTransparency = 1,
            }
        )
        tween.Completed:Connect(function()
            popup:Destroy()
        end)
        tween:Play()
    end

    local function updateStats()
        local data = DataController.GetData()
        if data == nil then
            return
        end
        if lastCoins and data.coins - lastCoins >= 1 then
            showCoinGain(data.coins - lastCoins)
            flyCoins(data.coins - lastCoins)
        end
        lastCoins = data.coins
        coinsLabel.Text = string.format(Strings.Hud.CoinsValue, Format.Number(data.coins))
        incomeLabel.Text = string.format(
            Strings.Hud.PerSecondShort,
            Format.Number(PlayerStats.GetIncomePerSecond(data))
        )
    end

    -- Mochila: recuento, cuánto frena la carga y color de aviso al llenarse.
    local carried = 0
    local backpackFull = false
    local backpackNearFull = false
    local function updateBackpack()
        local capacity = CarryController.GetCapacity()
        local before = carried
        carried = #CarryController.GetItems()
        local wasFull = backpackFull
        local wasNearFull = backpackNearFull
        backpackFull = capacity > 0 and carried >= capacity
        backpackNearFull = capacity > 0 and carried >= capacity * CarryConfig.NearFullFraction

        -- Aviso al acercarse al límite y aviso más fuerte al llenarse, solo cuando se cruza.
        if carried > before then
            if backpackFull and not wasFull then
                Sound.Play("BackpackFull")
                Effects.Flash(Components.Colors.Gold, 0.14, 0.5)
                local character = Players.LocalPlayer.Character
                local head = if character then character:FindFirstChild("Head") else nil
                if head and head:IsA("BasePart") then
                    Effects.Popup({
                        position = head.Position + Vector3.new(0, 3, 0),
                        text = Strings.Hud.BackpackFullPopup,
                        color = Components.Colors.Gold,
                        height = 1.8,
                    })
                end
            elseif backpackNearFull and not wasNearFull then
                Sound.Play("BackpackNearFull")
            end
        end

        local slowdown = math.min(carried * CarryConfig.SlowdownPerItem, CarryConfig.MaxSlowdown)
        backpackLabel.Text = string.format(Strings.Hud.BackpackCount, carried, capacity)
        slowLabel.Text = string.format(Strings.Hud.BackpackSlowShort, math.round(slowdown * 100))
        -- La barra se encoge para dejar sitio al aviso de lentitud cuando se carga algo.
        slowLabel.Visible = carried > 0
        backpackBar.Size = UDim2.fromScale(if carried > 0 then 0.5 else 0.82, 0.2)
        local color = if backpackFull
            then Components.Colors.Danger
            elseif backpackNearFull then Components.Colors.Gold
            else BACKPACK_COLOR
        backpackLabel.TextColor3 = if backpackFull or backpackNearFull
            then color
            else Components.Colors.Text
        backpackStroke.Color = color
        TweenService
            :Create(backpackFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                Size = UDim2.fromScale(
                    if capacity > 0 then math.min(carried / capacity, 1) else 0,
                    1
                ),
                BackgroundColor3 = color,
            })
            :Play()
    end

    -- Gira una flecha del HUD hacia un punto del mundo y devuelve la distancia en el plano.
    local function pointArrow(label: TextLabel, from: Vector3, target: Vector3): number?
        local camera = Workspace.CurrentCamera
        if camera == nil then
            return nil
        end
        local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
        local direction = (target - from) * Vector3.new(1, 0, 1)
        if look.Magnitude < 1e-3 or direction.Magnitude < 1e-3 then
            return nil
        end
        local unit = direction.Unit
        local forward = look.Unit
        -- Ángulo en pantalla: 0 = hacia delante, positivo = a la derecha.
        label.Rotation = -math.deg(math.atan2(forward:Cross(unit).Y, forward:Dot(unit)))
        return direction.Magnitude
    end

    local function updateBoosts()
        local data = DataController.GetData()
        if data == nil then
            return
        end
        local now = Workspace:GetServerTimeNow()
        local parts: { string } = {}
        for _, boost in BOOST_ORDER do
            local remaining = PlayerStats.GetBoostRemaining(data, boost, now)
            if remaining > 0 then
                table.insert(parts, `{BOOST_ICONS[boost]} {Format.Duration(remaining)}`)
            end
        end
        local friendBonus = PlayerStats.GetFriendBonus(data)
        if friendBonus > 0 then
            table.insert(parts, string.format(Strings.Social.Hud, math.round(friendBonus * 100)))
        end
        boostsLabel.Text = table.concat(parts, "   ")
        boostsCard.Visible = #parts > 0

        -- Avisos de los botones: recompensa diaria lista o misión terminada sin cobrar.
        local dailyBadge = badges.daily
        if dailyBadge then
            dailyBadge.Visible = data.daily.lastClaim <= 0
                or now - data.daily.lastClaim >= DailyConfig.Cooldown
        end
        local questsBadge = badges.quests
        if questsBadge then
            local ready = false
            for _, quest in QuestsConfig.List do
                if
                    PlayerStats.GetQuestProgress(data, quest.id, now) >= quest.goal
                    and not PlayerStats.IsQuestClaimed(data, quest.id, now)
                then
                    ready = true
                    break
                end
            end
            questsBadge.Visible = ready
        end
    end

    -- Nombre, tiempo restante, puesto y puntos del jugador en la competición en curso.
    local function updateCompetition()
        local kind = Workspace:GetAttribute("CompetitionKind")
        local endsAt = Workspace:GetAttribute("CompetitionEndsAt")
        if type(kind) ~= "string" or type(endsAt) ~= "number" then
            competitionPill.Visible = false
            return
        end
        local function scoreOf(player: Player): number
            local score = player:GetAttribute("CompetitionScore")
            return if type(score) == "number" then score else 0
        end
        local score = scoreOf(Players.LocalPlayer)
        local place = 1
        for _, player in Players:GetPlayers() do
            if scoreOf(player) > score then
                place += 1
            end
        end
        competitionLabel.Text = string.format(
            Strings.Competition.Hud,
            Strings.Competition.Names[kind] or kind,
            Format.Duration(endsAt - Workspace:GetServerTimeNow()),
            place,
            score
        )
        competitionPill.Visible = true
    end

    local function updateTutorial()
        local step = DataController.Get("tutorialStep")
        local text = if type(step) == "number" then Strings.Tutorial.Steps[step + 1] else nil
        tutorialLabel.Text = text or ""
        tutorialLabel.Visible = text ~= nil
    end

    -- Evento global: cuenta atrás, tiempo restante y un aviso grande cuando empieza.
    local announcedEvent: string? = nil
    local function updateEvent()
        local eventId = Workspace:GetAttribute("EventId")
        local startsAt = Workspace:GetAttribute("EventStartsAt")
        local endsAt = Workspace:GetAttribute("EventEndsAt")
        if type(eventId) ~= "string" then
            eventPill.Visible = false
            announcedEvent = nil
            return
        end
        local name = Strings.Events.Names[eventId] or eventId
        local now = Workspace:GetServerTimeNow()
        if type(endsAt) == "number" then
            eventLabel.Text =
                string.format(Strings.Events.HudActive, name, Format.Duration(endsAt - now))
            if announcedEvent ~= eventId then
                announcedEvent = eventId
                Banner.Show({
                    heading = Strings.Events.BannerHeading,
                    title = name,
                    subtitle = Strings.Events.Descriptions[eventId],
                    color = Color3.fromRGB(255, 150, 90),
                    sound = "EventStart",
                })
                Effects.Flash(Color3.fromRGB(255, 150, 90), 0.15, 0.8)
            end
        elseif type(startsAt) == "number" then
            eventLabel.Text =
                string.format(Strings.Events.HudCountdown, name, Format.Duration(startsAt - now))
        end
        eventPill.Visible = true
    end

    for _, key in
        {
            "coins",
            "pedestals",
            "inventory",
            "upgrades",
            "passes",
            "rebirths",
            "friendsOnline",
        }
    do
        DataController.OnChanged(key, updateStats)
    end
    DataController.OnChanged("tutorialStep", updateTutorial)
    CarryController.OnChanged(updateBackpack)
    updateStats()
    updateBackpack()
    updateTutorial()
    -- Al cambiar de idioma se repintan los contadores (lo que se actualiza cada fotograma o
    -- cada cuarto de segundo ya sale solo en el idioma nuevo).
    Locale.OnChanged(function()
        updateStats()
        updateBackpack()
        updateTutorial()
    end)

    local lastSlowUpdate = 0
    RunService.RenderStepped:Connect(function()
        local now = os.clock()
        if now - lastSlowUpdate >= 0.25 then
            lastSlowUpdate = now
            local nextAt = Workspace:GetAttribute("NextMeteorAt")
            nextMeteorPill.Visible = type(nextAt) == "number"
            if type(nextAt) == "number" then
                nextMeteorLabel.Text =
                    Format.Duration(math.max(nextAt - Workspace:GetServerTimeNow(), 0))
            end
            updateBoosts()
            updateCompetition()
            updateEvent()
        end

        local character = Players.LocalPlayer.Character
        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
        local position = if root and root:IsA("BasePart") then root.Position else nil

        -- Flecha al meteorito activo más cercano.
        local meteorDistance: number? = nil
        if position then
            local _, nearest = MeteorController.GetNearestMeteor(position, math.huge)
            if nearest then
                meteorDistance = pointArrow(arrow, position, nearest)
            end
        end
        arrow.Visible = meteorDistance ~= nil
        distanceLabel.Visible = meteorDistance ~= nil
        if meteorDistance then
            distanceLabel.Text =
                string.format(Strings.Hud.MeteorDistance, math.floor(meteorDistance))
        end

        -- Flecha a la base (al llevar minerales) y aviso de zona segura.
        local inside = position ~= nil and BaseController.IsInside(position)
        safeLabel.Visible = inside
        local basePosition = BaseController.GetPosition()
        local baseDistance: number? = nil
        if position and basePosition and carried > 0 and not inside then
            baseDistance = pointArrow(baseArrow, position, basePosition)
        end
        baseArrow.Visible = baseDistance ~= nil
        baseDistanceLabel.Visible = baseDistance ~= nil
        if baseDistance then
            baseDistanceLabel.Text = string.format(
                if backpackFull then Strings.Hud.BaseDistanceFull else Strings.Hud.BaseDistance,
                math.floor(baseDistance)
            )
            -- Con la mochila llena parpadea para llamar la atención.
            local color = if backpackFull and now % 0.8 < 0.4
                then Components.Colors.Gold
                else Components.Colors.Success
            baseArrow.TextColor3 = color
            baseDistanceLabel.TextColor3 = color
        end
    end)

    Offers.Mount(gui)
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return Hud
