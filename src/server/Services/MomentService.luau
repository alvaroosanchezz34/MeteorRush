--!strict

-- Momentos legendarios: anuncia a todo el servidor los acontecimientos más raros
-- (Config/Moments). Lo decide siempre el servidor; el cliente no puede pedir uno. Hay un
-- intervalo mínimo entre anuncios y otro por jugador y tipo, para que no se amontonen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MomentsConfig = require(Shared.Config.Moments)
local Remotes = require(Shared.Remotes)

local MomentService = {}

local lastGlobal = -math.huge
local lastByPlayer: { [Player]: { [string]: number } } = {}

-- Anuncia un momento de ese jugador a todos. `kind`: "discovery" (con mineral y mutación),
-- "collection" o "streak". Devuelve false si no se ha anunciado por los límites.
function MomentService.Announce(
    player: Player,
    kind: string,
    mineralId: string?,
    mutationId: string?
): boolean
    local now = os.clock()
    local history = lastByPlayer[player]
    if history == nil then
        history = {}
        lastByPlayer[player] = history
    end
    if
        now - lastGlobal < MomentsConfig.GlobalGap
        or now - (history[kind] or -math.huge) < MomentsConfig.PlayerCooldown
    then
        return false
    end
    lastGlobal = now
    history[kind] = now
    Remotes.LegendaryMoment:FireAllClients(player.DisplayName, kind, mineralId, mutationId)
    return true
end

function MomentService.Start()
    Players.PlayerRemoving:Connect(function(player: Player)
        lastByPlayer[player] = nil
    end)
end

return MomentService
