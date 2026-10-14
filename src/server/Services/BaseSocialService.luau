--!strict

-- Parte social de las bases: visitas, likes y clasificaciones. Es solo social y
-- competitivo: ni las visitas ni los likes dan monedas ni ninguna otra ventaja.
--   * Visita: cuenta cuando un jugador entra en la base de otro, como mucho una vez cada
--     cierto tiempo por pareja de jugadores.
--   * Like: un jugador puede dar un solo like a cada base, para siempre. Quién ha dado like a
--     quién se guarda en el perfil de quien lo da; el total, en el del dueño. El dueño
--     siempre está conectado en ese momento, así que los dos perfiles se cambian a la vez.
--   * Clasificaciones globales de visitas y likes (OrderedDataStore), publicadas en atributos
--     de Workspace como texto JSON.
-- También publica en atributos de cada jugador lo que muestra la ventana de inspeccionar base.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AchievementService = require(script.Parent.AchievementService)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local PlotService = require(script.Parent.PlotService)

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Util.Log)
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local SocialConfig = require(Shared.Config.Social)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)

-- Valor máximo que admite un OrderedDataStore con margen de sobra.
local MAX_SCORE = 2 ^ 50
-- Campos del perfil de los que sale lo que se ve al inspeccionar una base.
local PUBLISHED_FIELDS = { "social", "inventory", "pedestals", "decor", "upgrades", "passes" }

local BaseSocialService = {}

local limiter = RateLimiter.new(Network.RateLimits.LikeBase)
-- lastVisit[visitante][dueño] = momento de la última visita contada.
local lastVisit: { [Player]: { [Player]: number } } = {}
local stores: { [string]: OrderedDataStore } = {}
-- Última puntuación guardada de cada jugador en cada clasificación (para no guardar si no cambia).
local savedScores: { [Player]: { [string]: number } } = {}
local nameCache: { [number]: string } = {}
local warned = false

local function warnOnce(message: string)
    if not warned then
        warned = true
        Log.Warn("BaseSocial", message)
    end
end

-- Publica en atributos del jugador los datos de su base que ven los demás.
local function publish(player: Player)
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    local best: Types.InventoryItem? = nil
    local bestIncome = -1
    for _, item in data.inventory do
        local income = PlayerStats.GetItemBaseIncome(item)
        if income > bestIncome then
            best = item
            bestIncome = income
        end
    end
    local used = 0
    for _ in data.pedestals do
        used += 1
    end
    local decorations = 0
    for _ in data.decor.slots do
        decorations += 1
    end

    player:SetAttribute("BaseVisits", data.social.visits)
    player:SetAttribute("BaseLikes", data.social.likes)
    player:SetAttribute("BestMineral", if best then `{best.mineral}:{best.mutation}` else nil)
    player:SetAttribute("PedestalsUsed", used)
    player:SetAttribute("PedestalCount", PlayerStats.GetPedestalCount(data))
    player:SetAttribute("DecorCount", decorations)
    player:SetAttribute("BaseEffect", data.decor.effect)
end

local function onLikeBase(player: Player, target: unknown)
    if not limiter.Check(player) then
        return
    end
    if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Player") then
        Log.Suspicious(player, "LikeBase", "tipo inválido")
        return
    end
    local owner = target :: Player
    local data = DataService.GetData(player)
    local ownerData = DataService.GetData(owner)
    if owner == player or data == nil or ownerData == nil or PlotService.GetPlot(owner) == nil then
        return
    end
    -- Las cuentas recién creadas no pueden dar likes: frena las cuentas hechas para inflarlos.
    if DataService.GetPlaytime(player) < SocialConfig.LikeMinPlaytime then
        Remotes.Notify:FireClient(player, Locale.Msg("Inspect.LikeTooNew"))
        return
    end
    local key = tostring(owner.UserId)
    if data.social.liked[key] then
        Remotes.Notify:FireClient(player, Locale.Msg("Inspect.AlreadyLiked"))
        return
    end
    local count = 0
    for _ in data.social.liked do
        count += 1
    end
    if count >= SocialConfig.MaxLikesGiven then
        return
    end

    -- Los dos cambios seguidos, sin ceder el hilo entre uno y otro.
    DataService.Update(player, "social", function(social: Types.SocialData)
        social.liked[key] = true
        return social
    end)
    DataService.Update(owner, "social", function(social: Types.SocialData)
        social.likes += 1
        return social
    end)
    Remotes.Notify:FireClient(player, Locale.Msg("Inspect.LikeGiven", owner.DisplayName))
    Remotes.Notify:FireClient(owner, Locale.Msg("Inspect.LikeReceived", player.DisplayName))
end

-- Cuenta una visita por cada jugador que está dentro de la base de otro, con su espera.
local function checkVisits()
    local now = os.clock()
    for _, player in Players:GetPlayers() do
        local character = player.Character
        local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
        local plot = if root and root:IsA("BasePart")
            then PlotService.GetPlotAt(root.Position)
            else nil
        local owner = if plot then PlotService.GetOwner(plot.index) else nil
        if owner and owner ~= player and DataService.GetData(owner) then
            local visits = lastVisit[player]
            if visits == nil then
                visits = {}
                lastVisit[player] = visits
            end
            if now - (visits[owner] or -math.huge) >= SocialConfig.VisitCountCooldown then
                visits[owner] = now
                DataService.Update(owner, "social", function(social: Types.SocialData)
                    social.visits += 1
                    return social
                end)
                AchievementService.AddStat(player, "basesVisited", 1)
            end
        end
    end
end

-- Clasificaciones ------------------------------------------------------------------------

local function getStore(kind: string): OrderedDataStore?
    local store = stores[kind]
    if store then
        return store
    end
    local ok, result = pcall(function(): OrderedDataStore
        return DataStoreService:GetOrderedDataStore(SocialConfig.RankingStores[kind])
    end)
    if not ok then
        warnOnce(`Clasificaciones de bases no disponibles: {result}`)
        return nil
    end
    stores[kind] = result
    return result
end

-- Guarda las puntuaciones de un jugador, solo las que han cambiado desde el último guardado.
local function saveScores(player: Player, data: Types.Profile)
    local saved = savedScores[player]
    if saved == nil then
        saved = {}
        savedScores[player] = saved
    end
    local scores = { visits = data.social.visits, likes = data.social.likes }
    for kind, value in scores do
        local score = math.clamp(math.floor(value), 0, MAX_SCORE)
        local store = getStore(kind)
        if store and score > 0 and saved[kind] ~= score then
            local ok, err = pcall(function()
                store:SetAsync(tostring(player.UserId), score)
            end)
            if ok then
                saved[kind] = score
            else
                warnOnce(`No se pudo guardar la clasificación de bases: {err}`)
            end
        end
    end
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

-- Lee los primeros puestos de cada clasificación y los publica como JSON en Workspace.
local function refreshRankings()
    for kind in SocialConfig.RankingStores do
        local store = getStore(kind)
        if store then
            local ok, page = pcall(function(): { any }
                return store:GetSortedAsync(false, SocialConfig.RankingSize):GetCurrentPage()
            end)
            if ok then
                local entries: { { name: string, value: number } } = {}
                for _, entry in page do
                    local userId = tonumber(entry.key)
                    if userId then
                        table.insert(entries, { name = getName(userId), value = entry.value })
                    end
                end
                Workspace:SetAttribute(`BaseRanking_{kind}`, HttpService:JSONEncode(entries))
            else
                warnOnce(`No se pudo leer la clasificación de bases: {page}`)
            end
        end
    end
end

function BaseSocialService.Init()
    Remotes.LikeBase.OnServerEvent:Connect(onLikeBase)
    DataService.OnProfileLoaded(publish)
    for _, field in PUBLISHED_FIELDS do
        DataService.OnFieldChanged(field, publish)
    end
    -- Al salir se guardan sus puntuaciones si han cambiado.
    DataService.OnProfileReleasing(function(player: Player, data: Types.Profile)
        task.spawn(saveScores, player, data)
    end)

    -- Opción de inspeccionar la base, en el cartel de cada parcela. La abre el cliente.
    for _, plot in MapService.GetPlots() do
        local sign = plot.model:FindFirstChild("Sign")
        local part = if sign and sign:IsA("Model")
            then sign.PrimaryPart or sign:FindFirstChildWhichIsA("BasePart", true)
            else sign
        if part and part:IsA("BasePart") then
            local prompt = Instance.new("ProximityPrompt")
            prompt.Name = "InspectBase"
            Locale.Tag(prompt, "ActionText", Locale.Msg("Inspect.Prompt"))
            Locale.Tag(prompt, "ObjectText", Locale.Msg("Inspect.PromptObject"))
            prompt.MaxActivationDistance = SocialConfig.InspectDistance
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
            -- En mando, X ya es golpear.
            prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
            prompt.Parent = part
        end
    end
end

function BaseSocialService.Start()
    Players.PlayerRemoving:Connect(function(player: Player)
        lastVisit[player] = nil
        savedScores[player] = nil
        for _, visits in lastVisit do
            visits[player] = nil
        end
    end)

    task.spawn(function()
        while true do
            task.wait(SocialConfig.VisitCheckSeconds)
            checkVisits()
        end
    end)
    task.spawn(function()
        while true do
            refreshRankings()
            task.wait(SocialConfig.RankingRefreshSeconds)
        end
    end)
    task.spawn(function()
        while true do
            task.wait(SocialConfig.RankingSaveSeconds)
            for _, player in Players:GetPlayers() do
                local data = DataService.GetData(player)
                if data then
                    saveScores(player, data)
                end
            end
        end
    end)
end

return BaseSocialService
