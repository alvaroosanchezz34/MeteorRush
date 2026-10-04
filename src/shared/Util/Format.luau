--!strict

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- Número abreviado: 950, 1.2K, 3.4M...
function Format.Number(value: number): string
    if value ~= value then
        return "0"
    end
    local negative = value < 0
    local absolute = math.abs(value)
    if absolute < 1000 then
        local text = tostring(math.floor(absolute))
        return if negative then "-" .. text else text
    end

    local tier = math.min(math.floor(math.log10(absolute) / 3), #SUFFIXES - 1)
    local scaled = absolute / 10 ^ (tier * 3)
    -- Un decimal, sin ".0" al final.
    local text = string.format("%.1f", math.floor(scaled * 10) / 10):gsub("%.0$", "")
    text = text .. SUFFIXES[tier + 1]
    return if negative then "-" .. text else text
end

-- Duración en formato corto: "45s", "2:05", "1h 20m".
function Format.Duration(seconds: number): string
    local total = math.max(math.floor(seconds), 0)
    if total < 60 then
        return `{total}s`
    end
    if total < 3600 then
        return string.format("%d:%02d", total // 60, total % 60)
    end
    return string.format("%dh %dm", total // 3600, (total % 3600) // 60)
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
