--!strict

-- Rebirth: explica qué se gana, muestra las estadísticas de rebirth y el siguiente
-- desbloqueo, y pide una confirmación en dos pasos con lo que se pierde y lo que se conserva.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local PermanentConfig = require(Config:WaitForChild("Permanent"))
local RebirthConfig = require(Config:WaitForChild("Rebirth"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShopConfig = require(Config:WaitForChild("Shop"))
local Strings = require(Shared:WaitForChild("Strings"))

local RebirthMenu = {}

local function bonus(rebirths: number): string
    return tostring(math.round(RebirthConfig.IncomeBonusPerRebirth * rebirths * 100))
end

-- Lo que se desbloquea en el primer número de rebirths mayor que el actual que desbloquea algo.
local function nextUnlocks(rebirths: number): (number?, { string })
    local nextAt: number? = nil
    local names: { string } = {}
    local function consider(required: number?, name: string)
        if required == nil or required <= rebirths then
            return
        end
        if nextAt == nil or required < nextAt then
            nextAt = required
            table.clear(names)
        end
        if required == nextAt then
            table.insert(names, name)
        end
    end
    for _, node in PermanentConfig.List do
        consider(node.minRebirths, Strings.Permanent.Names[node.id] or node.id)
    end
    for _, cosmetic in ShopConfig.Cosmetics do
        consider(cosmetic.rebirthsRequired, Strings.Shop.Names[cosmetic.key] or cosmetic.key)
    end
    return nextAt, names
end

function RebirthMenu.Mount(window: Components.Window)
    local info = Components.Label({
        text = "",
        size = UDim2.fromScale(1, 0.42),
        parent = window.content,
    })
    local stats = Components.Label({
        text = "",
        size = UDim2.fromScale(1, 0.26),
        position = UDim2.fromScale(0, 0.46),
        color = Components.Colors.Muted,
        parent = window.content,
    })

    -- Segundo paso: qué se pierde, qué se conserva y qué se gana.
    local confirm = Components.Confirm({
        parent = window.content,
        confirmText = function(): string
            return Strings.Rebirth.ConfirmYes
        end,
        cancelText = function(): string
            return Strings.Rebirth.ConfirmNo
        end,
        onConfirm = function()
            Remotes.Rebirth:FireServer()
        end,
    })

    local button = Components.Button({
        text = function(): string
            return Strings.Rebirth.Confirm
        end,
        size = UDim2.fromScale(0.4, 0.16),
        position = UDim2.fromScale(0.3, 0.8),
        parent = window.content,
        onClick = function()
            local data = DataController.GetData()
            if data == nil then
                return
            end
            if data.coins < RebirthConfig.GetCost(data.rebirths) then
                -- El servidor responde con lo que falta.
                Remotes.Rebirth:FireServer()
                return
            end
            confirm.Show(
                string.format(
                    Strings.Rebirth.ConfirmInfo,
                    Format.Number(data.coins),
                    #data.inventory,
                    bonus(1),
                    RebirthConfig.GetShardReward(data.rebirths)
                )
            )
        end,
    })

    local function refresh()
        if not window.IsOpen() then
            return
        end
        local data = DataController.GetData()
        if data == nil then
            return
        end
        local cost = RebirthConfig.GetCost(data.rebirths)
        info.Text = string.format(
            Strings.Rebirth.Info,
            Format.Number(cost),
            bonus(data.rebirths),
            bonus(data.rebirths + 1),
            RebirthConfig.GetShardReward(data.rebirths)
        )

        local lines = {
            string.format(
                Strings.Rebirth.Stats,
                data.rebirths,
                data.shards,
                Format.Duration(data.playtime - data.rebirthInfo.lastPlaytime),
                if data.rebirthInfo.fastest > 0
                    then Format.Duration(data.rebirthInfo.fastest)
                    else Strings.Rebirth.NoFastest
            ),
        }
        local nextAt, names = nextUnlocks(data.rebirths)
        if nextAt then
            table.insert(
                lines,
                string.format(Strings.Rebirth.NextUnlock, nextAt, table.concat(names, ", "))
            )
        end
        stats.Text = table.concat(lines, "\n")

        button.BackgroundColor3 = if data.coins >= cost
            then Components.Colors.Gold
            else Components.Colors.Disabled
    end

    window.OnOpened(function()
        confirm.Hide()
        refresh()
    end)
    for _, key in { "coins", "rebirths", "shards", "rebirthInfo", "playtime" } do
        DataController.OnChanged(key, refresh)
    end
end

return RebirthMenu
