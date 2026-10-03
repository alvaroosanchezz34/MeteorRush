--!strict

local WeightedRandom = {}

-- Elige un elemento según su peso. Los pesos <= 0 nunca salen. Devuelve nil si la lista está vacía.
function WeightedRandom.Pick<T>(items: { T }, getWeight: (item: T) -> number, rng: Random): T?
    local total = 0
    for _, item in items do
        total += math.max(getWeight(item), 0)
    end
    if total <= 0 then
        return nil
    end

    local roll = rng:NextNumber() * total
    local last: T? = nil
    for _, item in items do
        local weight = math.max(getWeight(item), 0)
        if weight > 0 then
            last = item
            if roll < weight then
                return item
            end
            roll -= weight
        end
    end
    -- Solo por errores de redondeo.
    return last
end

return WeightedRandom
