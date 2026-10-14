--!strict

-- Logros, estadísticas de por vida y títulos. Los demás servicios suman estadísticas con
-- AddStat; cuando una llega al objetivo de un logro, se desbloquea solo y da su recompensa
-- una única vez. Los títulos se equipan desde el perfil y se ven sobre la cabeza y en el
-- cartel de la base (atributo `Title` del jugador). Los especiales (Config/Titles) los da el
-- servidor: owner, admin y vip al entrar; staff y legend, un administrador desde el panel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local Shared = ReplicatedStorage.Shared
local AchievementsConfig = require(Shared.Config.Achievements)
local AdminPermissions = require(script.Parent.Parent.Admin.AdminPermissions)
local TitlesConfig = require(Shared.Config.Titles)
local Log = require(Shared.Util.Log)
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)

local TITLE_TAG = "TitleTag"

-- Campos del perfil de los que salen estadísticas que no se cuentan con AddStat.
local DERIVED_FIELDS =
    { "rebirths", "totalCoinsEarned", "index", "indexRewards", "daily", "codes", "social", "decor" }

local AchievementService = {}

type StatCallback = (player: Player, stat: string, amount: number) -> ()

local limiter = RateLimiter.new(Network.RateLimits.EquipTitle)
local statCallbacks: { StatCallback } = {}

local function unlock(
    player: Player,
    data: Types.Profile,
    achievement: AchievementsConfig.Achievement
)
    -- Se marca antes de dar la recompensa: las monedas cambian estadísticas y vuelven a
    -- comprobar los logros.
    DataService.Update(player, "achievements", function(unlocked: { [string]: boolean })
        unlocked[achievement.id] = true
        return unlocked
    end)
    local reward = PlayerStats.GetAchievementReward(data, achievement)
    IncomeService.AddCoins(player, reward, "achievements")
    Remotes.AchievementUnlocked:FireClient(player, achievement.id, reward)
end

-- Desbloquea los logros cuyo objetivo ya se ha alcanzado. Con `stat`, solo los de esa estadística.
local function check(player: Player, stat: string?)
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    for _, achievement in AchievementsConfig.List do
        if
            (stat == nil or achievement.stat == stat)
            and not data.achievements[achievement.id]
            and PlayerStats.GetStat(data, achievement.stat) >= achievement.goal
        then
            unlock(player, data, achievement)
        end
    end
end

-- Pone el título equipado sobre la cabeza del personaje y en los atributos `TitleId` (id del
-- logro, para traducirlo en cada cliente) y `Title` (texto en inglés, el de siempre).
local function applyTitle(player: Player)
    local data = DataService.GetData(player)
    local titleId = if data and PlayerStats.OwnsTitle(data, data.title) then data.title else nil
    local text = if titleId then Strings.Titles[titleId] else nil
    -- TitleId antes que Title: quien escucha los cambios de Title ya encuentra el id nuevo.
    player:SetAttribute("TitleId", titleId)
    player:SetAttribute("Title", text)

    local character = player.Character
    local head = if character then character:FindFirstChild("Head") else nil
    if head == nil or not head:IsA("BasePart") then
        return
    end
    local existing = head:FindFirstChild(TITLE_TAG)
    if existing then
        existing:Destroy()
    end
    if text == nil then
        return
    end

    local style = TitlesConfig.GetStyle(titleId)
    local special = TitlesConfig.IsSpecial(titleId)
    local size = if special then TitlesConfig.SpecialBillboardSize else TitlesConfig.BillboardSize
    local billboard = Instance.new("BillboardGui")
    -- Los textos ya salen en el idioma elegido: sin traducción automática de Roblox.
    billboard.AutoLocalize = false
    billboard.Name = TITLE_TAG
    billboard.Size = UDim2.fromScale(size.X, size.Y)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
    billboard.MaxDistance = if special then 140 else 80
    billboard.LightInfluence = 0
    -- Cada cliente le pone sus efectos (degradado animado, brillos): TitleController.
    billboard:SetAttribute("TitleId", titleId)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    Locale.Tag(label, "Text", Locale.Ref(`Titles.{titleId}`))
    label.TextColor3 = style.color
    label.TextScaled = true
    label.TextStrokeTransparency = if special then 0 else 0.3
    label.Font = if special then Enum.Font.GothamBlack else Enum.Font.GothamBold
    label.Parent = billboard
    billboard.Parent = head
end

local function onEquipTitle(player: Player, titleId: unknown)
    if not limiter.Check(player) then
        return
    end
    if type(titleId) ~= "string" or #titleId > 32 then
        Log.Suspicious(player, "EquipTitle", "tipo inválido")
        return
    end
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    -- La cadena vacía quita el título.
    if titleId ~= "" and not PlayerStats.OwnsTitle(data, titleId) then
        return
    end
    DataService.Set(player, "title", titleId)
end

-- Pone los títulos especiales automáticos (owner, admin, vip) según quién es el jugador. Los
-- que da un administrador (staff, legend) no se tocan. A un dueño que entra sin título se le
-- equipa el suyo.
local function syncSpecialTitles(player: Player)
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    local wanted = {
        owner = AdminPermissions.IsOwner(player),
        admin = AdminPermissions.IsAdmin(player),
        vip = PlayerStats.HasPass(data, "vip"),
    }
    local changed = false
    for titleId, owns in wanted do
        if (data.specialTitles[titleId] == true) ~= owns then
            changed = true
        end
    end
    if changed then
        DataService.Update(player, "specialTitles", function(titles: { [string]: boolean })
            for titleId, owns in wanted do
                titles[titleId] = if owns then true else nil
            end
            return titles
        end)
    end
    if wanted.owner and data.title == "" then
        DataService.Set(player, "title", "owner")
    end
end

-- Da o quita un título especial de los que reparte un administrador (Titles.Grantable).
-- Devuelve false si ese título no se puede dar así.
function AchievementService.SetSpecialTitle(player: Player, titleId: string, owns: boolean): boolean
    if not TitlesConfig.Grantable[titleId] or DataService.GetData(player) == nil then
        return false
    end
    DataService.Update(player, "specialTitles", function(titles: { [string]: boolean })
        titles[titleId] = if owns then true else nil
        return titles
    end)
    return true
end

-- Suma a varias estadísticas de por vida a la vez (las cantidades a 0 se ignoran) y
-- comprueba los logros que dependen de ellas.
function AchievementService.AddStats(player: Player, amounts: { [string]: number })
    if DataService.GetData(player) == nil then
        return
    end
    DataService.Update(player, "stats", function(stats: { [string]: number })
        for stat, amount in amounts do
            if amount > 0 then
                stats[stat] = (stats[stat] or 0) + amount
            end
        end
        return stats
    end)
    for stat, amount in amounts do
        if amount > 0 then
            for _, callback in statCallbacks do
                callback(player, stat, amount)
            end
            check(player, stat)
        end
    end
end

-- Registra una función que se llama cada vez que sube una estadística. Debe registrarse en Init.
function AchievementService.OnStat(callback: StatCallback)
    table.insert(statCallbacks, callback)
end

-- Suma a una estadística de por vida y comprueba los logros que dependen de ella.
function AchievementService.AddStat(player: Player, stat: string, amount: number)
    AchievementService.AddStats(player, { [stat] = amount })
end

function AchievementService.Init()
    Remotes.EquipTitle.OnServerEvent:Connect(onEquipTitle)
    for _, field in DERIVED_FIELDS do
        DataService.OnFieldChanged(field, function(player: Player)
            check(player)
        end)
    end
    DataService.OnFieldChanged("title", applyTitle)
    -- Si pierde el título especial que llevaba puesto, se le quita del todo.
    DataService.OnFieldChanged("specialTitles", applyTitle)
    DataService.OnFieldChanged("passes", syncSpecialTitles)
    DataService.OnProfileLoaded(function(player: Player)
        check(player)
        syncSpecialTitles(player)
        applyTitle(player)
    end)
end

function AchievementService.Start()
    local function onPlayer(player: Player)
        player.CharacterAdded:Connect(function(character: Model)
            if character:WaitForChild("Head", 10) then
                applyTitle(player)
            end
        end)
    end
    Players.PlayerAdded:Connect(onPlayer)
    for _, player in Players:GetPlayers() do
        onPlayer(player)
    end

    -- El tiempo de juego se guarda sin avisar del cambio, así que se comprueba cada cierto tiempo.
    task.spawn(function()
        while true do
            task.wait(AchievementsConfig.PlaytimeCheckInterval)
            for _, player in Players:GetPlayers() do
                check(player, "playtime")
            end
        end
    end)
end

return AchievementService
