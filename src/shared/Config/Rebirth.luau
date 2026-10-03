--!strict

local Rebirth = {}

Rebirth.BaseCost = 1000000
Rebirth.CostFactor = 5

-- Bonificación de ingresos por rebirth, acumulativa de forma aditiva (+50 % cada uno).
Rebirth.IncomeBonusPerRebirth = 0.5

-- Monedas necesarias para el siguiente rebirth.
function Rebirth.GetCost(rebirths: number): number
    return Rebirth.BaseCost * Rebirth.CostFactor ^ rebirths
end

-- Multiplicador de ingresos que dan los rebirths.
function Rebirth.GetIncomeMultiplier(rebirths: number): number
    return 1 + Rebirth.IncomeBonusPerRebirth * rebirths
end

return Rebirth
