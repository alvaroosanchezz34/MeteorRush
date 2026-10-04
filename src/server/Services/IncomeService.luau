--!strict

-- Ingresos pasivos: los pedestales suman monedas a `pendingIncome` cada segundo y el jugador
-- las cobra pisando la placa de cobro (o automáticamente con el pass autoCollect).
-- Al entrar se abonan los ingresos generados sin conexión.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local IncomeConfig = require(Shared.Config.Income)
local PlayerStats = require(Shared.Util.PlayerStats)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)

local IncomeService = {}

local function updatePadLabel(player: Player, data: Types.Profile)
    local plot = PlotService.GetPlot(player)
    if plot then
        plot.collectLabel.Text =
            string.format(Strings.Plot.CollectPad, Format.Number(math.floor(data.pendingIncome)))
    end
end

-- Añade monedas al jugador y al total histórico. Devuelve false si el perfil no está cargado.
-- `source` dice de dónde salen ("pedestals", "sell", "quests"...) para las estadísticas.
function IncomeService.AddCoins(player: Player, amount: number, source: string): boolean
    if amount <= 0 or DataService.GetData(player) == nil then
        return false
    end
    DataService.Increment(player, "coins", amount)
    DataService.Increment(player, "totalCoinsEarned", amount)
    EconomyService.RecordEarned(player, source, amount)
    return true
end

-- Cobra monedas al jugador. Devuelve false, sin cobrar nada, si no tiene suficientes.
-- `sink` dice en qué se gastan ("upgrades", "fuse"...) para las estadísticas.
function IncomeService.SpendCoins(player: Player, amount: number, sink: string): boolean
    local data = DataService.GetData(player)
    if data == nil or amount ~= amount or amount < 0 or data.coins < amount then
        return false
    end
    if amount > 0 then
        DataService.Increment(player, "coins", -amount)
        EconomyService.RecordSpent(player, sink, amount)
    end
    return true
end

-- Cobra la parte entera de los ingresos pendientes.
function IncomeService.Collect(player: Player, silent: boolean?)
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    local amount = math.floor(data.pendingIncome)
    if amount <= 0 then
        return
    end
    DataService.Set(player, "pendingIncome", data.pendingIncome - amount)
    IncomeService.AddCoins(player, amount, "pedestals")
    updatePadLabel(player, data)
    if not silent then
        Remotes.Notify:FireClient(
            player,
            string.format(Strings.Income.Collected, Format.Number(amount))
        )
    end
end

local function tick(seconds: number)
    for _, player in Players:GetPlayers() do
        local data = DataService.GetData(player)
        if data then
            local rate = PlayerStats.GetIncomePerSecond(data)
            if rate > 0 then
                DataService.Set(player, "pendingIncome", data.pendingIncome + rate * seconds)
            end
            if PlayerStats.HasPass(data, "autoCollect") then
                IncomeService.Collect(player, true)
            end
            updatePadLabel(player, data)
        end
    end
end

local function checkCollectPads()
    for _, player in Players:GetPlayers() do
        local character = player.Character
        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
        if root and root:IsA("BasePart") and PlotService.IsOnCollectPad(player, root.Position) then
            IncomeService.Collect(player)
        end
    end
end

local function grantOfflineIncome(player: Player, data: Types.Profile)
    if data.lastSeen <= 0 then
        return
    end
    local elapsed = math.clamp(os.time() - data.lastSeen, 0, IncomeConfig.OfflineCapSeconds)
    local amount = PlayerStats.GetIncomePerSecond(data) * elapsed * PlayerStats.GetOfflineRate(data)
    if amount < 1 then
        return
    end
    DataService.Set(player, "pendingIncome", data.pendingIncome + amount)
    Remotes.Notify:FireClient(
        player,
        string.format(Strings.Income.Offline, Format.Number(math.floor(amount)))
    )
    updatePadLabel(player, data)
end

function IncomeService.Init()
    DataService.OnProfileLoaded(grantOfflineIncome)
end

function IncomeService.Start()
    task.spawn(function()
        while true do
            local elapsed = task.wait(IncomeConfig.TickSeconds)
            tick(elapsed)
        end
    end)
    task.spawn(function()
        while true do
            task.wait(IncomeConfig.CollectCheckInterval)
            checkCollectPads()
        end
    end)
end

return IncomeService
