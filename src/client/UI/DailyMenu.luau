--!strict

-- Racha diaria: los 7 días, el siguiente resaltado, botón de cobro y tiempo restante.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyConfig = require(Shared:WaitForChild("Config"):WaitForChild("Daily"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local DailyMenu = {}

function DailyMenu.Mount(window: Components.Window)
    local grid = Components.ScrollList({
        size = UDim2.fromScale(1, 0.62),
        cellSize = UDim2.fromScale(0.23, 0.45),
        parent = window.content,
    })
    local status = Components.Label({
        text = "",
        size = UDim2.fromScale(1, 0.1),
        position = UDim2.fromScale(0, 0.68),
        color = Components.Colors.Muted,
        parent = window.content,
    })
    local claimButton = Components.Button({
        text = Strings.Daily.Claim,
        size = UDim2.fromScale(0.4, 0.14),
        position = UDim2.fromScale(0.3, 0.82),
        color = Components.Colors.Success,
        parent = window.content,
        onClick = function()
            Remotes.ClaimDaily:FireServer()
        end,
    })

    local function updateStatus(): boolean
        local data = DataController.GetData()
        if data == nil then
            return false
        end
        local now = Workspace:GetServerTimeNow()
        local remaining = data.daily.lastClaim + DailyConfig.Cooldown - now
        local ready = data.daily.lastClaim <= 0 or remaining <= 0
        status.Text = if ready
            then ""
            else string.format(Strings.Daily.NextIn, Format.Duration(remaining))
        claimButton.BackgroundColor3 = if ready
            then Components.Colors.Success
            else Components.Colors.Disabled
        return ready
    end

    local function refresh()
        if not window.IsOpen() then
            return
        end
        local data = DataController.GetData()
        Components.Clear(grid)
        if data == nil then
            return
        end
        local nextDay = DailyConfig.GetNextDay(data.daily, Workspace:GetServerTimeNow())
        local ready = updateStatus()

        for day, reward in DailyConfig.Rewards do
            local isNext = day == nextDay and ready
            local done = day < nextDay
            local cell = Components.Panel({
                size = UDim2.new(),
                layoutOrder = day,
                color = if isNext
                    then Components.Colors.Primary
                    elseif done then Components.Colors.Success
                    else Components.Colors.Panel,
                parent = grid,
            })
            Components.Label({
                text = string.format(Strings.Daily.Day, day),
                size = UDim2.fromScale(0.9, 0.35),
                position = UDim2.fromScale(0.05, 0.05),
                parent = cell,
            })
            local rewardText = string.format(Strings.Daily.Coins, Format.Number(reward.coins))
            if reward.mineral then
                rewardText = string.format(
                    Strings.Daily.MineralReward,
                    rewardText,
                    Strings.Minerals[reward.mineral] or reward.mineral
                )
            end
            Components.Label({
                text = rewardText,
                size = UDim2.fromScale(0.9, 0.5),
                position = UDim2.fromScale(0.05, 0.45),
                color = Components.Colors.Gold,
                parent = cell,
            })
        end
    end

    window.OnOpened(function()
        refresh()
        -- Actualiza la cuenta atrás mientras la ventana está abierta.
        while window.IsOpen() do
            task.wait(1)
            if window.IsOpen() and updateStatus() then
                refresh()
            end
        end
    end)
    DataController.OnChanged("daily", refresh)
end

return DailyMenu
