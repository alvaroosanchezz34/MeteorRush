--!strict

-- Interfaz del centro de control de administración: barra lateral con las secciones, zona
-- de contenido, selector del jugador objetivo y barra de estado. Pensada para PC (F2 la
-- abre y la cierra), compacta y con medidas en píxeles; se encoge sola si la pantalla es
-- pequeña.
-- Aquí solo se dibuja y se piden cosas: todo pasa por AdminController → servidor. Las
-- acciones destructivas piden confirmación antes de enviarse (y el servidor la exige).
-- Los textos van aquí y no en Strings porque ningún jugador los ve.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AdminController = require(script.Parent.AdminController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AmbientConfig = require(Config:WaitForChild("Ambient"))
local CompetitionConfig = require(Config:WaitForChild("Competition"))
local CratesConfig = require(Config:WaitForChild("Crates"))
local DecorConfig = require(Config:WaitForChild("Decor"))
local EquipmentConfig = require(Config:WaitForChild("Equipment"))
local EventsConfig = require(Config:WaitForChild("Events"))
local LiveOps = require(Config:WaitForChild("LiveOps"))
local MeteorsConfig = require(Config:WaitForChild("Meteors"))
local Minerals = require(Config:WaitForChild("Minerals"))
local Mutations = require(Config:WaitForChild("Mutations"))
local NpcsConfig = require(Config:WaitForChild("Npcs"))

local TOGGLE_KEY = Enum.KeyCode.F2
local WINDOW_SIZE = Vector2.new(980, 600)
local SIDEBAR_WIDTH = 168
local ROW_HEIGHT = 28
-- Segundos entre actualizaciones de las páginas que muestran datos en directo.
local REFRESH_SECONDS = 2
-- Palabra que hay que escribir para confirmar las acciones más graves.
local STRONG_WORD = "CONFIRMAR"

local COLORS = {
    background = Color3.fromRGB(10, 12, 22),
    panel = Color3.fromRGB(18, 22, 38),
    raised = Color3.fromRGB(30, 36, 60),
    stroke = Color3.fromRGB(70, 90, 150),
    text = Color3.fromRGB(232, 238, 255),
    muted = Color3.fromRGB(130, 142, 178),
    accent = Color3.fromRGB(80, 210, 255),
    ok = Color3.fromRGB(60, 200, 130),
    warn = Color3.fromRGB(240, 180, 60),
    danger = Color3.fromRGB(230, 70, 90),
}
local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold
local FONT_MONO = Enum.Font.Code

local PAGES = {
    "Dashboard",
    "Players",
    "Economy",
    "Minerals",
    "Meteorites",
    "Events",
    "Competitions",
    "Inventory",
    "Bases",
    "Announcements",
    "Debug",
    "Logs",
    "Settings",
}

type Builder = (page: ScrollingFrame) -> (() -> ())?

local AdminUI = {}

local player = Players.LocalPlayer
local window: Frame
local statusLabel: TextLabel
local targetButton: TextButton
local confirmOverlay: Frame
local confirmLabel: TextLabel
local confirmBox: TextBox
local confirmAction: (() -> ())? = nil
local confirmWord: string? = nil
local target: Player? = nil
local spectating = false
local clientFps = 60
local pages: { [string]: ScrollingFrame } = {}
-- Función que actualiza los datos en directo de cada página (si la tiene).
local refreshers: { [string]: () -> () } = {}
local currentPage = ""

-- Piezas -----------------------------------------------------------------------------------

local function create(className: string, props: { [string]: any }, parent: Instance?): any
    local instance = Instance.new(className) :: any
    for key, value in props do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end

local function round(parent: Instance, radius: number)
    create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function text(parent: Instance, content: string, width: number, color: Color3?): TextLabel
    return create("TextLabel", {
        Size = UDim2.new(0, width, 1, 0),
        BackgroundTransparency = 1,
        Text = content,
        TextColor3 = color or COLORS.text,
        TextSize = 13,
        Font = FONT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
end

local function button(
    parent: Instance,
    label: string,
    width: number,
    color: Color3?,
    onClick: () -> ()
): TextButton
    local instance: TextButton = create("TextButton", {
        Size = UDim2.new(0, width, 1, 0),
        BackgroundColor3 = color or COLORS.raised,
        AutoButtonColor = true,
        Text = label,
        TextColor3 = COLORS.text,
        TextSize = 12,
        Font = FONT_BOLD,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
    round(instance, 5)
    instance.Activated:Connect(onClick)
    return instance
end

local function input(
    parent: Instance,
    placeholder: string,
    width: number,
    default: string?
): TextBox
    local box: TextBox = create("TextBox", {
        Size = UDim2.new(0, width, 1, 0),
        BackgroundColor3 = COLORS.background,
        Text = default or "",
        PlaceholderText = placeholder,
        PlaceholderColor3 = COLORS.muted,
        TextColor3 = COLORS.text,
        TextSize = 13,
        Font = FONT,
        ClearTextOnFocus = false,
    }, parent)
    round(box, 5)
    create("UIStroke", { Color = COLORS.stroke, Transparency = 0.5 }, box)
    return box
end

-- Fila horizontal dentro de una página.
local function row(page: Instance, height: number?): Frame
    local frame: Frame = create("Frame", {
        Size = UDim2.new(1, -10, 0, height or ROW_HEIGHT),
        BackgroundTransparency = 1,
    }, page)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, frame)
    return frame
end

-- Título de un bloque de controles.
local function section(page: Instance, title: string)
    local label = text(row(page, 22), string.upper(title), 500, COLORS.accent)
    label.Font = FONT_BOLD
    label.TextSize = 12
end

-- Bloque de texto de varias líneas (datos, listas).
local function block(page: Instance, lines: number): TextLabel
    return create("TextLabel", {
        Size = UDim2.new(1, -10, 0, lines * 16 + 12),
        BackgroundColor3 = COLORS.panel,
        Text = "",
        TextColor3 = COLORS.text,
        TextSize = 13,
        Font = FONT_MONO,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, page)
end

-- Selector que recorre una lista de opciones: clic para la siguiente, clic derecho para la
-- anterior. Devuelve una función que da la opción elegida.
local function cycle(
    parent: Instance,
    label: string,
    options: { string },
    width: number
): () -> string
    local index = 1
    local instance: TextButton
    local function update()
        instance.Text = `{label}: {options[index] or "-"}  ⇄`
    end
    instance = button(parent, "", width, COLORS.panel, function()
        index = index % math.max(#options, 1) + 1
        update()
    end)
    create("UIStroke", { Color = COLORS.stroke, Transparency = 0.5 }, instance)
    instance.MouseButton2Click:Connect(function()
        index = (index - 2) % math.max(#options, 1) + 1
        update()
    end)
    update()
    return function(): string
        return options[index] or ""
    end
end

-- Interruptor de dos estados.
local function toggle(parent: Instance, label: string, width: number): () -> boolean
    local enabled = false
    local instance: TextButton
    instance = button(parent, `{label}: NO`, width, COLORS.panel, function()
        enabled = not enabled
        instance.Text = `{label}: {if enabled then "SÍ" else "NO"}`
        instance.BackgroundColor3 = if enabled then COLORS.ok else COLORS.panel
    end)
    return function(): boolean
        return enabled
    end
end

local function ids(list: { any }): { string }
    local result: { string } = {}
    for _, entry in list do
        table.insert(result, entry.id)
    end
    return result
end

local function keys(dictionary: { [string]: any }): { string }
    local result: { string } = {}
    for key in dictionary do
        table.insert(result, key)
    end
    table.sort(result)
    return result
end

local function formatDuration(seconds: number): string
    local total = math.floor(seconds)
    return string.format("%02d:%02d:%02d", total // 3600, total // 60 % 60, total % 60)
end

-- Estado, objetivo y peticiones ------------------------------------------------------------

local function setStatus(message: string, color: Color3?)
    statusLabel.Text = message
    statusLabel.TextColor3 = color or COLORS.muted
end

-- Envía un comando y muestra el resultado en la barra de estado.
local function run(
    action: string,
    args: { [string]: any }?,
    after: ((ok: boolean, result: any) -> ())?
)
    task.spawn(function()
        setStatus(`{action}…`)
        local ok, result = AdminController.Request(action, args)
        if type(result) == "string" then
            setStatus(result, if ok then COLORS.ok else COLORS.danger)
        else
            setStatus(
                if ok then `{action} ✔` else `{action}: error`,
                if ok then COLORS.ok else COLORS.danger
            )
        end
        if after then
            after(ok, result)
        end
    end)
end

-- Argumentos con el jugador objetivo, o nil (con aviso) si no hay ninguno elegido.
local function withTarget(args: { [string]: any }?): { [string]: any }?
    local chosen = target
    if chosen == nil or chosen.Parent ~= Players then
        setStatus("Elige primero un jugador objetivo (arriba a la derecha).", COLORS.warn)
        return nil
    end
    local result = args or {}
    result.userId = chosen.UserId
    return result
end

local function runOnTarget(action: string, args: { [string]: any }?, after: ((boolean, any) -> ())?)
    local full = withTarget(args)
    if full then
        run(action, full, after)
    end
end

-- Pide confirmación y, si se acepta, llama a `onYes`. Con `word`, además hay que escribirla.
local function confirm(message: string, word: string?, onYes: () -> ())
    confirmLabel.Text = if word then `{message}\n\nEscribe {word} para confirmar.` else message
    confirmBox.Visible = word ~= nil
    confirmBox.Text = ""
    confirmWord = word
    confirmAction = onYes
    confirmOverlay.Visible = true
end

-- Acción destructiva: confirmación en el panel y `confirm = true` para el servidor.
local function danger(
    message: string,
    action: string,
    args: { [string]: any }?,
    strong: boolean?,
    after: ((boolean, any) -> ())?
)
    confirm(message, if strong then STRONG_WORD else nil, function()
        local full = args or {}
        full.confirm = true
        run(action, full, after)
    end)
end

local function dangerOnTarget(
    message: string,
    action: string,
    args: { [string]: any }?,
    strong: boolean?
)
    local full = withTarget(args)
    local chosen = target
    if full and chosen then
        danger(`{message}\n\nJugador: {chosen.Name}`, action, full, strong)
    end
end

local function setTarget(chosen: Player?)
    target = chosen
    targetButton.Text = if chosen then `🎯 {chosen.Name}` else "🎯 sin objetivo"
end

local function number(box: TextBox): number?
    return tonumber(box.Text)
end

-- Módulo del cliente del juego (para las pruebas visuales), o nil si no se encuentra.
local function clientModule(...: string): any
    local node: Instance? = player:WaitForChild("PlayerScripts"):FindFirstChild("Client")
    for _, name in { ... } do
        node = if node then node:FindFirstChild(name) else nil
    end
    if node and node:IsA("ModuleScript") then
        local ok, module = pcall(require :: any, node)
        return if ok then module else nil
    end
    return nil
end

local function ownPosition(): Vector3
    local character = player.Character
    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
    return if root and root:IsA("BasePart") then root.Position else Vector3.zero
end

local function spectate(chosen: Player?)
    local camera = Workspace.CurrentCamera
    local character = (chosen or player).Character
    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
    if camera and humanoid then
        camera.CameraSubject = humanoid
        spectating = chosen ~= nil and chosen ~= player
        setStatus(
            if spectating and chosen then `Observando a {chosen.Name}.` else "Cámara normal."
        )
    end
end

-- Páginas ---------------------------------------------------------------------------------------

local builders: { [string]: Builder } = {}

builders.Dashboard = function(page: ScrollingFrame)
    section(page, "Servidor")
    local info = block(page, 12)
    section(page, "Sistemas")
    local systems = block(page, 8)
    return function()
        local ok, data = AdminController.Request("dashboard")
        if not ok or type(data) ~= "table" then
            info.Text = " Sin datos del servidor."
            return
        end
        local competition = data.competition or {}
        info.Text = table.concat({
            ` Jugadores      {data.players} / {data.maxPlayers}`,
            ` Versión        {data.version}{if data.studio then "  (Studio)" else ""}`,
            ` Tiempo activo  {formatDuration(data.uptime)}`,
            ` FPS servidor   {data.serverFps}`,
            ` FPS cliente    {math.round(clientFps)}`,
            ` Memoria        {data.memoryMb} MB`,
            ` Meteoritos     {#data.meteors}`,
            ` Evento         {data.event or "-"}{if data.eventActive
                then " (activo)"
                elseif data.event then " (cuenta atrás)"
                else ""}`,
            ` Suceso         {data.ambient or "-"}`,
            ` Competición    {competition.kind or "-"}`,
            ` PlaceId        {data.placeId}`,
            ` JobId          {if data.jobId == "" then "(Studio)" else data.jobId}`,
        }, "\n")
        local lines: { string } = {}
        for _, name in keys(data.features) do
            table.insert(lines, ` {if data.features[name] then "●  ON " else "○  OFF"}  {name}`)
        end
        systems.Text = table.concat(lines, "\n")
    end
end

builders.Players = function(page: ScrollingFrame)
    local controls = row(page)
    button(controls, "Dejar de observar", 130, nil, function()
        spectate(nil)
    end)
    text(controls, "Elegir = lo marca como objetivo del resto de páginas.", 420, COLORS.muted)
    local list: Frame = create("Frame", {
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, page)
    create("UIListLayout", { Padding = UDim.new(0, 4) }, list)

    return function()
        local ok, data = AdminController.Request("players")
        if not ok or type(data) ~= "table" then
            return
        end
        for _, child in list:GetChildren() do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        for _, entry in data do
            local other = Players:GetPlayerByUserId(entry.userId)
            local line = row(list)
            line.Size = UDim2.new(1, -10, 0, ROW_HEIGHT)
            text(
                line,
                `{if entry.admin then "★ " else ""}{entry.name}`,
                130,
                if entry.loaded then COLORS.text else COLORS.muted
            )
            text(
                line,
                `💰{string.format("%.3g", entry.coins)}  ⭐{entry.rebirths}  ⛏{entry.minerals}`,
                170,
                COLORS.muted
            )
            button(line, "Elegir", 56, COLORS.accent, function()
                setTarget(other)
            end).TextColor3 =
                COLORS.background
            button(line, "Ir", 40, nil, function()
                run("teleportTo", { userId = entry.userId })
            end)
            button(line, "Traer", 50, nil, function()
                run("bring", { userId = entry.userId })
            end)
            button(line, "Respawn", 64, nil, function()
                run("respawn", { userId = entry.userId })
            end)
            button(line, "Observar", 68, nil, function()
                spectate(other)
            end)
            button(line, "Kick", 48, COLORS.danger, function()
                danger(`¿Expulsar a {entry.name} del servidor?`, "kick", { userId = entry.userId })
            end)
        end
    end
end

builders.Economy = function(page: ScrollingFrame)
    section(page, "Monedas del objetivo")
    local coins = row(page)
    local amount = input(coins, "cantidad", 150)
    button(coins, "Añadir", 80, COLORS.ok, function()
        runOnTarget("coinsAdd", { amount = number(amount) })
    end)
    button(coins, "Quitar", 80, COLORS.warn, function()
        runOnTarget("coinsRemove", { amount = number(amount) })
    end)
    button(coins, "Fijar", 80, nil, function()
        runOnTarget("coinsSet", { amount = number(amount) })
    end)
    button(coins, "Resetear a 0", 110, COLORS.danger, function()
        dangerOnTarget("¿Dejar las monedas a 0? No se puede deshacer.", "coinsReset", nil, true)
    end)

    section(page, "Multiplicadores temporales (boosts del juego)")
    local boosts = row(page)
    local boost = cycle(boosts, "Boost", { "luck", "magnet", "carryShield" }, 180)
    local minutes = input(boosts, "minutos", 80, "30")
    button(boosts, "Dar", 70, COLORS.ok, function()
        runOnTarget("boostGive", { boost = boost(), minutes = number(minutes) })
    end)
    button(boosts, "Quitar todos", 110, COLORS.warn, function()
        runOnTarget("boostClear")
    end)

    section(page, "Rebirths (solo cambia el número; no reinicia nada)")
    local rebirths = row(page)
    local count = input(rebirths, "cantidad", 100, "1")
    button(rebirths, "Añadir", 80, COLORS.warn, function()
        dangerOnTarget(`¿Añadir {count.Text} rebirths?`, "rebirthAdd", { amount = number(count) })
    end)
    button(rebirths, "Fijar", 80, COLORS.warn, function()
        dangerOnTarget(
            `¿Fijar los rebirths en {count.Text}?`,
            "rebirthSet",
            { amount = number(count) }
        )
    end)
    button(rebirths, "Resetear a 0", 110, COLORS.danger, function()
        dangerOnTarget("¿Dejar los rebirths a 0? No se puede deshacer.", "rebirthReset", nil, true)
    end)
    return nil
end

builders.Minerals = function(page: ScrollingFrame)
    section(page, "Dar un mineral concreto al objetivo")
    local give = row(page)
    local mineral = cycle(give, "Mineral", ids(Minerals.List), 190)
    local mutation = cycle(give, "Mutación", ids(Mutations.List), 190)
    local quantity = input(give, "cantidad", 70, "1")
    button(give, "Dar", 70, COLORS.ok, function()
        runOnTarget(
            "mineralGive",
            { mineral = mineral(), mutation = mutation(), quantity = number(quantity) }
        )
    end)

    section(page, "Al azar (mismas tiradas que el juego; no cambia las probabilidades)")
    local random = row(page)
    local count = input(random, "cantidad", 70, "1")
    button(random, "Dar aleatorio", 120, nil, function()
        runOnTarget("mineralRandom", { quantity = number(count) })
    end)
    button(random, "Dar raro o superior", 150, nil, function()
        runOnTarget("mineralRare", { quantity = number(count) })
    end)
    return nil
end

builders.Meteorites = function(page: ScrollingFrame)
    section(page, "Generar (no cambia los tiempos normales de caída)")
    local spawn = row(page)
    local kind = cycle(spawn, "Tipo", keys(MeteorsConfig.Types), 170)
    local where = cycle(spawn, "Dónde", { "aleatorio", "junto al objetivo" }, 220)
    local instant = toggle(spawn, "Inmediato", 120)
    button(spawn, "Generar", 90, COLORS.ok, function()
        local args: { [string]: any } = { type = kind(), instant = instant() }
        if where() == "aleatorio" then
            run("meteorSpawn", args)
        else
            args.where = "player"
            runOnTarget("meteorSpawn", args)
        end
    end)

    section(page, "En el suelo")
    local controls = row(page)
    button(controls, "Eliminar todos", 120, COLORS.danger, function()
        danger("¿Eliminar todos los meteoritos del suelo?", "meteorClear")
    end)
    local list: Frame = create("Frame", {
        Size = UDim2.fromScale(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, page)
    create("UIListLayout", { Padding = UDim.new(0, 4) }, list)

    return function()
        local ok, data = AdminController.Request("dashboard")
        if not ok or type(data) ~= "table" then
            return
        end
        for _, child in list:GetChildren() do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        for _, meteor in data.meteors do
            local line = row(list)
            text(line, `#{meteor.id}  {meteor.type}  ·  golpes: {meteor.hitsLeft}`, 300)
            button(line, "Eliminar", 80, COLORS.warn, function()
                run("meteorRemove", { id = meteor.id })
            end)
        end
    end
end

builders.Events = function(page: ScrollingFrame)
    section(page, "Evento global")
    local events = row(page)
    local event = cycle(events, "Evento", ids(EventsConfig.List), 240)
    button(events, "Iniciar", 80, COLORS.ok, function()
        run("eventStart", { event = event() })
    end)
    button(events, "Detener el actual", 130, COLORS.warn, function()
        run("eventStop")
    end)
    local state = block(page, 2)

    section(page, "Suceso ambiental (solo visual)")
    local ambient = row(page)
    local rare = cycle(ambient, "Suceso", ids(AmbientConfig.RareEvents), 240)
    button(ambient, "Iniciar", 80, COLORS.ok, function()
        run("ambientStart", { event = rare() })
    end)

    return function()
        local id = Workspace:GetAttribute("EventId")
        local endsAt = Workspace:GetAttribute("EventEndsAt")
        local startsAt = Workspace:GetAttribute("EventStartsAt")
        local now = Workspace:GetServerTimeNow()
        state.Text = if type(id) ~= "string"
            then " Sin evento en marcha."
            elseif type(endsAt) == "number" then ` {id}: activo, quedan {formatDuration(
                endsAt - now
            )}`
            elseif type(startsAt) == "number" then ` {id}: empieza en {formatDuration(
                startsAt - now
            )}`
            else ` {id}`
    end
end

builders.Competitions = function(page: ScrollingFrame)
    section(page, "Competición de servidor")
    local controls = row(page)
    local kind = cycle(controls, "Tipo", ids(CompetitionConfig.Kinds), 200)
    button(controls, "Iniciar", 80, COLORS.ok, function()
        run("competitionStart", { kind = kind() })
    end)
    button(controls, "Detener (sin premios)", 160, COLORS.warn, function()
        run("competitionStop")
    end)
    section(page, "Puntuaciones")
    local scores = block(page, 9)
    return function()
        local ok, data = AdminController.Request("dashboard")
        local competition = if ok and type(data) == "table" then data.competition else nil
        if type(competition) ~= "table" or competition.kind == nil then
            scores.Text = " Sin competición en marcha."
            return
        end
        local lines = { ` Tipo: {competition.kind}` }
        for place, entry in competition.scores do
            table.insert(lines, ` {place}.  {entry.name}  —  {entry.points}`)
        end
        scores.Text = table.concat(lines, "\n")
    end
end

builders.Inventory = function(page: ScrollingFrame)
    section(page, "Inventario del objetivo")
    local controls = row(page)
    local view = block(page, 10)
    button(controls, "Ver / actualizar", 130, COLORS.accent, function()
        runOnTarget("inventory", nil, function(ok: boolean, data: any)
            if not ok or type(data) ~= "table" then
                return
            end
            local lines = {
                ` {data.name}   💰 {data.coins}   💎 {data.shards}   ⭐ {data.rebirths}`,
                ` Título: {if data.title == "" then "-" else data.title}   ·   Títulos: {#data.titles}`,
                ` Cosméticos: {if #data.cosmetics > 0
                    then table.concat(data.cosmetics, ", ")
                    else "-"}`,
                ` Pases: {table.concat(keys(data.passes), ", ")}`,
                ` Pico: {data.equipment.pickaxe}   ·   Arma: {data.equipment.weapon}   ·   Forge Dust: {data.equipment.dust}`,
                ` Equipamiento: {table.concat(keys(data.equipment.owned), ", ")}`,
                " Minerales:",
            }
            table.sort(data.minerals, function(a: any, b: any): boolean
                return a.count > b.count
            end)
            for _, group in data.minerals do
                table.insert(
                    lines,
                    `   {group.count} × {group.mineral}`
                        .. `{if group.mutation == "none" then "" else ` ({group.mutation})`}`
                        .. `{if group.placed > 0 then `   [{group.placed} en pedestal]` else ""}`
                )
            end
            view.Text = table.concat(lines, "\n")
            setStatus("Inventario actualizado.", COLORS.ok)
        end)
    end).TextColor3 =
        COLORS.background

    section(page, "Quitar minerales (los que no están en un pedestal)")
    local remove = row(page)
    local mineral = cycle(remove, "Mineral", ids(Minerals.List), 190)
    local mutation = cycle(remove, "Mutación", ids(Mutations.List), 190)
    local quantity = input(remove, "cantidad", 70, "1")
    button(remove, "Quitar", 80, COLORS.danger, function()
        dangerOnTarget(
            `¿Quitar {quantity.Text} × {mineral()} ({mutation()})?`,
            "inventoryRemove",
            { mineral = mineral(), mutation = mutation(), quantity = number(quantity) }
        )
    end)

    -- Objetos por tipo: cada uno tiene su proveedor registrado en AdminService.
    section(page, "Objetos: cosméticos, picos y armas (Ver ids enseña los que hay)")
    local items = row(page)
    local kind = cycle(items, "Tipo", { "cosmetic", "pickaxe", "weapon" }, 160)
    local item = input(items, "id del objeto", 170)
    button(items, "Dar", 60, COLORS.ok, function()
        runOnTarget("itemGive", { kind = kind(), item = item.Text })
    end)
    button(items, "Quitar", 70, COLORS.danger, function()
        dangerOnTarget(
            `¿Quitar {kind()}:{item.Text}?`,
            "itemRemove",
            { kind = kind(), item = item.Text }
        )
    end)
    local available = block(page, 2)

    section(page, "Cajas y Forge Dust")
    local crates = row(page)
    local crate = cycle(crates, "Caja", ids(CratesConfig.List), 170)
    local crateCount = input(crates, "cantidad", 70, "1")
    button(crates, "Dar cajas", 90, COLORS.ok, function()
        runOnTarget("crateGive", { crate = crate(), quantity = number(crateCount) })
    end)
    button(crates, "Fijar seguro", 100, nil, function()
        runOnTarget("pitySet", { crate = crate(), count = number(crateCount) })
    end)
    button(crates, "Dar Forge Dust", 120, nil, function()
        runOnTarget("dustGive", { amount = number(crateCount) })
    end)

    section(page, "Pruebas de apertura (solo las ves tú; no dan nada)")
    local tests = row(page)
    local revealItem = cycle(tests, "Objeto", ids(EquipmentConfig.List), 230)
    button(tests, "Probar caja", 100, nil, function()
        run("crateTest", { crate = crate() })
    end)
    button(tests, "Forzar presentación", 150, nil, function()
        run("forceReveal", { crate = crate(), item = revealItem() })
    end)
    button(items, "Ver ids", 70, nil, function()
        run("itemList", nil, function(ok: boolean, data: any)
            if ok and type(data) == "table" then
                local lines: { string } = {}
                for _, name in keys(data) do
                    table.insert(lines, ` {name}: {table.concat(data[name], ", ")}`)
                end
                available.Text = table.concat(lines, "\n")
            end
        end)
    end)
    return nil
end

builders.Bases = function(page: ScrollingFrame)
    section(page, "Base del objetivo")
    local main = row(page)
    button(main, "Teletransportarme", 140, nil, function()
        runOnTarget("baseTeleport")
    end)
    button(main, "Vaciar pedestales", 140, COLORS.danger, function()
        dangerOnTarget(
            "¿Vaciar todos sus pedestales? Los minerales vuelven a su inventario.",
            "baseClearPedestals"
        )
    end)
    button(main, "Resetear decoración", 150, COLORS.danger, function()
        dangerOnTarget("¿Quitar toda su decoración y su efecto?", "baseResetDecor")
    end)

    section(page, "Efecto de la base")
    local effects = row(page)
    local effectIds = ids(DecorConfig.Effects)
    table.insert(effectIds, 1, "(ninguno)")
    local effect = cycle(effects, "Efecto", effectIds, 220)
    button(effects, "Aplicar", 80, COLORS.ok, function()
        local id = effect()
        runOnTarget("baseSetEffect", { effect = if id == "(ninguno)" then "" else id })
    end)

    section(page, "Decoración")
    local decor = row(page)
    local slots: { string } = {}
    for index = 1, #DecorConfig.Slots do
        table.insert(slots, tostring(index))
    end
    local slot = cycle(decor, "Hueco", slots, 110)
    local decorationIds = ids(DecorConfig.Decorations)
    table.insert(decorationIds, 1, "(vacío)")
    local decoration = cycle(decor, "Decoración", decorationIds, 240)
    button(decor, "Colocar", 80, COLORS.ok, function()
        local id = decoration()
        runOnTarget(
            "baseDecorate",
            { slot = tonumber(slot()), decoration = if id == "(vacío)" then "" else id }
        )
    end)
    return nil
end

builders.Announcements = function(page: ScrollingFrame)
    section(page, "Anuncio a todo el servidor (pasa por el filtro de texto de Roblox)")
    local message = input(row(page, 34), "mensaje (máx. 120 caracteres)", 620)
    local options = row(page)
    local seconds = input(options, "segundos", 80, "6")
    local style = cycle(options, "Estilo", { "info", "success", "warning", "event" }, 170)
    local sound = toggle(options, "Sonido", 110)
    button(options, "Enviar", 90, COLORS.ok, function()
        run("announce", {
            message = message.Text,
            seconds = number(seconds),
            style = style(),
            sound = sound(),
        })
    end)
    return nil
end

builders.Debug = function(page: ScrollingFrame)
    section(page, "Selección para las pruebas")
    local selection = row(page)
    local mineral = cycle(selection, "Mineral", ids(Minerals.List), 190)
    local mutation = cycle(selection, "Mutación", ids(Mutations.List), 190)

    section(page, "Pruebas visuales (solo las ves tú)")
    local visuals = row(page)
    button(visuals, "Forzar descubrimiento", 160, nil, function()
        local module = clientModule("UI", "DiscoveryMoment")
        if module then
            module.Play(mineral(), mutation(), ownPosition())
        end
    end)
    button(visuals, "Momento legendario", 150, nil, function()
        run("testLegendary", { mineral = mineral(), mutation = mutation() })
    end)
    button(visuals, "Momento mítico", 130, nil, function()
        local mythic = Minerals.List[#Minerals.List].id
        for _, candidate in Minerals.List do
            if candidate.rarity == "mythic" then
                mythic = candidate.id
            end
        end
        run("testLegendary", { mineral = mythic, mutation = mutation() })
    end)
    button(visuals, "VFX de mutación", 130, nil, function()
        local module = clientModule("Controllers", "MutationFxController")
        if module then
            module.Reveal(ownPosition() + Vector3.new(0, 3, 0), mutation(), true)
        end
    end)

    local sounds = row(page)
    local soundName = input(sounds, "clave de Config/Sounds", 200, "Banner")
    button(sounds, "Probar sonido", 120, nil, function()
        local module = clientModule("UI", "AudioManager")
        if module then
            module.Play(soundName.Text)
        end
    end)
    button(sounds, "Probar notificación", 150, nil, function()
        local module = clientModule("UI", "Notifications")
        if module then
            module.Show("Test notification from the admin panel")
        end
    end)

    section(page, "NPCs ambientales")
    local npcs = row(page)
    local npc = cycle(npcs, "NPC", ids(NpcsConfig.List), 220)
    button(npcs, "Ir al NPC", 100, nil, function()
        run("npcTeleport", { npc = npc() })
    end)

    section(page, "Limpieza")
    local cleanup = row(page)
    button(cleanup, "Recargar panel", 120, nil, function()
        AdminUI.Reload()
    end)
    button(cleanup, "Respawn (yo)", 110, nil, function()
        run("respawn", { userId = player.UserId })
    end)
    button(cleanup, "Limpiar VFX", 100, nil, function()
        local folder = Workspace:FindFirstChild("Effects")
        if folder then
            for _, child in folder:GetChildren() do
                child:Destroy()
            end
        end
        setStatus("Efectos locales limpiados.", COLORS.ok)
    end)
    button(cleanup, "Limpiar meteoritos", 140, COLORS.warn, function()
        danger("¿Eliminar todos los meteoritos del suelo?", "meteorClear")
    end)
    button(cleanup, "Quitar boosts (objetivo)", 170, COLORS.warn, function()
        runOnTarget("boostClear")
    end)
    return nil
end

builders.Logs = function(page: ScrollingFrame)
    section(page, "Acciones de administración de este servidor (también en la consola)")
    local view = block(page, 20)
    return function()
        local ok, data = AdminController.Request("logs")
        if not ok or type(data) ~= "table" then
            return
        end
        local lines: { string } = {}
        for _, entry in data do
            table.insert(
                lines,
                ` [{os.date("%H:%M:%S", entry.time)}] {entry.admin} {entry.action} {entry.target} {entry.value}`
            )
        end
        view.Text = if #lines > 0 then table.concat(lines, "\n") else " Sin acciones todavía."
    end
end

builders.Settings = function(page: ScrollingFrame)
    section(page, "Interruptores de contenido (se guardan y llegan a todos los servidores)")
    for _, name in keys(LiveOps.Features) do
        local line = row(page)
        local attribute = `Feature_{name}`
        local switch: TextButton
        local function isEnabled(): boolean
            return Workspace:GetAttribute(attribute) ~= false
        end
        local function update()
            switch.Text = if isEnabled() then "ON" else "OFF"
            switch.BackgroundColor3 = if isEnabled() then COLORS.ok else COLORS.danger
        end
        text(line, name, 160)
        switch = button(line, "", 70, nil, function()
            run("featureSet", { feature = name, enabled = not isEnabled() })
        end)
        Workspace:GetAttributeChangedSignal(attribute):Connect(update)
        update()
    end

    section(page, "Servidor")
    local server = row(page)
    button(server, "Reiniciar sistemas", 150, COLORS.warn, function()
        danger(
            "¿Parar el evento y la competición en curso y quitar los meteoritos? No toca datos.",
            "systemsReset"
        )
    end)
    button(server, "Cerrar servidor", 130, COLORS.danger, function()
        danger(
            "¿CERRAR ESTE SERVIDOR? Se expulsa a todos los jugadores (sus datos se guardan).",
            "shutdown",
            nil,
            true
        )
    end)
    section(page, `Panel · {TOGGLE_KEY.Name} abre y cierra`)
    return nil
end

-- Montaje -------------------------------------------------------------------------------------

local function showPage(name: string, sidebar: Frame)
    currentPage = name
    for pageName, page in pages do
        page.Visible = pageName == name
    end
    for _, child in sidebar:GetChildren() do
        if child:IsA("TextButton") then
            local selected = child.Name == name
            child.BackgroundColor3 = if selected then COLORS.raised else COLORS.panel
            child.TextColor3 = if selected then COLORS.accent else COLORS.text
        end
    end
    local refresh = refreshers[name]
    if refresh then
        task.spawn(refresh)
    end
end

local function build(gui: ScreenGui)
    -- Botón siempre visible para abrir el panel.
    local opener: TextButton = create("TextButton", {
        Name = "Opener",
        Size = UDim2.fromOffset(74, 24),
        Position = UDim2.new(1, -84, 0, 44),
        BackgroundColor3 = COLORS.background,
        BackgroundTransparency = 0.2,
        Text = "⚙ ADMIN",
        TextColor3 = COLORS.accent,
        TextSize = 12,
        Font = FONT_BOLD,
    }, gui)
    round(opener, 6)

    window = create("Frame", {
        Name = "Window",
        Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = COLORS.background,
        BorderSizePixel = 0,
        Visible = false,
        Active = true,
    }, gui)
    round(window, 10)
    create("UIStroke", { Color = COLORS.accent, Transparency = 0.5, Thickness = 1.5 }, window)
    -- En pantallas pequeñas se encoge para caber.
    local scale: UIScale = create("UIScale", {}, window)
    local function fit()
        local camera = Workspace.CurrentCamera
        local viewport = if camera then camera.ViewportSize else WINDOW_SIZE
        scale.Scale =
            math.min(1, (viewport.X - 20) / WINDOW_SIZE.X, (viewport.Y - 20) / WINDOW_SIZE.Y)
    end
    fit()
    local camera = Workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
    end

    -- Cabecera.
    local header: Frame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
    }, window)
    round(header, 10)
    create("TextLabel", {
        Size = UDim2.new(0, 400, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1,
        Text = `☄ METEOR RUSH  ·  ADMIN CONTROL CENTER  ·  v{LiveOps.Version}`,
        TextColor3 = COLORS.accent,
        TextSize = 14,
        Font = FONT_BOLD,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)
    targetButton = create("TextButton", {
        Size = UDim2.fromOffset(200, 26),
        Position = UDim2.new(1, -250, 0, 7),
        BackgroundColor3 = COLORS.raised,
        Text = "",
        TextColor3 = COLORS.text,
        TextSize = 12,
        Font = FONT_BOLD,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, header)
    round(targetButton, 5)
    -- Clic: siguiente jugador del servidor como objetivo.
    targetButton.Activated:Connect(function()
        local list = Players:GetPlayers()
        local index = if target then table.find(list, target) or 0 else 0
        setTarget(list[index % #list + 1])
    end)
    local close: TextButton = create("TextButton", {
        Size = UDim2.fromOffset(30, 26),
        Position = UDim2.new(1, -40, 0, 7),
        BackgroundColor3 = COLORS.danger,
        Text = "✕",
        TextColor3 = COLORS.text,
        TextSize = 14,
        Font = FONT_BOLD,
    }, header)
    round(close, 5)

    -- Barra lateral.
    local sidebar: Frame = create("Frame", {
        Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -78),
        Position = UDim2.fromOffset(8, 46),
        BackgroundTransparency = 1,
    }, window)
    create(
        "UIListLayout",
        { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder },
        sidebar
    )

    -- Contenido.
    local content: Frame = create("Frame", {
        Size = UDim2.new(1, -SIDEBAR_WIDTH - 24, 1, -78),
        Position = UDim2.fromOffset(SIDEBAR_WIDTH + 16, 46),
        BackgroundColor3 = COLORS.panel,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
    }, window)
    round(content, 8)

    -- Barra de estado.
    statusLabel = create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 24),
        Position = UDim2.new(0, 12, 1, -28),
        BackgroundTransparency = 1,
        Text = "Listo.",
        TextColor3 = COLORS.muted,
        TextSize = 13,
        Font = FONT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, window)

    table.clear(pages)
    table.clear(refreshers)
    for index, name in PAGES do
        local page: ScrollingFrame = create("ScrollingFrame", {
            Name = name,
            Size = UDim2.new(1, -16, 1, -16),
            Position = UDim2.fromOffset(10, 8),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = COLORS.accent,
            Visible = false,
        }, content)
        create(
            "UIListLayout",
            { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder },
            page
        )
        pages[name] = page
        local refresh = builders[name](page)
        if refresh then
            refreshers[name] = refresh
        end

        local tab: TextButton = create("TextButton", {
            Name = name,
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = COLORS.panel,
            Text = `   {name}`,
            TextColor3 = COLORS.text,
            TextSize = 13,
            Font = FONT_BOLD,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = index,
        }, sidebar)
        round(tab, 6)
        tab.Activated:Connect(function()
            showPage(name, sidebar)
        end)
    end

    -- Diálogo de confirmación: tapa toda la ventana.
    confirmOverlay = create("Frame", {
        Name = "Confirm",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = COLORS.background,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Visible = false,
        Active = true,
        ZIndex = 20,
    }, window)
    round(confirmOverlay, 10)
    local dialog: Frame = create("Frame", {
        Size = UDim2.fromOffset(460, 230),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
        ZIndex = 21,
    }, confirmOverlay)
    round(dialog, 8)
    create("UIStroke", { Color = COLORS.danger, Thickness = 1.5 }, dialog)
    confirmLabel = create("TextLabel", {
        Size = UDim2.new(1, -30, 0, 120),
        Position = UDim2.fromOffset(15, 12),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = COLORS.text,
        TextSize = 15,
        Font = FONT_BOLD,
        TextWrapped = true,
        ZIndex = 22,
    }, dialog)
    confirmBox = create("TextBox", {
        Size = UDim2.fromOffset(200, 28),
        Position = UDim2.new(0.5, -100, 0, 138),
        BackgroundColor3 = COLORS.background,
        Text = "",
        PlaceholderText = STRONG_WORD,
        PlaceholderColor3 = COLORS.muted,
        TextColor3 = COLORS.text,
        TextSize = 14,
        Font = FONT_BOLD,
        ClearTextOnFocus = false,
        ZIndex = 22,
    }, dialog)
    round(confirmBox, 5)
    local yes: TextButton = create("TextButton", {
        Size = UDim2.fromOffset(180, 34),
        Position = UDim2.new(0.5, -190, 1, -48),
        BackgroundColor3 = COLORS.danger,
        Text = "Confirmar",
        TextColor3 = COLORS.text,
        TextSize = 14,
        Font = FONT_BOLD,
        ZIndex = 22,
    }, dialog)
    round(yes, 6)
    local no: TextButton = create("TextButton", {
        Size = UDim2.fromOffset(180, 34),
        Position = UDim2.new(0.5, 10, 1, -48),
        BackgroundColor3 = COLORS.raised,
        Text = "Cancelar",
        TextColor3 = COLORS.text,
        TextSize = 14,
        Font = FONT_BOLD,
        ZIndex = 22,
    }, dialog)
    round(no, 6)
    yes.Activated:Connect(function()
        local word = confirmWord
        if word and string.upper(confirmBox.Text) ~= word then
            confirmBox.Text = ""
            confirmBox.PlaceholderText = `escribe {word}`
            return
        end
        local action = confirmAction
        confirmAction = nil
        confirmOverlay.Visible = false
        if action then
            action()
        end
    end)
    no.Activated:Connect(function()
        confirmAction = nil
        confirmOverlay.Visible = false
        setStatus("Cancelado.")
    end)

    local function setOpen(open: boolean)
        window.Visible = open
        if open then
            showPage(if currentPage == "" then PAGES[1] else currentPage, sidebar)
        else
            confirmOverlay.Visible = false
            confirmAction = nil
        end
    end
    opener.Activated:Connect(function()
        setOpen(not window.Visible)
    end)
    close.Activated:Connect(function()
        setOpen(false)
    end)

    setTarget(if target and target.Parent == Players then target else player)
    return setOpen
end

local mounted: ScreenGui? = nil
local setOpen: ((open: boolean) -> ())? = nil

-- Destruye y vuelve a construir la interfaz (botón "Recargar panel").
function AdminUI.Reload()
    local gui = mounted
    if gui == nil then
        return
    end
    for _, child in gui:GetChildren() do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    local open = build(gui)
    setOpen = open
    open(true)
    setStatus("Panel recargado.", COLORS.ok)
end

function AdminUI.Mount(gui: ScreenGui)
    mounted = gui
    setOpen = build(gui)

    UserInputService.InputBegan:Connect(function(inputObject: InputObject, processed: boolean)
        if inputObject.KeyCode == TOGGLE_KEY and not processed and setOpen then
            setOpen(not window.Visible)
        end
    end)

    RunService.RenderStepped:Connect(function(delta: number)
        clientFps += (1 / math.max(delta, 1e-3) - clientFps) * 0.05
    end)

    Players.PlayerRemoving:Connect(function(leaving: Player)
        if leaving == target then
            if spectating then
                spectate(nil)
            end
            setTarget(nil)
        end
    end)

    -- Las páginas con datos en directo se actualizan solas mientras están a la vista.
    task.spawn(function()
        while gui.Parent do
            task.wait(REFRESH_SECONDS)
            local refresh = refreshers[currentPage]
            if window.Visible and refresh and not confirmOverlay.Visible then
                refresh()
            end
        end
    end)
end

return AdminUI
