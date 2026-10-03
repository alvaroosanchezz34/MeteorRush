--!strict

-- Localiza la base del jugador local para la interfaz (flecha de vuelta, aviso de zona
-- segura) y la resalta: su baliza y sus luces se ven de otro color solo para su dueño.
-- Es solo informativo: la zona segura y el depósito los decide siempre el servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("Config"):WaitForChild("Map"))

-- Segundos entre comprobaciones de cuál es la parcela del jugador.
local CHECK_INTERVAL = 1
-- Partes de la decoración que cambian de color en la base propia.
local HIGHLIGHT_NAMES = { Beacon = true, PillarLight = true }

local BaseController = {}

local plotModel: Model? = nil
-- Centro de la parcela a la altura del suelo, con la misma orientación que en el servidor.
local plotCFrame: CFrame? = nil

local function isMine(model: Instance): boolean
    return model:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
end

local function highlight(model: Model)
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") and HIGHLIGHT_NAMES[descendant.Name] then
            descendant.Color = MapConfig.OwnBaseColor
            local light = descendant:FindFirstChildOfClass("PointLight")
            if light then
                light.Color = MapConfig.OwnBaseColor
            end
        end
    end
end

local function findPlot()
    local current = plotModel
    if current and current.Parent and isMine(current) then
        return
    end
    plotModel = nil
    plotCFrame = nil

    local map = Workspace:FindFirstChild("Map")
    local plots = if map then map:FindFirstChild("Plots") else nil
    if plots == nil then
        return
    end
    for _, child in plots:GetChildren() do
        if child:IsA("Model") and isMine(child) then
            local floor = child.PrimaryPart
            if floor then
                plotModel = child
                plotCFrame = floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)
                highlight(child)
            end
            return
        end
    end
end

-- Posición del centro de la base del jugador, o nil si aún no tiene.
function BaseController.GetPosition(): Vector3?
    local cframe = plotCFrame
    return if cframe then cframe.Position else nil
end

-- Indica si esa posición está dentro de la base del jugador (misma cuenta que el servidor).
function BaseController.IsInside(position: Vector3): boolean
    local cframe = plotCFrame
    if cframe == nil then
        return false
    end
    local half = MapConfig.PlotSize / 2
    local localPosition = cframe:PointToObjectSpace(position)
    return math.abs(localPosition.X) <= half
        and math.abs(localPosition.Z) <= half
        and localPosition.Y >= -MapConfig.PlotFloorThickness
        and localPosition.Y <= MapConfig.PlotSafeHeight
end

function BaseController.Start()
    task.spawn(function()
        while true do
            findPlot()
            task.wait(CHECK_INTERVAL)
        end
    end)
end

return BaseController
