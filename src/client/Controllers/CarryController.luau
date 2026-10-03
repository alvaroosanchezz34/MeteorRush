--!strict

-- Réplica local de la mochila (minerales transportados) y su capacidad.
-- Fase 3: solo datos. La Fase 4 añade los minerales visibles en la espalda.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

type ChangedCallback = (items: { Types.InventoryItem }, capacity: number) -> ()

local CarryController = {}

local items: { Types.InventoryItem } = {}
local capacity = 0
local callbacks: { ChangedCallback } = {}

-- Minerales que lleva el jugador (copia).
function CarryController.GetItems(): { Types.InventoryItem }
    return table.clone(items)
end

-- Capacidad actual de la mochila.
function CarryController.GetCapacity(): number
    return capacity
end

-- Llama a la función cada vez que cambia la mochila. Devuelve una función para desconectar.
function CarryController.OnChanged(callback: ChangedCallback): () -> ()
    table.insert(callbacks, callback)
    return function()
        local index = table.find(callbacks, callback)
        if index then
            table.remove(callbacks, index)
        end
    end
end

function CarryController.Init()
    Remotes.CarryUpdate.OnClientEvent:Connect(function(newItems: any, newCapacity: any)
        if type(newItems) ~= "table" or type(newCapacity) ~= "number" then
            return
        end
        items = newItems
        capacity = newCapacity
        for _, callback in table.clone(callbacks) do
            task.spawn(callback, table.clone(items), capacity)
        end
    end)
end

return CarryController
