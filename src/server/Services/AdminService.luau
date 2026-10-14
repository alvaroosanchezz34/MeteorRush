--!strict

-- Centro de control de administración: una capa encima del juego para administrarlo,
-- probarlo y depurarlo sin tocar código. No sustituye a ningún sistema: cada comando llama
-- al servicio que ya hace ese trabajo.
--
-- Flujo: panel → remote AdminRequest → validación en servidor → comando → sistema del juego
-- → remote AdminResponse.
--
-- Seguridad:
--   * Cada petición vuelve a comprobar que quien la envía es administrador
--     (Admin/AdminPermissions, por UserId). Lo que diga el cliente no cuenta.
--   * Quien no es administrador no recibe respuesta ni dato alguno, y queda registrado
--     como acción sospechosa. Tampoco recibe el código del panel: está en ServerScriptService y
--     el servidor solo se lo entrega a los administradores.
--   * Todos los argumentos se validan aquí: tipos, rangos, ids que existan y cantidades
--     máximas. Nada llega a los datos sin pasar por esas comprobaciones.
--   * Las acciones destructivas exigen además `confirm = true`, que el panel solo envía
--     tras el diálogo de confirmación.
--   * Toda acción queda en el registro (Admin/AdminLogs).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local AdminLogs = require(script.Parent.Parent.Admin.AdminLogs)
local AdminPermissions = require(script.Parent.Parent.Admin.AdminPermissions)
local AmbientService = require(script.Parent.AmbientService)
local CompetitionService = require(script.Parent.CompetitionService)
local CrateService = require(script.Parent.CrateService)
local DataService = require(script.Parent.DataService)
local EquipmentService = require(script.Parent.EquipmentService)
local EventService = require(script.Parent.EventService)
local IndexService = require(script.Parent.IndexService)
local LiveOpsService = require(script.Parent.LiveOpsService)
local MeteorService = require(script.Parent.MeteorService)
local PlotService = require(script.Parent.PlotService)

local Shared = ReplicatedStorage.Shared
local AmbientConfig = require(Shared.Config.Ambient)
local CompetitionConfig = require(Shared.Config.Competition)
local Crates = require(Shared.Config.Crates)
local DecorConfig = require(Shared.Config.Decor)
local Equipment = require(Shared.Config.Equipment)
local EventsConfig = require(Shared.Config.Events)
local LiveOps = require(Shared.Config.LiveOps)
local Log = require(Shared.Util.Log)
local Loot = require(Shared.Util.Loot)
local MapConfig = require(Shared.Config.Map)
local MeteorsConfig = require(Shared.Config.Meteors)
local Minerals = require(Shared.Config.Minerals)
local Mutations = require(Shared.Config.Mutations)
local Network = require(Shared.Config.Network)
local NpcsConfig = require(Shared.Config.Npcs)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local ShopConfig = require(Shared.Config.Shop)
local Locale = require(Shared.Locale)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local WeightedRandom = require(Shared.Util.WeightedRandom)

-- Límites de lo que se puede pedir de una vez.
local MAX_COINS = 1e15
local MAX_REBIRTHS = 500
local MAX_MINERALS = 50
local MAX_BOOST_MINUTES = 24 * 60
local MAX_ANNOUNCEMENT = 120
local MIN_ANNOUNCEMENT_SECONDS = 2
local MAX_ANNOUNCEMENT_SECONDS = 15
local ANNOUNCEMENT_STYLES = { info = true, success = true, warning = true, event = true }
-- Segundos hasta el impacto de un meteorito pedido como "instantáneo".
local INSTANT_IMPACT = 2
local BOOSTS = { carryShield = true, magnet = true, luck = true, coins2x = true }
-- Código del panel: está junto a Services, dentro de ServerScriptService, que no se envía a
-- los clientes. El servidor lo copia al PlayerGui de cada administrador.
local CLIENT_FOLDER = "AdminClient"

type Args = { [string]: any }
type Handler = (admin: Player, args: Args) -> (boolean, any)
type Command = { handler: Handler, danger: boolean? }

-- Proveedor de un tipo de objeto que el panel puede dar o quitar. Los sistemas futuros
-- (armas, picos de caja...) se enganchan aquí con RegisterItemProvider, sin tocar el panel.
export type ItemProvider = {
    -- Ids que existen, para que el panel los liste.
    list: () -> { string },
    give: (target: Player, itemId: string) -> (boolean, string),
    remove: (target: Player, itemId: string) -> (boolean, string),
}

local AdminService = {}

local limiter = RateLimiter.new(Network.RateLimits.AdminRequest)
local rng = Random.new()
local startedAt = os.clock()
local serverFps = 60
local itemProviders: { [string]: ItemProvider } = {}
local commands: { [string]: Command } = {}
local shuttingDown = false

-- Validación de argumentos ----------------------------------------------------------------

-- Jugador conectado con ese UserId y con el perfil cargado.
local function getTarget(args: Args): (Player?, Types.Profile?)
    local userId = args.userId
    if type(userId) ~= "number" then
        return nil, nil
    end
    local player = Players:GetPlayerByUserId(userId)
    if player == nil then
        return nil, nil
    end
    return player, DataService.GetData(player)
end

-- Número entero dentro de un rango, o nil si no lo es (NaN, infinito, texto...).
local function getInteger(value: any, min: number, max: number): number?
    if type(value) ~= "number" or value ~= value or value % 1 ~= 0 then
        return nil
    end
    if value < min or value > max then
        return nil
    end
    return value
end

local function getRoot(player: Player): BasePart?
    local character = player.Character
    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
    return if root and root:IsA("BasePart") then root else nil
end

local function mineralName(mineralId: string, mutationId: string): string
    return Strings.MineralName(mineralId, mutationId)
end

local NO_TARGET = "Jugador no encontrado o sin datos cargados."

-- Añade minerales al inventario de la base del jugador y los registra en su índice.
local function giveMinerals(target: Player, items: { Types.InventoryItem })
    DataService.Update(target, "inventory", function(inventory: { Types.InventoryItem })
        for _, item in items do
            table.insert(inventory, item)
        end
        return inventory
    end)
    for _, item in items do
        IndexService.Register(target, item.mineral, item.mutation)
    end
end

local function newItem(mineralId: string, mutationId: string): Types.InventoryItem
    return { id = HttpService:GenerateGUID(false), mineral = mineralId, mutation = mutationId }
end

-- Comandos ------------------------------------------------------------------------------------

-- Estado del servidor.
commands.dashboard = {
    handler = function(_admin: Player, _args: Args): (boolean, any)
        local meteors = {}
        for _, meteor in MeteorService.GetAll() do
            table.insert(
                meteors,
                { id = meteor.id, type = meteor.typeId, hitsLeft = meteor.hitsLeft }
            )
        end
        local features = {}
        for name in LiveOps.Features do
            features[name] = LiveOpsService.IsEnabled(name)
        end
        return true,
            {
                players = #Players:GetPlayers(),
                maxPlayers = Players.MaxPlayers,
                jobId = game.JobId,
                placeId = game.PlaceId,
                uptime = os.clock() - startedAt,
                version = LiveOps.Version,
                serverFps = math.round(serverFps),
                memoryMb = math.round(Stats:GetTotalMemoryUsageMb()),
                time = os.time(),
                meteors = meteors,
                features = features,
                event = Workspace:GetAttribute("EventId"),
                eventActive = Workspace:GetAttribute("EventEndsAt") ~= nil,
                ambient = Workspace:GetAttribute("AmbientEvent"),
                competition = CompetitionService.GetState(),
                studio = RunService:IsStudio(),
            }
    end,
}

-- Lista de jugadores con sus datos principales.
commands.players = {
    handler = function(_admin: Player, _args: Args): (boolean, any)
        local list = {}
        for _, player in Players:GetPlayers() do
            local data = DataService.GetData(player)
            table.insert(list, {
                userId = player.UserId,
                name = player.Name,
                displayName = player.DisplayName,
                loaded = data ~= nil,
                coins = if data then data.coins else 0,
                income = if data then PlayerStats.GetIncomePerSecond(data) else 0,
                rebirths = if data then data.rebirths else 0,
                minerals = if data then #data.inventory else 0,
                playtime = DataService.GetPlaytime(player),
                admin = AdminPermissions.IsAdmin(player),
            })
        end
        return true, list
    end,
}

commands.logs = {
    handler = function(_admin: Player, _args: Args): (boolean, any)
        return true, AdminLogs.GetRecent(100)
    end,
}

-- Jugadores.
commands.teleportTo = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local target = getTarget(args)
        local root = if target then getRoot(target) else nil
        local character = admin.Character
        if target == nil or root == nil or character == nil then
            return false, "Ese jugador no tiene personaje."
        end
        character:PivotTo(root.CFrame * CFrame.new(0, 0, 5))
        AdminLogs.Add(admin, "TELEPORT_TO", target.Name)
        return true, `Teletransportado a {target.Name}.`
    end,
}

commands.bring = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local target = getTarget(args)
        local root = getRoot(admin)
        local character = if target then target.Character else nil
        if target == nil or root == nil or character == nil then
            return false, "No se pudo traer a ese jugador."
        end
        character:PivotTo(root.CFrame * CFrame.new(0, 0, -5))
        AdminLogs.Add(admin, "BRING", target.Name)
        return true, `{target.Name} traído.`
    end,
}

commands.respawn = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local target = getTarget(args)
        if target == nil then
            return false, NO_TARGET
        end
        task.spawn(function()
            target:LoadCharacter()
        end)
        AdminLogs.Add(admin, "RESPAWN", target.Name)
        return true, `{target.Name} reaparecerá.`
    end,
}

commands.kick = {
    danger = true,
    handler = function(admin: Player, args: Args): (boolean, any)
        local target = getTarget(args)
        if target == nil then
            return false, NO_TARGET
        end
        if AdminPermissions.IsAdmin(target) then
            return false, "No se puede expulsar a un administrador."
        end
        AdminLogs.Add(admin, "KICK", target.Name)
        target:Kick(Locale.GetText("Admin.Kicked", Locale.GetCurrentLanguage(target)))
        return true, `{target.Name} expulsado.`
    end,
}

-- Economía. Las monedas se cambian directamente, sin contar como "ganadas", para no
-- alterar la clasificación ni los logros.
local function setCoins(
    admin: Player,
    args: Args,
    action: string,
    compute: (number, number) -> number
)
    local target, data = getTarget(args)
    local amount = args.amount
    if target == nil or data == nil then
        return false, NO_TARGET
    end
    if type(amount) ~= "number" or amount ~= amount or amount < 0 or amount > MAX_COINS then
        return false, "Cantidad no válida."
    end
    local value = math.clamp(math.floor(compute(data.coins, amount)), 0, MAX_COINS)
    DataService.Set(target, "coins", value)
    AdminLogs.Add(admin, action, target.Name, tostring(math.floor(amount)))
    return true, `{target.Name} tiene ahora {value} monedas.`
end

commands.coinsAdd = {
    handler = function(admin: Player, args: Args): (boolean, any)
        return setCoins(admin, args, "COINS_ADD", function(current: number, amount: number)
            return current + amount
        end)
    end,
}
commands.coinsRemove = {
    handler = function(admin: Player, args: Args): (boolean, any)
        return setCoins(admin, args, "COINS_REMOVE", function(current: number, amount: number)
            return current - amount
        end)
    end,
}
commands.coinsSet = {
    handler = function(admin: Player, args: Args): (boolean, any)
        return setCoins(admin, args, "COINS_SET", function(_: number, amount: number)
            return amount
        end)
    end,
}
commands.coinsReset = {
    danger = true,
    handler = function(admin: Player, args: Args): (boolean, any)
        args.amount = 0
        return setCoins(admin, args, "COINS_RESET", function(_: number, _: number)
            return 0
        end)
    end,
}

-- Multiplicadores temporales: los boosts que ya tiene el juego (suerte, imán y escudo).
commands.boostGive = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local target, data = getTarget(args)
        local boost = args.boost
        local minutes = getInteger(args.minutes, 1, MAX_BOOST_MINUTES)
        if target == nil or data == nil then
            return false, NO_TARGET
        end
        if type(boost) ~= "string" or not BOOSTS[boost] or minutes == nil then
            return false, "Boost o duración no válidos."
        end
        DataService.Update(target, "boosts", function(boosts: { [string]: number })
            boosts[boost] = math.max(boosts[boost] or 0, os.time()) + minutes * 60
            return boosts
        end)
        AdminLogs.Add(admin, "BOOST_GIVE", target.Name, `{boost} {minutes} min`)
        return true, `{boost} durante {minutes} min para {target.Name}.`
    end,
}
commands.boostClear = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local target, data = getTarget(args)
        if target == nil or data == nil then
            return false, NO_TARGET
        end
        DataService.Set(target, "boosts", {})
        AdminLogs.Add(admin, "BOOST_CLEAR", target.Name)
        return true, `Boosts de {target.Name} quitados.`
    end,
}

-- Rebirths. No reinician mejoras ni minerales: solo cambian el número.
local function setRebirths(
    admin: Player,
    args: Args,
    action: string,
    compute: (number, number) -> number
)
    local target, data = getTarget(args)
    local amount = getInteger(args.amount, 0, MAX_REBIRTHS)
    if target == nil or data == nil then
        return false, NO_TARGET
    end
    if amount == nil then
        return false, "Cantidad no válida."
    end
    local value = math.clamp(compute(data.rebirths, amount), 0, MAX_REBIRTHS)
    DataService.Set(target, "rebirths", value)
    AdminLogs.Add(admin, action, target.Name, tostring(value))
    return true, `{target.Name} tiene ahora {value} rebirths.`
end

commands.rebirthAdd = {
    danger = true,
    handler = function(admin: Player, args: Args): (boolean, any)
        return setRebirths(admin, args, "REBIRTH_ADD", function(current: number, amount: number)
            return current + amount
        end)
    end,
}
commands.rebirthSet = {
    danger = true,
    handler = function(admin: Player, args: Args): (boolean, any)
        return setRebirths(admin, args, "REBIRTH_SET", function(_: number, amount: number)
            return amount
        end)
    end,
}
commands.rebirthReset = {
    danger = true,
    handler = function(admin: Player, args: Args): (boolean, any)
        args.amount = 0
        return setRebirths(admin, args, "REBIRTH_RESET", function(_: number, _: number)
            return 0
        end)
    end,
}

-- Minerales. No tocan las probabilidades del juego: son entregas directas.
commands.mineralGive = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local target, data = getTarget(args)
        local mineralId, mutationId = args.mineral, args.mutation
        local quantity = getInteger(args.quantity, 1, MAX_MINERALS)
        if target == nil or data == nil then
            return false, NO_TARGET
        end
        if
            type(mineralId) ~= "string"
            or type(mutationId) ~= "string"
            or Minerals.ById[mineralId] == nil
            or Mutations.ById[mutationId] == nil
            or quantity == nil
        then
            return false, "Mineral, mutación o cantidad no válidos."
        end
        local items: { Types.InventoryItem } = {}
        for _ = 1, quantity do
            table.insert(items, newItem(mineralId, mutationId))
        end
        giveMinerals(target, items)
        local name = mineralName(mineralId, mutationId)
        AdminLogs.Add(admin, "GIVE_MINERAL", target.Name, `{name} x{quantity}`)
        return true, `{name} x{quantity} para {target.Name}.`
    end,
}

-- Al azar con las mismas tiradas que un meteorito normal, o solo entre Raro y superior.
local function giveRandom(admin: Player, args: Args, rareOnly: boolean): (boolean, any)
    local target, data = getTarget(args)
    local quantity = getInteger(args.quantity, 1, MAX_MINERALS)
    if target == nil or data == nil then
        return false, NO_TARGET
    end
    if quantity == nil then
        return false, "Cantidad no válida."
    end
    local items: { Types.InventoryItem } = {}
    local names: { string } = {}
    for _ = 1, quantity do
        local mineral = if rareOnly
            then WeightedRandom.Pick(Minerals.List, function(candidate: Minerals.Mineral): number
                return if Minerals.GetRank(candidate.id) >= Minerals.RareRank
                    then candidate.weight
                    else 0
            end, rng)
            else Loot.RollMineral(1, rng)
        local mutation = Loot.RollMutation(1, rng)
        if mineral then
            table.insert(items, newItem(mineral.id, mutation.id))
            table.insert(names, mineralName(mineral.id, mutation.id))
        end
    end
    giveMinerals(target, items)
    AdminLogs.Add(
        admin,
        if rareOnly then "GIVE_RARE" else "GIVE_RANDOM",
        target.Name,
        table.concat(names, ", ")
    )
    return true, `{#items} minerales para {target.Name}: {table.concat(names, ", ")}`
end

commands.mineralRandom = {
    handler = function(admin: Player, args: Args): (boolean, any)
        return giveRandom(admin, args, false)
    end,
}
commands.mineralRare = {
    handler = function(admin: Player, args: Args): (boolean, any)
        return giveRandom(admin, args, true)
    end,
}

-- Inventario de un jugador, resumido.
commands.inventory = {
    handler = function(_: Player, args: Args): (boolean, any)
        local target, data = getTarget(args)
        if target == nil or data == nil then
            return false, NO_TARGET
        end
        local placed: { [string]: boolean } = {}
        for _, itemId in data.pedestals do
            placed[itemId] = true
        end
        local groups: { [string]: { mineral: string, mutation: string, count: number, placed: number } } =
            {}
        for _, item in data.inventory do
            local key = `{item.mineral}:{item.mutation}`
            local group = groups[key]
            if group == nil then
                group = { mineral = item.mineral, mutation = item.mutation, count = 0, placed = 0 }
                groups[key] = group
            end
            group.count += 1
            if placed[item.id] then
                group.placed += 1
            end
        end
        local minerals = {}
        for _, group in groups do
            table.insert(minerals, group)
        end
        local titles: { string } = {}
        for id in data.achievements do
            if PlayerStats.OwnsTitle(data, id) then
                table.insert(titles, id)
            end
        end
        local now = os.time()
        local boosts: { [string]: number } = {}
        for boost, expiresAt in data.boosts do
            if expiresAt > now then
                boosts[boost] = expiresAt - now
            end
        end
        return true,
            {
                name = target.Name,
                coins = data.coins,
                shards = data.shards,
                rebirths = data.rebirths,
                minerals = minerals,
                cosmetics = data.cosmetics.owned,
                equipped = data.cosmetics.equipped,
                passes = data.passes,
                boosts = boosts,
                titles = titles,
                title = data.title,
                upgrades = data.upgrades,
                equipment = data.equipment,
            }
    end,
}

-- Quita minerales de un tipo que no estén en un pedestal.
commands.inventoryRemove = {
    danger = true,
    handler = function(admin: Player, args: Args): (boolean, any)
        local target, data = getTarget(args)
        local mineralId, mutationId = args.mineral, args.mutation
        local quantity = getInteger(args.quantity, 1, 1000)
        if target == nil or data == nil then
            return false, NO_TARGET
        end
        if type(mineralId) ~= "string" or type(mutationId) ~= "string" or quantity == nil then
            return false, "Mineral, mutación o cantidad no válidos."
        end
        local placed: { [string]: boolean } = {}
        for _, itemId in data.pedestals do
            placed[itemId] = true
        end
        local removed = 0
        DataService.Update(target, "inventory", function(inventory: { Types.InventoryItem })
            local kept: { Types.InventoryItem } = {}
            for _, item in inventory do
                if
                    removed < quantity
                    and item.mineral == mineralId
                    and item.mutation == mutationId
                    and not placed[item.id]
                then
                    removed += 1
                else
                    table.insert(kept, item)
                end
            end
            return kept
        end)
        local name = mineralName(mineralId, mutationId)
        AdminLogs.Add(admin, "REMOVE_MINERAL", target.Name, `{name} x{removed}`)
        return true, `{removed} {name} quitados a {target.Name}.`
    end,
}

-- Objetos por tipo (cosméticos ahora; armas y demás cuando existan).
commands.itemList = {
    handler = function(_admin: Player, _args: Args): (boolean, any)
        local kinds: { [string]: { string } } = {}
        for kind, provider in itemProviders do
            kinds[kind] = provider.list()
        end
        return true, kinds
    end,
}

local function useProvider(admin: Player, args: Args, give: boolean): (boolean, any)
    local target, data = getTarget(args)
    local kind, itemId = args.kind, args.item
    if target == nil or data == nil then
        return false, NO_TARGET
    end
    if type(kind) ~= "string" or type(itemId) ~= "string" then
        return false, "Objeto no válido."
    end
    local provider = itemProviders[kind]
    if provider == nil then
        return false, `Todavía no hay sistema de "{kind}" en el juego.`
    end
    local ok, message = (if give then provider.give else provider.remove)(target, itemId)
    if ok then
        AdminLogs.Add(
            admin,
            if give then "GIVE_ITEM" else "REMOVE_ITEM",
            target.Name,
            `{kind}:{itemId}`
        )
    end
    return ok, message
end

commands.itemGive = {
    handler = function(admin: Player, args: Args): (boolean, any)
        return useProvider(admin, args, true)
    end,
}
commands.itemRemove = {
    danger = true,
    handler = function(admin: Player, args: Args): (boolean, any)
        return useProvider(admin, args, false)
    end,
}

-- Cajas y equipamiento. Los picos y las armas se dan y se quitan con itemGive / itemRemove
-- (tipos "pickaxe" y "weapon").
commands.crateGive = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local target, data = getTarget(args)
        local crateId = args.crate
        local quantity = getInteger(args.quantity, 1, MAX_MINERALS)
        if target == nil or data == nil then
            return false, NO_TARGET
        end
        if type(crateId) ~= "string" or Crates.ById[crateId] == nil or quantity == nil then
            return false, "Caja o cantidad no válidas."
        end
        local given = CrateService.Give(target, crateId, quantity)
        AdminLogs.Add(admin, "GIVE_CRATE", target.Name, `{crateId} x{given}`)
        return true, `{given} cajas "{crateId}" para {target.Name}.`
    end,
}
commands.pitySet = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local target, data = getTarget(args)
        local crateId = args.crate
        local count = getInteger(args.count, 0, 1000)
        if target == nil or data == nil then
            return false, NO_TARGET
        end
        if type(crateId) ~= "string" or Crates.ById[crateId] == nil or count == nil then
            return false, "Caja o contador no válidos."
        end
        CrateService.SetPity(target, crateId, count)
        AdminLogs.Add(admin, "SET_PITY", target.Name, `{crateId} = {count}`)
        return true, `Seguro de "{crateId}" de {target.Name}: {count}.`
    end,
}
commands.dustGive = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local target, data = getTarget(args)
        local amount = getInteger(args.amount, 1, 1e6)
        if target == nil or data == nil then
            return false, NO_TARGET
        end
        if amount == nil then
            return false, "Cantidad no válida."
        end
        EquipmentService.AddDust(target, amount)
        AdminLogs.Add(admin, "GIVE_DUST", target.Name, tostring(amount))
        return true, `{amount} Forge Dust para {target.Name}.`
    end,
}
-- Pruebas de presentación: solo las ve quien las pide y no dan nada.
commands.crateTest = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local crateId = args.crate
        local reward = if type(crateId) == "string" then CrateService.Preview(crateId) else nil
        if type(crateId) ~= "string" or reward == nil then
            return false, "Caja no válida."
        end
        CrateService.ShowReveal(admin, crateId, reward, true, 0, true)
        return true, `Prueba de "{crateId}": {reward.id} ({reward.rarity}). No se ha dado nada.`
    end,
}
commands.forceReveal = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local crateId, itemId = args.crate, args.item
        local item = if type(itemId) == "string" then Equipment.ById[itemId] else nil
        if type(crateId) ~= "string" or Crates.ById[crateId] == nil or item == nil then
            return false, "Caja u objeto no válidos."
        end
        CrateService.ShowReveal(
            admin,
            crateId,
            { kind = item.kind, id = item.id, rarity = item.rarity },
            true,
            0,
            true
        )
        return true, `Presentación de {item.id}. No se ha dado nada.`
    end,
}

-- Meteoritos. Solo se generan a mano: no cambian los tiempos del juego.
commands.meteorSpawn = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local typeId = args.type
        if type(typeId) ~= "string" or MeteorsConfig.Types[typeId] == nil then
            return false, "Tipo de meteorito no válido."
        end
        local position: Vector3? = nil
        if args.where == "player" then
            local target = getTarget(args)
            local root = if target then getRoot(target) else nil
            if root == nil then
                return false, "Ese jugador no tiene personaje."
            end
            -- Dentro de la zona de impacto, lo más cerca posible del jugador.
            local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
            local limit = MapConfig.ImpactZoneRadius - MeteorsConfig.Types[typeId].radius
            if flat.Magnitude > limit then
                flat = flat.Unit * limit
            end
            position = flat
        end
        -- `instant`: cae casi al momento, sin esperar el aviso normal.
        local impactIn = if args.instant == true then INSTANT_IMPACT else MeteorsConfig.WarningTime
        MeteorService.Spawn(typeId, impactIn, position)
        AdminLogs.Add(admin, "SPAWN_METEOR", nil, typeId)
        return true, `Meteorito "{typeId}" en camino.`
    end,
}
commands.meteorRemove = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local id = args.id
        if type(id) ~= "number" or MeteorService.GetMeteor(id) == nil then
            return false, "Ese meteorito ya no existe."
        end
        MeteorService.Remove(id)
        AdminLogs.Add(admin, "REMOVE_METEOR", nil, tostring(id))
        return true, "Meteorito eliminado."
    end,
}
commands.meteorClear = {
    handler = function(admin: Player, _args: Args): (boolean, any)
        local count = 0
        for _, meteor in MeteorService.GetAll() do
            MeteorService.Remove(meteor.id)
            count += 1
        end
        AdminLogs.Add(admin, "CLEAR_METEORS", nil, tostring(count))
        return true, `{count} meteoritos eliminados.`
    end,
}

-- Eventos, sucesos ambientales y competiciones.
commands.eventStart = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local eventId = args.event
        if type(eventId) ~= "string" or EventsConfig.ById[eventId] == nil then
            return false, "Evento no válido."
        end
        if not EventService.DebugStart(eventId) then
            return false, "Ya hay un evento en marcha."
        end
        AdminLogs.Add(admin, "START_EVENT", nil, eventId)
        return true, `Evento "{eventId}" en marcha.`
    end,
}
commands.eventStop = {
    handler = function(admin: Player, _args: Args): (boolean, any)
        if not EventService.Stop() then
            return false, "No hay ningún evento en marcha."
        end
        AdminLogs.Add(admin, "STOP_EVENT")
        return true, "Evento detenido."
    end,
}
commands.ambientStart = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local eventId = args.event
        if type(eventId) ~= "string" or AmbientConfig.RareById[eventId] == nil then
            return false, "Suceso no válido."
        end
        if not AmbientService.DebugStart(eventId) then
            return false, "Ya hay un suceso ambiental en marcha."
        end
        AdminLogs.Add(admin, "START_AMBIENT", nil, eventId)
        return true, `Suceso "{eventId}" en marcha.`
    end,
}
commands.competitionStart = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local kind = args.kind
        if type(kind) ~= "string" or CompetitionConfig.ById[kind] == nil then
            return false, "Competición no válida."
        end
        if not CompetitionService.DebugStart(kind) then
            return false, "Ya hay una competición en marcha."
        end
        AdminLogs.Add(admin, "START_COMPETITION", nil, kind)
        return true, `Competición "{kind}" en marcha.`
    end,
}
commands.competitionStop = {
    handler = function(admin: Player, _args: Args): (boolean, any)
        if not CompetitionService.Stop() then
            return false, "No hay ninguna competición en marcha."
        end
        AdminLogs.Add(admin, "STOP_COMPETITION")
        return true, "Competición detenida."
    end,
}

-- Bases.
commands.baseTeleport = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local target = getTarget(args)
        local plot = if target then PlotService.GetPlot(target) else nil
        local character = admin.Character
        if target == nil or plot == nil or character == nil then
            return false, "Ese jugador no tiene base."
        end
        character:PivotTo(plot.cframe * CFrame.new(0, 4, 0))
        AdminLogs.Add(admin, "TELEPORT_BASE", target.Name)
        return true, `En la base de {target.Name}.`
    end,
}
-- Vacía los pedestales: los minerales vuelven al inventario, no se pierden.
commands.baseClearPedestals = {
    danger = true,
    handler = function(admin: Player, args: Args): (boolean, any)
        local target, data = getTarget(args)
        if target == nil or data == nil then
            return false, NO_TARGET
        end
        DataService.Set(target, "pedestals", {})
        AdminLogs.Add(admin, "CLEAR_PEDESTALS", target.Name)
        return true, `Pedestales de {target.Name} vaciados.`
    end,
}
commands.baseResetDecor = {
    danger = true,
    handler = function(admin: Player, args: Args): (boolean, any)
        local target, data = getTarget(args)
        if target == nil or data == nil then
            return false, NO_TARGET
        end
        DataService.Set(target, "decor", { slots = {}, effect = "" })
        AdminLogs.Add(admin, "RESET_DECOR", target.Name)
        return true, `Decoración de {target.Name} reiniciada.`
    end,
}
-- Efecto y decoraciones: solo se ven si el jugador los tiene desbloqueados (lo comprueba
-- DecorService, como siempre).
commands.baseSetEffect = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local target, data = getTarget(args)
        local effect = args.effect
        if target == nil or data == nil then
            return false, NO_TARGET
        end
        if
            type(effect) ~= "string" or (effect ~= "" and DecorConfig.EffectsById[effect] == nil)
        then
            return false, "Efecto no válido."
        end
        DataService.Update(target, "decor", function(decor: Types.DecorData)
            decor.effect = effect
            return decor
        end)
        AdminLogs.Add(admin, "SET_BASE_EFFECT", target.Name, effect)
        return true, `Efecto de {target.Name}: {if effect == "" then "ninguno" else effect}.`
    end,
}
commands.baseDecorate = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local target, data = getTarget(args)
        local slot = getInteger(args.slot, 1, #DecorConfig.Slots)
        local decoration = args.decoration
        if target == nil or data == nil then
            return false, NO_TARGET
        end
        if
            slot == nil
            or type(decoration) ~= "string"
            or (decoration ~= "" and DecorConfig.DecorationsById[decoration] == nil)
        then
            return false, "Hueco o decoración no válidos."
        end
        DataService.Update(target, "decor", function(decor: Types.DecorData)
            decor.slots[tostring(slot)] = if decoration == "" then nil else decoration
            return decor
        end)
        AdminLogs.Add(admin, "DECORATE_BASE", target.Name, `{slot}:{decoration}`)
        return true, `Hueco {slot} de {target.Name} actualizado.`
    end,
}

-- Anuncio a todo el servidor. El texto pasa por el filtro de Roblox antes de mostrarse.
commands.announce = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local message = args.message
        local seconds = getInteger(args.seconds, MIN_ANNOUNCEMENT_SECONDS, MAX_ANNOUNCEMENT_SECONDS)
        local style = args.style
        if
            type(message) ~= "string"
            or #message == 0
            or #message > MAX_ANNOUNCEMENT
            or seconds == nil
            or type(style) ~= "string"
            or not ANNOUNCEMENT_STYLES[style]
        then
            return false, "Mensaje, duración o estilo no válidos."
        end
        local ok, filtered = pcall(function(): string
            return TextService:FilterStringAsync(message, admin.UserId)
                :GetNonChatStringForBroadcastAsync()
        end)
        if not ok then
            return false, "No se pudo filtrar el texto. Inténtalo de nuevo."
        end
        Remotes.Announcement:FireAllClients(filtered, seconds, style, args.sound == true)
        AdminLogs.Add(admin, "ANNOUNCE", nil, filtered)
        return true, "Anuncio enviado."
    end,
}

-- Interruptores de contenido (Live Ops).
commands.featureSet = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local feature, enabled = args.feature, args.enabled
        if
            type(feature) ~= "string"
            or LiveOps.Features[feature] == nil
            or type(enabled) ~= "boolean"
        then
            return false, "Interruptor no válido."
        end
        LiveOpsService.SetFeature(feature, enabled)
        AdminLogs.Add(admin, "SET_FEATURE", nil, `{feature} = {enabled}`)
        return true, `{feature} = {if enabled then "ON" else "OFF"}`
    end,
}

-- Pruebas: el momento legendario solo lo ve quien lo pide.
commands.testLegendary = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local mineralId, mutationId = args.mineral, args.mutation
        if
            type(mineralId) ~= "string"
            or type(mutationId) ~= "string"
            or Minerals.ById[mineralId] == nil
            or Mutations.ById[mutationId] == nil
        then
            return false, "Mineral o mutación no válidos."
        end
        Remotes.LegendaryMoment:FireClient(
            admin,
            admin.DisplayName,
            "discovery",
            mineralId,
            mutationId
        )
        return true, "Momento legendario de prueba (solo lo ves tú)."
    end,
}

-- Lleva al administrador delante de un NPC ambiental (para comprobar que están en su sitio).
commands.npcTeleport = {
    handler = function(admin: Player, args: Args): (boolean, any)
        local character = admin.Character
        for _, model in CollectionService:GetTagged(NpcsConfig.Tag) do
            local base = model:GetAttribute("Base")
            if
                model:GetAttribute("NpcId") == args.npc
                and typeof(base) == "CFrame"
                and character
            then
                character:PivotTo(base * CFrame.new(0, 4, -9) * CFrame.Angles(0, math.pi, 0))
                return true, `Delante de "{args.npc}".`
            end
        end
        return false, "Ese NPC no está en el mapa."
    end,
}

-- Servidor.
-- Para lo que está en marcha: evento, competición y meteoritos. No toca datos.
commands.systemsReset = {
    danger = true,
    handler = function(admin: Player, _args: Args): (boolean, any)
        EventService.Stop()
        CompetitionService.Stop()
        for _, meteor in MeteorService.GetAll() do
            MeteorService.Remove(meteor.id)
        end
        AdminLogs.Add(admin, "RESET_SYSTEMS")
        return true, "Evento, competición y meteoritos reiniciados."
    end,
}
commands.shutdown = {
    danger = true,
    handler = function(admin: Player, _args: Args): (boolean, any)
        AdminLogs.Add(admin, "SHUTDOWN")
        shuttingDown = true
        -- Los datos se guardan al salir cada jugador, como en cualquier desconexión.
        for _, player in Players:GetPlayers() do
            if player ~= admin then
                player:Kick(Locale.GetText("Admin.Shutdown", Locale.GetCurrentLanguage(player)))
            end
        end
        task.delay(1, function()
            admin:Kick(Locale.GetText("Admin.Shutdown", Locale.GetCurrentLanguage(admin)))
        end)
        return true, "Cerrando el servidor."
    end,
}

-- Petición ---------------------------------------------------------------------------------------

local function onRequest(player: Player, requestId: unknown, action: unknown, args: unknown)
    -- Siempre, en cada petición: ¿es administrador? Quien no lo es no recibe ni respuesta
    -- (y si insiste, el límite de peticiones lo expulsa).
    if not limiter.Check(player) then
        return
    end
    if not AdminPermissions.IsAdmin(player) then
        Log.Suspicious(player, "AdminRequest", "sin permiso")
        return
    end
    if type(requestId) ~= "number" or type(action) ~= "string" then
        return
    end
    local command = commands[action]
    if command == nil then
        Remotes.AdminResponse:FireClient(player, requestId, false, "Comando desconocido.")
        return
    end
    local arguments: Args = if type(args) == "table" then args :: Args else {}
    if command.danger and arguments.confirm ~= true then
        Remotes.AdminResponse:FireClient(player, requestId, false, "Falta la confirmación.")
        return
    end

    local ok, success, result = pcall(command.handler, player, arguments)
    if not ok then
        Log.Warn("Admin", `Error en el comando {action}: {success}`)
        Remotes.AdminResponse:FireClient(
            player,
            requestId,
            false,
            "Error interno. Mira la consola."
        )
        return
    end
    Remotes.AdminResponse:FireClient(player, requestId, success, result)
end

-- Registra un tipo de objeto que el panel puede dar o quitar (armas, picos...).
function AdminService.RegisterItemProvider(kind: string, provider: ItemProvider)
    itemProviders[kind] = provider
end

function AdminService.Init()
    Remotes.AdminRequest.OnServerEvent:Connect(onRequest)

    -- Cosméticos (picos, estelas y colores de base): el sistema que ya existe.
    AdminService.RegisterItemProvider("cosmetic", {
        list = function(): { string }
            local keys: { string } = {}
            for _, cosmetic in ShopConfig.Cosmetics do
                table.insert(keys, cosmetic.key)
            end
            return keys
        end,
        give = function(target: Player, itemId: string): (boolean, string)
            if ShopConfig.CosmeticsByKey[itemId] == nil then
                return false, "Ese cosmético no existe."
            end
            DataService.Update(target, "cosmetics", function(cosmetics: Types.CosmeticsData)
                if not table.find(cosmetics.owned, itemId) then
                    table.insert(cosmetics.owned, itemId)
                end
                return cosmetics
            end)
            return true, `{itemId} entregado a {target.Name}.`
        end,
        remove = function(target: Player, itemId: string): (boolean, string)
            DataService.Update(target, "cosmetics", function(cosmetics: Types.CosmeticsData)
                local index = table.find(cosmetics.owned, itemId)
                if index then
                    table.remove(cosmetics.owned, index)
                end
                for kind, key in cosmetics.equipped do
                    if key == itemId then
                        cosmetics.equipped[kind] = nil
                    end
                end
                return cosmetics
            end)
            return true, `{itemId} quitado a {target.Name}.`
        end,
    })
end

-- Proveedor de un tipo de equipamiento ("pickaxe" o "weapon") para itemGive / itemRemove.
local function gearProvider(kind: string): ItemProvider
    return {
        list = function(): { string }
            local keys: { string } = {}
            for _, item in Equipment.GetByKind(kind) do
                table.insert(keys, item.id)
            end
            return keys
        end,
        give = function(target: Player, itemId: string): (boolean, string)
            local item = Equipment.ById[itemId]
            if item == nil or item.kind ~= kind then
                return false, "Ese objeto no existe."
            end
            local _, isNew = EquipmentService.Grant(target, itemId)
            return true,
                if isNew
                    then `{itemId} entregado a {target.Name}.`
                    else `{target.Name} ya lo tenía: convertido en Forge Dust.`
        end,
        remove = function(target: Player, itemId: string): (boolean, string)
            local item = Equipment.ById[itemId]
            if item == nil or item.kind ~= kind then
                return false, "Ese objeto no existe."
            end
            if not EquipmentService.Remove(target, itemId) then
                return false, "No lo tiene, o es el objeto inicial."
            end
            return true, `{itemId} quitado a {target.Name}.`
        end,
    }
end

function AdminService.Start()
    AdminService.RegisterItemProvider("pickaxe", gearProvider("pickaxe"))
    AdminService.RegisterItemProvider("weapon", gearProvider("weapon"))

    -- FPS del servidor, suavizado, para el panel.
    RunService.Heartbeat:Connect(function(delta: number)
        serverFps += (1 / math.max(delta, 1e-3) - serverFps) * 0.05
    end)

    -- El código del panel solo se entrega a los administradores.
    -- Cada paso deja una línea en la consola, para saber por qué alguien no lo ve.
    local source = script.Parent.Parent:FindFirstChild(CLIENT_FOLDER)
    if source == nil then
        Log.Warn("Admin", `Falta {CLIENT_FOLDER} junto a Services: nadie recibirá el panel`)
    end
    local function deliver(player: Player)
        if not AdminPermissions.IsAdmin(player) then
            -- Solo en Studio: en el juego publicado sería una línea por cada jugador que entra.
            if RunService:IsStudio() then
                print(`[Admin] {player.Name} (UserId {player.UserId}) no es administrador`)
            end
            return
        end
        local playerGui = player:FindFirstChildOfClass("PlayerGui")
            or player:WaitForChild("PlayerGui", 10)
        if source == nil or playerGui == nil or playerGui:FindFirstChild(CLIENT_FOLDER) then
            return
        end
        source:Clone().Parent = playerGui
        print(`[Admin] Panel entregado a {player.Name} (UserId {player.UserId})`)
    end
    local function onPlayer(player: Player)
        task.spawn(deliver, player)
        -- Por si algo vacía el PlayerGui al reaparecer: se vuelve a entregar si falta.
        player.CharacterAdded:Connect(function()
            deliver(player)
        end)
    end
    Players.PlayerAdded:Connect(onPlayer)
    for _, player in Players:GetPlayers() do
        onPlayer(player)
    end
    -- Mientras se cierra el servidor no entra nadie más.
    Players.PlayerAdded:Connect(function(player: Player)
        if shuttingDown then
            player:Kick(Locale.GetText("Admin.Shutdown", Locale.GetCurrentLanguage(player)))
        end
    end)
end

return AdminService
