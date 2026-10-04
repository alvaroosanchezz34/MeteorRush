--!strict

-- Árbol de mejoras permanentes: se compran con Meteor Shards y no se pierden con el rebirth.
-- Cada nodo muestra su nivel, su efecto y, si está bloqueado, qué hace falta para abrirlo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PermanentConfig = require(Shared:WaitForChild("Config"):WaitForChild("Permanent"))
local PlayerStats = require(Shared:WaitForChild("Util"):WaitForChild("PlayerStats"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))

local PermanentMenu = {}

local function formatValue(node: PermanentConfig.Node, level: number): string
    local value = PermanentConfig.GetValue(node.id, level)
    return if node.percent then string.format("%g%%", value * 100) else string.format("%g", value)
end

-- Texto de lo que falta para desbloquear un nodo.
local function describeLock(node: PermanentConfig.Node, data: Types.Profile): string
    local parts: { string } = {}
    local minRebirths = node.minRebirths
    if minRebirths and data.rebirths < minRebirths then
        table.insert(parts, string.format(Strings.Permanent.NeedsRebirths, minRebirths))
    end
    local requires = node.requires
    if requires and PlayerStats.GetPermanentLevel(data, requires.id) < requires.level then
        table.insert(
            parts,
            string.format(
                Strings.Permanent.NeedsNode,
                Strings.Permanent.Names[requires.id] or requires.id,
                requires.level
            )
        )
    end
    return table.concat(parts, " · ")
end

function PermanentMenu.Mount(window: Components.Window)
    local header = Components.Label({
        text = "",
        size = UDim2.fromScale(1, 0.09),
        alignment = Enum.TextXAlignment.Left,
        color = Components.Colors.Primary,
        parent = window.content,
    })
    local list = Components.ScrollList({
        size = UDim2.fromScale(1, 0.89),
        position = UDim2.fromScale(0, 0.11),
        cellSize = UDim2.fromScale(0.98, 0.2),
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
        header.Text = string.format(Strings.Permanent.Shards, data.shards)

        for order, node in PermanentConfig.List do
            local level = PlayerStats.GetPermanentLevel(data, node.id)
            local isMax = level >= node.maxLevel
            local unlocked = PlayerStats.IsPermanentUnlocked(data, node)
            local cost = PermanentConfig.GetCost(node.id, level)

            local row = Components.Panel({
                size = UDim2.new(),
                layoutOrder = order,
                color = if unlocked then Components.Colors.Panel else Components.Colors.Background,
                parent = list,
            })
            Components.Label({
                text = `{Strings.Permanent.Names[node.id]}  {string.format(
                    Strings.Upgrades.Level,
                    level,
                    node.maxLevel
                )}`,
                size = UDim2.fromScale(0.6, 0.45),
                position = UDim2.fromScale(0.03, 0.08),
                alignment = Enum.TextXAlignment.Left,
                parent = row,
            })
            local effect: string
            if not unlocked then
                effect = describeLock(node, data)
            elseif isMax then
                effect =
                    string.format(Strings.Permanent.EffectsMax[node.id], formatValue(node, level))
            else
                effect = string.format(
                    Strings.Permanent.Effects[node.id],
                    formatValue(node, level),
                    formatValue(node, level + 1)
                )
            end
            Components.Label({
                text = effect,
                size = UDim2.fromScale(0.6, 0.38),
                position = UDim2.fromScale(0.03, 0.55),
                alignment = Enum.TextXAlignment.Left,
                color = Components.Colors.Muted,
                parent = row,
            })

            local text = string.format(Strings.Permanent.Cost, cost)
            if isMax then
                text = Strings.Upgrades.Max
            elseif not unlocked then
                text = Strings.Permanent.LockedButton
            end
            Components.Button({
                text = text,
                size = UDim2.fromScale(0.3, 0.66),
                position = UDim2.fromScale(0.67, 0.17),
                color = if isMax
                        or not unlocked
                        or data.shards < cost
                    then Components.Colors.Disabled
                    else Components.Colors.Primary,
                parent = row,
                onClick = function()
                    if unlocked and not isMax then
                        Remotes.BuyPermanent:FireServer(node.id)
                    end
                end,
            })
        end
    end

    window.OnOpened(refresh)
    for _, key in { "permanent", "shards", "rebirths" } do
        DataController.OnChanged(key, refresh)
    end
end

return PermanentMenu
