--!strict

-- Comunicación del panel con el servidor. Cada petición lleva un número; la respuesta del
-- servidor vuelve con el mismo número y despierta a quien la estaba esperando.
-- Aquí no se decide nada: el servidor comprueba el permiso y los valores de cada petición.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

-- Segundos que se espera una respuesta antes de darla por perdida.
local TIMEOUT = 8

local AdminController = {}

local nextId = 0
local pending: { [number]: thread } = {}

-- Envía un comando y espera el resultado: (true, datos o mensaje) o (false, motivo).
-- Hay que llamarla desde una corrutina (task.spawn), porque espera.
function AdminController.Request(action: string, args: { [string]: any }?): (boolean, any)
    nextId += 1
    local id = nextId
    pending[id] = coroutine.running()
    Remotes.AdminRequest:FireServer(id, action, args or {})
    task.delay(TIMEOUT, function()
        local thread = pending[id]
        if thread then
            pending[id] = nil
            task.spawn(thread, false, "Sin respuesta del servidor.")
        end
    end)
    return coroutine.yield()
end

function AdminController.Init()
    Remotes.AdminResponse.OnClientEvent:Connect(function(id: any, ok: any, payload: any)
        local thread = if type(id) == "number" then pending[id] else nil
        if thread then
            pending[id] = nil
            task.spawn(thread, ok == true, payload)
        end
    end)
end

return AdminController
