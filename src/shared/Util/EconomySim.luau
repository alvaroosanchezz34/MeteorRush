--!strict

-- Simulador de economía para pruebas de equilibrio. Juega solo el bucle
-- minar → volver → colocar → vender/fusionar → mejorar → rebirth con los valores de `Config`
-- y las fórmulas de `PlayerStats` y `Loot`, y apunta el estado a ciertas horas de juego.
-- No toca datos de jugadores: trabaja sobre una copia de la plantilla del perfil.
-- Se lanza desde DebugService (solo en Studio).
--
-- Simplificaciones del modelo:
--   * Los golpes de meteorito del servidor se reparten a partes iguales entre los jugadores.
--   * Cada viaje llena la mochila; la distancia de ida y de vuelta es `Map.PlotRingRadius`.
--   * Los ingresos se cobran en cada viaje. No hay robos, misiones, racha, índice, eventos
--     (ni sus meteoritos especiales) ni ingresos sin conexión.
--   * El jugador coloca siempre lo mejor, fusiona solo si el resultado merece un pedestal,
--     vende el resto, compra la mejora más barata y hace rebirth en cuanto puede. Los shards
--     los gasta en el nodo desbloqueado más barato del árbol permanente.

local Config = script.Parent.Parent.Config
local DataConfig = require(Config.Data)
local Map = require(Config.Map)
local Meteors = require(Config.Meteors)
local Minerals = require(Config.Minerals)
local Mutations = require(Config.Mutations)
local Permanent = require(Config.Permanent)
local Rebirth = require(Config.Rebirth)
local Upgrades = require(Config.Upgrades)
local Format = require(script.Parent.Format)
local Loot = require(script.Parent.Loot)
local PlayerStats = require(script.Parent.PlayerStats)
local TableUtil = require(script.Parent.TableUtil)
local Types = require(script.Parent.Parent.Types)

export type Options = {
    -- Horas de juego en las que se apunta el estado, en orden creciente.
    checkpoints: { number },
    -- Jugadores en el servidor: se reparten los golpes de los meteoritos.
    players: number,
    -- Fracción del tiempo (0-1) que el jugador dedica de verdad al bucle.
    activity: number,
    -- No compra mejoras que cuesten más que esta fracción del siguiente rebirth.
    upgradeBudget: number,
    -- Game passes que tiene el jugador simulado.
    passes: { [string]: boolean }?,
}

export type Snapshot = {
    hours: number,
    coins: number,
    earned: number,
    income: number,
    rebirths: number,
    upgradeLevels: number,
    -- Minutos que faltan para pagar el siguiente rebirth con los ingresos actuales.
    minutesToRebirth: number,
}

export type Result = {
    snapshots: { Snapshot },
    -- [mineral] = hora de juego en la que salió por primera vez.
    firstFound: { [string]: number },
    earned: { [string]: number },
    spent: { [string]: number },
}

export type Range = { low: number, median: number, high: number }

export type Summary = {
    options: Options,
    runs: number,
    -- Por cada hora de `checkpoints`: percentiles 10, 50 y 90 de cada dato.
    checkpoints: { { [string]: Range } },
    -- [mineral] = fracción de partidas en las que salió, mediana de la hora y fracción de
    -- partidas en las que salió antes de `BestMineralEarlyHours`.
    firstFound: { [string]: { chance: number, hours: number, early: number } },
    earned: { [string]: number },
    spent: { [string]: number },
}

local EconomySim = {}

EconomySim.DefaultOptions = {
    checkpoints = { 1, 5, 10, 30 },
    players = 4,
    activity = 0.8,
    upgradeBudget = 0.25,
} :: Options

-- Avisos del informe.
EconomySim.BestMineralEarlyHours = 1
EconomySim.BestMineralEarlyChance = 0.25
EconomySim.WallMinutes = 180

local maxUpgradeLevels = 0
for _, upgrade in Upgrades.List do
    maxUpgradeLevels += upgrade.maxLevel
end

local function byIncome(a: Types.InventoryItem, b: Types.InventoryItem): boolean
    return PlayerStats.GetItemBaseIncome(a) > PlayerStats.GetItemBaseIncome(b)
end

-- Simula una partida. `random` devuelve un número en [0, 1).
function EconomySim.Run(options: Options, random: () -> number): Result
    local rng: any = {
        NextNumber = function(): number
            return random()
        end,
    }
    local data: Types.Profile = TableUtil.DeepCopy(DataConfig.Template)
    data.passes = options.passes or {}

    local supply = 0
    local meteorTypes: { Meteors.MeteorType } = {}
    for _, meteorType in Meteors.Types do
        -- Los especiales solo caen en eventos, que el simulador no modela.
        if not meteorType.special then
            table.insert(meteorTypes, meteorType)
            supply += meteorType.hits / meteorType.interval
        end
    end
    table.sort(meteorTypes, function(a: Meteors.MeteorType, b: Meteors.MeteorType): boolean
        return a.id < b.id
    end)

    local result: Result = { snapshots = {}, firstFound = {}, earned = {}, spent = {} }
    local items: { Types.InventoryItem } = {}
    local income = 0
    local seconds = 0

    local function earn(source: string, amount: number)
        data.coins += amount
        data.totalCoinsEarned += amount
        result.earned[source] = (result.earned[source] or 0) + amount
    end

    local function spend(sink: string, amount: number)
        data.coins -= amount
        result.spent[sink] = (result.spent[sink] or 0) + amount
    end

    -- Tira un mineral como lo hace MiningService, eligiendo el meteorito según sus golpes.
    local function mine(carried: { Types.InventoryItem })
        local roll = random() * supply
        local meteorType = meteorTypes[#meteorTypes]
        for _, candidate in meteorTypes do
            roll -= candidate.hits / candidate.interval
            if roll < 0 then
                meteorType = candidate
                break
            end
        end
        local mineral = Loot.RollMineral(
            meteorType.rareWeightMultiplier * PlayerStats.GetLuckMultiplier(data, 0),
            rng
        )
        local mutation = Loot.RollMutation(
            meteorType.mutationMultiplier * PlayerStats.GetMutationMultiplier(data),
            rng
        )
        table.insert(carried, { id = "", mineral = mineral.id, mutation = mutation.id })
        if result.firstFound[mineral.id] == nil then
            result.firstFound[mineral.id] = seconds / 3600
        end
    end

    -- Fusiona tríos de sobrantes si el resultado merece un pedestal, vende el resto.
    local function manageInventory()
        local slots = PlayerStats.GetPedestalCount(data)
        local fused = true
        while fused do
            fused = false
            table.sort(items, byIncome)
            local worstPlaced = if #items >= slots
                then PlayerStats.GetItemBaseIncome(items[slots])
                else 0
            local groups: { [string]: { number } } = {}
            for index = slots + 1, #items do
                local item = items[index]
                local nextMutation = Mutations.GetNext(item.mutation)
                local cost = PlayerStats.GetFuseCost(item)
                if
                    nextMutation
                    and cost <= data.coins
                    and Minerals.ById[item.mineral].coinsPerSecond * nextMutation.multiplier
                        > worstPlaced
                then
                    local key = `{item.mineral}:{item.mutation}`
                    local group = groups[key] or {}
                    groups[key] = group
                    table.insert(group, index)
                    if #group == Mutations.FuseCount then
                        spend("fuse", cost)
                        -- De mayor a menor índice para no mover los que faltan por quitar.
                        for position = #group, 1, -1 do
                            table.remove(items, group[position])
                        end
                        table.insert(
                            items,
                            { id = "", mineral = item.mineral, mutation = nextMutation.id }
                        )
                        fused = true
                        break
                    end
                end
            end
        end

        for index = #items, slots + 1, -1 do
            earn("sell", PlayerStats.GetSellPrice(items[index]))
            table.remove(items, index)
        end
    end

    local function updateIncome()
        income = 0
        for _, item in items do
            income += PlayerStats.GetItemBaseIncome(item)
        end
        income *= PlayerStats.GetIncomeMultiplier(data)
    end

    local function buyUpgrades()
        local budget = Rebirth.GetCost(data.rebirths) * options.upgradeBudget
        while true do
            local cheapest: string? = nil
            local cheapestCost = math.huge
            for _, upgrade in Upgrades.List do
                local level = PlayerStats.GetUpgradeLevel(data, upgrade.id)
                local cost = Upgrades.GetCost(upgrade.id, level)
                if level < upgrade.maxLevel and cost < cheapestCost then
                    cheapest = upgrade.id
                    cheapestCost = cost
                end
            end
            if cheapest == nil or cheapestCost > data.coins or cheapestCost > budget then
                return
            end
            spend("upgrades", cheapestCost)
            local upgrades = data.upgrades :: any
            upgrades[cheapest] = PlayerStats.GetUpgradeLevel(data, cheapest) + 1
        end
    end

    local function buyPermanent()
        while true do
            local cheapest: string? = nil
            local cheapestCost = math.huge
            for _, node in Permanent.List do
                local level = PlayerStats.GetPermanentLevel(data, node.id)
                local cost = Permanent.GetCost(node.id, level)
                if
                    level < node.maxLevel
                    and cost < cheapestCost
                    and PlayerStats.IsPermanentUnlocked(data, node)
                then
                    cheapest = node.id
                    cheapestCost = cost
                end
            end
            if cheapest == nil or cheapestCost > data.shards then
                return
            end
            data.shards -= cheapestCost
            data.permanent[cheapest] = PlayerStats.GetPermanentLevel(data, cheapest) + 1
        end
    end

    local function snapshot(hours: number)
        local levels = 0
        for _, upgrade in Upgrades.List do
            levels += PlayerStats.GetUpgradeLevel(data, upgrade.id)
        end
        local missing = math.max(Rebirth.GetCost(data.rebirths) - data.coins, 0)
        table.insert(result.snapshots, {
            hours = hours,
            coins = data.coins,
            earned = data.totalCoinsEarned,
            income = income,
            rebirths = data.rebirths,
            upgradeLevels = levels,
            minutesToRebirth = if income > 0 then missing / income / 60 else math.huge,
        })
    end

    local hitsPerSecond = supply / math.max(options.players, 1)
    local nextCheckpoint = 1
    while nextCheckpoint <= #options.checkpoints do
        -- Un viaje: ir al meteorito, llenar la mochila y volver cargado.
        local capacity = PlayerStats.GetBackpackCapacity(data)
        local carried: { Types.InventoryItem } = {}
        local hits = 0
        while #carried < capacity do
            hits += 1
            mine(carried)
            if #carried < capacity and random() < PlayerStats.GetExtraMineralChance(data) then
                mine(carried)
            end
        end
        local hitSeconds = math.max(PlayerStats.GetMineTime(data), 1 / hitsPerSecond)
        local tripSeconds = (
            Map.PlotRingRadius / PlayerStats.GetWalkSpeed(data, 0)
            + hits * hitSeconds
            + Map.PlotRingRadius / PlayerStats.GetWalkSpeed(data, #carried)
        ) / options.activity

        seconds += tripSeconds
        earn("pedestals", income * tripSeconds)
        table.move(carried, 1, #carried, #items + 1, items)
        -- Primero las mejoras (por si hay más pedestales) y otra vez con lo que dé la venta.
        buyUpgrades()
        manageInventory()
        buyUpgrades()
        updateIncome()

        local rebirthCost = Rebirth.GetCost(data.rebirths)
        if data.coins >= rebirthCost then
            -- El rebirth se queda con todas las monedas, no solo con el coste.
            spend("rebirth", data.coins)
            data.shards += Rebirth.GetShardReward(data.rebirths)
            data.rebirths += 1
            data.upgrades = TableUtil.DeepCopy(DataConfig.Template.upgrades)
            data.coins = PlayerStats.GetStartCoins(data)
            buyPermanent()
            table.clear(items)
            income = 0
        end

        while
            nextCheckpoint <= #options.checkpoints
            and seconds >= options.checkpoints[nextCheckpoint] * 3600
        do
            snapshot(options.checkpoints[nextCheckpoint])
            nextCheckpoint += 1
        end
    end

    return result
end

local function range(values: { number }): Range
    table.sort(values)
    local function at(fraction: number): number
        return values[math.clamp(math.ceil(#values * fraction), 1, #values)]
    end
    return { low = at(0.1), median = at(0.5), high = at(0.9) }
end

-- Repite la simulación `runs` veces y resume los resultados. `afterRun` se llama tras cada
-- partida (sirve para ceder el hilo y no agotar el tiempo de ejecución del script).
function EconomySim.RunMany(
    options: Options,
    runs: number,
    random: () -> number,
    afterRun: (() -> ())?
): Summary
    local samples: { { [string]: { number } } } = {}
    local found: { [string]: { number } } = {}
    local summary: Summary = {
        options = options,
        runs = runs,
        checkpoints = {},
        firstFound = {},
        earned = {},
        spent = {},
    }

    for _ = 1, runs do
        local result = EconomySim.Run(options, random)
        for index, snapshot in result.snapshots do
            local sample = samples[index] or {}
            samples[index] = sample
            for key, value in snapshot :: any do
                sample[key] = sample[key] or {}
                table.insert(sample[key], value)
            end
        end
        for mineralId, hours in result.firstFound do
            found[mineralId] = found[mineralId] or {}
            table.insert(found[mineralId], hours)
        end
        for source, amount in result.earned do
            summary.earned[source] = (summary.earned[source] or 0) + amount / runs
        end
        for sink, amount in result.spent do
            summary.spent[sink] = (summary.spent[sink] or 0) + amount / runs
        end
        if afterRun then
            afterRun()
        end
    end

    for index, sample in samples do
        local checkpoint: { [string]: Range } = {}
        for key, values in sample do
            checkpoint[key] = range(values)
        end
        summary.checkpoints[index] = checkpoint
    end
    for mineralId, hours in found do
        local early = 0
        for _, hour in hours do
            if hour < EconomySim.BestMineralEarlyHours then
                early += 1
            end
        end
        summary.firstFound[mineralId] =
            { chance = #hours / runs, hours = range(hours).median, early = early / runs }
    end
    return summary
end

local function shares(amounts: { [string]: number }): string
    local total = 0
    local keys: { string } = {}
    for key, amount in amounts do
        total += amount
        table.insert(keys, key)
    end
    table.sort(keys)
    local parts: { string } = {}
    for _, key in keys do
        table.insert(
            parts,
            string.format(
                "%s %s (%d %%)",
                key,
                Format.Number(amounts[key]),
                math.round(amounts[key] / total * 100)
            )
        )
    end
    return table.concat(parts, " · ")
end

local function minutes(value: number): string
    return if value == math.huge then "sin ingresos" else Format.Number(value)
end

-- Informe en texto de un resumen, una línea por elemento de la lista.
function EconomySim.Report(summary: Summary): { string }
    local options = summary.options
    local lines = {
        string.format(
            "Simulación de economía: %d partidas · %d jugadores · actividad %d %%",
            summary.runs,
            options.players,
            math.round(options.activity * 100)
        ),
        "Hora | Monedas | Ganado en total | Ingresos/s (p10 - p90) | Rebirths | Mejoras | Min. al rebirth",
    }
    local warnings: { string } = {}

    for _, checkpoint in summary.checkpoints do
        local hours = checkpoint.hours.median
        table.insert(
            lines,
            string.format(
                "%3dh | %s | %s | %s (%s - %s) | %d (%d - %d) | %d/%d | %s",
                hours,
                Format.Number(checkpoint.coins.median),
                Format.Number(checkpoint.earned.median),
                Format.Number(checkpoint.income.median),
                Format.Number(checkpoint.income.low),
                Format.Number(checkpoint.income.high),
                checkpoint.rebirths.median,
                checkpoint.rebirths.low,
                checkpoint.rebirths.high,
                checkpoint.upgradeLevels.median,
                maxUpgradeLevels,
                minutes(checkpoint.minutesToRebirth.median)
            )
        )
        if checkpoint.minutesToRebirth.median > EconomySim.WallMinutes then
            table.insert(
                warnings,
                string.format(
                    "AVISO: a las %d h faltan %s minutos para el siguiente rebirth%s.",
                    hours,
                    minutes(checkpoint.minutesToRebirth.median),
                    if checkpoint.upgradeLevels.median >= maxUpgradeLevels
                        then " y no quedan mejoras que comprar (las monedas se acumulan)"
                        else ""
                )
            )
        end
    end

    table.insert(lines, "Primer hallazgo (mediana de la hora de juego y partidas en las que sale):")
    for _, mineral in Minerals.List do
        local found = summary.firstFound[mineral.id]
        table.insert(
            lines,
            if found
                then string.format(
                    "  %-10s %6.2f h · %3d %%",
                    mineral.id,
                    found.hours,
                    math.round(found.chance * 100)
                )
                else string.format("  %-10s nunca", mineral.id)
        )
    end
    table.insert(lines, "Monedas ganadas por partida: " .. shares(summary.earned))
    table.insert(lines, "Monedas gastadas por partida: " .. shares(summary.spent))

    local best = Minerals.List[#Minerals.List]
    local bestFound = summary.firstFound[best.id]
    if bestFound and bestFound.early > EconomySim.BestMineralEarlyChance then
        table.insert(
            warnings,
            string.format(
                "AVISO: %s sale antes de %d h en el %d %% de las partidas.",
                best.id,
                EconomySim.BestMineralEarlyHours,
                math.round(bestFound.early * 100)
            )
        )
    end
    table.move(warnings, 1, #warnings, #lines + 1, lines)
    return lines
end

return EconomySim
