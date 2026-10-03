--!strict

-- Códigos canjeables (una vez por jugador). Se escriben en mayúsculas; al canjear no se
-- distinguen mayúsculas de minúsculas. Para retirar un código, bórralo de la lista.

export type Code = {
    coins: number?,
    -- Id de un mineral que se añade al inventario de la base, sin mutación.
    mineral: string?,
}

local Codes = {}

-- Longitud máxima del texto que se acepta del cliente.
Codes.MaxLength = 32

Codes.List = {
    WELCOME = { coins = 2500 },
    RUSH = { coins = 10000 },
    PLASMA = { mineral = "plasma" },
} :: { [string]: Code }

return Codes
