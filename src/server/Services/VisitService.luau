--!strict

-- Visitar la base de otro jugador: lleva al personaje a la entrada de su parcela (fuera, así
-- que no entra en ninguna zona segura). No se puede usar llevando minerales, para que no
-- sirva de atajo ni para escapar de un robo, y tiene un enfriamiento.
-- También publica en atributos del jugador lo que muestra la lista de jugadores.
-- Con las mismas reglas lleva al jugador al Outpost (la plaza de los NPCs) y de vuelta a su
-- base: sin minerales encima y con un enfriamiento corto.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Util.Log)
local MapConfig = require(Shared.Config.Map)
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local SocialConfig = require(Shared.Config.Social)
local Locale = require(Shared.Locale)

local VisitService = {}

local limiter = RateLimiter.new(Network.RateLimits.VisitBase)
local teleportLimiter = RateLimiter.new(Network.RateLimits.Teleport)
local lastTeleport: { [Player]: number } = {}
local lastVisit: { [Player]: number } = {}

local function publish(player: Player)
    local data = DataService.GetData(player)
    if data then
        player:SetAttribute("Rebirths", data.rebirths)
        player:SetAttribute("IndexCount", PlayerStats.GetStat(data, "index"))
    end
end

local function onVisitBase(player: Player, target: unknown)
    if not limiter.Check(player) then
        return
    end
    if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Player") then
        Log.Suspicious(player, "VisitBase", "tipo inválido")
        return
    end
    local owner = target :: Player
    local plot = PlotService.GetPlot(owner)
    local character = player.Character
    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
    if owner == player or plot == nil or character == nil or humanoid == nil then
        return
    end
    if humanoid.Health <= 0 then
        return
    end
    if CarryService.GetCount(player) > 0 then
        Remotes.Notify:FireClient(player, Locale.Msg("Visit.Carrying"))
        return
    end
    local now = os.clock()
    local wait = SocialConfig.VisitCooldown - (now - (lastVisit[player] or -math.huge))
    if wait > 0 then
        Remotes.Notify:FireClient(player, Locale.Msg("Visit.Cooldown", Locale.Dur(math.ceil(wait))))
        return
    end
    lastVisit[player] = now

    -- Delante de la entrada, mirando hacia dentro de la base.
    local front = plot.cframe
        * CFrame.new(0, 3, -MapConfig.PlotSize / 2 - SocialConfig.VisitDistance)
    local inside = plot.cframe * CFrame.new(0, 3, 0)
    humanoid.Sit = false
    character:PivotTo(CFrame.lookAt(front.Position, inside.Position))
    Remotes.Notify:FireClient(player, Locale.Msg("Visit.Arrived", owner.DisplayName))
end

-- Teletransporte al Outpost ("outpost") o a la base propia ("home").
local function onTeleport(player: Player, destination: unknown)
    if not teleportLimiter.Check(player) then
        return
    end
    if destination ~= "outpost" and destination ~= "home" then
        Log.Suspicious(player, "Teleport", "destino inválido")
        return
    end
    local character = player.Character
    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
    local plot = PlotService.GetPlot(player)
    if character == nil or humanoid == nil or humanoid.Health <= 0 or plot == nil then
        return
    end
    -- Sin carga: si no, sería la forma de escapar de un robo o de saltarse el camino a casa.
    if CarryService.GetCount(player) > 0 then
        Remotes.Notify:FireClient(player, Locale.Msg("Visit.TeleportCarrying"))
        return
    end
    local now = os.clock()
    local wait = MapConfig.Hub.cooldown - (now - (lastTeleport[player] or -math.huge))
    if wait > 0 then
        Remotes.Notify:FireClient(player, Locale.Msg("Visit.Cooldown", Locale.Dur(math.ceil(wait))))
        return
    end
    lastTeleport[player] = now

    humanoid.Sit = false
    if destination == "outpost" then
        -- En la losa central, mirando hacia el interior de la plaza.
        local center = MapConfig.GetHubCFrame() * CFrame.new(0, MapConfig.Hub.height + 3, 0)
        character:PivotTo(center * CFrame.Angles(0, math.pi, 0))
        Remotes.Notify:FireClient(player, Locale.Msg("Visit.OutpostArrived"))
    else
        character:PivotTo(plot.spawnLocation.CFrame + Vector3.new(0, 3, 0))
        Remotes.Notify:FireClient(player, Locale.Msg("Visit.HomeArrived"))
    end
end

function VisitService.Init()
    Remotes.Teleport.OnServerEvent:Connect(onTeleport)
    Remotes.VisitBase.OnServerEvent:Connect(onVisitBase)
    DataService.OnProfileLoaded(publish)
    for _, field in { "rebirths", "index" } do
        DataService.OnFieldChanged(field, publish)
    end
end

function VisitService.Start()
    game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
        lastVisit[player] = nil
        lastTeleport[player] = nil
    end)
end

return VisitService
