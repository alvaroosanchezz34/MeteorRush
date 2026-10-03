--!strict

local Steal = {}

-- Distancia máxima (studs) entre los HumanoidRootPart para que un golpe cuente.
Steal.HitRange = 8
-- Margen extra en el servidor por la latencia.
Steal.HitRangeTolerance = 2

Steal.AttackerCooldown = 2
Steal.VictimImmunity = 5

-- Fracción de lo transportado que se suelta al ser golpeado (redondeado hacia arriba).
Steal.DropFraction = 0.5

-- Segundos que permanecen en el suelo los minerales soltados.
Steal.DropLifetime = 20
-- Distancia a la que se esparcen alrededor de la víctima.
Steal.DropScatterRadius = 6
-- Distancia a la que se recogen al pasar por encima.
Steal.PickupRadius = 4
-- Distancia de recogida con el boost "magnet".
Steal.MagnetPickupRadius = 20
-- Segundos tras soltarse durante los que nadie puede recogerlos.
Steal.DropPickupDelay = 1
-- Segundos entre comprobaciones de recogida.
Steal.PickupCheckInterval = 0.2

-- Segundos de juego total por debajo de los cuales se tiene protección de novato.
Steal.NewbieProtectionSeconds = 10 * 60

return Steal
