--!strict

-- Herramientas de prueba que solo existen en Studio. Se usan desde la barra de comandos del
-- servidor (que no comparte `require` con los scripts), mediante BindableFunctions:
--   game.ServerScriptService.Server.Services.DebugService.SkipNewbie:Invoke(player)
--   ...ResetDaily:Invoke(player)
--   ...GiveMineral:Invoke(player, "darkmatter", "rainbow")
--   ...AddStat:Invoke(player, "mined", 99)  suma a una estadística (para probar logros)
--   ...ResetAchievements:Invoke(player)     borra logros, estadísticas y título
--   ...SetFriends:Invoke(player, 2)         simula 2 amigos conectados (nil = los reales)
--   ...StartCompetition:Invoke("mine")      empieza ya una competición ("mine", "deposit"...)
--   ...StartEvent:Invoke("supernova")       empieza ya un evento (ids en Config/Events)
--   ...FakeReceipt:Invoke(player, "coinsSmall", "test-1")  procesa un recibo inventado
--   ...ResetSeason:Invoke(player)           borra su progreso de temporada y la versión vista
--   ...StartAmbient:Invoke("eclipse")       suceso ambiental raro (ids en Config/Ambient)
--   ...AddShards:Invoke(player, 50)         da Meteor Shards
--   ...EconomyReport:Invoke(player)         estadísticas económicas de su sesión
--   ...SimulateEconomy:Invoke(4, 30)        simulación con 4 jugadores y 30 partidas

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AchievementService = require(script.Parent.AchievementService)
local AmbientService = require(script.Parent.AmbientService)
local CompetitionService = require(script.Parent.CompetitionService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local IndexService = require(script.Parent.IndexService)
local ShopService = require(script.Parent.ShopService)
local SocialService = require(script.Parent.SocialService)

local Shared = ReplicatedStorage.Shared
local DailyConfig = require(Shared.Config.Daily)
local EconomySim = require(Shared.Util.EconomySim)
local Format = require(Shared.Util.Format)
local Minerals = require(Shared.Config.Minerals)
local Mutations = require(Shared.Config.Mutations)
local StealConfig = require(Shared.Config.Steal)
local TableUtil = require(Shared.Util.TableUtil)
local Types = require(Shared.Types)

local DebugService = {}

local function isPlayer(value: any): boolean
    return typeof(value) == "Instance" and value:IsA("Player")
end

local function bind(name: string, callback: (...any) -> boolean)
    local bindable = Instance.new("BindableFunction")
    bindable.Name = name
    bindable.OnInvoke = callback
    bindable.Parent = script
end

function DebugService.Init()
    if not RunService:IsStudio() then
        return
    end

    -- Quita la protección de novato sumando el tiempo de juego necesario.
    bind("SkipNewbie", function(player: any): boolean
        if not isPlayer(player) or DataService.GetData(player) == nil then
            return false
        end
        return DataService.Increment(player, "playtime", StealConfig.NewbieProtectionSeconds)
    end)

    -- Permite volver a cobrar la racha diaria ya (como si hubieran pasado 24 h).
    bind("ResetDaily", function(player: any): boolean
        local data = if isPlayer(player) then DataService.GetData(player) else nil
        if data == nil then
            return false
        end
        local daily = data.daily
        return DataService.Set(player, "daily", {
            streak = daily.streak,
            lastClaim = if daily.lastClaim > 0 then os.time() - DailyConfig.Cooldown else 0,
        })
    end)

    -- Añade un mineral al inventario de la base.
    bind("GiveMineral", function(player: any, mineralId: any, mutationId: any): boolean
        local mutation = if type(mutationId) == "string" then mutationId else "none"
        if
            not isPlayer(player)
            or type(mineralId) ~= "string"
            or Minerals.ById[mineralId] == nil
            or Mutations.ById[mutation] == nil
        then
            return false
        end
        local item: Types.InventoryItem = {
            id = HttpService:GenerateGUID(false),
            mineral = mineralId,
            mutation = mutation,
        }
        local ok = DataService.Update(
            player,
            "inventory",
            function(inventory: { Types.InventoryItem })
                table.insert(inventory, item)
                return inventory
            end
        )
        if ok then
            IndexService.Register(player, mineralId, mutation)
        end
        return ok
    end)

    -- Suma a una estadística de por vida, para probar los logros sin jugar horas.
    bind("AddStat", function(player: any, stat: any, amount: any): boolean
        if
            not isPlayer(player)
            or type(stat) ~= "string"
            or type(amount) ~= "number"
            or DataService.GetData(player) == nil
        then
            return false
        end
        AchievementService.AddStat(player, stat, amount)
        return true
    end)

    -- Deja al jugador sin logros, estadísticas ni título.
    bind("ResetAchievements", function(player: any): boolean
        if not isPlayer(player) or DataService.GetData(player) == nil then
            return false
        end
        DataService.Set(player, "title", "")
        DataService.Set(player, "stats", {})
        return DataService.Set(player, "achievements", {})
    end)

    -- Simula que el jugador tiene ese número de amigos conectados (nil vuelve a los reales).
    bind("SetFriends", function(player: any, count: any): boolean
        if not isPlayer(player) or (count ~= nil and type(count) ~= "number") then
            return false
        end
        SocialService.DebugSetFriends(player, count)
        return true
    end)

    -- Empieza ya una competición, aunque no haya jugadores suficientes.
    bind("StartCompetition", function(kindId: any): boolean
        return CompetitionService.DebugStart(if type(kindId) == "string" then kindId else "mine")
    end)

    -- Empieza ya un evento, con una cuenta atrás de 5 segundos.
    bind("StartEvent", function(eventId: any): boolean
        return type(eventId) == "string" and EventService.DebugStart(eventId)
    end)

    -- Procesa un recibo inventado de un producto o cosmético (claves de Config/Shop) y
    -- escribe la decisión. Con el mismo id de compra dos veces no debe entregarse dos veces.
    bind("FakeReceipt", function(player: any, key: any, purchaseId: any): boolean
        if not isPlayer(player) or type(key) ~= "string" or type(purchaseId) ~= "string" then
            return false
        end
        local decision = ShopService.DebugProcessReceipt(player, key, purchaseId)
        print(`[Shop] Recibo {purchaseId} de {key}: {decision}`)
        return decision == "PurchaseGranted"
    end)

    -- Borra el progreso de temporada del jugador y la versión vista (al volver a entrar
    -- salen otra vez las notas de la actualización).
    bind("ResetSeason", function(player: any): boolean
        if not isPlayer(player) or DataService.GetData(player) == nil then
            return false
        end
        DataService.Set(player, "seenVersion", "")
        return DataService.Set(
            player,
            "season",
            { id = "", points = 0, progress = {}, done = {}, claimed = {} }
        )
    end)

    -- Lanza ya un suceso ambiental raro (solo visual).
    bind("StartAmbient", function(eventId: any): boolean
        return type(eventId) == "string" and AmbientService.DebugStart(eventId)
    end)

    -- Da Meteor Shards, para probar el árbol de mejoras permanentes sin hacer rebirths.
    bind("AddShards", function(player: any, amount: any): boolean
        if not isPlayer(player) or type(amount) ~= "number" or amount ~= amount then
            return false
        end
        return DataService.Increment(player, "shards", math.floor(amount))
    end)

    -- Escribe en la Salida las estadísticas económicas de la sesión del jugador.
    bind("EconomyReport", function(player: any): boolean
        if not isPlayer(player) then
            return false
        end
        local stats = EconomyService.GetStats(player)
        print(`[Economy] {player.Name} · sesión {Format.Duration(stats.seconds)}`)
        for _, group in { "earned", "spent", "minedByRarity" } do
            for key, amount in (stats :: any)[group] do
                print(`[Economy]   {group}.{key} = {Format.Number(amount)}`)
            end
        end
        print(`[Economy]   mined = {stats.mined} · mutated = {stats.mutated}`)
        return true
    end)

    -- Simula el progreso a 1, 5, 10 y 30 horas con la configuración actual y escribe el
    -- informe en la Salida. `players` (por defecto 4) son los jugadores que se reparten los
    -- meteoritos; `runs` (por defecto 30), las partidas simuladas.
    bind("SimulateEconomy", function(players: any, runs: any): boolean
        local options = TableUtil.DeepCopy(EconomySim.DefaultOptions)
        if type(players) == "number" and players >= 1 then
            options.players = math.floor(players)
        end
        local count = if type(runs) == "number" then math.clamp(math.floor(runs), 1, 200) else 30
        local rng = Random.new()
        local summary = EconomySim.RunMany(options, count, function(): number
            return rng:NextNumber()
        end, task.wait)
        for _, line in EconomySim.Report(summary) do
            print(`[EconomySim] {line}`)
        end
        return true
    end)
end

return DebugService
