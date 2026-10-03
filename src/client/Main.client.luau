--!strict

local Controllers = script.Parent:WaitForChild("Controllers")

type Controller = {
    Init: (() -> ())?,
    Start: (() -> ())?,
}

local CONTROLLER_ORDER: { string } = {
    "DataController",
    "NotificationController",
    "CarryController",
    "MeteorController",
    "DisplayController",
    "InputController",
    "UIController",
}

local controllers: { Controller } = {}

for _, name in CONTROLLER_ORDER do
    local module = Controllers:WaitForChild(name)
    table.insert(controllers, require(module) :: Controller)
end

for _, controller in controllers do
    if controller.Init then
        controller.Init()
    end
end

for _, controller in controllers do
    if controller.Start then
        controller.Start()
    end
end
