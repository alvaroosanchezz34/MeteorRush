--!strict

-- Misiones diarias (progreso, recompensa y botón de cobro) y, debajo, la casilla para
-- canjear códigos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CodesConfig = require(Config:WaitForChild("Codes"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local PlayerStats = require(Shared:WaitForChild("Util"):WaitForChild("PlayerStats"))
local QuestsConfig = require(Config:WaitForChild("Quests"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local QuestsMenu = {}

function QuestsMenu.Mount(window: Components.Window)
    local resetLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(1, 0.07),
        alignment = Enum.TextXAlignment.Left,
        color = Components.Colors.Muted,
        parent = window.content,
    })
    local list = Components.ScrollList({
        size = UDim2.fromScale(1, 0.68),
        position = UDim2.fromScale(0, 0.09),
        cellSize = UDim2.fromScale(0.98, 0.23),
        parent = window.content,
    })

    -- Códigos -------------------------------------------------------------------
    local codeBox = Components.Input({
        placeholder = function(): string
            return Strings.Codes.Placeholder
        end,
        size = UDim2.fromScale(0.62, 0.14),
        position = UDim2.fromScale(0, 0.82),
        parent = window.content,
    })

    Components.Button({
        text = function(): string
            return Strings.Codes.Redeem
        end,
        size = UDim2.fromScale(0.34, 0.14),
        position = UDim2.fromScale(0.66, 0.82),
        color = Components.Colors.Primary,
        parent = window.content,
        onClick = function()
            local text = string.sub(codeBox.Text, 1, CodesConfig.MaxLength)
            if text ~= "" then
                Remotes.RedeemCode:FireServer(text)
                codeBox.Text = ""
            end
        end,
    })

    -- Misiones ------------------------------------------------------------------
    local function updateReset()
        resetLabel.Text = string.format(
            Strings.Quests.ResetsIn,
            Format.Duration(QuestsConfig.GetSecondsToReset(Workspace:GetServerTimeNow()))
        )
    end

    local function refresh()
        if not window.IsOpen() then
            return
        end
        local data = DataController.GetData()
        Components.Clear(list)
        if data == nil then
            return
        end
        updateReset()
        local now = Workspace:GetServerTimeNow()

        for order, quest in QuestsConfig.List do
            local progress = PlayerStats.GetQuestProgress(data, quest.id, now)
            local claimed = PlayerStats.IsQuestClaimed(data, quest.id, now)
            local complete = progress >= quest.goal

            local row = Components.Panel({ size = UDim2.new(), layoutOrder = order, parent = list })
            Components.Label({
                text = string.format(Strings.Quests.Descriptions[quest.id] or quest.id, quest.goal),
                size = UDim2.fromScale(0.62, 0.4),
                position = UDim2.fromScale(0.03, 0.08),
                alignment = Enum.TextXAlignment.Left,
                parent = row,
            })

            -- Barra de progreso con el recuento encima.
            local bar = Components.Panel({
                size = UDim2.fromScale(0.62, 0.3),
                position = UDim2.fromScale(0.03, 0.58),
                color = Components.Colors.Background,
                parent = row,
            })
            if progress > 0 then
                Components.Panel({
                    size = UDim2.fromScale(math.clamp(progress / quest.goal, 0, 1), 1),
                    color = if complete
                        then Components.Colors.Success
                        else Components.Colors.Primary,
                    parent = bar,
                })
            end
            local count = Components.Label({
                text = string.format(Strings.Quests.Progress, progress, quest.goal),
                size = UDim2.fromScale(1, 0.9),
                position = UDim2.fromScale(0, 0.05),
                parent = bar,
            })
            count.ZIndex = 2

            Components.Button({
                text = if claimed
                    then Strings.Quests.Claimed
                    else string.format(
                        Strings.Quests.Reward,
                        Format.Number(PlayerStats.GetQuestReward(data, quest))
                    ),
                size = UDim2.fromScale(0.3, 0.7),
                position = UDim2.fromScale(0.67, 0.15),
                color = if claimed or not complete
                    then Components.Colors.Disabled
                    else Components.Colors.Success,
                parent = row,
                onClick = function()
                    if complete and not claimed then
                        Remotes.ClaimQuest:FireServer(quest.id)
                    end
                end,
            })
        end
    end

    -- Una sola cuenta atrás aunque se vuelva a pintar con la ventana abierta (p. ej. al
    -- cambiar de idioma).
    local ticking = false
    window.OnOpened(function()
        refresh()
        if ticking then
            return
        end
        ticking = true
        -- Actualiza la cuenta atrás mientras la ventana está abierta.
        local lastDay = QuestsConfig.GetDay(Workspace:GetServerTimeNow())
        while window.IsOpen() do
            task.wait(1)
            if window.IsOpen() then
                local day = QuestsConfig.GetDay(Workspace:GetServerTimeNow())
                if day ~= lastDay then
                    lastDay = day
                    refresh()
                else
                    updateReset()
                end
            end
        end
        ticking = false
    end)
    for _, key in { "quests", "rebirths" } do
        DataController.OnChanged(key, refresh)
    end
end

return QuestsMenu
