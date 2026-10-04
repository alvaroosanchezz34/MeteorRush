--!strict

export type Mutation = {
    id: string,
    -- Probabilidad en porcentaje; se usa como peso.
    chance: number,
    multiplier: number,
    color: Color3?,
    -- Aspecto del mineral mutado: "metal" (metálico), "neon" (brillante) o "rainbow" (multicolor).
    style: string?,
    -- Si true, cuando alguien la consigue lo ve y lo lee todo el servidor.
    announce: boolean?,
}

local Mutations = {}

Mutations.NoneId = "none"

Mutations.List = {
    { id = "none", chance = 93.4, multiplier = 1 },
    {
        id = "gold",
        chance = 5,
        multiplier = 2,
        color = Color3.fromRGB(255, 205, 60),
        style = "metal",
    },
    {
        id = "radioactive",
        chance = 1.5,
        multiplier = 5,
        color = Color3.fromRGB(120, 255, 80),
        style = "neon",
    },
    {
        id = "rainbow",
        chance = 0.1,
        multiplier = 15,
        color = Color3.fromRGB(255, 120, 230),
        style = "rainbow",
        announce = true,
    },
} :: { Mutation }

-- Fusión: este número de minerales iguales (mismo mineral y misma mutación) se convierten
-- en uno con la mutación siguiente de la lista.
Mutations.FuseCount = 3

-- Fusionar cuesta lo que generaría el mineral resultante en un pedestal durante estos segundos
-- (sin multiplicadores). Es un gasto de monedas que crece con el valor del mineral; 0 = gratis.
Mutations.FuseCostSeconds = 60

local byId: { [string]: Mutation } = {}
for _, mutation in Mutations.List do
    byId[mutation.id] = mutation
end
Mutations.ById = byId

-- Devuelve la mutación siguiente a la indicada, o nil si ya es la última.
function Mutations.GetNext(mutationId: string): Mutation?
    for index, mutation in Mutations.List do
        if mutation.id == mutationId then
            return Mutations.List[index + 1]
        end
    end
    return nil
end

return Mutations
