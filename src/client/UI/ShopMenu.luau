--!strict

-- Tienda: packs, game passes, boosts, paquetes de monedas y cosméticos.
-- Se abre al pulsar su botón, desde el "+" de las monedas o desde una oferta (ShopMenu.Select
-- elige la pestaña). Un id 0 muestra "Coming soon" y no lanza la compra.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local LiveOps = require(Shared:WaitForChild("Config"):WaitForChild("LiveOps"))
local PlayerStats = require(Shared:WaitForChild("Util"):WaitForChild("PlayerStats"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShopConfig = require(Shared:WaitForChild("Config"):WaitForChild("Shop"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))

local TABS = { "packs", "passes", "boosts", "coins", "cosmetics" }
-- Segundos que un botón queda en espera tras pulsarlo (mientras responde Roblox o el servidor).
local BUSY_SECONDS = 2

type Entry = {
    key: string,
    name: string,
    description: string,
    swatch: Color3?,
    buttonText: string,
    buttonColor: Color3,
    onClick: (() -> ())?,
    -- Etiqueta destacada en la esquina de la fila ("MEJOR VALOR").
    tag: string?,
}

local ShopMenu = {}

-- Pestaña que se enseñará la próxima vez que se pinte la tienda.
local currentTab = TABS[1]
local refreshShop: (() -> ())? = nil

local function priceButton(id: number, price: number): (string, Color3)
    if id == 0 then
        return Strings.Shop.ComingSoon, Components.Colors.Disabled
    end
    return string.format(Strings.Shop.Buy, price), Components.Colors.Success
end

local function buildEntries(tab: string, data: Types.Profile): { Entry }
    local player = Players.LocalPlayer
    local entries: { Entry } = {}

    if tab == "packs" then
        for _, product in ShopConfig.Products do
            if product.kind == "bundle" or product.kind == "meteor" then
                local bought = product.oncePerAccount == true and data.offers[product.key] == true
                local description = Strings.Shop.Descriptions[product.key]
                if product.kind == "bundle" then
                    description = string.format(
                        description,
                        Format.Number(PlayerStats.GetCoinPackAmount(data, product))
                    )
                end
                local text, color = priceButton(product.id, product.price)
                table.insert(entries, {
                    key = product.key,
                    name = Strings.Shop.Names[product.key],
                    description = description,
                    buttonText = if bought then Strings.Shop.Owned else text,
                    buttonColor = if bought then Components.Colors.Disabled else color,
                    onClick = if bought or product.id == 0
                        then nil
                        else function()
                            MarketplaceService:PromptProductPurchase(player, product.id)
                        end,
                    tag = if product.key == "megaPack"
                        then Strings.Shop.BestValue
                        elseif product.oncePerAccount then Strings.Upper(
                            Strings.Shop.OncePerAccount
                        )
                        else nil,
                })
            end
        end
    elseif tab == "passes" then
        for _, pass in ShopConfig.GamePasses do
            local owned = PlayerStats.HasPass(data, pass.key)
            local text, color = priceButton(pass.id, pass.price)
            table.insert(entries, {
                key = pass.key,
                name = Strings.Shop.Names[pass.key],
                description = Strings.Shop.Descriptions[pass.key],
                buttonText = if owned then Strings.Shop.Owned else text,
                buttonColor = if owned then Components.Colors.Disabled else color,
                onClick = if owned or pass.id == 0
                    then nil
                    else function()
                        MarketplaceService:PromptGamePassPurchase(player, pass.id)
                    end,
            })
        end
    else
        for _, product in ShopConfig.Products do
            local isBoost = product.kind == "boost"
            if (tab == "boosts" and isBoost) or (tab == "coins" and product.kind == "coins") then
                local description = Strings.Shop.Descriptions[product.key]
                if not isBoost then
                    description = string.format(
                        Strings.Shop.Descriptions.coins,
                        Format.Number(PlayerStats.GetCoinPackAmount(data, product))
                    )
                elseif product.boost then
                    local remaining = PlayerStats.GetBoostRemaining(
                        data,
                        product.boost,
                        Workspace:GetServerTimeNow()
                    )
                    if remaining > 0 then
                        description ..= "  " .. string.format(
                            Strings.Shop.BoostActive,
                            Format.Duration(remaining)
                        )
                    end
                end
                local text, color = priceButton(product.id, product.price)
                table.insert(entries, {
                    key = product.key,
                    name = Strings.Shop.Names[product.key],
                    description = description,
                    buttonText = text,
                    buttonColor = color,
                    onClick = if product.id == 0
                        then nil
                        else function()
                            MarketplaceService:PromptProductPurchase(player, product.id)
                        end,
                })
            end
        end
    end

    if tab == "cosmetics" then
        for _, cosmetic in ShopConfig.Cosmetics do
            local owned = PlayerStats.OwnsCosmetic(data, cosmetic)
            local equipped = data.cosmetics.equipped[cosmetic.kind] == cosmetic.key
            local text, color, onClick
            if owned then
                text = if equipped then Strings.Shop.Equipped else Strings.Shop.Equip
                color = if equipped then Components.Colors.Gold else Components.Colors.Primary
                onClick = function()
                    Remotes.EquipCosmetic:FireServer(cosmetic.key, not equipped)
                end
            elseif cosmetic.vipOnly then
                text, color = Strings.Shop.VipOnly, Components.Colors.Disabled
            elseif cosmetic.crate then
                text, color = Strings.Shop.CrateOnly, Components.Colors.Disabled
            elseif cosmetic.bundle then
                text, color = Strings.Shop.BundleOnly, Components.Colors.Disabled
            elseif cosmetic.season then
                text, color = Strings.Shop.SeasonOnly, Components.Colors.Disabled
            elseif cosmetic.rebirthsRequired then
                text = string.format(Strings.Shop.RebirthOnly, cosmetic.rebirthsRequired)
                color = Components.Colors.Disabled
            else
                text, color = priceButton(cosmetic.id, cosmetic.price)
                if cosmetic.id ~= 0 then
                    onClick = function()
                        MarketplaceService:PromptProductPurchase(player, cosmetic.id)
                    end
                end
            end
            -- Los cosméticos de una temporada que ya pasó solo los ve quien los consiguió.
            local season = LiveOps.GetSeason(Workspace:GetServerTimeNow())
            local expired = cosmetic.season ~= nil
                and not owned
                and (season == nil or season.id ~= cosmetic.season)
            if not expired then
                table.insert(entries, {
                    key = cosmetic.key,
                    name = Strings.Shop.Names[cosmetic.key],
                    description = Strings.Shop.Descriptions[cosmetic.kind],
                    swatch = cosmetic.color,
                    buttonText = text,
                    buttonColor = color,
                    onClick = onClick,
                })
            end
        end
    end
    return entries
end

-- Elige la pestaña que se enseña ("packs", "passes", "boosts", "coins" o "cosmetics").
function ShopMenu.Select(tab: string)
    if table.find(TABS, tab) then
        currentTab = tab
        if refreshShop then
            refreshShop()
        end
    end
end

function ShopMenu.Mount(window: Components.Window)
    local tabBar = Instance.new("Frame")
    tabBar.BackgroundTransparency = 1
    tabBar.Size = UDim2.fromScale(1, 0.1)
    tabBar.Parent = window.content
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0.01, 0)
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = tabBar

    local list = Components.ScrollList({
        size = UDim2.fromScale(1, 0.88),
        position = UDim2.fromScale(0, 0.12),
        cellSize = UDim2.fromScale(0.98, 0.2),
        parent = window.content,
    })

    local tabButtons: { [string]: TextButton } = {}
    local refresh: () -> ()

    for order, tab in TABS do
        tabButtons[tab] = Components.Button({
            text = function(): string
                return Strings.Shop.Tabs[tab]
            end,
            size = UDim2.fromScale(0.19, 1),
            layoutOrder = order,
            parent = tabBar,
            onClick = function()
                currentTab = tab
                refresh()
            end,
        })
    end

    refresh = function()
        if not window.IsOpen() then
            return
        end
        for tab, button in tabButtons do
            button.BackgroundColor3 = if tab == currentTab
                then Components.Colors.Primary
                else Components.Colors.Panel
        end
        Components.Clear(list)
        local data = DataController.GetData()
        if data == nil then
            return
        end

        for order, entry in buildEntries(currentTab, data) do
            local row = Components.Panel({ size = UDim2.new(), layoutOrder = order, parent = list })
            local textX = 0.03
            if entry.swatch then
                local swatch = Components.Panel({
                    size = UDim2.fromScale(0.08, 0.7),
                    position = UDim2.fromScale(0.02, 0.15),
                    color = entry.swatch,
                    parent = row,
                })
                local aspect = Instance.new("UIAspectRatioConstraint")
                aspect.AspectRatio = 1
                aspect.Parent = swatch
                textX = 0.12
            end
            Components.Label({
                text = entry.name,
                size = UDim2.fromScale(0.6 - textX, 0.42),
                position = UDim2.fromScale(textX, 0.08),
                alignment = Enum.TextXAlignment.Left,
                parent = row,
            })
            Components.Label({
                text = entry.description,
                size = UDim2.fromScale(0.62 - textX, 0.42),
                position = UDim2.fromScale(textX, 0.52),
                alignment = Enum.TextXAlignment.Left,
                color = Components.Colors.Muted,
                parent = row,
            })
            local tag = entry.tag
            if tag then
                row.BackgroundColor3 = Components.Colors.PanelRaised
                local stroke = row:FindFirstChildOfClass("UIStroke")
                if stroke then
                    stroke.Color = Components.Colors.Gold
                    stroke.Transparency = 0.2
                end
                local badge = Components.Label({
                    text = tag,
                    size = UDim2.fromScale(0.3, 0.22),
                    position = UDim2.fromScale(0.67, 0.05),
                    color = Components.Colors.TextDark,
                    heading = true,
                    parent = row,
                })
                badge.BackgroundColor3 = Components.Colors.Gold
                badge.BackgroundTransparency = 0
                badge.ZIndex = 3
                local badgeCorner = Instance.new("UICorner")
                badgeCorner.CornerRadius = UDim.new(0.5, 0)
                badgeCorner.Parent = badge
            end
            local onClick = entry.onClick
            local button: TextButton
            button = Components.Button({
                text = entry.buttonText,
                -- Con etiqueta, el botón baja para dejarle sitio encima.
                size = UDim2.fromScale(0.3, if tag then 0.58 else 0.66),
                position = UDim2.fromScale(0.67, if tag then 0.33 else 0.17),
                color = entry.buttonColor,
                parent = row,
                onClick = function()
                    if onClick and not button:GetAttribute("Busy") then
                        Components.SetBusy(button, BUSY_SECONDS)
                        onClick()
                    end
                end,
            })
        end
    end

    refreshShop = refresh
    window.OnOpened(refresh)
    for _, key in { "passes", "boosts", "cosmetics", "rebirths", "offers" } do
        DataController.OnChanged(key, refresh)
    end
end

return ShopMenu
