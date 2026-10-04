--!strict

-- Momentos legendarios: acontecimientos tan raros que se anuncian a todo el servidor con un
-- aviso propio (un Star Heart, un Arcoíris de rareza alta, completar el índice, ganar tres
-- competiciones seguidas). Los decide y los envía el servidor (MomentService); aquí están
-- las reglas y los límites para que no se repitan demasiado.

local Minerals = require(script.Parent.Minerals)
local Mutations = require(script.Parent.Mutations)

local Moments = {}

-- Segundos mínimos entre dos momentos en el servidor, y entre dos del mismo tipo de un
-- mismo jugador.
Moments.GlobalGap = 6
Moments.PlayerCooldown = 20

-- Un mineral de este rango o superior siempre es un momento (6 = Mítico).
Moments.AlwaysRank = 6
-- Una mutación de las que se anuncian (Mutations.announce) lo es desde este rango (4 = Épico).
Moments.MutationRank = 4

-- Segundos que se ve el aviso en pantalla.
Moments.BannerSeconds = 4.5

-- Indica si conseguir ese mineral con esa mutación es un momento legendario.
function Moments.IsDiscovery(mineralId: string, mutationId: string): boolean
    local rank = Minerals.GetRank(mineralId)
    local mutation = Mutations.ById[mutationId]
    return rank >= Moments.AlwaysRank
        or (mutation ~= nil and mutation.announce == true and rank >= Moments.MutationRank)
end

return Moments
