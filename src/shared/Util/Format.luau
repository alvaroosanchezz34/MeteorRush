--!strict

-- Formatos de números y tiempos. Los números siguen el idioma activo (Locale): en el cliente,
-- el que ha elegido el jugador; en el servidor, siempre inglés.

local Locale = require(script.Parent.Parent.Locale)

local Format = {}

-- Número abreviado: 950, 1.2K, 3.4M... (1,2K en español).
function Format.Number(value: number): string
    return Locale.FormatNumber(value)
end

-- Duración en formato corto: "45s", "2:05", "1h 20m".
function Format.Duration(seconds: number): string
    return Locale.FormatDuration(seconds)
end

-- Duración larga, con días: "12d 3h". Por debajo de un día, igual que Duration.
function Format.LongDuration(seconds: number): string
    local total = math.max(math.floor(seconds), 0)
    if total < 86400 then
        return Format.Duration(total)
    end
    return string.format("%dd %dh", total // 86400, (total % 86400) // 3600)
end

return Format
