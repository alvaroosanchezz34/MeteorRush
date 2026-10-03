--!strict

local Services = script.Parent:WaitForChild("Services")

type Service = {
    Init: (() -> ())?,
    Start: (() -> ())?,
}

local SERVICE_ORDER: { string } = {
    "MapService",
    "PlotService",
    "DataService",
    "LeaderboardService",
    "TutorialService",
    "CarryService",
    "IncomeService",
    "QuestService",
    "IndexService",
    "CodeService",
    "PedestalService",
    "InventoryService",
    "MeteorService",
    "MiningService",
    "UpgradeService",
    "StealService",
    "DailyService",
    "RebirthService",
    "ShopService",
    "TradeService",
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
