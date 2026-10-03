--!strict

-- Clasificación global (todos los servidores) por monedas ganadas en total.

local Leaderboard = {}

-- Nombre del OrderedDataStore. Cambiarlo equivale a empezar la clasificación de cero.
Leaderboard.StoreName = "TopMiners_v1"

-- Puestos que se muestran.
Leaderboard.Size = 10

-- Segundos entre lecturas de la clasificación y entre guardados de cada jugador.
Leaderboard.RefreshSeconds = 120
Leaderboard.SaveSeconds = 300

-- Tableros en el mapa: justo fuera de la zona de impacto, entre estas parcelas y la siguiente,
-- mirando al centro.
Leaderboard.BoardGaps = { 2, 6 }
Leaderboard.BoardRadius = 322
Leaderboard.BoardSize = Vector3.new(26, 15, 1)
-- Altura del borde inferior del tablero sobre el suelo.
Leaderboard.BoardHeight = 4
Leaderboard.TitleColor = Color3.fromRGB(255, 200, 60)

return Leaderboard
