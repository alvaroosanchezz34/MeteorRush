--!strict

-- Nivel de detalle de los efectos del cliente, según el dispositivo y los gráficos que ha
-- elegido el jugador. Los efectos piden aquí cuántas partículas y piezas crear: en un móvil o
-- con gráficos bajos salen menos, pero el efecto se sigue viendo igual de claro.

local UserInputService = game:GetService("UserInputService")

export type Level = "low" | "medium" | "high"

-- Gráficos elegidos (1-10) hasta los que se cuenta como bajo y como medio.
local LOW_GRAPHICS = 3
local MEDIUM_GRAPHICS = 6
-- Segundos que se recuerda el nivel: el jugador puede cambiar los gráficos en el menú.
local CACHE_SECONDS = 2

local Quality = {}

-- Fracción de partículas y piezas que se crean en cada nivel.
Quality.Scales = {
    low = 0.4,
    medium = 0.7,
    high = 1,
} :: { [Level]: number }

-- Efectos de mundo vivos a la vez en cada nivel.
Quality.MaxActive = {
    low = 18,
    medium = 30,
    high = 40,
} :: { [Level]: number }

local cached: Level = "high"
local cachedAt = -math.huge

local function compute(): Level
    local level: Level = "high"
    -- Pantalla táctil sin teclado: móvil o tableta.
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        level = "medium"
    end
    local ok, saved = pcall(function(): number
        return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
    end)
    -- 0 = automático: no se sabe, así que no se limita más.
    if ok and saved > 0 then
        if saved <= LOW_GRAPHICS then
            level = "low"
        elseif saved <= MEDIUM_GRAPHICS then
            level = "medium"
        end
    end
    return level
end

-- Nivel de detalle actual.
function Quality.Get(): Level
    local now = os.clock()
    if now - cachedAt >= CACHE_SECONDS then
        cached = compute()
        cachedAt = now
    end
    return cached
end

-- Cuántas piezas crear de las `count` que pide un efecto (al menos una).
function Quality.Count(count: number): number
    return math.max(math.floor(count * Quality.Scales[Quality.Get()] + 0.5), 1)
end

-- Indica si se está en el nivel más bajo: los adornos que no explican nada se omiten.
function Quality.IsLow(): boolean
    return Quality.Get() == "low"
end

return Quality
