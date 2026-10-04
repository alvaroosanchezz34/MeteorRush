--!strict

-- Visitar la base de otro jugador: lleva al personaje a la entrada de su parcela (fuera, así
-- que no entra en ninguna zona segura). No se puede usar llevando minerales, para que no
-- sirva de atajo ni para escapar de un robo, y tiene un enfriamiento.
-- También publica en atributos del jugador lo que muestra la lista de jugadores.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local Log = require(Shared.Util.Log)
local MapConfig = require(Shared.Config.Map)
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local SocialConfig = require(Shared.Config.Social)
local Strings = require(Shared.Strings)

local VisitService = {}

local limiter = RateLimiter.new(Network.RateLimits.VisitBase)
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
        Remotes.Notify:FireClient(player, Strings.Visit.Carrying)
        return
    end
    local now = os.clock()
    local wait = SocialConfig.VisitCooldown - (now - (lastVisit[player] or -math.huge))
    if wait > 0 then
        Remotes.Notify:FireClient(
            player,
            string.format(Strings.Visit.Cooldown, Format.Duration(math.ceil(wait)))
        )
        return
    end
    lastVisit[player] = now

    -- Delante de la entrada, mirando hacia dentro de la base.
    local front = plot.cframe
        * CFrame.new(0, 3, -MapConfig.PlotSize / 2 - SocialConfig.VisitDistance)
    local inside = plot.cframe * CFrame.new(0, 3, 0)
    humanoid.Sit = false
    character:PivotTo(CFrame.lookAt(front.Position, inside.Position))
    Remotes.Notify:FireClient(player, string.format(Strings.Visit.Arrived, owner.DisplayName))
end

function VisitService.Init()
    Remotes.VisitBase.OnServerEvent:Connect(onVisitBase)
    DataService.OnProfileLoaded(publish)
    for _, field in { "rebirths", "index" } do
        DataService.OnFieldChanged(field, publish)
    end
end

function VisitService.Start()
    game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
        lastVisit[player] = nil
    end)
end

return VisitService
