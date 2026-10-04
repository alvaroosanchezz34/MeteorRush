--!strict

-- Colección de equipamiento: todos los picos y armas del juego, los descubiertos con su
-- nombre y su rareza y los que faltan como "???" (se ve la rareza, no el objeto), con el
-- porcentaje completado. Es independiente del índice de minerales.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared:WaitForChild("Config"):WaitForChild("Equipment"))
local Strings = require(Shared:WaitForChild("Strings"))

local GearCollectionMenu = {}

function GearCollectionMenu.Mount(window: Components.Window)
    local header = Components.Label({
        text = "",
        size = UDim2.fromScale(1, 0.08),
        alignment = Enum.TextXAlignment.Left,
        color = Components.Colors.Muted,
        parent = window.content,
    })
    local list = Components.ScrollList({
        size = UDim2.fromScale(1, 0.9),
        position = UDim2.fromScale(0, 0.1),
        cellSize = UDim2.fromScale(0.235, 0.2),
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
        local discovered, total, order = 0, 0, 0
        for _, kind in Equipment.Kinds do
            for _, item in Equipment.GetByKind(kind) do
                total += 1
                order += 1
                local found = data.equipment.collection[item.id] == true
                if found then
                    discovered += 1
                end
                local color = Equipment.Rarities[item.rarity].color
                local cell = Components.Panel({
                    size = UDim2.new(),
                    layoutOrder = order,
                    color = if found then Components.Colors.Panel else Components.Colors.Background,
                    parent = list,
                })
                local stroke = cell:FindFirstChildOfClass("UIStroke")
                if stroke then
                    stroke.Color = color
                    stroke.Transparency = if found then 0.3 else 0.75
                end
                Components.Label({
                    text = if found
                        then Strings.Equipment.Names[item.id] or item.id
                        else Strings.Equipment.Undiscovered,
                    size = UDim2.fromScale(0.9, 0.5),
                    position = UDim2.fromScale(0.05, 0.08),
                    color = if found then color else Components.Colors.Muted,
                    parent = cell,
                })
                Components.Label({
                    text = `{Strings.Equipment.Rarities[item.rarity]} · {Strings.Equipment.KindNames[item.kind]}`,
                    size = UDim2.fromScale(0.9, 0.26),
                    position = UDim2.fromScale(0.05, 0.64),
                    color = Components.Colors.Muted,
                    parent = cell,
                })
            end
        end
        header.Text = string.format(
            Strings.Equipment.Collection,
            discovered,
            total,
            if total > 0 then math.floor(discovered / total * 100) else 0
        )
    end

    window.OnOpened(refresh)
    DataController.OnChanged("equipment", refresh)
end

return GearCollectionMenu
