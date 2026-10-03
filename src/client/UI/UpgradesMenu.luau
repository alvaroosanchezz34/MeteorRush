--!strict

-- Menú de mejoras: nivel, efecto actual y siguiente, y botón de compra.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Upgrades = require(Shared:WaitForChild("Config"):WaitForChild("Upgrades"))

local UpgradesMenu = {}

local function formatValue(upgradeId: string, level: number): string
    if upgradeId == "pickaxe" then
        return string.format("%.2f", Upgrades.GetMineTime(level))
    elseif upgradeId == "backpack" then
        return tostring(Upgrades.GetBackpackCapacity(level))
    elseif upgradeId == "speed" then
        return tostring(Upgrades.GetWalkSpeed(level))
    elseif upgradeId == "pedestals" then
        return tostring(Upgrades.GetPedestalCount(level))
    end
    return string.format("%.2f", Upgrades.GetLuckMultiplier(level))
end

function UpgradesMenu.Mount(window: Components.Window)
    local list = Components.ScrollList({
        size = UDim2.fromScale(1, 1),
        cellSize = UDim2.fromScale(0.98, 0.18),
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

        for order, upgrade in Upgrades.List do
            local level = (data.upgrades :: any)[upgrade.id] :: number
            local isMax = level >= upgrade.maxLevel
            local cost = Upgrades.GetCost(upgrade.id, level)

            local row = Components.Panel({ size = UDim2.new(), layoutOrder = order, parent = list })
            Components.Label({
                text = `{Strings.Upgrades.Names[upgrade.id]}  {string.format(
                    Strings.Upgrades.Level,
                    level,
                    upgrade.maxLevel
                )}`,
                size = UDim2.fromScale(0.6, 0.45),
                position = UDim2.fromScale(0.03, 0.08),
                alignment = Enum.TextXAlignment.Left,
                parent = row,
            })
            Components.Label({
                text = if isMax
                    then Strings.Upgrades.Max
                    else string.format(
                        Strings.Upgrades.Effects[upgrade.id],
                        formatValue(upgrade.id, level),
                        formatValue(upgrade.id, level + 1)
                    ),
                size = UDim2.fromScale(0.6, 0.38),
                position = UDim2.fromScale(0.03, 0.55),
                alignment = Enum.TextXAlignment.Left,
                color = Components.Colors.Muted,
                parent = row,
            })
            Components.Button({
                text = if isMax then Strings.Upgrades.Max else `${Format.Number(cost)}`,
                size = UDim2.fromScale(0.3, 0.7),
                position = UDim2.fromScale(0.67, 0.15),
                color = if isMax or data.coins < cost
                    then Components.Colors.Disabled
                    else Components.Colors.Success,
                parent = row,
                onClick = function()
                    if not isMax then
                        Remotes.BuyUpgrade:FireServer(upgrade.id)
                    end
                end,
            })
        end
    end

    window.OnOpened(refresh)
    for _, key in { "upgrades", "coins" } do
        DataController.OnChanged(key, refresh)
    end
end

return UpgradesMenu
