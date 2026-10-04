--!strict

-- Arranque del panel de administración. Este código vive en ServerScriptService (que no se envía a los clientes) y el servidor
-- solo lo copia al PlayerGui de los administradores: el resto de jugadores no lo recibe.
-- Tenerlo no da ningún permiso: cada acción la valida el servidor (AdminService).

local AdminController = require(script.Parent:WaitForChild("AdminController"))
local AdminUI = require(script.Parent:WaitForChild("AdminUI"))

AdminController.Init()
AdminUI.Mount(script.Parent :: ScreenGui)
