--!strict

-- Sistema de idiomas. Hay una tabla de textos por idioma (Locale/en, Locale/es) con las mismas
-- claves; lo que falte en un idioma sale en inglés.
--
-- Cliente: `Locale.Active` (que es lo que devuelve el módulo Strings) contiene los textos del
-- idioma elegido. Al cambiar de idioma se reescribe en el sitio, así que todo el código que lee
-- `Strings.X.Y` al pintar ya sale en el idioma nuevo; lo que se pinta una sola vez se enlaza
-- con `Locale.Bind` para que se repinte solo.
--
-- Servidor: nunca cambia de idioma (Active siempre en inglés). Los avisos a jugadores se mandan
-- como mensajes (`Locale.Msg`: clave + parámetros) y cada cliente los muestra en su idioma; los
-- textos del mundo (carteles, BillboardGui, ProximityPrompt) se marcan con `Locale.Tag`.
--
-- El idioma solo cambia lo que se ve. Ninguna regla del juego depende de él.

local en = require(script.en)
local es = require(script.es)

export type Language = string

-- Mensaje localizable que viaja por los remotes o se guarda en atributos:
--   { k = "Clave.Del.Texto", a = { parámetros } }   texto con parámetros
--   { n = 1234 }                                      número abreviado (1.2K / 1,2K)
--   { d = 90 }                                        duración ("1:30")
--   { m = "iron", u = "gold" }                        nombre de mineral con mutación
--   { j = " + ", l = { mensajes } }                   lista unida con un separador
--   { up = mensaje }                                  el mensaje en mayúsculas
-- Un texto suelto (string) se muestra tal cual: nombres de jugador, anuncios de administración.
export type Message = string | { [string]: any }

local Locale = {}

-- Idioma de respaldo: el original del juego.
Locale.Default = "en" :: Language
-- Orden en el selector de ajustes.
Locale.Languages = { "es", "en" } :: { Language }
-- Nombre de cada idioma en su propio idioma (no se traduce).
Locale.LanguageNames = {
    es = "Español 🇪🇸",
    en = "English 🇬🇧",
} :: { [Language]: string }
-- Atributo del jugador con su idioma efectivo. Lo pone el servidor (LanguageService).
Locale.Attribute = "Language"
-- Etiqueta de CollectionService para los textos del mundo localizados.
Locale.WorldTag = "Localized"
-- Prefijo de los atributos de esos textos: `L10n_Text`, `L10n_ActionText`...
Locale.AttributePrefix = "L10n_"

local tables: { [Language]: any } = {
    en = en,
    es = es,
}

local function deepCopy(value: any): any
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, child in value do
        copy[key] = deepCopy(child)
    end
    return copy
end

-- Textos del idioma activo. Empieza en inglés.
Locale.Active = deepCopy(en) :: typeof(en)

local current: Language = Locale.Default
local listeners: { [number]: (language: Language) -> () } = {}
local nextListener = 0
local warned: { [string]: boolean } = {}

local function warnOnce(message: string)
    if not warned[message] then
        warned[message] = true
        warn(`[Locale] {message}`)
    end
end

-- Idiomas ------------------------------------------------------------------------------

function Locale.IsSupported(language: any): boolean
    return type(language) == "string" and tables[language] ~= nil
end

-- El idioma si está soportado; si no, el de respaldo.
function Locale.Normalize(language: any): Language
    return if Locale.IsSupported(language) then language else Locale.Default
end

-- Idioma del juego para un LocaleId de Roblox ("es-es", "es-mx", "en-us", "pt-br"...):
-- cualquier español es "es", cualquier otro idioma es inglés.
function Locale.FromLocaleId(localeId: any): Language
    if type(localeId) ~= "string" then
        return Locale.Default
    end
    local prefix = string.lower(string.sub(localeId, 1, 2))
    return if Locale.IsSupported(prefix) then prefix else Locale.Default
end

-- Cliente: idioma que se está mostrando. Servidor: idioma de ese jugador (su atributo, o el
-- de su cuenta de Roblox si aún no tiene).
function Locale.GetCurrentLanguage(player: Player?): Language
    if player == nil then
        return current
    end
    local attribute = player:GetAttribute(Locale.Attribute)
    if Locale.IsSupported(attribute) then
        return attribute :: Language
    end
    local ok, localeId = pcall(function(): string
        return player.LocaleId
    end)
    return Locale.FromLocaleId(if ok then localeId else nil)
end

-- Textos ------------------------------------------------------------------------------

local function lookup(root: any, key: string): any
    local node = root
    for part in string.gmatch(key, "[^%.]+") do
        if type(node) ~= "table" then
            return nil
        end
        node = node[tonumber(part) or part]
    end
    return node
end

-- Texto crudo (sin parámetros) de esa clave, con respaldo en inglés.
function Locale.GetRaw(key: string, language: Language?): any
    local value = lookup(tables[Locale.Normalize(language or current)], key)
    if value == nil then
        value = lookup(en, key)
    end
    return value
end

local resolve: (message: any, language: Language) -> string

-- Sustituye los %s / %d uno a uno, para cuando string.format falla (faltan parámetros o
-- uno no es del tipo esperado): nunca rompe, como mucho deja un hueco vacío.
local function safeFormat(template: string, args: { any }, count: number): string
    local index = 0
    return (
        string.gsub(
            template,
            "%%([%-%+ #0]*%d*%.?%d*)([%%sdifxXq])",
            function(flags: string, kind: string)
                if kind == "%" then
                    return "%"
                end
                index += 1
                local value = if index <= count then args[index] else nil
                if value == nil then
                    return ""
                end
                local ok, text = pcall(string.format, "%" .. flags .. kind, value)
                return if ok then text else tostring(value)
            end
        )
    )
end

local function format(template: string, params: { any }?, language: Language): string
    if params == nil then
        return template
    end
    local count = 0
    for index in params do
        if type(index) == "number" and index > count then
            count = index
        end
    end
    if count == 0 then
        return template
    end
    local args = table.create(count)
    for index = 1, count do
        local value = params[index]
        -- Los parámetros que son mensajes se traducen antes; los números se dejan tal cual
        -- para los %d.
        args[index] = if type(value) == "table" then resolve(value, language) else value
    end
    local ok, result = pcall(string.format, template, table.unpack(args, 1, count))
    if ok then
        return result
    end
    return safeFormat(template, args, count)
end

-- Texto de esa clave en ese idioma (por defecto, el activo), con sus parámetros. Si la clave no
-- existe en ningún idioma devuelve la propia clave, para que se vea el fallo sin romper nada.
function Locale.GetText(key: string, language: Language?, params: { any }?): string
    local lang = Locale.Normalize(language or current)
    local template = lookup(tables[lang], key)
    if type(template) ~= "string" then
        template = lookup(en, key)
    end
    if type(template) ~= "string" then
        warnOnce(`Falta el texto "{key}"`)
        return key
    end
    return format(template, params, lang)
end

-- Números ------------------------------------------------------------------------------

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
-- Separador decimal de cada idioma.
local DECIMAL: { [Language]: string } = { en = ".", es = "," }

-- Número abreviado: 950, 1.2K, 3.4M... En español con coma decimal: 1,2K.
function Locale.FormatNumber(value: number, language: Language?): string
    if value ~= value then
        return "0"
    end
    local negative = value < 0
    local absolute = math.abs(value)
    local text: string
    if absolute < 1000 then
        text = tostring(math.floor(absolute))
    else
        local tier = math.min(math.floor(math.log10(absolute) / 3), #SUFFIXES - 1)
        local scaled = absolute / 10 ^ (tier * 3)
        -- Un decimal, sin ".0" al final.
        text = string.format("%.1f", math.floor(scaled * 10) / 10):gsub("%.0$", "")
        local decimal = DECIMAL[Locale.Normalize(language or current)] or "."
        if decimal ~= "." then
            text = text:gsub("%.", decimal)
        end
        text ..= SUFFIXES[tier + 1]
    end
    return if negative then "-" .. text else text
end

-- Número con decimales fijos, con el separador decimal del idioma: 1.25 / 1,25.
function Locale.FormatDecimal(value: number, decimals: number, language: Language?): string
    local text = string.format(`%.{math.max(math.floor(decimals), 0)}f`, value)
    local decimal = DECIMAL[Locale.Normalize(language or current)] or "."
    return if decimal ~= "." then (text:gsub("%.", decimal)) else text
end

-- Cantidad de monedas del juego: "$1.2K" / "$1,2K".
function Locale.FormatCurrency(value: number, language: Language?): string
    return "$" .. Locale.FormatNumber(value, language)
end

-- Duración corta: "45s", "2:05", "1h 20m" (igual en los dos idiomas).
function Locale.FormatDuration(seconds: number): string
    local total = math.max(math.floor(seconds), 0)
    if total < 60 then
        return `{total}s`
    end
    if total < 3600 then
        return string.format("%d:%02d", total // 60, total % 60)
    end
    return string.format("%dh %dm", total // 3600, (total % 3600) // 60)
end

-- Nombre visible de un mineral con su mutación: "Golden Plasma Core" / "Núcleo de Plasma Dorado".
function Locale.MineralName(mineralId: string, mutationId: string, language: Language?): string
    local lang = Locale.Normalize(language or current)
    local name = Locale.GetRaw(`Minerals.{mineralId}`, lang)
    if type(name) ~= "string" then
        name = mineralId
    end
    if mutationId == "none" then
        return name
    end
    local mutation: any = nil
    local genders = tables[lang].MineralGenders
    if genders and genders[mineralId] == "f" then
        mutation = lookup(tables[lang], `MutationsFeminine.{mutationId}`)
    end
    if type(mutation) ~= "string" then
        mutation = Locale.GetRaw(`Mutations.{mutationId}`, lang)
    end
    if type(mutation) ~= "string" then
        mutation = mutationId
    end
    local pattern = Locale.GetRaw("MineralNameFormat", lang)
    if type(pattern) ~= "string" then
        pattern = "{mutation} {mineral}"
    end
    return (
        pattern
            :gsub("{mineral}", function()
                return name
            end)
            :gsub("{mutation}", function()
                return mutation
            end)
    )
end

-- Mayúsculas que también funcionan con las vocales acentuadas y la ñ (string.upper solo
-- cambia las letras ASCII: "Colección" saldría "COLECCIóN").
local UPPER: { [string]: string } = {
    ["á"] = "Á",
    ["é"] = "É",
    ["í"] = "Í",
    ["ó"] = "Ó",
    ["ú"] = "Ú",
    ["ñ"] = "Ñ",
    ["ü"] = "Ü",
}
function Locale.Upper(text: string): string
    return (
        string.gsub(string.upper(text), "\195[\128-\191]", function(character: string): string
            return UPPER[character] or character
        end)
    )
end

-- Mensajes -----------------------------------------------------------------------------

-- Mensaje con clave y parámetros. Los parámetros pueden ser números, textos sueltos u otros
-- mensajes (Num, Dur, Mineral, Ref...).
function Locale.Msg(key: string, ...: any): Message
    local count = select("#", ...)
    if count == 0 then
        return { k = key }
    end
    return { k = key, a = { ... } }
end

-- Texto de otra clave usado como parámetro (p. ej. el nombre de una mejora).
function Locale.Ref(key: string): Message
    return { k = key }
end

function Locale.Num(value: number): Message
    return { n = value }
end

function Locale.Dur(seconds: number): Message
    return { d = seconds }
end

function Locale.Mineral(mineralId: string, mutationId: string): Message
    return { m = mineralId, u = mutationId }
end

function Locale.Join(separator: string, list: { Message }): Message
    return { j = separator, l = list }
end

-- El mismo mensaje en mayúsculas.
function Locale.UpperMsg(message: Message): Message
    return { up = message }
end

resolve = function(message: any, language: Language): string
    if type(message) == "string" then
        return message
    elseif type(message) == "number" then
        return tostring(message)
    elseif type(message) ~= "table" then
        return ""
    end
    if type(message.k) == "string" then
        return Locale.GetText(
            message.k,
            language,
            if type(message.a) == "table" then message.a else nil
        )
    elseif type(message.n) == "number" then
        return Locale.FormatNumber(message.n, language)
    elseif type(message.d) == "number" then
        return Locale.FormatDuration(message.d)
    elseif type(message.m) == "string" then
        return Locale.MineralName(
            message.m,
            if type(message.u) == "string" then message.u else "none",
            language
        )
    elseif message.up ~= nil then
        return Locale.Upper(resolve(message.up, language))
    elseif type(message.l) == "table" then
        local parts = {}
        for _, part in message.l do
            table.insert(parts, resolve(part, language))
        end
        return table.concat(parts, if type(message.j) == "string" then message.j else " ")
    end
    return ""
end

-- Texto de un mensaje en ese idioma (por defecto, el activo).
function Locale.Resolve(message: Message, language: Language?): string
    return resolve(message, Locale.Normalize(language or current))
end

-- Cambio de idioma (cliente) -----------------------------------------------------------

-- Copia los textos de `source` (con respaldo en `fallback`) sobre `target`, sin cambiar las
-- tablas de sitio: quien guarde una referencia a una subtabla sigue viendo el idioma nuevo.
local function apply(target: any, fallback: any, source: any)
    for key, base in fallback do
        local value = if type(source) == "table" then source[key] else nil
        if type(base) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            -- Las listas (frases de NPC, pasos del tutorial) se cambian enteras.
            if #base > 0 then
                local lines = if type(value) == "table" and #value > 0 then value else base
                table.clear(target[key])
                for index, line in lines do
                    target[key][index] = line
                end
            else
                apply(target[key], base, value)
            end
        elseif type(base) == "string" then
            target[key] = if type(value) == "string" then value else base
        end
    end
    -- Claves que solo existen en este idioma (p. ej. géneros en español).
    if type(source) == "table" then
        for key, value in source do
            if fallback[key] == nil then
                target[key] = deepCopy(value)
            end
        end
    end
end

-- Muestra el juego en ese idioma: reescribe los textos activos y avisa a quien esté
-- escuchando (OnChanged). Solo en el cliente.
function Locale.SetCurrent(language: Language)
    local lang = Locale.Normalize(language)
    if lang == current then
        return
    end
    -- Quita las claves exclusivas del idioma anterior antes de poner las del nuevo.
    for key in tables[current] do
        if (en :: any)[key] == nil then
            (Locale.Active :: any)[key] = nil
        end
    end
    current = lang
    apply(Locale.Active, en, tables[lang])
    for _, callback in table.clone(listeners) do
        task.spawn(callback, lang)
    end
end

-- Llama a la función cada vez que cambia el idioma. Devuelve la función que deja de escuchar.
function Locale.OnChanged(callback: (language: Language) -> ()): () -> ()
    nextListener += 1
    local id = nextListener
    listeners[id] = callback
    return function()
        listeners[id] = nil
    end
end

-- Pone en esa propiedad lo que devuelva `getter` y lo vuelve a poner cada vez que cambia el
-- idioma, hasta que se destruye la instancia. Para los textos que se pintan una sola vez.
function Locale.Bind(instance: Instance, property: string, getter: () -> string)
    local function update()
        local ok, text = pcall(getter)
        if ok and type(text) == "string" then
            (instance :: any)[property] = text
        end
    end
    update()
    local disconnect = Locale.OnChanged(update)
    instance.Destroying:Connect(disconnect)
end

-- Textos del mundo (servidor) ----------------------------------------------------------

-- Marca una propiedad de texto de una instancia del mundo como localizada: guarda el mensaje
-- en un atributo para que cada cliente la pinte en su idioma (LanguageController) y deja el
-- inglés como texto por defecto. Llamarla otra vez actualiza el texto.
function Locale.Tag(instance: Instance, property: string, message: Message)
    local HttpService = game:GetService("HttpService")
    local CollectionService = game:GetService("CollectionService")
    local encoded = if type(message) == "string" then message else HttpService:JSONEncode(message)
    instance:SetAttribute(Locale.AttributePrefix .. property, encoded)
    local target: any = instance
    target[property] = Locale.Resolve(message, Locale.Default)
    if not CollectionService:HasTag(instance, Locale.WorldTag) then
        CollectionService:AddTag(instance, Locale.WorldTag)
    end
end

return Locale
