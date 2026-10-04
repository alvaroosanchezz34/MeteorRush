--!strict

-- Competiciones de servidor: cada cierto tiempo, durante unos minutos, todos los jugadores
-- compiten por ser quien más hace una acción. Los tres primeros ganan monedas.

export type Kind = {
    id: string,
    -- Estadística (las de AchievementService.AddStat) que da puntos.
    stat: string,
}

local Competition = {}

-- Segundos desde que arranca el servidor hasta la primera competición.
Competition.FirstDelay = 6 * 60
-- Segundos entre el final de una competición y el inicio de la siguiente.
Competition.Interval = 12 * 60
-- Segundos que dura cada una.
Competition.Duration = 3 * 60

-- Jugadores necesarios para que empiece. Si no hay bastantes, se reintenta tras RetryDelay.
Competition.MinPlayers = 2
Competition.RetryDelay = 60

-- Se van turnando en este orden.
Competition.Kinds = {
    { id = "mine", stat = "mined" },
    { id = "deposit", stat = "deposited" },
    { id = "rare", stat = "rareMined" },
    { id = "steal", stat = "hitsLanded" },
} :: { Kind }

-- Recompensa de cada puesto: fracción del coste del siguiente rebirth del ganador.
Competition.RewardFractions = { 0.03, 0.015, 0.0075 }
-- Recompensa mínima del primer puesto; los demás, en proporción a su fracción.
Competition.MinReward = 2000

local byId: { [string]: Kind } = {}
for _, kind in Competition.Kinds do
    byId[kind.id] = kind
end
Competition.ById = byId

return Competition
