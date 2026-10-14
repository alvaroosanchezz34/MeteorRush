--!strict

-- Textos visibles para el jugador, en el idioma activo. Los textos de cada idioma están en
-- Locale/en y Locale/es; esta tabla es Locale.Active, que el cliente reescribe al cambiar de
-- idioma (en el servidor es siempre inglés). Léela al pintar, no guardes copias de sus textos.

local Locale = require(script.Parent.Locale)

type StringsTable = typeof(Locale.Active) & {
    MineralName: (mineralId: string, mutationId: string) -> string,
    Upper: (text: string) -> string,
    TitleOf: (player: Player) -> string?,
}

local Strings = Locale.Active :: any

-- Nombre visible de un mineral con su mutación, p. ej. "Golden Plasma Core" o, en español,
-- "Núcleo de Plasma Dorado".
function Strings.MineralName(mineralId: string, mutationId: string): string
    return Locale.MineralName(mineralId, mutationId)
end

-- Mayúsculas que respetan las vocales acentuadas y la ñ. Úsala en vez de string.upper con
-- cualquier texto visible.
function Strings.Upper(text: string): string
    return Locale.Upper(text)
end

-- Título equipado de un jugador en el idioma activo, o nil si no lleva. El servidor publica el
-- id en el atributo `TitleId` (y el texto en inglés en `Title`, por compatibilidad).
function Strings.TitleOf(player: Player): string?
    local titleId = player:GetAttribute("TitleId")
    if type(titleId) == "string" then
        local text = Strings.Titles[titleId]
        if type(text) == "string" then
            return text
        end
    end
    local title = player:GetAttribute("Title")
    return if type(title) == "string" then title else nil
end

return Strings :: StringsTable
