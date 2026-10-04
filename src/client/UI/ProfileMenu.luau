--!strict

-- Perfil: nombre, título equipado y estadísticas de por vida del jugador.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementsMenu = require(script.Parent.AchievementsMenu)
local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AchievementsConfig = require(Config:WaitForChild("Achievements"))
local Minerals = require(Config:WaitForChild("Minerals"))
local Mutations = require(Config:WaitForChild("Mutations"))
local PlayerStats = require(Shared:WaitForChild("Util"):WaitForChild("PlayerStats"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local ProfileMenu = {}

function ProfileMenu.Mount(window: Components.Window)
    Components.Label({
        text = Players.LocalPlayer.DisplayName,
        size = UDim2.fromScale(0.6, 0.1),
        alignment = Enum.TextXAlignment.Left,
        parent = window.content,
    })
    local titleLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.6, 0.07),
        position = UDim2.fromScale(0, 0.1),
        alignment = Enum.TextXAlignment.Left,
        color = Components.Colors.Gold,
        parent = window.content,
    })
    local removeButton = Components.Button({
        text = Strings.Profile.RemoveTitle,
        size = UDim2.fromScale(0.3, 0.12),
        position = UDim2.fromScale(0.68, 0.03),
        color = Components.Colors.Danger,
        parent = window.content,
        onClick = function()
            Remotes.EquipTitle:FireServer("")
        end,
    })
    local list = Components.ScrollList({
        size = UDim2.fromScale(1, 0.78),
        position = UDim2.fromScale(0, 0.2),
        cellSize = UDim2.fromScale(0.485, 0.14),
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

        local hasTitle = PlayerStats.OwnsTitle(data, data.title)
        titleLabel.Text = if hasTitle then Strings.Titles[data.title] else Strings.Profile.NoTitle
        titleLabel.TextColor3 = if hasTitle then Components.Colors.Gold else Components.Colors.Muted
        removeButton.Visible = hasTitle

        for order, stat in AchievementsConfig.ProfileStats do
            local value = AchievementsMenu.FormatStat(stat, PlayerStats.GetStat(data, stat))
            if stat == "index" then
                value = `{value}/{#Minerals.List * #Mutations.List}`
            end
            local row = Components.Panel({ size = UDim2.new(), layoutOrder = order, parent = list })
            Components.Label({
                text = Strings.Profile.Stats[stat] or stat,
                size = UDim2.fromScale(0.6, 0.6),
                position = UDim2.fromScale(0.04, 0.2),
                alignment = Enum.TextXAlignment.Left,
                color = Components.Colors.Muted,
                parent = row,
            })
            Components.Label({
                text = value,
                size = UDim2.fromScale(0.32, 0.6),
                position = UDim2.fromScale(0.64, 0.2),
                alignment = Enum.TextXAlignment.Right,
                parent = row,
            })
        end
    end

    window.OnOpened(refresh)
    for _, key in
        {
            "stats",
            "title",
            "achievements",
            "rebirths",
            "index",
            "daily",
            "playtime",
            "totalCoinsEarned",
        }
    do
        DataController.OnChanged(key, refresh)
    end
end

return ProfileMenu
