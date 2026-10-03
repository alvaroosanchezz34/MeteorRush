--!strict

-- Rebirth: reinicia monedas, mejoras y minerales (inventario, pedestales y mochila)
-- a cambio de +50 % de ingresos permanente por rebirth.
-- Conserva índice, rebirths, cosméticos, game passes y racha diaria.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)

local Shared = ReplicatedStorage.Shared
local DataConfig = require(Shared.Config.Data)
local Format = require(Shared.Util.Format)
local Network = require(Shared.Config.Network)
local RateLimiter = require(Shared.Util.RateLimiter)
local RebirthConfig = require(Shared.Config.Rebirth)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
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
        Remotes.Notify:FireClient(
            player,
            string.format(Strings.Rebirth.NotEnough, Format.Number(cost))
        )
        return
    end

    local newRebirths = data.rebirths + 1
    local template = DataConfig.Template
    DataService.Set(player, "coins", 0)
    DataService.Set(player, "pendingIncome", 0)
    DataService.Set(player, "pedestals", {})
    DataService.Set(player, "inventory", {})
    DataService.Set(player, "upgrades", TableUtil.DeepCopy(template.upgrades))
    DataService.Set(player, "rebirths", newRebirths)
    CarryService.Clear(player)

    local bonus = math.round(RebirthConfig.IncomeBonusPerRebirth * newRebirths * 100)
    Remotes.Notify:FireClient(player, string.format(Strings.Rebirth.Done, tostring(bonus)))
end

function RebirthService.Init()
    Remotes.Rebirth.OnServerEvent:Connect(onRebirth)
end

return RebirthService
