--!strict

local Rebirth = {}

Rebirth.BaseCost = 2000000
Rebirth.CostFactor = 2.5

-- Bonificación de ingresos por rebirth, acumulativa de forma aditiva (+50 % cada uno).
Rebirth.IncomeBonusPerRebirth = 0.5

-- Meteor Shards que da un rebirth: ShardsBase el primero y ShardsPerRebirth más cada uno
-- de los siguientes. Se gastan en el árbol de mejoras permanentes (Config/Permanent).
Rebirth.ShardsBase = 5
Rebirth.ShardsPerRebirth = 2

-- Shards que da el siguiente rebirth a quien lleva `rebirths` hechos.
function Rebirth.GetShardReward(rebirths: number): number
    return Rebirth.ShardsBase + Rebirth.ShardsPerRebirth * rebirths
end

-- Monedas necesarias para el siguiente rebirth.
function Rebirth.GetCost(rebirths: number): number
    return math.round(Rebirth.BaseCost * Rebirth.CostFactor ^ rebirths)
end

-- Multiplicador de ingresos que dan los rebirths.
function Rebirth.GetIncomeMultiplier(rebirths: number): number
    return 1 + Rebirth.IncomeBonusPerRebirth * rebirths
end

return Rebirth
