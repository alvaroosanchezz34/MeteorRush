--!strict

local Players = game:GetService("Players")

local Log = require(script.Parent.Log)
local Network = require(script.Parent.Parent.Config.Network)
local Locale = require(script.Parent.Parent.Locale)

export type RateLimiter = {
    -- Devuelve true si la petición del jugador está dentro del límite.
    Check: (player: Player) -> boolean,
}

type PlayerState = {
    windowStart: number,
    count: number,
    violations: number,
    lastViolation: number,
}

local RateLimiter = {}

-- Crea un limitador de ventana fija. Solo debe usarse en el servidor.
function RateLimiter.new(limit: Network.RateLimit): RateLimiter
    local states: { [Player]: PlayerState } = {}

    -- Nombre del límite en Config/Network, para los registros.
    local name = "?"
    for key, candidate in Network.RateLimits :: { [string]: Network.RateLimit } do
        if candidate == limit then
            name = key
        end
    end

    Players.PlayerRemoving:Connect(function(player: Player)
        states[player] = nil
    end)

    local function check(player: Player): boolean
        local now = os.clock()
        local state = states[player]
        if state == nil then
            state = { windowStart = now, count = 0, violations = 0, lastViolation = 0 }
            states[player] = state
        end

        if now - state.windowStart >= limit.windowSeconds then
            state.windowStart = now
            state.count = 0
        end

        state.count += 1
        if state.count <= limit.maxRequests then
            return true
        end

        if now - state.lastViolation >= Network.ViolationResetSeconds then
            state.violations = 0
        end
        state.violations += 1
        state.lastViolation = now

        -- Se registra la primera infracción de cada racha y la expulsión, no cada petición.
        if state.violations == 1 then
            Log.Suspicious(player, "RateLimit", name)
        end
        if state.violations >= Network.MaxViolations then
            Log.Suspicious(player, "RateLimitKick", name)
            player:Kick(Locale.GetText("Network.RateLimitKick", Locale.GetCurrentLanguage(player)))
        end
        return false
    end

    return { Check = check }
end

return RateLimiter
