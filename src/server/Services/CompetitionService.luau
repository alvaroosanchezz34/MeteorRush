--!strict

-- Competiciones de servidor. Durante unos minutos, cada acción del tipo elegido suma un punto
-- (las acciones llegan por AchievementService.OnStat, así que cuentan igual que las
-- estadísticas). Al acabar, los tres primeros ganan monedas.
-- El estado se replica con atributos: `CompetitionKind` y `CompetitionEndsAt` en Workspace y
-- `CompetitionScore` en cada jugador.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AchievementService = require(script.Parent.AchievementService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local LiveOpsService = require(script.Parent.LiveOpsService)
local MomentService = require(script.Parent.MomentService)

local Shared = ReplicatedStorage.Shared
local AchievementsConfig = require(Shared.Config.Achievements)
local CompetitionConfig = require(Shared.Config.Competition)
local Format = require(Shared.Util.Format)
local PlayerStats = require(Shared.Util.PlayerStats)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)

type Score = {
    points: number,
    -- Momento del último punto: en caso de empate gana quien llegó antes.
    at: number,
}

local CompetitionService = {}

local current: CompetitionConfig.Kind? = nil
local scores: { [Player]: Score } = {}
local nextKind = 1
local winStreaks: { [Player]: number } = {}
-- Un administrador ha pedido parar la competición en curso.
local stopRequested = false

local function onStat(player: Player, stat: string, amount: number)
    local kind = current
    if kind == nil or kind.stat ~= stat then
        return
    end
    local score = scores[player] or { points = 0, at = 0 }
    scores[player] = score
    score.points += amount
    score.at = os.clock()
    player:SetAttribute("CompetitionScore", score.points)
end

local function finish(kind: CompetitionConfig.Kind)
    current = nil
    Workspace:SetAttribute("CompetitionKind", nil)
    Workspace:SetAttribute("CompetitionEndsAt", nil)

    local ranking: { Player } = {}
    for player in scores do
        -- Quien se fue a mitad no cuenta.
        if player.Parent == Players then
            table.insert(ranking, player)
        end
    end
    table.sort(ranking, function(a: Player, b: Player): boolean
        if scores[a].points ~= scores[b].points then
            return scores[a].points > scores[b].points
        end
        return scores[a].at < scores[b].at
    end)

    local name = Strings.Competition.Names[kind.id] or kind.id
    local podium: { string } = {}
    for place, player in ranking do
        if place > #CompetitionConfig.RewardFractions then
            break
        end
        table.insert(
            podium,
            string.format(
                Strings.Competition.PodiumEntry,
                place,
                player.DisplayName,
                scores[player].points
            )
        )
        local data = DataService.GetData(player)
        if data then
            local reward = PlayerStats.GetCompetitionReward(data, place)
            IncomeService.AddCoins(player, reward, "competition")
            Remotes.Notify:FireClient(
                player,
                string.format(Strings.Competition.Reward, place, Format.Number(reward))
            )
        end
    end
    -- Racha de victorias seguidas (dentro de la sesión): solo la mantiene quien gana.
    local winner = ranking[1]
    for _, player in Players:GetPlayers() do
        if player ~= winner then
            winStreaks[player] = nil
        end
    end
    if winner then
        local streak = (winStreaks[winner] or 0) + 1
        local completed = streak >= AchievementsConfig.StreakWins
        winStreaks[winner] = if completed then 0 else streak
        if completed then
            MomentService.Announce(winner, "streak")
        end
        AchievementService.AddStats(winner, {
            competitionsWon = 1,
            competitionStreaks = if completed then 1 else 0,
        })
    end

    Remotes.Notify:FireAllClients(
        if #podium > 0
            then string.format(Strings.Competition.Finished, name, table.concat(podium, "   "))
            else string.format(Strings.Competition.NoWinner, name)
    )
    for _, player in Players:GetPlayers() do
        player:SetAttribute("CompetitionScore", nil)
    end
    table.clear(scores)
end

-- Termina la competición sin ganadores ni recompensas (parada a mano).
local function cancel(kind: CompetitionConfig.Kind)
    current = nil
    Workspace:SetAttribute("CompetitionKind", nil)
    Workspace:SetAttribute("CompetitionEndsAt", nil)
    for _, player in Players:GetPlayers() do
        player:SetAttribute("CompetitionScore", nil)
    end
    table.clear(scores)
    Remotes.Notify:FireAllClients(
        string.format(Strings.Competition.Cancelled, Strings.Competition.Names[kind.id] or kind.id)
    )
end

local function run(kind: CompetitionConfig.Kind)
    table.clear(scores)
    current = kind
    Workspace:SetAttribute("CompetitionKind", kind.id)
    Workspace:SetAttribute(
        "CompetitionEndsAt",
        Workspace:GetServerTimeNow() + CompetitionConfig.Duration
    )
    Remotes.Notify:FireAllClients(
        string.format(
            Strings.Competition.Started,
            Strings.Competition.Names[kind.id] or kind.id,
            Strings.Competition.Goals[kind.id] or kind.id,
            Format.Duration(CompetitionConfig.Duration)
        )
    )
    local deadline = os.clock() + CompetitionConfig.Duration
    while os.clock() < deadline and not stopRequested do
        task.wait(math.min(0.5, deadline - os.clock()))
    end
    if stopRequested then
        stopRequested = false
        cancel(kind)
    else
        finish(kind)
    end
end

-- Para la competición en curso (panel de administración): nadie gana ni cobra.
-- Devuelve false si no hay ninguna.
function CompetitionService.Stop(): boolean
    if current == nil then
        return false
    end
    stopRequested = true
    return true
end

-- Competición en curso y sus puntuaciones, de mayor a menor (panel de administración).
function CompetitionService.GetState(): { kind: string?, scores: { { name: string, points: number } } }
    local list: { { name: string, points: number } } = {}
    for player, score in scores do
        table.insert(list, { name = player.Name, points = score.points })
    end
    table.sort(list, function(a, b): boolean
        return a.points > b.points
    end)
    return { kind = if current then current.id else nil, scores = list }
end

-- Para pruebas y para el panel de administración: empieza ya una competición, haya los
-- jugadores que haya.
function CompetitionService.DebugStart(kindId: string): boolean
    local kind = CompetitionConfig.ById[kindId]
    if kind == nil or current ~= nil then
        return false
    end
    task.spawn(run, kind)
    return true
end

function CompetitionService.Init()
    AchievementService.OnStat(onStat)
end

function CompetitionService.Start()
    Players.PlayerRemoving:Connect(function(player: Player)
        scores[player] = nil
        winStreaks[player] = nil
    end)

    task.spawn(function()
        task.wait(CompetitionConfig.FirstDelay)
        while true do
            if
                current == nil
                and LiveOpsService.IsEnabled("competitions")
                and #Players:GetPlayers() >= CompetitionConfig.MinPlayers
            then
                local kind = CompetitionConfig.Kinds[nextKind]
                nextKind = nextKind % #CompetitionConfig.Kinds + 1
                run(kind)
                task.wait(CompetitionConfig.Interval)
            else
                task.wait(CompetitionConfig.RetryDelay)
            end
        end
    end)
end

return CompetitionService
