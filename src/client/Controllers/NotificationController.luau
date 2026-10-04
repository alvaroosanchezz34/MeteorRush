--!strict

-- Muestra en pantalla los avisos del servidor: los mensajes cortos del remote Notify y los
-- avisos grandes de nuevo descubrimiento del índice y de logro desbloqueado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementsMenu = require(script.Parent.Parent.UI.AchievementsMenu)
local Announcement = require(script.Parent.Parent.UI.Announcement)
local Banner = require(script.Parent.Parent.UI.Banner)
local Components = require(script.Parent.Parent.UI.Components)
local DataController = require(script.Parent.DataController)
local Effects = require(script.Parent.Parent.UI.Effects)
local LegendaryMoment = require(script.Parent.Parent.UI.LegendaryMoment)
local Notifications = require(script.Parent.Parent.UI.Notifications)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AchievementsConfig = require(Config:WaitForChild("Achievements"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Minerals = require(Config:WaitForChild("Minerals"))
local Mutations = require(Config:WaitForChild("Mutations"))
local RarityFx = require(Config:WaitForChild("RarityFx"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local SECRET_COLOR = Color3.fromRGB(190, 110, 255)

local NotificationController = {}

local function onIndexDiscovered(mineralId: any, mutationId: any)
    local mineral = if type(mineralId) == "string" then Minerals.ById[mineralId] else nil
    local mutation = if type(mutationId) == "string" then Mutations.ById[mutationId] else nil
    if mineral == nil or mutation == nil then
        return
    end
    local discovered = 0
    for _ in DataController.Get("index") or {} do
        discovered += 1
    end
    local entry: Banner.Entry = {
        heading = Strings.Index.NewDiscovery,
        title = Strings.MineralName(mineral.id, mutation.id),
        subtitle = string.format(
            Strings.Index.Progress,
            discovered,
            #Minerals.List * #Mutations.List
        ),
        color = mutation.color or Minerals.Rarities[mineral.rarity].color,
        mineral = mineral.id,
        mutation = mutation.id,
    }
    -- Si ese mineral tiene momento cinematográfico, el aviso espera a que termine.
    local tier = RarityFx.Discovery[Minerals.Rarities[mineral.rarity].rank]
    if tier and tier.cinematic then
        task.delay(RarityFx.CinematicSeconds + 0.3, Banner.Show, entry)
    else
        Banner.Show(entry)
    end
end

local function onAchievementUnlocked(achievementId: any, reward: any)
    local achievement = if type(achievementId) == "string"
        then AchievementsConfig.ById[achievementId]
        else nil
    if achievement == nil or type(reward) ~= "number" then
        return
    end
    local title = if achievement.title then Strings.Titles[achievement.id] else nil
    local rewardText = if title
        then string.format(Strings.Achievements.RewardTitle, Format.Number(reward), title)
        else string.format(Strings.Achievements.Reward, Format.Number(reward))
    if achievement.secret then
        -- Objetivo secreto: aviso propio con su descripción (que hasta ahora no se conocía),
        -- sonido especial y un destello.
        Banner.Show({
            heading = Strings.Achievements.SecretUnlocked,
            title = Strings.Achievements.Names[achievement.id] or achievement.id,
            subtitle = string.format(
                Strings.Achievements.SecretReward,
                AchievementsMenu.Describe(achievement),
                rewardText
            ),
            color = SECRET_COLOR,
            sound = "Secret",
        })
        Effects.Flash(SECRET_COLOR, 0.2, 0.9)
        return
    end
    Banner.Show({
        heading = Strings.Achievements.Unlocked,
        title = Strings.Achievements.Names[achievement.id] or achievement.id,
        subtitle = rewardText,
        color = Components.Colors.Gold,
    })
end

function NotificationController.Init()
    Remotes.Notify.OnClientEvent:Connect(function(text: any)
        if type(text) == "string" then
            Notifications.Show(text)
        end
    end)
    Remotes.IndexDiscovered.OnClientEvent:Connect(onIndexDiscovered)
    Remotes.AchievementUnlocked.OnClientEvent:Connect(onAchievementUnlocked)
    Remotes.LegendaryMoment.OnClientEvent:Connect(LegendaryMoment.Show)
    Remotes.Announcement.OnClientEvent:Connect(Announcement.Show)
end

return NotificationController
