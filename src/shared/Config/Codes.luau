--!strict

-- Códigos canjeables (una vez por jugador). Se escriben en mayúsculas; al canjear no se
-- distinguen mayúsculas de minúsculas. Para retirar un código, bórralo de la lista o ponle
-- una fecha de caducidad.

export type Code = {
    coins: number?,
    -- Id de un mineral que se añade al inventario de la base, sin mutación.
    mineral: string?,
    -- Hora Unix (UTC) a partir de la cual deja de valer. Sin ella, no caduca.
    expiresAt: number?,
}

local Codes = {}

-- Longitud máxima del texto que se acepta del cliente.
Codes.MaxLength = 32

Codes.List = {
    WELCOME = { coins = 2500 },
    RUSH = { coins = 10000 },
    PLASMA = { mineral = "plasma" },
    SEASON1 = { coins = 5000, expiresAt = os.time({ year = 2026, month = 11, day = 1, hour = 0 }) },
} :: { [string]: Code }

return Codes
