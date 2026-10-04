--!strict

-- Logros: progreso, recompensa y, en los que dan título, el botón para equiparlo.
-- Los objetivos secretos no aparecen hasta que se consiguen; solo se ve cuántos se han encontrado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AchievementsConfig = require(Shared:WaitForChild("Config"):WaitForChild("Achievements"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local PlayerStats = require(Shared:WaitForChild("Util"):WaitForChild("PlayerStats"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local AchievementsMenu = {}

-- Valor de una estadística como texto: el tiempo de juego va en horas y minutos.
function AchievementsMenu.FormatStat(stat: string, value: number): string
    return if stat == "playtime" then Format.Duration(value) else Format.Number(value)
end

-- Descripción de un logro, p. ej. "Mine 100 minerals".
function AchievementsMenu.Describe(achievement: AchievementsConfig.Achievement): string
    return string.format(
        Strings.Achievements.Descriptions[achievement.stat] or achievement.stat,
        AchievementsMenu.FormatStat(achievement.stat, achievement.goal)
    )
end

function AchievementsMenu.Mount(window: Components.Window)
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

        local unlockedCount = 0
        local visibleCount = 0
        local secretsFound = 0
        for order, achievement in AchievementsConfig.List do
            local unlocked = data.achievements[achievement.id] == true
            if achievement.secret then
                -- Un secreto sin conseguir no se muestra de ninguna forma.
                if not unlocked then
                    continue
                end
                secretsFound += 1
            else
                visibleCount += 1
                if unlocked then
                    unlockedCount += 1
                end
            end
            local value = math.min(PlayerStats.GetStat(data, achievement.stat), achievement.goal)

            local row = Components.Panel({
                size = UDim2.new(),
                -- Los conseguidos, al final.
                layoutOrder = if unlocked then order + #AchievementsConfig.List else order,
                color = if unlocked then Components.Colors.Panel else Components.Colors.Background,
                parent = list,
            })
            Components.Label({
                text = (if achievement.secret then Strings.Achievements.SecretMark else "")
                    .. (Strings.Achievements.Names[achievement.id] or achievement.id),
                size = UDim2.fromScale(0.62, 0.36),
                position = UDim2.fromScale(0.03, 0.06),
                alignment = Enum.TextXAlignment.Left,
                color = if unlocked then Components.Colors.Gold else Components.Colors.Text,
                parent = row,
            })
            Components.Label({
                text = AchievementsMenu.Describe(achievement),
                size = UDim2.fromScale(0.62, 0.26),
                position = UDim2.fromScale(0.03, 0.42),
                alignment = Enum.TextXAlignment.Left,
                color = Components.Colors.Muted,
                parent = row,
            })

            do
                local bar = Components.Panel({
                    size = UDim2.fromScale(0.62, 0.2),
                    position = UDim2.fromScale(0.03, 0.72),
                    color = Components.Colors.Background,
                    parent = row,
                })
                if value > 0 then
                    Components.Panel({
                        size = UDim2.fromScale(value / achievement.goal, 1),
                        color = if unlocked
                            then Components.Colors.Success
                            else Components.Colors.Primary,
                        parent = bar,
                    })
                end
                local count = Components.Label({
                    text = string.format(
                        Strings.Achievements.Count,
                        AchievementsMenu.FormatStat(achievement.stat, value),
                        AchievementsMenu.FormatStat(achievement.stat, achievement.goal)
                    ),
                    size = UDim2.fromScale(1, 0.9),
                    position = UDim2.fromScale(0, 0.05),
                    parent = bar,
                })
                count.ZIndex = 2
            end

            if unlocked and achievement.title then
                local equipped = data.title == achievement.id
                Components.Button({
                    text = if equipped
                        then Strings.Achievements.TitleEquipped
                        else Strings.Achievements.EquipTitle,
                    size = UDim2.fromScale(0.3, 0.66),
                    position = UDim2.fromScale(0.67, 0.17),
                    color = if equipped then Components.Colors.Gold else Components.Colors.Primary,
                    parent = row,
                    onClick = function()
                        Remotes.EquipTitle:FireServer(if equipped then "" else achievement.id)
                    end,
                })
            else
                Components.Label({
                    text = if unlocked
                        then Strings.Achievements.Done
                        else string.format(
                            Strings.Achievements.Reward,
                            Format.Number(PlayerStats.GetAchievementReward(data, achievement))
                        ),
                    size = UDim2.fromScale(0.3, 0.5),
                    position = UDim2.fromScale(0.67, 0.25),
                    color = if unlocked then Components.Colors.Success else Components.Colors.Gold,
                    parent = row,
                })
            end
        end

        header.Text =
            string.format(Strings.Achievements.Progress, unlockedCount, visibleCount, secretsFound)
    end

    window.OnOpened(refresh)
    for _, key in
        {
            "achievements",
            "stats",
            "title",
            "rebirths",
            "index",
            "daily",
            "codes",
            "playtime",
        }
    do
        DataController.OnChanged(key, refresh)
    end
end

return AchievementsMenu
