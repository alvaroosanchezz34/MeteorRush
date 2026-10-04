--!strict

-- Clasificaciones: el marcador de la lista de jugadores de Roblox (`leaderstats`, monedas y
-- rebirths) y los tableros del mapa con los mejores de todos los servidores, por monedas
-- ganadas en total (OrderedDataStore).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local LeaderboardConfig = require(Shared.Config.Leaderboard)
local MapConfig = require(Shared.Config.Map)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)

-- Los OrderedDataStore solo guardan enteros de 64 bits.
local MAX_SCORE = 9e18

local LeaderboardService = {}

local store: OrderedDataStore? = nil
-- Etiquetas de las filas de cada tablero.
local boards: { { TextLabel } } = {}
local nameCache: { [number]: string } = {}

-- Marcador de la lista de jugadores ---------------------------------------------

local function updateLeaderstats(player: Player)
    local data = DataService.GetData(player)
    if data == nil then
        return
    end

    local stats = player:FindFirstChild("leaderstats")
    if stats == nil then
        local folder = Instance.new("Folder")
        folder.Name = "leaderstats"
        local rebirths = Instance.new("IntValue")
        rebirths.Name = "Rebirths"
        rebirths.Parent = folder
        local coins = Instance.new("NumberValue")
        coins.Name = "Coins"
        coins.Parent = folder
        folder.Parent = player
        stats = folder
    end

    local rebirths = stats:FindFirstChild("Rebirths")
    local coins = stats:FindFirstChild("Coins")
    if rebirths and rebirths:IsA("IntValue") then
        rebirths.Value = data.rebirths
    end
    if coins and coins:IsA("NumberValue") then
        coins.Value = math.floor(data.coins)
    end
end

-- Clasificación global ------------------------------------------------------------

local function buildBoard(gap: number): { TextLabel }
    local sector = math.pi * 2 / MapConfig.PlotCount
    local angle = (gap - 1) * sector + sector / 2
    local radius = LeaderboardConfig.BoardRadius
    local size = LeaderboardConfig.BoardSize
    local ground = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
    -- lookAt deja -Z (la cara frontal) mirando al centro del mapa.
    local cframe = CFrame.lookAt(ground, Vector3.zero)
        * CFrame.new(0, LeaderboardConfig.BoardHeight + size.Y / 2, 0)

    local model = Instance.new("Model")
    model.Name = "Leaderboard"

    local board = Instance.new("Part")
    board.Name = "Board"
    board.Anchored = true
    board.Size = size
    board.CFrame = cframe
    board.Color = MapConfig.SignColor
    board.Material = Enum.Material.SmoothPlastic
    board.Parent = model

    local function addPart(
        name: string,
        partSize: Vector3,
        offset: CFrame,
        color: Color3,
        neon: boolean
    )
        local part = Instance.new("Part")
        part.Name = name
        part.Anchored = true
        part.Size = partSize
        part.CFrame = cframe * offset
        part.Color = color
        part.Material = if neon then Enum.Material.Neon else Enum.Material.Metal
        part.CanCollide = not neon
        part.Parent = model
    end
    local postHeight = LeaderboardConfig.BoardHeight + size.Y
    for _, side in { -1, 1 } do
        addPart(
            "Post",
            Vector3.new(1, postHeight, 1),
            CFrame.new(side * (size.X / 2 + 0.5), size.Y / 2 - postHeight / 2, 0),
            MapConfig.PlotTrimColor,
            false
        )
    end
    addPart(
        "Trim",
        Vector3.new(size.X + 2, 0.5, size.Z + 0.4),
        CFrame.new(0, size.Y / 2 + 0.25, 0),
        LeaderboardConfig.TitleColor,
        true
    )

    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 30
    gui.LightInfluence = 0
    gui.Parent = board

    local function addLabel(text: string, y: number, height: number, color: Color3): TextLabel
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(0.92, height)
        label.Position = UDim2.fromScale(0.04, y)
        label.BackgroundTransparency = 1
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.TextColor3 = color
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = text
        label.Parent = gui
        return label
    end

    local title = addLabel(Strings.Leaderboard.Title, 0.02, 0.14, LeaderboardConfig.TitleColor)
    title.TextXAlignment = Enum.TextXAlignment.Center

    local rows: { TextLabel } = {}
    local rowHeight = 0.8 / LeaderboardConfig.Size
    for index = 1, LeaderboardConfig.Size do
        rows[index] =
            addLabel("", 0.18 + (index - 1) * rowHeight, rowHeight * 0.85, Color3.new(1, 1, 1))
    end
    rows[1].Text = Strings.Leaderboard.Empty

    model.Parent = MapService.GetMapFolder()
    return rows
end

local function getName(userId: number): string
    local cached = nameCache[userId]
    if cached then
        return cached
    end
    local ok, name = pcall(function(): string
        return Players:GetNameFromUserIdAsync(userId)
    end)
    local result = if ok then name else `#{userId}`
    nameCache[userId] = result
    return result
end

local function refreshBoards()
    local current = store
    if current == nil then
        return
    end
    local ok, page = pcall(function(): { any }
        return current:GetSortedAsync(false, LeaderboardConfig.Size):GetCurrentPage()
    end)
    if not ok then
        warn(`[LeaderboardService] No se pudo leer la clasificación: {page}`)
        return
    end

    local lines: { string } = {}
    for rank, entry in page do
        local userId = tonumber(entry.key)
        if userId then
            table.insert(
                lines,
                string.format(
                    Strings.Leaderboard.Row,
                    rank,
                    getName(userId),
                    Format.Number(entry.value)
                )
            )
        end
    end
    if #lines == 0 then
        lines[1] = Strings.Leaderboard.Empty
    end
    for _, rows in boards do
        for index, label in rows do
            label.Text = lines[index] or ""
        end
    end
end

local function saveScore(player: Player, data: Types.Profile)
    local current = store
    if current == nil then
        return
    end
    local score = math.clamp(math.floor(data.totalCoinsEarned), 0, MAX_SCORE)
    if score <= 0 then
        return
    end
    local ok, err = pcall(function()
        current:SetAsync(tostring(player.UserId), score)
    end)
    if not ok then
        warn(`[LeaderboardService] No se pudo guardar la puntuación de {player.Name}: {err}`)
    end
end

function LeaderboardService.Init()
    DataService.OnProfileLoaded(function(player: Player, data: Types.Profile)
        updateLeaderstats(player)
        -- Al entrar se guarda la puntuación y se refrescan los tableros, para que el jugador
        -- se vea en la clasificación sin esperar al siguiente guardado periódico.
        saveScore(player, data)
        refreshBoards()
    end)
    DataService.OnFieldChanged("coins", updateLeaderstats)
    DataService.OnFieldChanged("rebirths", updateLeaderstats)
    -- Al salir se guarda la puntuación sin retrasar el cierre del perfil.
    DataService.OnProfileReleasing(function(player: Player, data: Types.Profile)
        task.spawn(saveScore, player, data)
    end)

    for _, gap in LeaderboardConfig.BoardGaps do
        table.insert(boards, buildBoard(gap))
    end

    local ok, result = pcall(function(): OrderedDataStore
        return DataStoreService:GetOrderedDataStore(LeaderboardConfig.StoreName)
    end)
    if ok then
        store = result
    else
        warn(`[LeaderboardService] Clasificación global no disponible: {result}`)
    end
end

function LeaderboardService.Start()
    -- Por si algún perfil se cargó antes de registrar las funciones.
    for _, player in Players:GetPlayers() do
        updateLeaderstats(player)
    end

    task.spawn(function()
        task.wait(5)
        while true do
            refreshBoards()
            task.wait(LeaderboardConfig.RefreshSeconds)
        end
    end)
    task.spawn(function()
        while true do
            task.wait(LeaderboardConfig.SaveSeconds)
            for _, player in Players:GetPlayers() do
                local data = DataService.GetData(player)
                if data then
                    saveScore(player, data)
                end
            end
        end
    end)
end

return LeaderboardService
