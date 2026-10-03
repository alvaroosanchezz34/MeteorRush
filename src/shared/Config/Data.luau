--!strict

local Types = require(script.Parent.Parent.Types)

local Data = {}

-- Nombre del almacén de ProfileStore. Cambiarlo equivale a empezar con datos vacíos.
Data.StoreName = "PlayerData"

-- Cada cuántos segundos se suma el tiempo de juego de la sesión al perfil.
Data.PlaytimeFlushInterval = 60

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
}

Data.Template = template

return Data
