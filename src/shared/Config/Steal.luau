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

-- Tope de la fracción que se suelta, lleve el arma que lleve el atacante.
Steal.MaxDropFraction = 0.6

-- Anti-frustración -------------------------------------------------------------------------
-- Segundos tras un aturdimiento durante los que no se puede volver a aturdir a ese jugador.
Steal.StunImmunity = 20
-- Golpes seguidos a la misma víctima: cada golpe recibido dentro de esta ventana reduce lo
-- que suelta el siguiente (x RepeatFactor cada vez, nunca menos de MinRepeatFactor).
Steal.RepeatWindow = 60
Steal.RepeatFactor = 0.5
Steal.MinRepeatFactor = 0.25

-- Rareza mínima (rango de Config/Minerals) del mineral robado para el aviso de "robado".
Steal.MomentRank = 5

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
