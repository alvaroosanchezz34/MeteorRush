--!strict

-- Misiones diarias: otros servicios avisan del progreso con QuestService.Progress y el
-- jugador cobra cada misión completada desde el menú. Se reinician a medianoche UTC.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementService = require(script.Parent.AchievementService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Util.Log)
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local QuestsConfig = require(Shared.Config.Quests)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)

local QuestService = {}

local limiter = RateLimiter.new(Network.RateLimits.ClaimQuest)

local function describe(quest: QuestsConfig.Quest): Locale.Message
    return Locale.Msg("Quests.Descriptions." .. quest.id, quest.goal)
end

-- Si el progreso guardado es de otro día, empieza el de hoy desde cero.
local function ensureDay(player: Player, data: Types.Profile)
    local today = QuestsConfig.GetDay(os.time())
    if data.quests.day ~= today then
        DataService.Set(player, "quests", { day = today, progress = {}, claimed = {} })
    end
end

-- Suma progreso a todas las misiones de ese tipo. Lo llaman los servicios donde ocurre la acción.
function QuestService.Progress(player: Player, kind: string, amount: number)
    local data = DataService.GetData(player)
    if data == nil or amount <= 0 then
        return
    end
    ensureDay(player, data)

    local completed: { QuestsConfig.Quest } = {}
    local changed = false
    for _, quest in QuestsConfig.List do
        local current = data.quests.progress[quest.id] or 0
        if quest.kind == kind and current < quest.goal then
            changed = true
            if current + amount >= quest.goal then
                table.insert(completed, quest)
            end
        end
    end
    if not changed then
        return
    end

    DataService.Update(player, "quests", function(quests: Types.QuestData)
        for _, quest in QuestsConfig.List do
            local current = quests.progress[quest.id] or 0
            if quest.kind == kind and current < quest.goal then
                quests.progress[quest.id] = math.min(current + amount, quest.goal)
            end
        end
        return quests
    end)
    for _, quest in completed do
        Remotes.Notify:FireClient(player, Locale.Msg("Quests.Completed", describe(quest)))
    end
end

local function onClaimQuest(player: Player, questId: unknown)
    if not limiter.Check(player) then
        return
    end
    if type(questId) ~= "string" then
        Log.Suspicious(player, "ClaimQuest", "tipo inválido")
        return
    end
    local quest = QuestsConfig.ById[questId]
    local data = DataService.GetData(player)
    if quest == nil or data == nil then
        return
    end
    ensureDay(player, data)
    if (data.quests.progress[questId] or 0) < quest.goal or data.quests.claimed[questId] then
        return
    end

    local reward = PlayerStats.GetQuestReward(data, quest)
    DataService.Update(player, "quests", function(quests: Types.QuestData)
        quests.claimed[questId] = true
        return quests
    end)
    IncomeService.AddCoins(player, reward, "quests")
    AchievementService.AddStat(player, "questsClaimed", 1)
    Remotes.Notify:FireClient(player, Locale.Msg("Quests.RewardClaimed", Locale.Num(reward)))
end

function QuestService.Init()
    Remotes.ClaimQuest.OnServerEvent:Connect(onClaimQuest)
    DataService.OnProfileLoaded(ensureDay)
end

return QuestService
