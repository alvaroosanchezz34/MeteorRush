--!strict

-- Muestra en pantalla los mensajes que envía el servidor por el remote Notify.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Notifications = require(script.Parent.Parent.UI.Notifications)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local NotificationController = {}

function NotificationController.Init()
    Remotes.Notify.OnClientEvent:Connect(function(text: any)
        if type(text) == "string" then
            Notifications.Show(text)
        end
    end)
end

return NotificationController
