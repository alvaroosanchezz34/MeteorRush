--!strict

-- Rebirth: explica qué se pierde y qué se conserva, muestra el coste y pide confirmación.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local RebirthConfig = require(Shared:WaitForChild("Config"):WaitForChild("Rebirth"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local RebirthMenu = {}

function RebirthMenu.Mount(window: Components.Window)
    local info = Components.Label({
        text = "",
        size = UDim2.fromScale(1, 0.7),
        parent = window.content,
    })
    local button = Components.Button({
        text = Strings.Rebirth.Confirm,
        size = UDim2.fromScale(0.4, 0.16),
        position = UDim2.fromScale(0.3, 0.78),
        parent = window.content,
        onClick = function()
            Remotes.Rebirth:FireServer()
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
        local function bonus(rebirths: number): string
            return tostring(math.round(RebirthConfig.IncomeBonusPerRebirth * rebirths * 100))
        end
        info.Text = string.format(
            Strings.Rebirth.Info,
            Format.Number(cost),
            bonus(data.rebirths),
            bonus(data.rebirths + 1)
        )
        button.BackgroundColor3 = if data.coins >= cost
            then Components.Colors.Gold
            else Components.Colors.Disabled
    end

    window.OnOpened(refresh)
    for _, key in { "coins", "rebirths" } do
        DataController.OnChanged(key, refresh)
    end
end

return RebirthMenu
