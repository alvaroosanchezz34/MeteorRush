--!strict

local Carry = {}

-- La velocidad baja esta fracción por cada mineral transportado...
Carry.SlowdownPerItem = 0.03
-- ...hasta este máximo.
Carry.MaxSlowdown = 0.4

-- Minerales visibles como máximo en la espalda (los demás no se dibujan).
Carry.MaxVisibleItems = 12
Carry.VisibleColumns = 2
Carry.VisibleItemSize = 1

-- Segundos entre comprobaciones de la zona de depósito.
Carry.DepositCheckInterval = 0.2

return Carry
