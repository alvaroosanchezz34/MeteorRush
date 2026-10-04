--!strict

-- Equipamiento: picos y armas. Este módulo reúne las definiciones de Config/Pickaxes y
-- Config/Weapons, sus rarezas (una tabla propia: no toca las de los minerales), los topes de
-- cada estadística y lo que vale un duplicado. Todo el balance del equipamiento se cambia
-- aquí y en esos dos archivos.
--
-- Las estadísticas las leen servidor y cliente con `GetStat`, así la interfaz enseña
-- exactamente lo que aplica el servidor.

local Pickaxes = require(script.Parent.Pickaxes)
local Weapons = require(script.Parent.Weapons)
local Types = require(script.Parent.Parent.Types)

export type Rarity = {
    id: string,
    rank: number,
    color: Color3,
    -- Forge Dust que da un duplicado de esta rareza.
    dust: number,
}

export type Item = {
    id: string,
    -- "pickaxe" o "weapon".
    kind: string,
    rarity: string,
    -- Objeto inicial: todos lo tienen, no sale en cajas y no se intercambia.
    starter: boolean?,
    style: string,
    color: Color3,
    accent: Color3?,
    ability: string?,
    stats: { [string]: number },
    -- false = no se puede intercambiar (objetos exclusivos). Por defecto, sí.
    tradeable: boolean?,
    -- false = no sale en ninguna caja (objetos de evento o de temporada).
    droppable: boolean?,
}

local Equipment = {}

Equipment.Kinds = { "pickaxe", "weapon" }

Equipment.Rarities = {
    common = { id = "common", rank = 1, color = Color3.fromRGB(170, 170, 170), dust = 5 },
    uncommon = { id = "uncommon", rank = 2, color = Color3.fromRGB(90, 200, 90), dust = 12 },
    rare = { id = "rare", rank = 3, color = Color3.fromRGB(70, 140, 255), dust = 30 },
    epic = { id = "epic", rank = 4, color = Color3.fromRGB(170, 80, 240), dust = 80 },
    legendary = { id = "legendary", rank = 5, color = Color3.fromRGB(255, 170, 30), dust = 200 },
    mythic = { id = "mythic", rank = 6, color = Color3.fromRGB(255, 60, 90), dust = 500 },
} :: { [string]: Rarity }

-- De la más común a la más rara.
Equipment.RarityOrder = { "common", "uncommon", "rare", "epic", "legendary", "mythic" }

-- Objeto equipado por defecto de cada tipo (el inicial).
Equipment.Defaults = {
    pickaxe = "rustedPick",
    weapon = "rustyBat",
} :: { [string]: string }

-- Topes de cada estadística: { mínimo, máximo }. Un objeto nunca los supera, se escriba lo
-- que se escriba en su definición. Son el seguro contra multiplicadores absurdos.
Equipment.Limits = {
    -- Picos.
    speed = { 0, 0.12 },
    crit = { 0, 0.06 },
    rareFind = { 0, 0.08 },
    mutation = { 0, 0.1 },
    fragment = { 0, 0.1 },
    -- Armas.
    range = { 0, 3 },
    cooldown = { 1.6, 3 },
    dropPower = { 0, 0.1 },
    knockback = { 0, 60 },
    stunChance = { 0, 0.3 },
    stun = { 0, 0.8 },
} :: { [string]: { number } }

-- Estadísticas que se enseñan de cada tipo, en este orden.
Equipment.StatOrder = {
    pickaxe = { "speed", "crit", "rareFind", "mutation", "fragment" },
    weapon = { "range", "cooldown", "dropPower", "knockback", "stunChance", "stun" },
} :: { [string]: { string } }

-- Estadísticas que se muestran como porcentaje.
Equipment.PercentStats = {
    speed = true,
    crit = true,
    rareFind = true,
    mutation = true,
    fragment = true,
    dropPower = true,
    stunChance = true,
} :: { [string]: boolean }

-- Forge Dust por golpe cuando salta la estadística `fragment`.
Equipment.FragmentDust = 1

-- Qué pasa con un duplicado. "dust": se convierte en Forge Dust según su rareza.
-- (Solo existe ese modo; el campo está para poder añadir otros sin tocar CrateService.)
Equipment.DuplicateMode = "dust"

local list: { Item } = {}
local byId: { [string]: Item } = {}
for _, source in { Pickaxes :: { Item }, Weapons.List :: { Item } } do
    for _, item in source do
        table.insert(list, item)
        byId[item.id] = item
    end
end
Equipment.List = list
Equipment.ById = byId

function Equipment.GetRank(item: Item): number
    return Equipment.Rarities[item.rarity].rank
end

-- Objetos de un tipo, del más común al más raro.
function Equipment.GetByKind(kind: string): { Item }
    local result: { Item } = {}
    for _, item in list do
        if item.kind == kind then
            table.insert(result, item)
        end
    end
    table.sort(result, function(a: Item, b: Item): boolean
        return Equipment.GetRank(a) < Equipment.GetRank(b)
    end)
    return result
end

-- Valor de una estadística de un objeto, dentro de sus topes. `default` es lo que vale si el
-- objeto no la define (0 salvo que se indique otra cosa).
function Equipment.GetItemStat(item: Item, stat: string, default: number?): number
    local value = item.stats[stat] or default or 0
    local limit = Equipment.Limits[stat]
    return if limit then math.clamp(value, limit[1], limit[2]) else value
end

-- Indica si el jugador tiene ese objeto.
function Equipment.Owns(data: Types.Profile, itemId: string): boolean
    return data.equipment.owned[itemId] == true
end

-- Objeto equipado de ese tipo. Si el guardado no vale (no existe, no es de ese tipo o no lo
-- tiene), el inicial.
function Equipment.GetEquipped(data: Types.Profile, kind: string): Item
    local itemId = (data.equipment :: any)[kind]
    local item = if type(itemId) == "string" then byId[itemId] else nil
    if item and item.kind == kind and Equipment.Owns(data, item.id) then
        return item
    end
    return byId[Equipment.Defaults[kind]]
end

-- Estadística del objeto que el jugador lleva equipado.
function Equipment.GetStat(
    data: Types.Profile,
    kind: string,
    stat: string,
    default: number?
): number
    return Equipment.GetItemStat(Equipment.GetEquipped(data, kind), stat, default)
end

-- Indica si el objeto se puede intercambiar: no es el inicial ni está marcado como exclusivo.
function Equipment.IsTradeable(item: Item): boolean
    return item.starter ~= true and item.tradeable ~= false
end

return Equipment
