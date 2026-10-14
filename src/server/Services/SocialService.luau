--!strict

-- Bonus por jugar con amigos: cada amigo de Roblox en el mismo servidor sube los ingresos.
-- El número de amigos conectados se guarda en el campo `friendsOnline` del perfil para que
-- PlayerStats y el cliente calculen lo mismo; se pone a 0 al cerrar el perfil, así que nunca
-- cuenta para los ingresos sin conexión.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Util.Log)
local PlayerStats = require(Shared.Util.PlayerStats)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)

local SocialService = {}

-- friends[a][b] = true si a y b son amigos y están los dos en el servidor.
local friends: { [Player]: { [Player]: boolean } } = {}
-- Número de amigos fijado a mano desde DebugService (solo en Studio).
local debugCounts: { [Player]: number } = {}

local function refresh(player: Player)
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    local count = debugCounts[player]
    if count == nil then
        count = 0
        for _ in friends[player] or {} do
            count += 1
        end
    end
    if data.friendsOnline == count then
        return
    end
    local before = PlayerStats.GetFriendBonus(data)
    DataService.Set(player, "friendsOnline", count)
    local after = PlayerStats.GetFriendBonus(data)
    if after > before then
        Remotes.Notify:FireClient(player, Locale.Msg("Social.Bonus", math.round(after * 100)))
    end
end

local function checkPair(a: Player, b: Player)
    local ok, result = pcall(function(): boolean
        return a:IsFriendsWith(b.UserId)
    end)
    if not ok then
        Log.Warn("Social", `No se pudo comprobar la amistad de {a.Name} y {b.Name}: {result}`)
        return
    end
    -- La consulta tarda: puede que alguno ya se haya ido.
    if result ~= true or a.Parent ~= Players or b.Parent ~= Players then
        return
    end
    friends[a] = friends[a] or {}
    friends[b] = friends[b] or {}
    friends[a][b] = true
    friends[b][a] = true
    refresh(a)
    refresh(b)
end

local function onPlayerAdded(player: Player)
    for _, other in Players:GetPlayers() do
        if other ~= player then
            task.spawn(checkPair, player, other)
        end
    end
end

local function onPlayerRemoving(player: Player)
    debugCounts[player] = nil
    local list = friends[player]
    friends[player] = nil
    if list == nil then
        return
    end
    for other in list do
        local otherList = friends[other]
        if otherList then
            otherList[player] = nil
            refresh(other)
        end
    end
end

-- Solo para pruebas: fija el número de amigos conectados de un jugador (nil lo deja en el real).
function SocialService.DebugSetFriends(player: Player, count: number?)
    debugCounts[player] = count
    refresh(player)
end

function SocialService.Init()
    DataService.OnProfileLoaded(refresh)
    DataService.OnProfileReleasing(function(_: Player, data: Types.Profile)
        data.friendsOnline = 0
    end)
end

function SocialService.Start()
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)
    for _, player in Players:GetPlayers() do
        onPlayerAdded(player)
    end
end

return SocialService
