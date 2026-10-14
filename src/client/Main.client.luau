--!strict

local Controllers = script.Parent:WaitForChild("Controllers")

type Controller = {
    Init: (() -> ())?,
    Start: (() -> ())?,
}

local CONTROLLER_ORDER: { string } = {
    -- Primero el idioma, para que todo lo que se pinte después salga ya traducido.
    "LanguageController",
    "DataController",
    "NotificationController",
    "CarryController",
    "BaseController",
    "MutationFxController",
    "RarityVisualController",
    "MeteorController",
    "AmbienceController",
    "SkyController",
    "AmbientController",
    "NpcController",
    "DisplayController",
    "SwingController",
    "StealController",
    "EquipmentController",
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
