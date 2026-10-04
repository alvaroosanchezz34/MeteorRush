--!strict

-- Live Ops: todo lo que cambia de una actualización a otra sin tocar la lógica del juego.
-- Interruptores de contenido, temporadas, calendario de eventos y registro de versiones.
-- Las horas son UTC. Los textos visibles de aquí (nombres de temporada, notas de versión)
-- van en inglés, como el resto del juego.

export type Mission = {
    id: string,
    -- Estadística (las de AchievementService.AddStat) que la hace avanzar.
    stat: string,
    goal: number,
    -- Puntos de temporada que da al completarla.
    points: number,
    -- Texto de la misión; %s = objetivo.
    text: string,
}

export type Tier = {
    -- Puntos de temporada necesarios.
    points: number,
    -- Recompensa: monedas (fracción del coste del siguiente rebirth), shards o un cosmético
    -- de Config/Shop con `season` igual al id de esta temporada.
    coinsFraction: number?,
    shards: number?,
    cosmetic: string?,
}

export type Season = {
    id: string,
    name: string,
    color: Color3,
    -- Inicio (hora Unix, UTC) y duración en días.
    startsAt: number,
    days: number,
    -- Puntos que da cada unidad de una estadística mientras dura la temporada.
    pointSources: { [string]: number },
    missions: { Mission },
    tiers: { Tier },
}

export type CalendarEntry = {
    -- Id de un evento de Config/Events.
    eventId: string,
    -- Se repite cada semana: día (1 = domingo ... 7 = sábado), hora y minuto UTC.
    weekday: number,
    hour: number,
    minute: number,
}

export type Release = {
    version: string,
    date: string,
    notes: { string },
}

local DAY = 24 * 60 * 60

local LiveOps = {}

-- Interruptores de contenido ----------------------------------------------------
-- Valor por defecto de cada interruptor. Un administrador puede cambiarlos en caliente
-- desde el panel de administración; el cambio se guarda en un DataStore y llega a todos los
-- servidores en menos de `FeaturePollSeconds`.
LiveOps.Features = {
    events = true,
    competitions = true,
    seasons = true,
    codes = true,
    trading = true,
    stealing = true,
    -- Sucesos ambientales del cielo (solo visuales).
    ambient = true,
} :: { [string]: boolean }

LiveOps.FeatureStore = "LiveOps"
LiveOps.FeatureKey = "features"
LiveOps.FeaturePollSeconds = 60

-- Temporadas ---------------------------------------------------------------------
-- Cada temporada tiene su id; el progreso del jugador se guarda con ese id y empieza de
-- cero cuando cambia. Para lanzar una temporada nueva basta con añadirla a la lista.
LiveOps.SeasonMinCoins = 5000

LiveOps.Seasons = {
    {
        id = "s1",
        name = "Season 1: First Impact",
        color = Color3.fromRGB(255, 140, 60),
        startsAt = os.time({ year = 2026, month = 10, day = 1, hour = 0 }),
        days = 30,
        pointSources = {
            questsClaimed = 10,
            eventsJoined = 15,
            competitionsWon = 25,
        },
        missions = {
            { id = "mine", stat = "mined", goal = 2000, points = 60, text = "Mine %s minerals" },
            {
                id = "rare",
                stat = "rareMined",
                goal = 150,
                points = 60,
                text = "Mine %s Rare or better minerals",
            },
            {
                id = "deposit",
                stat = "deposited",
                goal = 1500,
                points = 40,
                text = "Deposit %s minerals",
            },
            {
                id = "fuse",
                stat = "fused",
                goal = 20,
                points = 40,
                text = "Fuse minerals %s times",
            },
            {
                id = "events",
                stat = "eventsJoined",
                goal = 15,
                points = 60,
                text = "Take part in %s events",
            },
            {
                id = "upgrades",
                stat = "upgradesBought",
                goal = 150,
                points = 40,
                text = "Buy %s upgrades",
            },
        },
        tiers = {
            { points = 50, coinsFraction = 0.01 },
            { points = 120, shards = 3 },
            { points = 220, coinsFraction = 0.03 },
            { points = 350, cosmetic = "trailSeason1" },
            { points = 500, shards = 8 },
            { points = 700, cosmetic = "baseSeason1" },
        },
    },
} :: { Season }

-- Calendario de eventos -----------------------------------------------------------
-- Eventos fijos, a la misma hora en todos los servidores, además de los que salen solos.
-- Cada cuántos segundos se comprueba si toca alguno.
LiveOps.CalendarCheckSeconds = 20

LiveOps.EventCalendar = {
    { eventId = "supernova", weekday = 7, hour = 18, minute = 0 },
    { eventId = "meteorShower", weekday = 1, hour = 18, minute = 0 },
} :: { CalendarEntry }

-- Versiones -------------------------------------------------------------------------
-- La primera de la lista es la actual. Al entrar con una versión nueva se muestran sus notas.
LiveOps.Releases = {
    {
        version = "1.0.0",
        date = "2026-10-04",
        notes = {
            "Achievements, titles and a player profile",
            "Rebirth shards and the permanent Shard Tree",
            "Base decorations, effects and collection board",
            "Server events, special meteors and competitions",
            "Season 1: First Impact",
        },
    },
} :: { Release }

LiveOps.Version = LiveOps.Releases[1].version

-- Temporada activa en ese momento (hora Unix), o nil si no hay ninguna.
function LiveOps.GetSeason(now: number): Season?
    for _, season in LiveOps.Seasons do
        if now >= season.startsAt and now < season.startsAt + season.days * DAY then
            return season
        end
    end
    return nil
end

-- Segundos que le quedan a una temporada.
function LiveOps.GetSeasonRemaining(season: Season, now: number): number
    return math.max(season.startsAt + season.days * DAY - now, 0)
end

-- Próxima cita del calendario a partir de `now`: la entrada y su hora Unix.
function LiveOps.GetNextScheduled(now: number): (CalendarEntry?, number?)
    local today = os.date("!*t", now) :: any
    local dayStart = now - (today.hour * 3600 + today.min * 60 + today.sec)
    local best: CalendarEntry? = nil
    local bestAt: number? = nil
    for _, entry in LiveOps.EventCalendar do
        local at = dayStart
            + ((entry.weekday - today.wday) % 7) * DAY
            + entry.hour * 3600
            + entry.minute * 60
        if at <= now then
            at += 7 * DAY
        end
        if bestAt == nil or at < bestAt then
            best = entry
            bestAt = at
        end
    end
    return best, bestAt
end

return LiveOps
