--!strict

-- Frases de los NPCs. Cada uno tiene sus frases fijas en Strings.Npcs y, si hace falta, un
-- proveedor que añade por delante comentarios sobre lo que está pasando en ese momento
-- (un evento, un meteorito gigante, el progreso del jugador...). Para que un NPC nuevo
-- comente algo, basta con añadirle aquí un proveedor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MeteorsConfig = require(Config:WaitForChild("Meteors"))
local Minerals = require(Config:WaitForChild("Minerals"))
local Mutations = require(Config:WaitForChild("Mutations"))
local PlayerStats = require(Shared:WaitForChild("Util"):WaitForChild("PlayerStats"))
local Strings = require(Shared:WaitForChild("Strings"))

type Provider = () -> { string }

local NpcDialogue = {}

-- Segundos antes de un impacto en los que el meteorólogo avisa.
local INCOMING_SECONDS = 15

local providers: { [string]: Provider } = {
    -- Comenta lo que pasa en el mapa y explica los tres tipos de meteorito con sus tiempos reales.
    meteorologist = function(): { string }
        local text = Strings.Npcs.Meteorologist
        local lines: { string } = {}
        local eventId = Workspace:GetAttribute("EventId")
        local nextAt = Workspace:GetAttribute("NextMeteorAt")
        if Workspace:GetAttribute("GiantActive") == true then
            table.insert(lines, text.GiantActive)
        elseif type(eventId) == "string" and Workspace:GetAttribute("EventEndsAt") ~= nil then
            table.insert(lines, string.format(text.Event, Strings.Events.Names[eventId] or eventId))
        elseif type(Workspace:GetAttribute("AmbientEvent")) == "string" then
            table.insert(lines, text.Sky)
        elseif
            type(nextAt) == "number"
            and nextAt - Workspace:GetServerTimeNow() <= INCOMING_SECONDS
        then
            table.insert(lines, text.Incoming)
        end
        local types = MeteorsConfig.Types
        table.insert(lines, string.format(text.Normal, types.normal.interval))
        table.insert(lines, string.format(text.Big, types.big.interval / 60))
        table.insert(lines, string.format(text.Giant, types.giant.interval / 60))
        return lines
    end,

    -- Explica las mutaciones con sus multiplicadores reales y comenta el índice del jugador.
    scientist = function(): { string }
        local text = Strings.Npcs.Scientist
        local lines: { string } = {}
        local data = DataController.GetData()
        if data then
            table.insert(
                lines,
                string.format(
                    text.Index,
                    PlayerStats.GetStat(data, "index"),
                    #Minerals.List * #Mutations.List
                )
            )
        end
        table.insert(
            lines,
            string.format(
                text.Multipliers,
                Mutations.ById.gold.multiplier,
                Mutations.ById.radioactive.multiplier,
                Mutations.ById.rainbow.multiplier
            )
        )
        table.insert(lines, string.format(text.Fuse, Mutations.FuseCount))
        local best = Minerals.List[#Minerals.List]
        table.insert(lines, string.format(text.Rarest, Strings.Minerals[best.id] or best.id))
        return lines
    end,

    -- Explica el intercambio; si está desactivado, lo dice.
    trader = function(): { string }
        local text = Strings.Npcs.Trader
        if Workspace:GetAttribute("Feature_trading") == false then
            return { text.Closed }
        end
        return {}
    end,
}

-- Frases del NPC para hablar con él: primero las que dependen del momento y luego las fijas.
function NpcDialogue.GetLines(npcId: string): { string }
    local lines: { string } = {}
    local provider = providers[npcId]
    if provider then
        lines = provider()
    end
    for _, line in Strings.Npcs.Lines[npcId] or {} do
        table.insert(lines, line)
    end
    return lines
end

-- Comentarios cortos que el NPC suelta por su cuenta cuando hay un jugador cerca.
function NpcDialogue.GetIdleLines(npcId: string): { string }
    return Strings.Npcs.Idle[npcId] or {}
end

return NpcDialogue
