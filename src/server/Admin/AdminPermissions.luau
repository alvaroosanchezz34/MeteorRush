--!strict

-- Quién es administrador. Es el ÚNICO sitio donde se decide, y solo se ejecuta en el
-- servidor: este archivo no se envía a ningún cliente.
--
-- La autorización usa el UserId de la cuenta, que el cliente no puede falsear. Nunca se
-- mira el nombre, el DisplayName, un atributo ni nada que llegue del cliente.

local RunService = game:GetService("RunService")

local AdminPermissions = {}

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  PON AQUÍ TU USERID DE ROBLOX (el número de tu perfil, no tu nombre).   ║
-- ║  Ejemplo:   [123456789] = true,                                          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
AdminPermissions.ADMIN_USER_IDS = {
    [10062862461] = true,
} :: { [number]: boolean }

-- Dueños: llevan el título especial "owner" (👑). Solo estas cuentas y el creador de la
-- experiencia (si es de un usuario). No se puede dar desde el panel.
AdminPermissions.OWNER_USER_IDS = {
    [10062862461] = true,
} :: { [number]: boolean }

-- El creador de la experiencia es administrador aunque no esté en la lista. Solo vale si
-- la experiencia es de una cuenta de usuario; si es de un grupo, usa la lista de arriba.
AdminPermissions.AllowCreator = true

-- En Roblox Studio, cualquier jugador de prueba es administrador, para poder probar el
-- panel con las cuentas de prueba. No afecta al juego publicado.
AdminPermissions.AllowStudio = true

-- Indica si ese jugador es dueño (título "owner").
function AdminPermissions.IsOwner(player: Player): boolean
    if typeof(player) ~= "Instance" or not player:IsA("Player") then
        return false
    end
    return AdminPermissions.OWNER_USER_IDS[player.UserId] == true
        or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)
end

-- Indica si ese jugador es administrador. Se comprueba en cada acción.
function AdminPermissions.IsAdmin(player: Player): boolean
    if typeof(player) ~= "Instance" or not player:IsA("Player") then
        return false
    end
    if AdminPermissions.ADMIN_USER_IDS[player.UserId] == true then
        return true
    end
    if
        AdminPermissions.AllowCreator
        and game.CreatorType == Enum.CreatorType.User
        and player.UserId == game.CreatorId
    then
        return true
    end
    return AdminPermissions.AllowStudio and RunService:IsStudio()
end

return AdminPermissions
