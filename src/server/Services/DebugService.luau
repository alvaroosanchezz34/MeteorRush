--!strict

-- Herramientas de prueba que solo existen en Studio. Se usan desde la barra de comandos del
-- servidor (que no comparte `require` con los scripts), mediante BindableFunctions:
--   game.ServerScriptService.Server.Services.DebugService.SkipNewbie:Invoke(player)
--   ...ResetDaily:Invoke(player)
--   ...GiveMineral:Invoke(player, "darkmatter", "rainbow")

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)

local Shared = ReplicatedStorage.Shared
local DailyConfig = require(Shared.Config.Daily)
local Minerals = require(Shared.Config.Minerals)
local Mutations = require(Shared.Config.Mutations)
local StealConfig = require(Shared.Config.Steal)
local Types = require(Shared.Types)

local DebugService = {}

local function isPlayer(value: any): boolean
    return typeof(value) == "Instance" and value:IsA("Player")
end

local function bind(name: string, callback: (...any) -> boolean)
    local bindable = Instance.new("BindableFunction")
    bindable.Name = name
    bindable.OnInvoke = callback
    bindable.Parent = script
end

function DebugService.Init()
    if not RunService:IsStudio() then
        return
    end

    -- Quita la protección de novato sumando el tiempo de juego necesario.
    bind("SkipNewbie", function(player: any): boolean
        if not isPlayer(player) or DataService.GetData(player) == nil then
            return false
        end
        return DataService.Increment(player, "playtime", StealConfig.NewbieProtectionSeconds)
    end)

    -- Permite volver a cobrar la racha diaria ya (como si hubieran pasado 24 h).
    bind("ResetDaily", function(player: any): boolean
        local data = if isPlayer(player) then DataService.GetData(player) else nil
        if data == nil then
            return false
        end
        local daily = data.daily
        return DataService.Set(player, "daily", {
            streak = daily.streak,
            lastClaim = if daily.lastClaim > 0 then os.time() - DailyConfig.Cooldown else 0,
        })
    end)

    -- Añade un mineral al inventario de la base.
    bind("GiveMineral", function(player: any, mineralId: any, mutationId: any): boolean
        local mutation = if type(mutationId) == "string" then mutationId else "none"
        if
            not isPlayer(player)
            or type(mineralId) ~= "string"
            or Minerals.ById[mineralId] == nil
            or Mutations.ById[mutation] == nil
        then
            return false
        end
        local item: Types.InventoryItem = {
            id = HttpService:GenerateGUID(false),
            mineral = mineralId,
            mutation = mutation,
        }
        local ok = DataService.Update(
            player,
            "inventory",
            function(inventory: { Types.InventoryItem })
                table.insert(inventory, item)
                return inventory
            end
        )
        if ok then
            IndexService.Register(player, mineralId, mutation)
        end
        return ok
    end)
end

return DebugService
