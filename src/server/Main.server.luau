--!strict

local Services = script.Parent:WaitForChild("Services")

type Service = {
    Init: (() -> ())?,
    Start: (() -> ())?,
}

local SERVICE_ORDER: { string } = {
    "MapService",
    "PlotService",
    "NpcService",
    "DataService",
    "LiveOpsService",
    "AmbientService",
    "LeaderboardService",
    "TutorialService",
    "CarryService",
    "EquipmentService",
    "EconomyService",
    "IncomeService",
    "MomentService",
    "AchievementService",
    "CrateService",
    "SeasonService",
    "SocialService",
    "CompetitionService",
    "QuestService",
    "IndexService",
    "CodeService",
    "PedestalService",
    "InventoryService",
    "MeteorService",
    "EventService",
    "MiningService",
    "UpgradeService",
    "StealService",
    "DailyService",
    "RebirthService",
    "PermanentService",
    "ShopService",
    "TradeService",
    "DecorService",
    "VisitService",
    "BaseSocialService",
    "AdminService",
    "DebugService",
}

local services: { Service } = {}

for _, name in SERVICE_ORDER do
    local module = Services:WaitForChild(name)
    table.insert(services, require(module) :: Service)
end

for _, service in services do
    if service.Init then
        service.Init()
    end
end

for _, service in services do
    if service.Start then
        service.Start()
    end
end
