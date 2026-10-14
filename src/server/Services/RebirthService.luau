--!strict

-- Rebirth: reinicia monedas, mejoras y minerales (inventario, pedestales y mochila)
-- a cambio de +50 % de ingresos permanente por rebirth y de Meteor Shards.
-- Conserva índice, logros, rebirths, shards, mejoras permanentes, cosméticos, game passes
-- y racha diaria.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementService = require(script.Parent.AchievementService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local Shared = ReplicatedStorage.Shared
local DataConfig = require(Shared.Config.Data)
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local RebirthConfig = require(Shared.Config.Rebirth)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local TableUtil = require(Shared.Util.TableUtil)

local RebirthService = {}

local limiter = RateLimiter.new(Network.RateLimits.Rebirth)

local function onRebirth(player: Player)
    if not limiter.Check(player) then
        return
    end
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    local cost = RebirthConfig.GetCost(data.rebirths)
    if data.coins < cost then
        Remotes.Notify:FireClient(player, Locale.Msg("Rebirth.NotEnough", Locale.Num(cost)))
        return
    end

    local newRebirths = data.rebirths + 1
    local shards = RebirthConfig.GetShardReward(data.rebirths)
    -- Duración de este rebirth, en tiempo de juego.
    local playtime = math.floor(DataService.GetPlaytime(player))
    local runSeconds = playtime - data.rebirthInfo.lastPlaytime
    local fastest = data.rebirthInfo.fastest
    local template = DataConfig.Template
    -- El rebirth se queda con todas las monedas, no solo con el coste.
    EconomyService.RecordSpent(player, "rebirth", data.coins)
    DataService.Set(player, "coins", 0)
    DataService.Set(player, "pendingIncome", 0)
    DataService.Set(player, "pedestals", {})
    DataService.Set(player, "inventory", {})
    DataService.Set(player, "upgrades", TableUtil.DeepCopy(template.upgrades))
    DataService.Set(player, "rebirths", newRebirths)
    -- Con los rebirths ya actualizados: las monedas iniciales dependen del coste del siguiente.
    -- Se suman, porque el cambio de rebirths puede haber dado ya la recompensa de un logro.
    DataService.Increment(player, "coins", PlayerStats.GetStartCoins(data))
    DataService.Increment(player, "shards", shards)
    DataService.Set(player, "rebirthInfo", {
        lastPlaytime = playtime,
        fastest = if fastest > 0 then math.min(fastest, runSeconds) else runSeconds,
    })
    CarryService.Clear(player)
    AchievementService.AddStat(player, "shardsEarned", shards)

    local bonus = math.round(RebirthConfig.IncomeBonusPerRebirth * newRebirths * 100)
    Remotes.Notify:FireClient(player, Locale.Msg("Rebirth.Done", tostring(bonus), shards))
end

function RebirthService.Init()
    Remotes.Rebirth.OnServerEvent:Connect(onRebirth)
end

return RebirthService
