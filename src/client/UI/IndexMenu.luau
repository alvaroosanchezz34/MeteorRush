--!strict

-- Índice: las 32 combinaciones mineral + mutación. Cada fila es un mineral; la última
-- columna muestra la recompensa por completarla.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local IndexConfig = require(Config:WaitForChild("Index"))
local Minerals = require(Config:WaitForChild("Minerals"))
local Mutations = require(Config:WaitForChild("Mutations"))
local Strings = require(Shared:WaitForChild("Strings"))

local IndexMenu = {}

function IndexMenu.Mount(window: Components.Window)
    local header = Components.Label({
        text = "",
        size = UDim2.fromScale(1, 0.08),
        alignment = Enum.TextXAlignment.Left,
        color = Components.Colors.Muted,
        parent = window.content,
    })
    local columns = #Mutations.List + 1
    local list = Components.ScrollList({
        size = UDim2.fromScale(1, 0.9),
        position = UDim2.fromScale(0, 0.1),
        cellSize = UDim2.fromScale(0.98 / columns - 0.01, 0.13),
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

        local discovered = 0
        local order = 0
        for _, mineral in Minerals.List do
            local rarityColor = Minerals.Rarities[mineral.rarity].color
            for _, mutation in Mutations.List do
                order += 1
                local found = data.index[IndexConfig.Key(mineral.id, mutation.id)] == true
                if found then
                    discovered += 1
                end
                local cell = Components.Panel({
                    size = UDim2.new(),
                    layoutOrder = order,
                    color = if found then Components.Colors.Panel else Components.Colors.Background,
                    parent = list,
                })
                Components.Label({
                    text = if found
                        then Strings.MineralName(mineral.id, mutation.id)
                        else Strings.Index.Undiscovered,
                    size = UDim2.fromScale(0.9, 0.8),
                    position = UDim2.fromScale(0.05, 0.1),
                    color = if found
                        then mutation.color or rarityColor
                        else Components.Colors.Muted,
                    parent = cell,
                })
            end

            order += 1
            local claimed = data.indexRewards[mineral.id] == true
            local rewardCell = Components.Panel({
                size = UDim2.new(),
                layoutOrder = order,
                color = if claimed then Components.Colors.Success else Components.Colors.Background,
                parent = list,
            })
            Components.Label({
                text = if claimed
                    then "✓"
                    else string.format(
                        Strings.Index.Reward,
                        Format.Number(IndexConfig.GetRowReward(mineral.id))
                    ),
                size = UDim2.fromScale(0.9, 0.8),
                position = UDim2.fromScale(0.05, 0.1),
                color = Components.Colors.Gold,
                parent = rewardCell,
            })
        end

        header.Text =
            string.format(Strings.Index.Progress, discovered, #Minerals.List * #Mutations.List)
    end

    window.OnOpened(refresh)
    for _, key in { "index", "indexRewards" } do
        DataController.OnChanged(key, refresh)
    end
end

return IndexMenu
