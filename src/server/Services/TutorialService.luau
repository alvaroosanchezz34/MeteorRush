--!strict

-- Tutorial de primer uso en tres pasos. El servidor avanza el paso cuando ocurre la acción;
-- el cliente solo muestra el texto del paso actual (campo `tutorialStep`).
--   0 -> 1: minar el primer mineral
--   1 -> 2: depositar en la base
--   2 -> 3: colocar un mineral en un pedestal (tutorial terminado)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)

local LAST_STEP = 3

local TutorialService = {}

-- Marca como completado el paso `step` si es el siguiente pendiente del jugador.
function TutorialService.Advance(player: Player, step: number)
    local data = DataService.GetData(player)
    if data == nil or data.tutorialStep ~= step - 1 then
        return
    end
    DataService.Set(player, "tutorialStep", step)
    if step >= LAST_STEP then
        Remotes.Notify:FireClient(player, Locale.Msg("Tutorial.Done"))
    end
end

return TutorialService
