--!strict

-- Logros y objetivos secretos. Cada uno se desbloquea solo, una única vez, cuando una
-- estadística del jugador llega a su objetivo, y da monedas. Algunos desbloquean además un
-- título equipable, cuyo id es el del logro.
-- Los objetivos secretos (`secret = true`) no aparecen en ninguna lista hasta conseguirlos:
-- el jugador solo ve cuántos ha encontrado.
-- Para añadir uno: una línea en `List` y su nombre en Strings.Achievements.Names (y en
-- Strings.Titles si da título). Si mide algo nuevo, el servicio donde ocurre llama a
-- AchievementService.AddStat, o se calcula en PlayerStats.GetStat a partir del perfil; su
-- descripción va en Strings.Achievements.Descriptions.

export type Achievement = {
    id: string,
    stat: string,
    goal: number,
    -- Recompensa: fracción del coste del siguiente rebirth (así escala con el progreso).
    rewardFraction: number,
    title: boolean?,
    secret: boolean?,
}

local HOUR = 60 * 60

local Achievements = {}

-- Recompensa mínima en monedas, por si la fracción da muy poco.
Achievements.MinReward = 1000

-- Segundos entre comprobaciones de los logros de tiempo de juego.
Achievements.PlaytimeCheckInterval = 60

-- Condiciones de algunos objetivos secretos.
-- Un robo es "de alto valor" si la víctima suelta algún mineral de este rango o superior
-- (4 = Épico) o con mutación.
Achievements.ValuableRank = 4
-- "Sobrevivir" a un robo: depositar lo que queda antes de que pasen estos segundos.
Achievements.EscapeSeconds = 90
-- Victorias seguidas en competiciones (dentro de la misma sesión) que cuentan como racha.
Achievements.StreakWins = 3

Achievements.List = {
    { id = "mined1", stat = "mined", goal = 100, rewardFraction = 0.005, title = true },
    { id = "mined2", stat = "mined", goal = 1000, rewardFraction = 0.01 },
    { id = "mined3", stat = "mined", goal = 10000, rewardFraction = 0.03, title = true },
    { id = "rare1", stat = "rareMined", goal = 50, rewardFraction = 0.01 },
    { id = "mutated1", stat = "mutatedMined", goal = 100, rewardFraction = 0.01 },
    { id = "deposited1", stat = "deposited", goal = 500, rewardFraction = 0.01 },
    { id = "fused1", stat = "fused", goal = 10, rewardFraction = 0.01 },
    { id = "upgrades1", stat = "upgradesBought", goal = 50, rewardFraction = 0.01 },
    { id = "trade1", stat = "tradesCompleted", goal = 1, rewardFraction = 0.005 },
    {
        id = "champion",
        stat = "competitionsWon",
        goal = 1,
        rewardFraction = 0.01,
        title = true,
    },
    { id = "quests1", stat = "questsClaimed", goal = 25, rewardFraction = 0.02 },
    { id = "events1", stat = "eventsJoined", goal = 10, rewardFraction = 0.02, title = true },
    { id = "index1", stat = "index", goal = 8, rewardFraction = 0.005, title = true },
    { id = "index2", stat = "index", goal = 16, rewardFraction = 0.02 },
    { id = "index3", stat = "index", goal = 32, rewardFraction = 0.1, title = true },
    { id = "rebirth1", stat = "rebirths", goal = 1, rewardFraction = 0.01, title = true },
    { id = "rebirth2", stat = "rebirths", goal = 5, rewardFraction = 0.02 },
    { id = "rebirth3", stat = "rebirths", goal = 10, rewardFraction = 0.05, title = true },
    { id = "coins1", stat = "totalCoinsEarned", goal = 1e6, rewardFraction = 0.005 },
    { id = "coins2", stat = "totalCoinsEarned", goal = 1e9, rewardFraction = 0.02, title = true },
    { id = "streak1", stat = "streak", goal = 7, rewardFraction = 0.02, title = true },
    { id = "playtime1", stat = "playtime", goal = 1 * HOUR, rewardFraction = 0.005 },
    { id = "playtime2", stat = "playtime", goal = 10 * HOUR, rewardFraction = 0.03, title = true },
    -- Objetivos secretos.
    {
        id = "rainbow",
        stat = "rainbowMined",
        goal = 1,
        rewardFraction = 0.02,
        title = true,
        secret = true,
    },
    { id = "top", stat = "topMined", goal = 1, rewardFraction = 0.03, title = true, secret = true },
    {
        id = "alchemist",
        stat = "rainbowFused",
        goal = 1,
        rewardFraction = 0.02,
        title = true,
        secret = true,
    },
    {
        id = "bandit",
        stat = "hitsLanded",
        goal = 25,
        rewardFraction = 0.01,
        title = true,
        secret = true,
    },
    { id = "victim", stat = "timesHit", goal = 10, rewardFraction = 0.01, secret = true },
    { id = "code", stat = "codes", goal = 1, rewardFraction = 0.005, secret = true },
    {
        id = "heist",
        stat = "valuableSteals",
        goal = 1,
        rewardFraction = 0.015,
        title = true,
        secret = true,
    },
    {
        id = "survivor",
        stat = "escapes",
        goal = 3,
        rewardFraction = 0.015,
        title = true,
        secret = true,
    },
    { id = "rareHaul", stat = "rareBackpacks", goal = 1, rewardFraction = 0.02, secret = true },
    {
        id = "hatTrick",
        stat = "competitionStreaks",
        goal = 1,
        rewardFraction = 0.04,
        title = true,
        secret = true,
    },
    {
        id = "eternal",
        stat = "rebirths",
        goal = 25,
        rewardFraction = 0.05,
        title = true,
        secret = true,
    },
    {
        id = "tourist",
        stat = "basesVisited",
        goal = 25,
        rewardFraction = 0.01,
        title = true,
        secret = true,
    },
    {
        id = "celebrity",
        stat = "likes",
        goal = 25,
        rewardFraction = 0.02,
        title = true,
        secret = true,
    },
    { id = "generous", stat = "likesGiven", goal = 10, rewardFraction = 0.01, secret = true },
    { id = "fullRow", stat = "indexRows", goal = 1, rewardFraction = 0.015, secret = true },
    { id = "specialist", stat = "specialMined", goal = 50, rewardFraction = 0.02, secret = true },
    {
        id = "giantSlayer",
        stat = "giantMined",
        goal = 100,
        rewardFraction = 0.03,
        title = true,
        secret = true,
    },
    { id = "lucky", stat = "doubleMinerals", goal = 100, rewardFraction = 0.015, secret = true },
    { id = "hazmat", stat = "radioactiveMined", goal = 25, rewardFraction = 0.015, secret = true },
    { id = "skyWatcher", stat = "ambientSeen", goal = 5, rewardFraction = 0.01, secret = true },
    { id = "decorator", stat = "decorSlots", goal = 6, rewardFraction = 0.01, secret = true },
    { id = "merchant", stat = "tradesCompleted", goal = 10, rewardFraction = 0.015, secret = true },
} :: { Achievement }

-- Estadísticas que se muestran en el perfil, en este orden.
Achievements.ProfileStats = {
    "playtime",
    "totalCoinsEarned",
    "rebirths",
    "shardsEarned",
    "index",
    "mined",
    "rareMined",
    "mutatedMined",
    "deposited",
    "sold",
    "fused",
    "upgradesBought",
    "questsClaimed",
    "tradesCompleted",
    "competitionsWon",
    "eventsJoined",
    "hitsLanded",
    "timesHit",
    "streak",
}

local byId: { [string]: Achievement } = {}
for _, achievement in Achievements.List do
    byId[achievement.id] = achievement
end
Achievements.ById = byId

return Achievements
