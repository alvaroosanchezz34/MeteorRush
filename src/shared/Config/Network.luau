--!strict

export type RateLimit = {
    maxRequests: number,
    windowSeconds: number,
}

local Network = {}

-- Límite de peticiones por jugador y por remote.
Network.RateLimits = {
    DataRequest = { maxRequests = 2, windowSeconds = 5 } :: RateLimit,
    MineStart = { maxRequests = 6, windowSeconds = 1 } :: RateLimit,
    MineStop = { maxRequests = 6, windowSeconds = 1 } :: RateLimit,
    PlaceMineral = { maxRequests = 8, windowSeconds = 1 } :: RateLimit,
    RemoveMineral = { maxRequests = 8, windowSeconds = 1 } :: RateLimit,
    BuyUpgrade = { maxRequests = 6, windowSeconds = 1 } :: RateLimit,
    Rebirth = { maxRequests = 2, windowSeconds = 2 } :: RateLimit,
    ClaimDaily = { maxRequests = 2, windowSeconds = 2 } :: RateLimit,
    HitPlayer = { maxRequests = 4, windowSeconds = 1 } :: RateLimit,
    TradeRequest = { maxRequests = 3, windowSeconds = 3 } :: RateLimit,
    TradeRespond = { maxRequests = 4, windowSeconds = 2 } :: RateLimit,
    TradeUpdateOffer = { maxRequests = 10, windowSeconds = 1 } :: RateLimit,
    TradeConfirm = { maxRequests = 4, windowSeconds = 1 } :: RateLimit,
    TradeCancel = { maxRequests = 4, windowSeconds = 1 } :: RateLimit,
    EquipCosmetic = { maxRequests = 4, windowSeconds = 1 } :: RateLimit,
}

-- Infracciones del límite que se toleran antes de expulsar al jugador.
Network.MaxViolations = 20

-- Segundos sin infracciones tras los que el contador de infracciones vuelve a 0.
Network.ViolationResetSeconds = 30

return Network
