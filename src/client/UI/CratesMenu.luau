--!strict

-- Cajas de equipamiento: una fila por caja con su modelo, sus probabilidades (siempre a la
-- vista), el seguro de mala suerte, cuántas tiene el jugador y los botones de comprar y abrir.
-- Comprar y abrir los decide el servidor (CrateService); el resultado llega por el remote
-- CrateResult y lo presenta UI/CrateOpening.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local GearView = require(script.Parent.GearView)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Crates = require(Config:WaitForChild("Crates"))
local Equipment = require(Config:WaitForChild("Equipment"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local CratesMenu = {}

function CratesMenu.Mount(window: Components.Window)
    local player = Players.LocalPlayer
    local header = Components.Label({
        text = Strings.Crates.Contents,
        size = UDim2.fromScale(0.62, 0.07),
        alignment = Enum.TextXAlignment.Left,
        color = Components.Colors.Muted,
        parent = window.content,
    })
    header.Name = "Header"
    local dustLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.34, 0.07),
        position = UDim2.fromScale(0.66, 0),
        alignment = Enum.TextXAlignment.Right,
        color = Components.Colors.Gold,
        parent = window.content,
    })
    local list = Components.ScrollList({
        size = UDim2.fromScale(1, 0.91),
        position = UDim2.fromScale(0, 0.09),
        cellSize = UDim2.fromScale(0.98, 0.3),
        parent = window.content,
    })

    -- Las filas se crean una vez (los visores con el modelo girando no se rehacen en cada
    -- cambio de datos); después solo se actualizan los textos y los botones.
    type Row = { owned: TextLabel, pity: TextLabel, buy: TextButton, open: TextButton }
    local rows: { [string]: Row } = {}

    for order, crate in Crates.List do
        local color = Equipment.Rarities[crate.rarity].color
        local row = Components.Panel({ size = UDim2.new(), layoutOrder = order, parent = list })
        local stroke = row:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = color
            stroke.Transparency = 0.45
        end
        GearView.Create({
            kind = "crate",
            id = crate.id,
            size = UDim2.fromScale(0.17, 0.92),
            position = UDim2.fromScale(0.01, 0.04),
            spin = false,
            parent = row,
        })
        Components.Label({
            text = Strings.Crates.Names[crate.id] or crate.id,
            size = UDim2.fromScale(0.4, 0.24),
            position = UDim2.fromScale(0.19, 0.05),
            alignment = Enum.TextXAlignment.Left,
            color = color,
            heading = true,
            parent = row,
        })
        Components.Label({
            text = `{Strings.Crates.Odds}: {GearView.OddsText(crate)}`,
            size = UDim2.fromScale(0.55, 0.2),
            position = UDim2.fromScale(0.19, 0.32),
            alignment = Enum.TextXAlignment.Left,
            parent = row,
        })
        local pity = Components.Label({
            text = "",
            size = UDim2.fromScale(0.55, 0.16),
            position = UDim2.fromScale(0.19, 0.55),
            alignment = Enum.TextXAlignment.Left,
            color = Components.Colors.Muted,
            parent = row,
        })
        local owned = Components.Label({
            text = "",
            size = UDim2.fromScale(0.3, 0.18),
            position = UDim2.fromScale(0.19, 0.76),
            alignment = Enum.TextXAlignment.Left,
            color = Components.Colors.Gold,
            parent = row,
        })
        local buy = Components.Button({
            text = "",
            size = UDim2.fromScale(0.22, 0.4),
            position = UDim2.fromScale(0.76, 0.07),
            color = Components.Colors.Primary,
            parent = row,
            onClick = function()
                Remotes.BuyCrate:FireServer(crate.id)
            end,
        })
        local open = Components.Button({
            text = Strings.Crates.Open,
            size = UDim2.fromScale(0.22, 0.4),
            position = UDim2.fromScale(0.76, 0.53),
            color = Components.Colors.Success,
            parent = row,
            onClick = function()
                Remotes.OpenCrate:FireServer(crate.id)
            end,
        })
        rows[crate.id] = { owned = owned, pity = pity, buy = buy, open = open }
    end

    local function refresh()
        if not window.IsOpen() then
            return
        end
        local data = DataController.GetData()
        if data == nil then
            return
        end
        dustLabel.Text = string.format(Strings.Equipment.Dust, Format.Number(data.equipment.dust))
        local restricted = player:GetAttribute("CratesRestricted") == true
        for _, crate in Crates.List do
            local row = rows[crate.id]
            local stored = data.equipment.crates[crate.id] or 0
            row.owned.Text = string.format(Strings.Crates.Owned, stored)
            row.open.BackgroundColor3 = if stored > 0
                then Components.Colors.Success
                else Components.Colors.Disabled

            local pity = crate.pity
            row.pity.Text = if pity.enabled
                then string.format(
                    Strings.Crates.Pity,
                    Strings.Equipment.Rarities[pity.minimum],
                    math.max(pity.threshold - (data.equipment.pity[crate.id] or 0), 1)
                )
                else ""

            local currency, price = Crates.GetCost(crate, data)
            if currency == nil then
                row.buy.Text = Strings.Crates.NotForSale
                row.buy.BackgroundColor3 = Components.Colors.Disabled
            elseif currency == "coins" then
                row.buy.Text = string.format(Strings.Crates.BuyCoins, Format.Number(price))
                row.buy.BackgroundColor3 = if restricted or data.coins < price
                    then Components.Colors.Disabled
                    else Components.Colors.Primary
            else
                row.buy.Text = string.format(Strings.Crates.BuyDust, Format.Number(price))
                row.buy.BackgroundColor3 = if data.equipment.dust < price
                    then Components.Colors.Disabled
                    else Components.Colors.Primary
            end
        end
        header.Text = if restricted then Strings.Crates.Restricted else Strings.Crates.Contents
    end

    window.OnOpened(refresh)
    for _, key in { "equipment", "coins", "rebirths" } do
        DataController.OnChanged(key, refresh)
    end
    player:GetAttributeChangedSignal("CratesRestricted"):Connect(refresh)
end

return CratesMenu
