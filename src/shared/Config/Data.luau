--!strict

local Types = require(script.Parent.Parent.Types)

local Data = {}

-- Nombre del almacén de ProfileStore. Cambiarlo equivale a empezar con datos vacíos.
Data.StoreName = "PlayerData"

-- Cada cuántos segundos se suma el tiempo de juego de la sesión al perfil.
Data.PlaytimeFlushInterval = 60

-- Al confirmar una compra se espera a que el perfil esté guardado: segundos entre reintentos
-- de guardado si el anterior no ha incluido la compra.
Data.SaveRetrySeconds = 10

local template: Types.Profile = {
    version = 1,
    coins = 0,
    totalCoinsEarned = 0,
    rebirths = 0,
    playtime = 0,
    lastSeen = 0,
    upgrades = {
        pickaxe = 0,
        backpack = 0,
        speed = 0,
        pedestals = 0,
        luck = 0,
        fortune = 0,
        mutation = 0,
        refinery = 0,
        grip = 0,
    },
    inventory = {},
    pedestals = {},
    pendingIncome = 0,
    index = {},
    indexRewards = {},
    daily = { streak = 0, lastClaim = 0 },
    passes = {},
    purchases = {},
    boosts = {},
    cosmetics = { owned = {}, equipped = {} },
    tutorialStep = 0,
    quests = { day = 0, progress = {}, claimed = {} },
    codes = {},
    stats = {},
    achievements = {},
    title = "",
    friendsOnline = 0,
    shards = 0,
    permanent = {},
    rebirthInfo = { lastPlaytime = 0, fastest = 0 },
    decor = { slots = {}, effect = "" },
    season = { id = "", points = 0, progress = {}, done = {}, claimed = {} },
    seenVersion = "",
    social = { visits = 0, likes = 0, liked = {} },
    -- Los perfiles anteriores al equipamiento reciben estos valores al cargar (Reconcile):
    -- el pico y el arma iniciales, sin cajas.
    equipment = {
        owned = { rustedPick = true, rustyBat = true },
        pickaxe = "rustedPick",
        weapon = "rustyBat",
        crates = {},
        pity = {},
        collection = { rustedPick = true, rustyBat = true },
        dust = 0,
        opened = 0,
    },
}

Data.Template = template

return Data
