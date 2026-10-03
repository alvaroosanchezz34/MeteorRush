--!strict

local Trade = {}

-- Cuenta atrás tras la doble confirmación; se reinicia si alguien cambia su oferta.
Trade.CountdownSeconds = 5
-- Segundos que dura una solicitud sin respuesta.
Trade.RequestTimeout = 30
-- Máximo de minerales por oferta.
Trade.MaxOfferItems = 20

return Trade
