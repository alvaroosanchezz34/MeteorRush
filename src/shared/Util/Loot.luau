--!strict

-- Tiradas de mineral y de mutación. Las comparten MiningService y el simulador de economía
-- (EconomySim), para que la simulación use exactamente las mismas probabilidades que el juego.

local Config = script.Parent.Parent.Config
local Minerals = require(Config.Minerals)
local Mutations = require(Config.Mutations)
local WeightedRandom = require(script.Parent.WeightedRandom)

local Loot = {}

-- Elige un mineral. `rareMultiplier` multiplica el peso de los minerales Raro o superior.
function Loot.RollMineral(rareMultiplier: number, rng: Random): Minerals.Mineral
    local mineral = WeightedRandom.Pick(Minerals.List, function(candidate: Minerals.Mineral): number
        if Minerals.Rarities[candidate.rarity].rank >= Minerals.RareRank then
            return candidate.weight * rareMultiplier
        end
        return candidate.weight
    end, rng)
    return mineral or Minerals.List[1]
end

-- Elige una mutación. `multiplier` multiplica el peso de las mutaciones distintas de "none".
function Loot.RollMutation(multiplier: number, rng: Random): Mutations.Mutation
    local mutation = WeightedRandom.Pick(
        Mutations.List,
        function(candidate: Mutations.Mutation): number
            if candidate.id == Mutations.NoneId then
                return candidate.chance
            end
            return candidate.chance * multiplier
        end,
        rng
    )
    return mutation or Mutations.ById[Mutations.NoneId]
end

return Loot
