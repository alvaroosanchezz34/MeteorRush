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

-- Con la mochila llena, la carga brilla: color, alcance de la luz y partículas por segundo.
Carry.FullGlowColor = Color3.fromRGB(255, 170, 60)
Carry.FullGlowRange = 12
Carry.FullGlowRate = 6
-- Fracción de la mochila a partir de la cual el HUD avisa de que queda poco sitio.
Carry.NearFullFraction = 0.8

-- Segundos entre comprobaciones de la zona de depósito.
Carry.DepositCheckInterval = 0.2

return Carry
