--!strict

-- Registro de desarrollo del servidor: errores de guardado y acciones sospechosas de clientes.
-- Todo sale por la consola con un prefijo fijo para poder filtrarlo en la Salida de Studio
-- o en la consola de desarrollador (F9) del juego publicado.

local Log = {}

-- Acciones sospechosas por jugador en esta sesión del servidor.
local suspiciousCounts: { [number]: number } = {}

-- Aviso general de un sistema (fallos de DataStore, de compras, etc.).
function Log.Warn(source: string, message: string)
    warn(`[{source}] {message}`)
end

-- Un cliente ha enviado algo que el cliente legítimo nunca envía (tipos inválidos, demasiadas
-- peticiones...). No expulsa a nadie: solo deja constancia, con el recuento del jugador.
function Log.Suspicious(player: Player, action: string, detail: string?)
    local count = (suspiciousCounts[player.UserId] or 0) + 1
    suspiciousCounts[player.UserId] = count
    warn(
        `[Suspicious] {player.Name} ({player.UserId}) · {action}`
            .. (if detail then ` · {detail}` else "")
            .. ` · #{count}`
    )
end

-- Número de acciones sospechosas registradas de un jugador en esta sesión.
function Log.GetSuspiciousCount(player: Player): number
    return suspiciousCounts[player.UserId] or 0
end

return Log
