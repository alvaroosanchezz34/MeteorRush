--!strict

-- Marcador de la lista de jugadores de Roblox (`leaderstats`): monedas y rebirths.

local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local function update(player: Player)
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

function LeaderboardService.Init()
    DataService.OnProfileLoaded(update)
    DataService.OnFieldChanged("coins", update)
    DataService.OnFieldChanged("rebirths", update)
end

function LeaderboardService.Start()
    -- Por si algún perfil se cargó antes de registrar las funciones.
    for _, player in Players:GetPlayers() do
        update(player)
    end
end

return LeaderboardService
