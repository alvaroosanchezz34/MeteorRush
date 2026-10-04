--!strict

-- Estadísticas económicas de la sesión de cada jugador: monedas ganadas por origen, gastadas
-- por destino y minerales minados por rareza. Solo lleva la cuenta; no decide nada.
-- En Studio se envían al cliente cada pocos segundos para el panel de pruebas (UI/EconomyPanel).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local IncomeConfig = require(Shared.Config.Income)
local Minerals = require(Shared.Config.Minerals)
local Mutations = require(Shared.Config.Mutations)
local Remotes = require(Shared.Remotes)

export type Stats = {
    -- Segundos de sesión (se rellena al pedir las estadísticas).
    seconds: number,
    earned: { [string]: number },
    spent: { [string]: number },
    mined: number,
    mutated: number,
    minedByRarity: { [string]: number },
}

local EconomyService = {}

local stats: { [Player]: Stats } = {}
local startedAt: { [Player]: number } = {}

local function getOrCreate(player: Player): Stats
    local current = stats[player]
    if current == nil then
        current =
            { seconds = 0, earned = {}, spent = {}, mined = 0, mutated = 0, minedByRarity = {} }
        stats[player] = current
        startedAt[player] = os.clock()
    end
    return current
end

-- Estadísticas de la sesión del jugador.
function EconomyService.GetStats(player: Player): Stats
    local current = getOrCreate(player)
    current.seconds = os.clock() - startedAt[player]
    return current
end

-- Apunta monedas ganadas. `source`: "pedestals", "sell", "quests", "daily", "index"...
function EconomyService.RecordEarned(player: Player, source: string, amount: number)
    local earned = getOrCreate(player).earned
    earned[source] = (earned[source] or 0) + amount
end

-- Apunta monedas gastadas. `sink`: "upgrades", "fuse" o "rebirth".
function EconomyService.RecordSpent(player: Player, sink: string, amount: number)
    local spent = getOrCreate(player).spent
    spent[sink] = (spent[sink] or 0) + amount
end

-- Apunta un mineral minado.
function EconomyService.RecordMined(player: Player, mineralId: string, mutationId: string)
    local current = getOrCreate(player)
    local mineral = Minerals.ById[mineralId]
    current.mined += 1
    if mutationId ~= Mutations.NoneId then
        current.mutated += 1
    end
    if mineral then
        current.minedByRarity[mineral.rarity] = (current.minedByRarity[mineral.rarity] or 0) + 1
    end
end

function EconomyService.Start()
    Players.PlayerRemoving:Connect(function(player: Player)
        stats[player] = nil
        startedAt[player] = nil
    end)

    if not RunService:IsStudio() then
        return
    end
    task.spawn(function()
        while true do
            task.wait(IncomeConfig.StatsInterval)
            for _, player in Players:GetPlayers() do
                Remotes.EconomyStats:FireClient(player, EconomyService.GetStats(player))
            end
        end
    end)
end

return EconomyService
