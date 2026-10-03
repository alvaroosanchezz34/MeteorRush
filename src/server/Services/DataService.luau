--!strict

-- Carga, guarda y replica los datos de cada jugador con ProfileStore.
-- Los demás servicios leen con GetData y escriben solo con Set/Update/Increment,
-- que replican el campo modificado al cliente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

local Shared = ReplicatedStorage.Shared
local DataConfig = require(Shared.Config.Data)
local Log = require(Shared.Util.Log)
local Network = require(Shared.Config.Network)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)

type StoreProfile = {
    Data: Types.Profile,
    AddUserId: (self: StoreProfile, userId: number) -> (),
    Reconcile: (self: StoreProfile) -> (),
    EndSession: (self: StoreProfile) -> (),
    OnSessionEnd: { Connect: (self: any, callback: () -> ()) -> any },
}

type ProfileCallback = (player: Player, data: Types.Profile) -> ()
type FieldCallback = (player: Player, value: any) -> ()

local DataService = {}

local playerStore: any = nil
local profiles: { [Player]: StoreProfile } = {}
local lastPlaytimeFlush: { [Player]: number } = {}
local loadedCallbacks: { ProfileCallback } = {}
local releasingCallbacks: { ProfileCallback } = {}
local fieldCallbacks: { [string]: { FieldCallback } } = {}
local requestLimiter = RateLimiter.new(Network.RateLimits.DataRequest)
local shuttingDown = false

local function sendSnapshot(player: Player, data: Types.Profile)
    Remotes.DataUpdate:FireClient(player, "snapshot", data)
end

local function sendField(player: Player, key: string, value: any)
    Remotes.DataUpdate:FireClient(player, "field", key, value)
end

local function fieldChanged(player: Player, key: string, value: any)
    sendField(player, key, value)
    local callbacks = fieldCallbacks[key]
    if callbacks == nil then
        return
    end
    for _, callback in callbacks do
        xpcall(callback, function(err: any)
            warn(`[DataService] Error en OnFieldChanged("{key}"): {err}`)
        end, player, value)
    end
end

local function flushPlaytime(player: Player, profile: StoreProfile)
    local last = lastPlaytimeFlush[player]
    if last == nil then
        return
    end
    -- Solo se suman segundos enteros; el resto se queda para el siguiente guardado.
    local seconds = math.floor(os.clock() - last)
    lastPlaytimeFlush[player] = last + seconds
    profile.Data.playtime += seconds
end

local function releaseProfile(player: Player)
    local profile = profiles[player]
    if profile == nil then
        return
    end
    profiles[player] = nil

    flushPlaytime(player, profile)
    lastPlaytimeFlush[player] = nil
    profile.Data.lastSeen = os.time()

    for _, callback in releasingCallbacks do
        xpcall(callback, function(err: any)
            warn(`[DataService] Error en OnProfileReleasing: {err}`)
        end, player, profile.Data)
    end

    profile:EndSession()
end

local function loadProfile(player: Player)
    local ok, result = pcall(function()
        return playerStore:StartSessionAsync(tostring(player.UserId), {
            Cancel = function(): boolean
                return player.Parent ~= Players
            end,
        })
    end)

    local profile: StoreProfile? = if ok then result else nil
    if not ok then
        warn(`[DataService] Error al cargar el perfil de {player.Name}: {result}`)
    end

    if profile == nil then
        if player.Parent == Players then
            player:Kick(Strings.Data.LoadFailed)
        end
        return
    end

    profile:AddUserId(player.UserId)
    profile:Reconcile()

    profile.OnSessionEnd:Connect(function()
        profiles[player] = nil
        lastPlaytimeFlush[player] = nil
        if player.Parent == Players then
            player:Kick(Strings.Data.SessionEnded)
        end
    end)

    if player.Parent ~= Players then
        profile:EndSession()
        return
    end

    profiles[player] = profile
    lastPlaytimeFlush[player] = os.clock()

    if RunService:IsStudio() then
        print(`[DataService] Perfil cargado: {player.Name} (coins = {profile.Data.coins})`)
    end

    sendSnapshot(player, profile.Data)

    for _, callback in loadedCallbacks do
        task.spawn(callback, player, profile.Data)
    end
end

local function assertKey(key: string)
    if (DataConfig.Template :: any)[key] == nil then
        error(`[DataService] Campo de datos desconocido: {key}`, 3)
    end
end

-- Indica si el perfil del jugador está cargado.
function DataService.IsLoaded(player: Player): boolean
    return profiles[player] ~= nil
end

-- Devuelve los datos del jugador o nil si no están cargados.
-- Úsalos solo para leer: modificarlos directamente no replica el cambio al cliente.
function DataService.GetData(player: Player): Types.Profile?
    local profile = profiles[player]
    return if profile then profile.Data else nil
end

-- Sustituye un campo de primer nivel y lo replica. Devuelve false si el perfil no está cargado.
function DataService.Set(player: Player, key: string, value: any): boolean
    assertKey(key)
    local profile = profiles[player]
    if profile == nil then
        return false
    end
    (profile.Data :: any)[key] = value
    fieldChanged(player, key, value)
    return true
end

-- Modifica un campo con una función que recibe el valor actual y devuelve el nuevo.
-- Si el campo es una tabla, la función puede modificarla y devolverla.
function DataService.Update(player: Player, key: string, updater: (current: any) -> any): boolean
    assertKey(key)
    local profile = profiles[player]
    if profile == nil then
        return false
    end
    local data = profile.Data :: any
    local newValue = updater(data[key])
    data[key] = newValue
    fieldChanged(player, key, newValue)
    return true
end

-- Suma una cantidad a un campo numérico y lo replica.
function DataService.Increment(player: Player, key: string, amount: number): boolean
    return DataService.Update(player, key, function(current: number): number
        return current + amount
    end)
end

-- Indica si el servidor se está cerrando (los perfiles se están guardando por última vez).
function DataService.IsShuttingDown(): boolean
    return shuttingDown or ProfileStore.IsClosing == true
end

-- Segundos de juego totales, incluida la parte de la sesión actual que aún no se ha sumado.
function DataService.GetPlaytime(player: Player): number
    local profile = profiles[player]
    if profile == nil then
        return 0
    end
    local last = lastPlaytimeFlush[player]
    return profile.Data.playtime + (if last then os.clock() - last else 0)
end

-- Registra una función que se llama cada vez que Set/Update/Increment cambian ese campo.
-- Se ejecuta de forma síncrona, justo después del cambio. Debe registrarse en Init.
function DataService.OnFieldChanged(key: string, callback: FieldCallback)
    assertKey(key)
    local callbacks = fieldCallbacks[key]
    if callbacks == nil then
        callbacks = {}
        fieldCallbacks[key] = callbacks
    end
    table.insert(callbacks, callback)
end

-- Registra una función que se llama cuando se carga el perfil de un jugador.
-- Debe registrarse en Init para no perderse ninguna carga.
function DataService.OnProfileLoaded(callback: ProfileCallback)
    table.insert(loadedCallbacks, callback)
end

-- Registra una función que se llama justo antes de guardar y cerrar el perfil.
-- Se ejecuta de forma síncrona: los cambios hechos en ella se guardan.
function DataService.OnProfileReleasing(callback: ProfileCallback)
    table.insert(releasingCallbacks, callback)
end

function DataService.Init()
    playerStore = ProfileStore.New(DataConfig.StoreName, DataConfig.Template)

    -- Registro de problemas de guardado.
    ProfileStore.OnError:Connect(function(message: string, storeName: string, profileKey: string)
        Log.Warn("DataStore", `Error en {storeName}/{profileKey}: {message}`)
    end)
    ProfileStore.OnOverwrite:Connect(function(storeName: string, profileKey: string)
        Log.Warn("DataStore", `Datos inválidos sobrescritos en {storeName}/{profileKey}`)
    end)
    ProfileStore.OnCriticalToggle:Connect(function(isCritical: boolean)
        Log.Warn(
            "DataStore",
            if isCritical
                then "Estado crítico: muchos fallos de DataStore seguidos"
                else "Fin del estado crítico"
        )
    end)

    Remotes.DataRequest.OnServerEvent:Connect(function(player: Player)
        if not requestLimiter.Check(player) then
            return
        end
        local profile = profiles[player]
        if profile then
            sendSnapshot(player, profile.Data)
        end
    end)

    if RunService:IsStudio() then
        -- Solo para pruebas en Studio: permite cambiar monedas desde la barra de comandos.
        local debugAddCoins = Instance.new("BindableFunction")
        debugAddCoins.Name = "DebugAddCoins"
        debugAddCoins.OnInvoke = function(player: Player, amount: number): boolean
            if typeof(player) ~= "Instance" or not player:IsA("Player") then
                return false
            end
            if type(amount) ~= "number" or amount ~= amount then
                return false
            end
            return DataService.Increment(player, "coins", amount)
        end
        debugAddCoins.Parent = script
    end
end

function DataService.Start()
    Players.PlayerAdded:Connect(loadProfile)
    Players.PlayerRemoving:Connect(releaseProfile)
    for _, player in Players:GetPlayers() do
        task.spawn(loadProfile, player)
    end

    game:BindToClose(function()
        shuttingDown = true
        for player in profiles do
            releaseProfile(player)
        end
    end)

    task.spawn(function()
        while true do
            task.wait(DataConfig.PlaytimeFlushInterval)
            for player, profile in profiles do
                flushPlaytime(player, profile)
                -- Se actualiza también lastSeen por si el servidor se cae sin cerrar la sesión.
                profile.Data.lastSeen = os.time()
                sendField(player, "playtime", profile.Data.playtime)
            end
        end
    end)
end

return DataService
