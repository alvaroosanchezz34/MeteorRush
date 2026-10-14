--!strict

local Trade = {}

-- Cuenta atrás tras la doble confirmación; se reinicia si alguien cambia su oferta.
Trade.CountdownSeconds = 5
-- Segundos que dura una solicitud sin respuesta.
Trade.RequestTimeout = 30
-- Máximo de minerales por oferta.
Trade.MaxOfferItems = 20

-- Política de Roblox (IsPaidItemTradingAllowed). Los picos y las armas salen de cajas que
-- se compran con monedas, y las monedas se compran con Robux: son objetos de pago, y nunca
-- se intercambian con un jugador que no tenga permitido ese intercambio.
-- true = a esos jugadores se les bloquea todo el intercambio, también el de minerales (la
-- opción prudente: los minerales se venden por monedas y hay boosts de pago que ayudan a
-- conseguirlos). false = solo se les bloquean los picos y las armas.
Trade.PolicyBlocksAllTrading = true

return Trade
