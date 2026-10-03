--!strict

export type DailyReward = {
    coins: number,
    -- Mineral garantizado que se añade al inventario de la base.
    mineral: string?,
}

local Daily = {}

-- Segundos mínimos entre dos cobros.
Daily.Cooldown = 24 * 60 * 60
-- Si pasa más que esto desde el último cobro, la racha vuelve al día 1.
Daily.ResetAfter = 48 * 60 * 60

-- Recompensa de cada día de la racha. Tras el día 7 vuelve a empezar por el 1.
Daily.Rewards = {
    { coins = 100 },
    { coins = 250 },
    { coins = 500 },
    { coins = 1000 },
    { coins = 2500 },
    { coins = 5000 },
    { coins = 10000, mineral = "nebula" },
} :: { DailyReward }

-- Día de la racha (1..7) que se cobraría en `now`, teniendo en cuenta el reinicio a las 48 h.
function Daily.GetNextDay(daily: { streak: number, lastClaim: number }, now: number): number
    if daily.lastClaim <= 0 or now - daily.lastClaim > Daily.ResetAfter then
        return 1
    end
    return daily.streak % #Daily.Rewards + 1
end

return Daily
