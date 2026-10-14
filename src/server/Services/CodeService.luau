--!strict

-- Códigos canjeables: cada jugador puede canjear cada código de Config/Codes una sola vez.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local IndexService = require(script.Parent.IndexService)
local LiveOpsService = require(script.Parent.LiveOpsService)

local Shared = ReplicatedStorage.Shared
local CodesConfig = require(Shared.Config.Codes)
local Minerals = require(Shared.Config.Minerals)
local Network = require(Shared.Config.Network)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)

local CodeService = {}

local limiter = RateLimiter.new(Network.RateLimits.RedeemCode)

local function onRedeemCode(player: Player, text: unknown)
    if not limiter.Check(player) then
        return
    end
    if type(text) ~= "string" or #text > CodesConfig.MaxLength then
        return
    end
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    if not LiveOpsService.IsEnabled("codes") then
        Remotes.Notify:FireClient(player, Locale.Msg("LiveOps.Disabled"))
        return
    end

    -- Sin espacios alrededor y en mayúsculas, que es como están en la lista.
    local key = string.upper((string.gsub(text, "^%s*(.-)%s*$", "%1")))
    local code = CodesConfig.List[key]
    if code == nil then
        Remotes.Notify:FireClient(player, Locale.Msg("Codes.Invalid"))
        return
    end
    local expiresAt = code.expiresAt
    if expiresAt and os.time() >= expiresAt then
        Remotes.Notify:FireClient(player, Locale.Msg("Codes.Expired"))
        return
    end
    if data.codes[key] then
        Remotes.Notify:FireClient(player, Locale.Msg("Codes.Used"))
        return
    end

    DataService.Update(player, "codes", function(codes: { [string]: boolean })
        codes[key] = true
        return codes
    end)

    local rewards: { Locale.Message } = {}
    local coins = code.coins
    if coins and coins > 0 then
        IncomeService.AddCoins(player, coins, "codes")
        table.insert(rewards, Locale.Msg("Daily.Coins", Locale.Num(coins)))
    end
    local mineralId = code.mineral
    if mineralId and Minerals.ById[mineralId] then
        local item: Types.InventoryItem = {
            id = HttpService:GenerateGUID(false),
            mineral = mineralId,
            mutation = "none",
        }
        DataService.Update(player, "inventory", function(inventory: { Types.InventoryItem })
            table.insert(inventory, item)
            return inventory
        end)
        IndexService.Register(player, mineralId, "none")
        table.insert(rewards, Locale.Mineral(mineralId, "none"))
    end

    Remotes.Notify:FireClient(player, Locale.Msg("Codes.Redeemed", Locale.Join(" + ", rewards)))
end

function CodeService.Init()
    Remotes.RedeemCode.OnServerEvent:Connect(onRedeemCode)
end

return CodeService
