--!strict

-- Registro de acciones de administración: quién, qué, a quién y con qué valor. Se guarda en
-- memoria (los últimos `MAX_ENTRIES` de este servidor) y además se escribe en la consola,
-- con el prefijo [Admin], para que quede en el registro del servidor.

export type Entry = {
    -- Hora Unix del servidor.
    time: number,
    admin: string,
    action: string,
    target: string,
    value: string,
}

local MAX_ENTRIES = 300

local AdminLogs = {}

local entries: { Entry } = {}

-- Apunta una acción.
function AdminLogs.Add(admin: Player, action: string, target: string?, value: string?)
    local entry: Entry = {
        time = os.time(),
        admin = admin.Name,
        action = action,
        target = target or "-",
        value = value or "-",
    }
    table.insert(entries, entry)
    if #entries > MAX_ENTRIES then
        table.remove(entries, 1)
    end
    print(
        `[Admin] [{os.date("!%H:%M:%S", entry.time)}] {entry.admin} · {action} · {entry.target} · {entry.value}`
    )
end

-- Las últimas `count` acciones, de la más reciente a la más antigua.
function AdminLogs.GetRecent(count: number): { Entry }
    local recent: { Entry } = {}
    for index = #entries, math.max(#entries - count + 1, 1), -1 do
        table.insert(recent, entries[index])
    end
    return recent
end

return AdminLogs
