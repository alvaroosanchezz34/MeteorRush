--!strict

-- Inventario de la base: colocar minerales en pedestales y quitarlos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local RarityStyle = require(script.Parent.RarityStyle)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Minerals = require(Shared:WaitForChild("Config"):WaitForChild("Minerals"))
local Mutations = require(Shared:WaitForChild("Config"):WaitForChild("Mutations"))
local PlayerStats = require(Shared:WaitForChild("Util"):WaitForChild("PlayerStats"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))

local InventoryMenu = {}

function InventoryMenu.Mount(window: Components.Window)
    local header = Components.Label({
        text = "",
        size = UDim2.fromScale(0.5, 0.08),
        alignment = Enum.TextXAlignment.Left,
        color = Components.Colors.Muted,
        parent = window.content,
    })
    Components.Button({
        text = Strings.Inventory.PlaceBest,
        size = UDim2.fromScale(0.23, 0.085),
        position = UDim2.fromScale(0.52, 0),
        color = Components.Colors.Success,
        parent = window.content,
        onClick = function()
            Remotes.PlaceBest:FireServer()
        end,
    })
    Components.Button({
        text = Strings.Inventory.SellJunk,
        size = UDim2.fromScale(0.23, 0.085),
        position = UDim2.fromScale(0.76, 0),
        color = Components.Colors.Gold,
        parent = window.content,
        onClick = function()
            Remotes.SellJunk:FireServer()
        end,
    })
    local list = Components.ScrollList({
        size = UDim2.fromScale(1, 0.9),
        position = UDim2.fromScale(0, 0.1),
        cellSize = UDim2.fromScale(0.98, 0.14),
        parent = window.content,
    })

    local function refresh()
        if not window.IsOpen() then
            return
        end
        local data = DataController.GetData()
        Components.Clear(list)
        if data == nil then
            return
        end

        local used = 0
        for _ in data.pedestals do
            used += 1
        end
        header.Text =
            string.format(Strings.Inventory.Pedestals, used, PlayerStats.GetPedestalCount(data))

        if #data.inventory == 0 then
            Components.Label({
                text = Strings.Inventory.Empty,
                size = UDim2.fromScale(1, 1),
                color = Components.Colors.Muted,
                parent = list,
            })
            return
        end

        local multiplier = PlayerStats.GetIncomeMultiplier(data)
        local items = table.clone(data.inventory)
        table.sort(items, function(a: Types.InventoryItem, b: Types.InventoryItem): boolean
            return PlayerStats.GetItemBaseIncome(a) > PlayerStats.GetItemBaseIncome(b)
        end)

        -- Cuántos minerales iguales hay fuera de los pedestales (para el botón de fusionar).
        local fusable: { [string]: number } = {}
        for _, item in items do
            if
                PlayerStats.GetPedestalOf(data, item.id) == nil
                and Mutations.GetNext(item.mutation) ~= nil
            then
                local key = `{item.mineral}:{item.mutation}`
                fusable[key] = (fusable[key] or 0) + 1
            end
        end

        for order, item in items do
            local row = Components.Panel({ size = UDim2.new(), layoutOrder = order, parent = list })
            local mineral = Minerals.ById[item.mineral]
            local rarityColor = if mineral
                then Minerals.Rarities[mineral.rarity].color
                else Components.Colors.Text

            local nameLabel = Components.Label({
                text = RarityStyle.Text(item.mineral, item.mutation),
                size = UDim2.fromScale(0.32, 0.5),
                position = UDim2.fromScale(0.03, 0.08),
                alignment = Enum.TextXAlignment.Left,
                color = rarityColor,
                parent = row,
            })
            RarityStyle.Apply(nameLabel, item.mineral, item.mutation)
            Components.Label({
                text = string.format(
                    Strings.Pedestal.PerSecond,
                    Format.Number(PlayerStats.GetItemBaseIncome(item) * multiplier)
                ),
                size = UDim2.fromScale(0.25, 0.4),
                position = UDim2.fromScale(0.03, 0.55),
                alignment = Enum.TextXAlignment.Left,
                color = Components.Colors.Gold,
                parent = row,
            })

            local pedestal = PlayerStats.GetPedestalOf(data, item.id)
            if pedestal then
                Components.Label({
                    text = string.format(Strings.Inventory.OnPedestal, pedestal),
                    size = UDim2.fromScale(0.22, 0.5),
                    position = UDim2.fromScale(0.5, 0.25),
                    color = Components.Colors.Muted,
                    parent = row,
                })
                Components.Button({
                    text = Strings.Inventory.Remove,
                    size = UDim2.fromScale(0.22, 0.7),
                    position = UDim2.fromScale(0.76, 0.15),
                    color = Components.Colors.Danger,
                    parent = row,
                    onClick = function()
                        Remotes.RemoveMineral:FireServer(pedestal)
                    end,
                })
            else
                local key = `{item.mineral}:{item.mutation}`
                if (fusable[key] or 0) >= Mutations.FuseCount then
                    Components.Button({
                        text = string.format(
                            Strings.Inventory.Fuse,
                            Format.Number(PlayerStats.GetFuseCost(item))
                        ),
                        size = UDim2.fromScale(0.14, 0.7),
                        position = UDim2.fromScale(0.36, 0.15),
                        color = Components.Colors.Primary,
                        parent = row,
                        onClick = function()
                            Remotes.FuseMineral:FireServer(item.id)
                        end,
                    })
                end
                Components.Button({
                    text = string.format(
                        Strings.Inventory.Sell,
                        Format.Number(PlayerStats.GetSellPrice(item))
                    ),
                    size = UDim2.fromScale(0.22, 0.7),
                    position = UDim2.fromScale(0.52, 0.15),
                    color = Components.Colors.Gold,
                    parent = row,
                    onClick = function()
                        Remotes.SellMineral:FireServer(item.id)
                    end,
                })
                Components.Button({
                    text = Strings.Inventory.Place,
                    size = UDim2.fromScale(0.22, 0.7),
                    position = UDim2.fromScale(0.76, 0.15),
                    color = Components.Colors.Success,
                    parent = row,
                    onClick = function()
                        Remotes.PlaceMineral:FireServer(item.id)
                    end,
                })
            end
        end
    end

    window.OnOpened(refresh)
    for _, key in { "inventory", "pedestals", "upgrades", "passes", "rebirths", "friendsOnline" } do
        DataController.OnChanged(key, refresh)
    end
end

return InventoryMenu
