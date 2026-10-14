--!strict

-- Framework de eventos globales. Un bucle elige el siguiente evento, lo anuncia con una
-- cuenta atrás, lo empieza, espera su duración, lo termina y reparte las recompensas.
-- Cada tipo de evento (`kind`) es un par de funciones start/finish; los eventos concretos
-- son solo datos de Config/Events. Pase lo que pase en esas funciones (van con pcall), el
-- evento termina a su hora y el estado se limpia, así que el servidor nunca se queda
-- atascado en un evento.
-- El estado se replica con atributos de Workspace: `EventId`, `EventStartsAt` (durante la
-- cuenta atrás), `EventEndsAt` (mientras está activo) y `EventTint` (color del cielo).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AchievementService = require(script.Parent.AchievementService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local LiveOpsService = require(script.Parent.LiveOpsService)
local MeteorService = require(script.Parent.MeteorService)

local Shared = ReplicatedStorage.Shared
local EventsConfig = require(Shared.Config.Events)
local LiveOps = require(Shared.Config.LiveOps)
local Log = require(Shared.Util.Log)
local MeteorsConfig = require(Shared.Config.Meteors)
local PlayerStats = require(Shared.Util.PlayerStats)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local WeightedRandom = require(Shared.Util.WeightedRandom)

type Handler = {
    start: (event: EventsConfig.Event) -> (),
    finish: (event: EventsConfig.Event) -> (),
}

local EventService = {}

local rng = Random.new()
-- Evento en curso, desde el anuncio hasta el final. `active` solo mientras está empezado.
local running: EventsConfig.Event? = nil
local active: EventsConfig.Event? = nil
local participants: { [Player]: boolean } = {}
local lastFinished: { [string]: number } = {}
-- Un administrador ha pedido parar el evento en curso.
local stopRequested = false

-- Espera esos segundos. Devuelve false si entre tanto se ha pedido parar el evento.
local function waitUnlessStopped(seconds: number): boolean
    local deadline = os.clock() + seconds
    while os.clock() < deadline do
        if stopRequested then
            return false
        end
        task.wait(math.min(0.5, deadline - os.clock()))
    end
    return not stopRequested
end

local function spawnMeteor(event: EventsConfig.Event)
    local meteorType = event.meteorType
    if meteorType and MeteorsConfig.Types[meteorType] then
        MeteorService.Spawn(meteorType, MeteorsConfig.WarningTime)
    end
end

local function nothing() end

local handlers: { [string]: Handler } = {
    -- Un meteorito especial; sus reglas están en su tipo de Config/Meteors.
    meteor = { start = spawnMeteor, finish = nothing },
    -- Varios meteoritos seguidos.
    shower = {
        start = function(event: EventsConfig.Event)
            task.spawn(function()
                for _ = 1, event.count or 1 do
                    if active ~= event then
                        return
                    end
                    spawnMeteor(event)
                    task.wait(event.spacing or 1)
                end
            end)
        end,
        finish = nothing,
    },
    -- Los multiplicadores los lee MiningService con GetRareMultiplier y GetMutationMultiplier
    -- mientras el evento está activo; aquí solo cae el meteorito de bienvenida.
    supernova = { start = spawnMeteor, finish = nothing },
}

local function name(event: EventsConfig.Event): Locale.Message
    return Locale.Ref(`Events.Names.{event.id}`)
end

local function reward()
    for player in participants do
        local data = if player.Parent == Players then DataService.GetData(player) else nil
        if data then
            local amount = PlayerStats.GetEventReward(data)
            IncomeService.AddCoins(player, amount, "events")
            AchievementService.AddStat(player, "eventsJoined", 1)
            Remotes.Notify:FireClient(player, Locale.Msg("Events.Reward", Locale.Num(amount)))
        end
    end
    table.clear(participants)
end

-- Deja el servidor sin evento: estado, atributos y participantes.
local function reset()
    active = nil
    running = nil
    table.clear(participants)
    for _, attribute in { "EventId", "EventStartsAt", "EventEndsAt", "EventTint" } do
        Workspace:SetAttribute(attribute, nil)
    end
end

-- Ciclo completo de un evento: anuncio, cuenta atrás, inicio, duración, final y recompensas.
local function run(event: EventsConfig.Event, countdown: number)
    local handler = handlers[event.kind]
    running = event
    Workspace:SetAttribute("EventId", event.id)
    Workspace:SetAttribute("EventStartsAt", Workspace:GetServerTimeNow() + countdown)
    Remotes.Notify:FireAllClients(Locale.Msg("Events.Starting", name(event), Locale.Dur(countdown)))
    if not waitUnlessStopped(countdown) then
        return
    end

    table.clear(participants)
    active = event
    Workspace:SetAttribute("EventStartsAt", nil)
    Workspace:SetAttribute("EventEndsAt", Workspace:GetServerTimeNow() + event.duration)
    Workspace:SetAttribute("EventTint", event.skyColor)
    local started, startError = pcall(handler.start, event)
    if not started then
        Log.Warn("Events", `Error al empezar {event.id}: {startError}`)
    end
    local completed = waitUnlessStopped(event.duration)

    local finished, finishError = pcall(handler.finish, event)
    if not finished then
        Log.Warn("Events", `Error al terminar {event.id}: {finishError}`)
    end
    active = nil
    lastFinished[event.id] = os.clock()
    Remotes.Notify:FireAllClients(Locale.Msg("Events.Ended", name(event)))
    -- Un evento parado a mano no reparte recompensas.
    if completed then
        reward()
    end
end

-- Ejecuta un evento y, falle lo que falle dentro, deja el servidor listo para el siguiente.
local function runSafely(event: EventsConfig.Event, countdown: number)
    local ok, err = pcall(run, event, countdown)
    if not ok then
        Log.Warn("Events", `El evento {event.id} se ha interrumpido: {err}`)
        lastFinished[event.id] = os.clock()
    end
    reset()
    stopRequested = false
end

-- Elige el siguiente evento entre los activados cuyo enfriamiento ya ha pasado.
local function pick(): EventsConfig.Event?
    local now = os.clock()
    return WeightedRandom.Pick(EventsConfig.List, function(event: EventsConfig.Event): number
        local last = lastFinished[event.id]
        if not event.enabled or handlers[event.kind] == nil then
            return 0
        end
        if last and now - last < event.cooldown then
            return 0
        end
        return event.weight
    end, rng)
end

-- Indica si puede empezar un evento ahora: ninguno en marcha, eventos activados y alguien jugando.
local function canStart(): boolean
    return running == nil and LiveOpsService.IsEnabled("events") and #Players:GetPlayers() > 0
end

-- Multiplicador de peso de los minerales Raro o superior del evento activo (1 si no hay).
function EventService.GetRareMultiplier(): number
    return if active then active.rareMultiplier or 1 else 1
end

-- Multiplicador de la probabilidad de mutación del evento activo (1 si no hay).
function EventService.GetMutationMultiplier(): number
    return if active then active.mutationMultiplier or 1 else 1
end

-- Para el evento en curso (panel de administración): termina sin repartir recompensas.
-- Devuelve false si no hay ninguno.
function EventService.Stop(): boolean
    if running == nil then
        return false
    end
    stopRequested = true
    return true
end

-- Para pruebas y para el panel de administración: empieza ya ese evento, con una cuenta
-- atrás corta.
function EventService.DebugStart(eventId: string): boolean
    local event = EventsConfig.ById[eventId]
    if event == nil or running ~= nil then
        return false
    end
    task.spawn(runSafely, event, 5)
    return true
end

function EventService.Init()
    -- Participa quien mina algo mientras el evento está activo.
    AchievementService.OnStat(function(player: Player, stat: string)
        if active and stat == "mined" then
            participants[player] = true
        end
    end)
end

function EventService.Start()
    Players.PlayerRemoving:Connect(function(player: Player)
        participants[player] = nil
    end)

    task.spawn(function()
        task.wait(EventsConfig.FirstDelay)
        while true do
            local event = if canStart() then pick() else nil
            if event then
                runSafely(event, EventsConfig.Countdown)
            end
            task.wait(EventsConfig.Interval)
        end
    end)

    -- Calendario (Config/LiveOps): eventos a una hora fija de la semana, la misma en todos
    -- los servidores. Si a esa hora ya hay otro evento en marcha, la cita se pierde.
    task.spawn(function()
        local lastSlot: { [number]: string } = {}
        while true do
            task.wait(LiveOps.CalendarCheckSeconds)
            local date = os.date("!*t", os.time()) :: any
            local slot = `{date.yday}-{date.hour}-{date.min}`
            for index, entry in LiveOps.EventCalendar do
                local event = EventsConfig.ById[entry.eventId]
                if
                    date.wday == entry.weekday
                    and date.hour == entry.hour
                    and date.min == entry.minute
                    and lastSlot[index] ~= slot
                then
                    lastSlot[index] = slot
                    if event and event.enabled and canStart() then
                        task.spawn(runSafely, event, EventsConfig.Countdown)
                    end
                end
            end
        end
    end)
end

return EventService
