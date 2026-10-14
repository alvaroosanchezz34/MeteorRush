--!strict

-- HUD: monedas, ingresos por segundo, mochila, boosts activos, cuenta atrás del próximo
-- meteorito, flecha hacia el meteorito activo más cercano, botones laterales de los menús
-- y texto del tutorial.

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
local InventoryMenu = require(script.Parent.InventoryMenu)
local MeteorController = require(script.Parent.Parent.Controllers.MeteorController)
local PermanentMenu = require(script.Parent.PermanentMenu)
local PlayersMenu = require(script.Parent.PlayersMenu)
local ProfileMenu = require(script.Parent.ProfileMenu)
local QuestsMenu = require(script.Parent.QuestsMenu)
local RebirthMenu = require(script.Parent.RebirthMenu)
local SeasonMenu = require(script.Parent.SeasonMenu)
local ShopMenu = require(script.Parent.ShopMenu)
local Sound = require(script.Parent.Sound)
local TabbedMenu = require(script.Parent.TabbedMenu)
local Theme = require(script.Parent.Theme)
local TradeMenu = require(script.Parent.TradeMenu)
local UpgradesMenu = require(script.Parent.UpgradesMenu)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarryConfig = require(Shared:WaitForChild("Config"):WaitForChild("Carry"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
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

local BOOST_NAMES: { [string]: string } = {
    carryShield = "carryShield30",
    magnet = "magnet30",
    luck = "luck30",
}

local Hud = {}

local function makeStatLabel(parent: Instance, order: number, color: Color3?): TextLabel
    return Components.Label({
        text = "",
        size = UDim2.fromScale(1, 0.24),
        alignment = Enum.TextXAlignment.Left,
        color = color,
        layoutOrder = order,
        parent = parent,
    })
end

function Hud.Mount()
    local gui = Instance.new("ScreenGui")
    gui.Name = "Hud"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Estadísticas (arriba a la izquierda) ------------------------------------
    local stats = Components.Panel({
        size = UDim2.fromScale(0.22, 0.17),
        position = UDim2.fromScale(0.01, 0.02),
        color = Components.Colors.Background,
        transparency = 0.3,
        parent = gui,
    })
    local statsPadding = Instance.new("UIPadding")
    statsPadding.PaddingLeft = UDim.new(0.05, 0)
    statsPadding.PaddingTop = UDim.new(0.04, 0)
    statsPadding.Parent = stats
    local statsStroke = Instance.new("UIStroke")
    statsStroke.Color = Components.Colors.Gold
    statsStroke.Thickness = 2
    statsStroke.Transparency = 0.3
    statsStroke.Parent = stats
    local statsLayout = Instance.new("UIListLayout")
    statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    statsLayout.Parent = stats

    local coinsLabel = makeStatLabel(stats, 1, Components.Colors.Gold)
    local incomeLabel = makeStatLabel(stats, 2)
    local backpackLabel = makeStatLabel(stats, 3)
    local boostsLabel = makeStatLabel(stats, 4, Components.Colors.Muted)

    -- Próximo meteorito y flecha (arriba en el centro) ------------------------
    local nextMeteorPill = Components.Panel({
        size = UDim2.fromScale(0.26, 0.05),
        position = UDim2.fromScale(0.37, 0.012),
        color = Components.Colors.Background,
        transparency = 0.3,
        parent = gui,
    })
    local nextMeteorLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.92, 0.76),
        position = UDim2.fromScale(0.04, 0.12),
        parent = nextMeteorPill,
    })
    nextMeteorLabel.TextStrokeTransparency = 0.4
    local arrow = Components.Label({
        text = "▲",
        size = UDim2.fromScale(0.04, 0.06),
        position = UDim2.fromScale(0.48, 0.065),
        color = Color3.fromRGB(255, 90, 60),
        parent = gui,
    })
    local arrowAspect = Instance.new("UIAspectRatioConstraint")
    arrowAspect.AspectRatio = 1
    arrowAspect.Parent = arrow
    local distanceLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.12, 0.03),
        position = UDim2.fromScale(0.44, 0.13),
        parent = gui,
    })
    distanceLabel.TextStrokeTransparency = 0.4

    -- Competición de servidor en curso (arriba, a la derecha del próximo meteorito).
    local competitionPill = Components.Panel({
        size = UDim2.fromScale(0.19, 0.05),
        position = UDim2.fromScale(0.645, 0.012),
        color = Components.Colors.Background,
        transparency = 0.3,
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
    local eventPill = Components.Panel({
        size = UDim2.fromScale(0.19, 0.05),
        position = UDim2.fromScale(0.645, 0.068),
        color = Components.Colors.Background,
        transparency = 0.3,
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
        position = UDim2.fromScale(0.6, 0.065),
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
        position = UDim2.fromScale(0.54, 0.13),
        color = Components.Colors.Success,
        parent = gui,
    })
    baseDistanceLabel.TextStrokeTransparency = 0.4
    baseDistanceLabel.Visible = false

    -- Aviso de zona segura: dentro de la base propia nadie puede robarte.
    local safeLabel = Components.Label({
        text = Strings.Hud.SafeZone,
        size = UDim2.fromScale(0.2, 0.04),
        position = UDim2.fromScale(0.4, 0.17),
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
        size = UDim2.fromScale(0.6, 0.06),
        position = UDim2.fromScale(0.2, 0.8),
        color = Components.Colors.Gold,
        parent = gui,
    })
    tutorialLabel.BackgroundColor3 = Components.Colors.Background
    tutorialLabel.BackgroundTransparency = 0.3
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
    sideBar.Size = UDim2.fromScale(0.16, 0.56)
    sideBar.Position = UDim2.fromScale(0.01, 0.22)
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
    for order, menu in MENUS do
        local title = if menu.key == "inventory"
            then Strings.Inventory.Title
            else Strings.Hud.Buttons[menu.key]
        local window = Components.Window({
            title = title,
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

        Components.IconButton({
            icon = Theme.Icons[menu.key] or "",
            text = Strings.Hud.Buttons[menu.key],
            layoutOrder = order,
            color = Theme.Accents[menu.key] or Components.Colors.Primary,
            parent = sideBar,
            onClick = function()
                window.Toggle()
            end,
        })
    end

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
            text = if destination == "outpost" then Strings.Hud.Outpost else Strings.Hud.Home,
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
    local COIN_FLY_GAP = 1.5
    local COIN_FLY_COUNT = 6
    local lastCoinFly = 0
    local function flyCoins()
        local now = os.clock()
        if now - lastCoinFly < COIN_FLY_GAP then
            return
        end
        lastCoinFly = now
        for index = 1, COIN_FLY_COUNT do
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
                { Position = UDim2.fromScale(0.05, 0.045), BackgroundTransparency = 0.3 }
            )
            tween.Completed:Connect(function()
                coin:Destroy()
            end)
            tween:Play()
        end
        -- El contador se enciende un momento cuando llegan.
        task.delay(0.55, function()
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
            flyCoins()
        end
        lastCoins = data.coins
        coinsLabel.Text = string.format(Strings.Hud.Coins, Format.Number(data.coins))
        incomeLabel.Text = string.format(
            Strings.Hud.PerSecond,
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
        backpackLabel.Text = if carried > 0
            then string.format(
                Strings.Hud.BackpackSlow,
                carried,
                capacity,
                math.round(slowdown * 100)
            )
            else string.format(Strings.Hud.Backpack, carried, capacity)
        backpackLabel.TextColor3 = if backpackFull
            then Components.Colors.Danger
            elseif backpackNearFull then Components.Colors.Gold
            else Components.Colors.Text
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
        for boost, productKey in BOOST_NAMES do
            local remaining = PlayerStats.GetBoostRemaining(data, boost, now)
            if remaining > 0 then
                table.insert(parts, `{Strings.Shop.Names[productKey]} {Format.Duration(remaining)}`)
            end
        end
        local friendBonus = PlayerStats.GetFriendBonus(data)
        if friendBonus > 0 then
            table.insert(parts, string.format(Strings.Social.Hud, math.round(friendBonus * 100)))
        end
        boostsLabel.Text = table.concat(parts, "  ")
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

    local lastSlowUpdate = 0
    RunService.RenderStepped:Connect(function()
        local now = os.clock()
        if now - lastSlowUpdate >= 0.25 then
            lastSlowUpdate = now
            local nextAt = Workspace:GetAttribute("NextMeteorAt")
            nextMeteorLabel.Text = if type(nextAt) == "number"
                then string.format(
                    Strings.Hud.NextMeteor,
                    Format.Duration(nextAt - Workspace:GetServerTimeNow())
                )
                else ""
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

    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return Hud
