--!strict

-- Sucesos ambientales raros (Config/Ambient): el servidor solo decide cuál toca y cuándo,
-- para que todos los jugadores vean lo mismo a la vez. Son puramente visuales: los dibuja
-- cada cliente (AmbientController) y no dan nada ni cambian ninguna regla.
-- El estado va en atributos de Workspace: `AmbientEvent` (id), `AmbientEventStart` (hora
-- del servidor) y `AmbientEventSeed` (para que las posiciones al azar coincidan).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AchievementService = require(script.Parent.AchievementService)
local LiveOpsService = require(script.Parent.LiveOpsService)

local Shared = ReplicatedStorage.Shared
local AmbientConfig = require(Shared.Config.Ambient)
local WeightedRandom = require(Shared.Util.WeightedRandom)

local AmbientService = {}

local rng = Random.new()
local running = false
local lastId: string? = nil

local function run(event: AmbientConfig.RareEvent)
    running = true
    lastId = event.id
    Workspace:SetAttribute("AmbientEventSeed", rng:NextInteger(1, 1e6))
    Workspace:SetAttribute("AmbientEventStart", Workspace:GetServerTimeNow())
    Workspace:SetAttribute("AmbientEvent", event.id)
    task.wait(event.duration)
    Workspace:SetAttribute("AmbientEvent", nil)
    running = false
    -- Haber estado ahí cuenta para un objetivo secreto; no da nada más.
    for _, player in Players:GetPlayers() do
        AchievementService.AddStat(player, "ambientSeen", 1)
    end
end

-- Solo para pruebas: lanza ya ese suceso.
function AmbientService.DebugStart(eventId: string): boolean
    local event = AmbientConfig.RareById[eventId]
    if event == nil or running then
        return false
    end
    task.spawn(run, event)
    return true
end

function AmbientService.Start()
    task.spawn(function()
        task.wait(AmbientConfig.RareFirstDelay)
        while true do
            if not running and LiveOpsService.IsEnabled("ambient") then
                -- No se repite el mismo dos veces seguidas.
                local event = WeightedRandom.Pick(
                    AmbientConfig.RareEvents,
                    function(candidate: AmbientConfig.RareEvent): number
                        return if candidate.id == lastId then 0 else candidate.weight
                    end,
                    rng
                )
                if event then
                    run(event)
                end
            end
            task.wait(rng:NextNumber(AmbientConfig.RareMinWait, AmbientConfig.RareMaxWait))
        end
    end)
end

return AmbientService
