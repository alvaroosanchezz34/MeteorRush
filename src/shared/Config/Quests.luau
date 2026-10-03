--!strict

-- Misiones diarias. Todos los jugadores tienen las mismas y se reinician a medianoche UTC.

export type Quest = {
    id: string,
    -- Qué acción la hace avanzar: "mine", "rare", "deposit" o "upgrade".
    kind: string,
    goal: number,
    -- Recompensa: fracción del coste del siguiente rebirth (así escala con el progreso).
    rewardFraction: number,
}

local Quests = {}

-- Segundos que dura un "día" de misiones.
Quests.DayLength = 24 * 60 * 60

-- Recompensa mínima en monedas, por si la fracción da muy poco.
Quests.MinReward = 500

Quests.List = {
    { id = "mine", kind = "mine", goal = 40, rewardFraction = 0.004 },
    { id = "deposit", kind = "deposit", goal = 30, rewardFraction = 0.004 },
    { id = "rare", kind = "rare", goal = 3, rewardFraction = 0.008 },
    { id = "upgrade", kind = "upgrade", goal = 3, rewardFraction = 0.006 },
    { id = "mineMore", kind = "mine", goal = 120, rewardFraction = 0.012 },
} :: { Quest }

local byId: { [string]: Quest } = {}
for _, quest in Quests.List do
    byId[quest.id] = quest
end
Quests.ById = byId

-- Número de día al que pertenece una hora Unix.
function Quests.GetDay(now: number): number
    return math.floor(now / Quests.DayLength)
end

-- Segundos que faltan para que se reinicien las misiones.
function Quests.GetSecondsToReset(now: number): number
    return Quests.DayLength - now % Quests.DayLength
end

return Quests
