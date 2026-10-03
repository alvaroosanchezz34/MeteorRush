--!strict

-- Réplica local y de solo lectura de los datos del jugador.
-- El servidor envía una copia completa al cargar ("snapshot") y después cada campo que cambia ("field").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local TableUtil = require(Shared:WaitForChild("Util"):WaitForChild("TableUtil"))
local Types = require(Shared:WaitForChild("Types"))

type ChangedCallback = (value: any) -> ()

local DataController = {}

local data: Types.Profile? = nil
local changedCallbacks: { [string]: { ChangedCallback } } = {}
local readyCallbacks: { (data: Types.Profile) -> () } = {}

local function notifyChanged(key: string, value: any)
    local callbacks = changedCallbacks[key]
    if callbacks == nil then
        return
    end
    for _, callback in table.clone(callbacks) do
        task.spawn(callback, value)
    end
end

local function onSnapshot(snapshot: any)
    if type(snapshot) ~= "table" then
        return
    end
    local wasReady = data ~= nil
    local frozen: Types.Profile = TableUtil.DeepFreeze(snapshot)
    data = frozen

    if RunService:IsStudio() then
        print(`[DataController] Datos recibidos (coins = {frozen.coins})`)
    end

    if wasReady then
        for key, value in frozen :: any do
            notifyChanged(key, value)
        end
    else
        for _, callback in readyCallbacks do
            task.spawn(callback, frozen)
        end
        table.clear(readyCallbacks)
    end
end

local function onField(key: any, value: any)
    local current = data
    if current == nil or type(key) ~= "string" then
        return
    end
    local updated = table.clone(current) :: any
    updated[key] = TableUtil.DeepFreeze(value)
    table.freeze(updated)
    data = updated
    notifyChanged(key, updated[key])
end

-- Indica si ya se han recibido los datos del servidor.
function DataController.IsReady(): boolean
    return data ~= nil
end

-- Devuelve los datos congelados (solo lectura) o nil si aún no han llegado.
function DataController.GetData(): Types.Profile?
    return data
end

-- Devuelve el valor de un campo de primer nivel o nil si los datos no han llegado.
function DataController.Get(key: string): any
    local current = data
    return if current then (current :: any)[key] else nil
end

-- Llama a la función cuando llegan los datos (o inmediatamente si ya están).
function DataController.OnReady(callback: (data: Types.Profile) -> ())
    local current = data
    if current then
        task.spawn(callback, current)
    else
        table.insert(readyCallbacks, callback)
    end
end

-- Llama a la función cada vez que cambia un campo. Devuelve una función para desconectar.
function DataController.OnChanged(key: string, callback: ChangedCallback): () -> ()
    local callbacks = changedCallbacks[key]
    if callbacks == nil then
        callbacks = {}
        changedCallbacks[key] = callbacks
    end
    table.insert(callbacks, callback)

    return function()
        local list = changedCallbacks[key]
        if list == nil then
            return
        end
        local index = table.find(list, callback)
        if index then
            table.remove(list, index)
        end
    end
end

function DataController.Init()
    Remotes.DataUpdate.OnClientEvent:Connect(function(action: any, ...: any)
        if action == "snapshot" then
            onSnapshot(...)
        elseif action == "field" then
            onField(...)
        end
    end)
end

function DataController.Start()
    -- Por si el servidor envió la copia antes de conectar el evento.
    if data == nil then
        Remotes.DataRequest:FireServer()
    end
end

return DataController
