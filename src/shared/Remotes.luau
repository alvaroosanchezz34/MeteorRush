--!strict

local RunService = game:GetService("RunService")

local function getOrCreateRemoteEvent(name: string): RemoteEvent
    if RunService:IsServer() then
        local existing = script:FindFirstChild(name)
        if existing then
            return existing :: RemoteEvent
        end
        local instance = Instance.new("RemoteEvent")
        instance.Name = name
        instance.Parent = script
        return instance
    end
    return script:WaitForChild(name) :: RemoteEvent
end

local Remotes = {
    DataUpdate = getOrCreateRemoteEvent("DataUpdate"),
    DataRequest = getOrCreateRemoteEvent("DataRequest"),
    MeteorIncoming = getOrCreateRemoteEvent("MeteorIncoming"),
    MineStart = getOrCreateRemoteEvent("MineStart"),
    MineStop = getOrCreateRemoteEvent("MineStop"),
    MineState = getOrCreateRemoteEvent("MineState"),
    MineReward = getOrCreateRemoteEvent("MineReward"),
    CarryUpdate = getOrCreateRemoteEvent("CarryUpdate"),
    HitPlayer = getOrCreateRemoteEvent("HitPlayer"),
    PlaceMineral = getOrCreateRemoteEvent("PlaceMineral"),
    RemoveMineral = getOrCreateRemoteEvent("RemoveMineral"),
    PlaceBest = getOrCreateRemoteEvent("PlaceBest"),
    SellMineral = getOrCreateRemoteEvent("SellMineral"),
    SellJunk = getOrCreateRemoteEvent("SellJunk"),
    FuseMineral = getOrCreateRemoteEvent("FuseMineral"),
    BuyUpgrade = getOrCreateRemoteEvent("BuyUpgrade"),
    Rebirth = getOrCreateRemoteEvent("Rebirth"),
    ClaimDaily = getOrCreateRemoteEvent("ClaimDaily"),
    TradeRequest = getOrCreateRemoteEvent("TradeRequest"),
    TradeRespond = getOrCreateRemoteEvent("TradeRespond"),
    TradeUpdateOffer = getOrCreateRemoteEvent("TradeUpdateOffer"),
    TradeConfirm = getOrCreateRemoteEvent("TradeConfirm"),
    TradeCancel = getOrCreateRemoteEvent("TradeCancel"),
    TradeState = getOrCreateRemoteEvent("TradeState"),
    EquipCosmetic = getOrCreateRemoteEvent("EquipCosmetic"),
    Notify = getOrCreateRemoteEvent("Notify"),
}

return Remotes
