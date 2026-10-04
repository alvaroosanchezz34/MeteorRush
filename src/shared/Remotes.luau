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
    MutationFound = getOrCreateRemoteEvent("MutationFound"),
    LegendaryMoment = getOrCreateRemoteEvent("LegendaryMoment"),
    CarryUpdate = getOrCreateRemoteEvent("CarryUpdate"),
    HitPlayer = getOrCreateRemoteEvent("HitPlayer"),
    StealHit = getOrCreateRemoteEvent("StealHit"),
    PlaceMineral = getOrCreateRemoteEvent("PlaceMineral"),
    RemoveMineral = getOrCreateRemoteEvent("RemoveMineral"),
    PlaceBest = getOrCreateRemoteEvent("PlaceBest"),
    SellMineral = getOrCreateRemoteEvent("SellMineral"),
    SellJunk = getOrCreateRemoteEvent("SellJunk"),
    FuseMineral = getOrCreateRemoteEvent("FuseMineral"),
    BuyUpgrade = getOrCreateRemoteEvent("BuyUpgrade"),
    Rebirth = getOrCreateRemoteEvent("Rebirth"),
    BuyPermanent = getOrCreateRemoteEvent("BuyPermanent"),
    ClaimDaily = getOrCreateRemoteEvent("ClaimDaily"),
    ClaimQuest = getOrCreateRemoteEvent("ClaimQuest"),
    RedeemCode = getOrCreateRemoteEvent("RedeemCode"),
    TradeRequest = getOrCreateRemoteEvent("TradeRequest"),
    TradeRespond = getOrCreateRemoteEvent("TradeRespond"),
    TradeUpdateOffer = getOrCreateRemoteEvent("TradeUpdateOffer"),
    TradeConfirm = getOrCreateRemoteEvent("TradeConfirm"),
    TradeCancel = getOrCreateRemoteEvent("TradeCancel"),
    TradeState = getOrCreateRemoteEvent("TradeState"),
    EquipCosmetic = getOrCreateRemoteEvent("EquipCosmetic"),
    EquipTitle = getOrCreateRemoteEvent("EquipTitle"),
    SetDecoration = getOrCreateRemoteEvent("SetDecoration"),
    SetBaseEffect = getOrCreateRemoteEvent("SetBaseEffect"),
    VisitBase = getOrCreateRemoteEvent("VisitBase"),
    LikeBase = getOrCreateRemoteEvent("LikeBase"),
    -- Equipamiento y cajas.
    EquipGear = getOrCreateRemoteEvent("EquipGear"),
    BuyCrate = getOrCreateRemoteEvent("BuyCrate"),
    OpenCrate = getOrCreateRemoteEvent("OpenCrate"),
    CrateResult = getOrCreateRemoteEvent("CrateResult"),
    UseAbility = getOrCreateRemoteEvent("UseAbility"),
    AbilityFx = getOrCreateRemoteEvent("AbilityFx"),
    MineBonus = getOrCreateRemoteEvent("MineBonus"),
    StealMoment = getOrCreateRemoteEvent("StealMoment"),
    -- Panel de administración: el servidor solo atiende a los administradores.
    AdminRequest = getOrCreateRemoteEvent("AdminRequest"),
    AdminResponse = getOrCreateRemoteEvent("AdminResponse"),
    Announcement = getOrCreateRemoteEvent("Announcement"),
    AckVersion = getOrCreateRemoteEvent("AckVersion"),
    IndexDiscovered = getOrCreateRemoteEvent("IndexDiscovered"),
    AchievementUnlocked = getOrCreateRemoteEvent("AchievementUnlocked"),
    Notify = getOrCreateRemoteEvent("Notify"),
    EconomyStats = getOrCreateRemoteEvent("EconomyStats"),
}

return Remotes
