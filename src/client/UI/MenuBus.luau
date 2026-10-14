--!strict

-- Abrir un menú del juego desde fuera de la interfaz (por ejemplo, al hablar con un NPC).
-- El HUD se registra aquí como quien sabe abrirlos; así quien lo pide no tiene que conocer
-- el HUD ni sus ventanas.

type Handler = (menu: string, tab: string?) -> ()

local MenuBus = {}

local handler: Handler? = nil

-- Lo llama el HUD al montarse.
function MenuBus.SetHandler(callback: Handler)
    handler = callback
end

-- Abre ese menú y, si tiene pestañas, esa pestaña. No hace nada si el HUD aún no está.
function MenuBus.Open(menu: string, tab: string?)
    local callback = handler
    if callback then
        callback(menu, tab)
    end
end

return MenuBus
