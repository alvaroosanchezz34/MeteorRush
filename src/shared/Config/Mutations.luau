--!strict

export type Mutation = {
    id: string,
    -- Probabilidad en porcentaje; se usa como peso.
    chance: number,
    multiplier: number,
    color: Color3?,
    -- Aspecto del mineral mutado: "metal" (metálico), "neon" (brillante) o "rainbow" (multicolor).
    style: string?,
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
    },
} :: { Mutation }

local byId: { [string]: Mutation } = {}
for _, mutation in Mutations.List do
    byId[mutation.id] = mutation
end
Mutations.ById = byId

return Mutations
