--!strict

-- HUD: monedas, ingresos por segundo, mochila, boosts activos, cuenta atrás del próximo
-- meteorito, flecha hacia el meteorito activo más cercano, botones laterales de los menús
-- y texto del tutorial.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CarryController = require(script.Parent.Parent.Controllers.CarryController)
local Components = require(script.Parent.Components)
local DailyMenu = require(script.Parent.DailyMenu)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local IndexMenu = require(script.Parent.IndexMenu)
local InventoryMenu = require(script.Parent.InventoryMenu)
local MeteorController = require(script.Parent.Parent.Controllers.MeteorController)
local RebirthMenu = require(script.Parent.RebirthMenu)
local ShopMenu = require(script.Parent.ShopMenu)
local Sound = require(script.Parent.Sound)
local TradeMenu = require(script.Parent.TradeMenu)
local UpgradesMenu = require(script.Parent.UpgradesMenu)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local PlayerStats = require(Shared:WaitForChild("Util"):WaitForChild("PlayerStats"))
local Strings = require(Shared:WaitForChild("Strings"))

type MenuModule = { Mount: (window: Components.Window) -> () }

local MENUS: { { key: string, module: MenuModule } } = {
    { key = "inventory", module = InventoryMenu },
    { key = "upgrades", module = UpgradesMenu },
    { key = "shop", module = ShopMenu },
    { key = "index", module = IndexMenu },
    { key = "daily", module = DailyMenu },
    { key = "rebirth", module = RebirthMenu },
    { key = "trade", module = TradeMenu },
}

local MENU_COLORS: { [string]: Color3 } = {
    inventory = Color3.fromRGB(60, 170, 200),
    upgrades = Color3.fromRGB(80, 190, 90),
    shop = Color3.fromRGB(235, 90, 150),
    index = Color3.fromRGB(150, 100, 240),
    daily = Color3.fromRGB(245, 140, 50),
    rebirth = Color3.fromRGB(250, 195, 50),
    trade = Color3.fromRGB(70, 130, 245),
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
        local window =
            Components.Window({ title = title, closeText = Strings.Hud.Close, parent = gui })
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
            icon = Strings.Hud.Icons[menu.key] or "",
            text = Strings.Hud.Buttons[menu.key],
            layoutOrder = order,
            color = MENU_COLORS[menu.key] or Components.Colors.Primary,
            parent = sideBar,
            onClick = function()
                Sound.Play("UiClick")
                window.Toggle()
            end,
        })
    end

    -- Actualización de valores -------------------------------------------------
    -- Texto "+$X" que sube y se desvanece junto al panel cada vez que entran monedas.
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
        end
        lastCoins = data.coins
        coinsLabel.Text = string.format(Strings.Hud.Coins, Format.Number(data.coins))
        incomeLabel.Text = string.format(
            Strings.Hud.PerSecond,
            Format.Number(PlayerStats.GetIncomePerSecond(data))
        )
    end

    local function updateBackpack()
        backpackLabel.Text = string.format(
            Strings.Hud.Backpack,
            #CarryController.GetItems(),
            CarryController.GetCapacity()
        )
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
        boostsLabel.Text = table.concat(parts, "  ")
    end

    local function updateTutorial()
        local step = DataController.Get("tutorialStep")
        local text = if type(step) == "number" then Strings.Tutorial.Steps[step + 1] else nil
        tutorialLabel.Text = text or ""
        tutorialLabel.Visible = text ~= nil
    end

    for _, key in { "coins", "pedestals", "inventory", "upgrades", "passes", "rebirths" } do
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
        end

        local character = Players.LocalPlayer.Character
        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
        local camera = Workspace.CurrentCamera
        local position = if root and root:IsA("BasePart") then root.Position else nil
        local meteorPosition: Vector3? = nil
        if position then
            local _, nearest = MeteorController.GetNearestMeteor(position, math.huge)
            meteorPosition = nearest
        end
        if position == nil or meteorPosition == nil or camera == nil then
            arrow.Visible = false
            distanceLabel.Visible = false
            return
        end

        local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
        local direction = (meteorPosition - position) * Vector3.new(1, 0, 1)
        if look.Magnitude < 1e-3 or direction.Magnitude < 1e-3 then
            return
        end
        look = look.Unit
        local unit = direction.Unit
        -- Ángulo en pantalla: 0 = hacia delante, positivo = a la derecha.
        local angle = -math.deg(math.atan2(look:Cross(unit).Y, look:Dot(unit)))
        arrow.Rotation = angle
        arrow.Visible = true
        distanceLabel.Visible = true
        distanceLabel.Text =
            string.format(Strings.Hud.MeteorDistance, math.floor(direction.Magnitude))
    end)

    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return Hud
