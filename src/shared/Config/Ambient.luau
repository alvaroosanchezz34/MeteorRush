--!strict

-- Vida ambiental del mapa: cosas que pasan en el cielo y alrededor sin afectar al juego.
--   * Sucesos corrientes: cada cliente los genera por su cuenta, uno cada cierto tiempo.
--   * Sucesos raros: los elige el servidor (AmbientService) para que todos los jugadores
--     vean lo mismo a la vez; cada cliente los dibuja (AmbientController).
-- Nada de esto da recompensas ni cambia probabilidades. Los textos están en Strings.Ambient.

export type RareEvent = {
    id: string,
    -- Probabilidad relativa de salir elegido y segundos que dura.
    weight: number,
    duration: number,
}

local Ambient = {}

-- Sucesos corrientes -----------------------------------------------------------------
-- Segundos entre uno y otro (mínimo y máximo). Se van turnando al azar.
Ambient.CommonMinWait = 14
Ambient.CommonMaxWait = 32
-- Probabilidad relativa de cada uno.
Ambient.CommonWeights = {
    skyMeteor = 4,
    satellite = 2,
    ship = 2,
} :: { [string]: number }

-- Sucesos raros ------------------------------------------------------------------------
-- Segundos desde que arranca el servidor hasta el primero y entre uno y otro.
Ambient.RareFirstDelay = 90
Ambient.RareMinWait = 140
Ambient.RareMaxWait = 260

Ambient.RareEvents = {
    { id = "starShower", weight = 3, duration = 24 },
    { id = "comet", weight = 3, duration = 20 },
    { id = "eclipse", weight = 2, duration = 36 },
    { id = "anomaly", weight = 2, duration = 30 },
    { id = "portal", weight = 2, duration = 32 },
} :: { RareEvent }

-- Estrellas de una lluvia de estrellas.
Ambient.StarShowerCount = 26

-- Luces del decorado que laten (cristales y farolas): cuántas a la vez como mucho, a qué
-- distancia de la cámara, cuánto varía el brillo y veces por segundo que se actualizan.
Ambient.PulseMaxLights = 16
Ambient.PulseDistance = 170
Ambient.PulseAmount = 0.22
Ambient.PulseRate = 10

-- Polvo espacial alrededor de la cámara: partículas por segundo.
Ambient.DustRate = 5

-- En móvil, las cantidades (estrellas, polvo, luces que laten) se multiplican por esto.
Ambient.MobileScale = 0.5

local byId: { [string]: RareEvent } = {}
for _, event in Ambient.RareEvents do
    byId[event.id] = event
end
Ambient.RareById = byId

return Ambient
