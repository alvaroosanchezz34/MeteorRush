--!strict

local Social = {}

-- Cada amigo de Roblox que está en el mismo servidor suma esta fracción a los ingresos...
Social.IncomeBonusPerFriend = 0.1
-- ...hasta este número de amigos.
Social.MaxFriends = 3

-- Visitar la base de otro jugador: segundos entre visitas y distancia a la entrada (studs)
-- a la que aparece el visitante.
Social.VisitCooldown = 30
Social.VisitDistance = 8

-- Bases como espacio social. Visitas y likes son solo sociales: no dan monedas ni ventajas.
-- Una visita cuenta al entrar en la base de otro, como mucho una vez cada VisitCountCooldown
-- segundos por pareja de jugadores; se comprueba cada VisitCheckSeconds.
Social.VisitCountCooldown = 10 * 60
Social.VisitCheckSeconds = 2
-- Para dar likes hace falta este tiempo de juego total (frena las cuentas recién creadas), y
-- un jugador puede tener marcadas como mucho estas bases distintas.
Social.LikeMinPlaytime = 10 * 60
Social.MaxLikesGiven = 2000
-- Distancia al cartel de una base a la que aparece la opción de inspeccionarla.
Social.InspectDistance = 14

-- Clasificaciones globales de bases (OrderedDataStore). Cambiar un nombre equivale a empezar
-- esa clasificación de cero.
Social.RankingStores = {
    visits = "BaseVisits_v1",
    likes = "BaseLikes_v1",
} :: { [string]: string }
Social.RankingSize = 10
-- Segundos entre lecturas de las clasificaciones y entre guardados de cada jugador (solo se
-- guarda lo que ha cambiado).
Social.RankingRefreshSeconds = 180
Social.RankingSaveSeconds = 300

return Social
