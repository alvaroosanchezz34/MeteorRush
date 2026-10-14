-- Comprobación de los idiomas y pruebas del módulo Locale, sin Roblox Studio.
-- Uso (desde la raíz del proyecto):  lune run tools/check-locales.luau
--
-- 1. Cada texto de Locale/es existe en Locale/en (no hay claves huérfanas o mal escritas).
-- 2. Cada texto traducido tiene los mismos %s / %d, en el mismo orden, que el inglés.
-- 3. Lista los textos en inglés que aún no tienen traducción.
-- 4. Pruebas de Locale: respaldo, claves y parámetros que faltan, números, nombres de mineral,
--    mensajes del servidor y cambio de idioma en caliente.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local task = require("@lune/task")

local ROOT = "src/shared/Locale/"
local failures = 0

local function fail(message: string)
    failures += 1
    print("  FALLO: " .. message)
end

local function loadModule(path: string, env: { [string]: any }?): any
    local source = fs.readFile(path)
    local chunk = luau.load(source, { debugName = path, environment = env or {} })
    return chunk()
end

local languages = {
    en = loadModule(ROOT .. "en.luau"),
    es = loadModule(ROOT .. "es.luau"),
}

-- Claves que solo tienen sentido en un idioma (gramática).
local LANGUAGE_ONLY = { MineralGenders = true, MutationsFeminine = true }

local function placeholders(text: string): string
    local found = {}
    for spec in string.gmatch(text, "%%[%-%+ #0]*%d*%.?%d*[%%sdifxXq]") do
        if spec ~= "%%" then
            -- Para comparar basta con el tipo: %s y %d no son intercambiables.
            table.insert(found, string.sub(spec, -1))
        end
    end
    return table.concat(found, ",")
end

local missing = {}
local function compare(base: any, other: any, path: string, language: string)
    for key, value in other do
        local keyPath = if path == "" then tostring(key) else `{path}.{key}`
        local reference = base[key]
        if path == "" and LANGUAGE_ONLY[key] then
            continue
        end
        if reference == nil then
            -- Las listas pueden tener otro número de frases.
            if type(key) ~= "number" then
                fail(`[{language}] "{keyPath}" no existe en inglés`)
            end
        elseif type(reference) ~= type(value) then
            fail(`[{language}] "{keyPath}" es {type(value)} y en inglés es {type(reference)}`)
        elseif type(value) == "table" then
            compare(reference, value, keyPath, language)
        elseif type(value) == "string" and type(key) ~= "number" then
            if placeholders(reference) ~= placeholders(value) then
                fail(
                    `[{language}] "{keyPath}": parámetros "{placeholders(value)}" y en inglés "{placeholders(
                        reference
                    )}"`
                )
            end
        end
    end
    for key, value in base do
        local keyPath = if path == "" then tostring(key) else `{path}.{key}`
        if other[key] == nil and type(key) ~= "number" then
            table.insert(missing, `[{language}] {keyPath}`)
        elseif type(value) == "table" and type(other[key]) == "table" and #value == 0 then
            -- Ya se recorre en la otra pasada; aquí solo se buscan huecos.
            local function holes(b: any, o: any, p: string)
                for k, v in b do
                    local kp = `{p}.{k}`
                    if o[k] == nil and type(k) ~= "number" then
                        table.insert(missing, `[{language}] {kp}`)
                    elseif type(v) == "table" and type(o[k]) == "table" and #v == 0 then
                        holes(v, o[k], kp)
                    end
                end
            end
            holes(value, other[key], keyPath)
        end
    end
end

print("Comprobando Locale/es contra Locale/en...")
compare(languages.en, languages.es, "", "es")
if #missing > 0 then
    print(`  Sin traducir ({#missing}), se mostrarán en inglés:`)
    for _, line in missing do
        print("    " .. line)
    end
    fail("hay textos sin traducir")
else
    print("  Todos los textos están traducidos.")
end

-- Pruebas del módulo ------------------------------------------------------------------

print("Probando el módulo Locale...")
local fakeScript = { en = "en", es = "es" }
local Locale = loadModule(ROOT .. "init.luau", {
    script = fakeScript,
    require = function(target: any): any
        return languages[target]
    end,
    warn = function() end,
    task = task,
    game = {},
})

local function check(name: string, got: any, expected: any)
    if got ~= expected then
        fail(`{name}: se esperaba {tostring(expected)}, salió {tostring(got)}`)
    end
end

-- Detección: español → es, inglés → en, cualquier otro → en.
check("es-es", Locale.FromLocaleId("es-es"), "es")
check("es-mx", Locale.FromLocaleId("es-mx"), "es")
check("en-us", Locale.FromLocaleId("en-us"), "en")
check("pt-br", Locale.FromLocaleId("pt-br"), "en")
check("nil", Locale.FromLocaleId(nil), "en")
check("Normalize fr", Locale.Normalize("fr"), "en")

-- Textos, respaldo y tolerancia.
check(
    "GetText en",
    Locale.GetText("Upgrades.Bought", "en", { "Pickaxe", 3 }),
    "Pickaxe upgraded to level 3!"
)
check(
    "GetText es",
    Locale.GetText("Upgrades.Bought", "es", { "Pico", 3 }),
    "¡Pico sube al nivel 3!"
)
check("Clave inexistente", Locale.GetText("No.Existe", "es"), "No.Existe")
check("Idioma inexistente", Locale.GetText("Hud.SafeZone", "fr"), languages.en.Hud.SafeZone)
check(
    "Faltan parámetros",
    Locale.GetText("Upgrades.Bought", "en", { "Pickaxe" }),
    "Pickaxe upgraded to level !"
)
check(
    "Parámetro de otro tipo",
    Locale.GetText("Carry.Deposited", "en", { "x" }),
    "Deposited x minerals in your base!"
)
check("Porcentaje", Locale.GetText("Social.Hud", "es", { 20 }), "👥 Amigos +20%")
check("Lista por índice", Locale.GetText("Tutorial.Steps.2", "es"), languages.es.Tutorial.Steps[2])

-- Números.
check("Número en", Locale.FormatNumber(1234, "en"), "1.2K")
check("Número es", Locale.FormatNumber(1234, "es"), "1,2K")
check("Número entero", Locale.FormatNumber(1000, "es"), "1K")
check("Número pequeño", Locale.FormatNumber(950, "es"), "950")
check("Negativo", Locale.FormatNumber(-2500000, "es"), "-2,5M")
check("Moneda", Locale.FormatCurrency(1500, "es"), "$1,5K")
check("NaN", Locale.FormatNumber(0 / 0, "en"), "0")

-- Nombres de mineral con concordancia en español.
check("Mineral en", Locale.MineralName("plasma", "gold", "en"), "Golden Plasma Core")
check("Mineral es m", Locale.MineralName("plasma", "gold", "es"), "Núcleo de Plasma Dorado")
check("Mineral es f", Locale.MineralName("stone", "radioactive", "es"), "Roca Espacial Radiactiva")
check("Mineral normal", Locale.MineralName("iron", "none", "es"), "Hierro Estelar")
check("Mineral desconocido", Locale.MineralName("xyz", "none", "es"), "xyz")

-- Mayúsculas con tildes.
check("Mayúsculas", Locale.Upper("Colección del árbol, niño"), "COLECCIÓN DEL ÁRBOL, NIÑO")
check(
    "Msg mayúsculas",
    Locale.Resolve(Locale.UpperMsg(Locale.Ref("Mutations.rainbow")), "es"),
    "ARCOÍRIS"
)

-- Mensajes del servidor.
local message = Locale.Msg("Pedestal.Placed", Locale.Mineral("nebula", "gold"))
check("Msg es", Locale.Resolve(message, "es"), "Colocado: Gema Nebular Dorada")
check("Msg en", Locale.Resolve(message, "en"), "Placed Golden Nebula Gem")
check(
    "Msg anidado",
    Locale.Resolve(Locale.Msg("Upgrades.Bought", Locale.Ref("Upgrades.Names.luck"), 4), "es"),
    "¡Suerte sube al nivel 4!"
)
check(
    "Msg número",
    Locale.Resolve(Locale.Msg("Income.Collected", Locale.Num(12500)), "es"),
    "+$12,5K"
)
check(
    "Msg lista",
    Locale.Resolve(
        Locale.Msg(
            "Codes.Redeemed",
            Locale.Join(
                " + ",
                { Locale.Msg("Daily.Coins", Locale.Num(500)), Locale.Mineral("iron", "none") }
            )
        ),
        "es"
    ),
    "Código canjeado: $500 + Hierro Estelar"
)
check("Msg texto suelto", Locale.Resolve("Hola", "en"), "Hola")
check("Msg vacío", Locale.Resolve({}, "en"), "")

-- Cambio de idioma en caliente: las referencias guardadas ven el idioma nuevo.
local active = Locale.Active
local names = active.Upgrades.Names
local lines = active.Npcs.Lines.miner
local calls = 0
local stop = Locale.OnChanged(function()
    calls += 1
end)
check("Inicio en inglés", active.Hud.SafeZone, languages.en.Hud.SafeZone)
Locale.SetCurrent("es")
task.wait()
check("Activo en español", active.Hud.SafeZone, languages.es.Hud.SafeZone)
check("Referencia guardada", names.pickaxe, "Pico")
check("Lista cambiada", lines[1], languages.es.Npcs.Lines.miner[1])
check("Clave solo en español", active.MineralGenders and active.MineralGenders.stone, "f")
check("Idioma actual", Locale.GetCurrentLanguage(), "es")
Locale.SetCurrent("es")
task.wait()
check("Sin aviso si no cambia", calls, 1)
Locale.SetCurrent("en")
task.wait()
check("Vuelta a inglés", names.pickaxe, "Pickaxe")
check("Lista en inglés", #lines, #languages.en.Npcs.Lines.miner)
check("Clave solo en español quitada", active.MineralGenders, nil)
stop()
Locale.SetCurrent("es")
task.wait()
check("Dejar de escuchar", calls, 2)
Locale.SetCurrent("fr")
check("Idioma no soportado → inglés", Locale.GetCurrentLanguage(), "en")

if failures > 0 then
    print(`\n{failures} fallo(s).`)
    process.exit(1)
end
print("\nTodo correcto.")
