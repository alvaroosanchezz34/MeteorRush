--!strict

-- Localiza la base del jugador local para la interfaz (flecha de vuelta, aviso de zona
-- segura) y la resalta: su baliza y sus luces se ven de otro color solo para su dueño.
-- Es solo informativo: la zona segura y el depósito los decide siempre el servidor.
-- Además da "presencia" a las bases de los demás: la baliza de cada una toma el color de lo
-- más raro que expone en sus pedestales (atributo `Prestige`, que pone el servidor), así que
-- desde lejos se ve qué base tiene algo extraordinario sin añadir una sola partícula.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("Config"):WaitForChild("Map"))
local Minerals = require(Shared:WaitForChild("Config"):WaitForChild("Minerals"))
local Mutations = require(Shared:WaitForChild("Config"):WaitForChild("Mutations"))

-- Segundos entre comprobaciones de cuál es la parcela del jugador.
local CHECK_INTERVAL = 1
-- Partes de la decoración que cambian de color en la base propia.
local HIGHLIGHT_NAMES = { Beacon = true, PillarLight = true, EdgeGlow = true }

-- Rango desde el que una base tiene presencia (4 = Épico) y transparencia de su baliza
-- normal y con el mineral más raro del juego.
local PRESTIGE_RANK = 4
local BEACON_TRANSPARENCY = 0.55
local BEACON_TOP_TRANSPARENCY = 0.25

local BaseController = {}

-- Última presencia aplicada a cada parcela, para no repintarla si no cambia.
local appliedPrestige: { [Instance]: string } = {}

-- Tiñe la baliza de una base ajena con el color de lo más raro que expone.
local function applyPrestige(model: Model)
    local rank = model:GetAttribute("Prestige")
    local mutationId = model:GetAttribute("PrestigeMutation")
    local key = `{rank}:{mutationId}`
    if appliedPrestige[model] == key then
        return
    end
    appliedPrestige[model] = key

    local color = MapConfig.PlotAccentColor
    local transparency = BEACON_TRANSPARENCY
    if type(rank) == "number" and rank >= PRESTIGE_RANK then
        local mutation = if type(mutationId) == "string" then Mutations.ById[mutationId] else nil
        for _, rarity in Minerals.Rarities do
            if rarity.rank == rank then
                color = rarity.color
            end
        end
        color = (if mutation then mutation.color else nil) or color
        local top = Minerals.GetRank(Minerals.List[#Minerals.List].id)
        transparency = BEACON_TRANSPARENCY
            + (BEACON_TOP_TRANSPARENCY - BEACON_TRANSPARENCY)
                * (rank - PRESTIGE_RANK + 1)
                / (top - PRESTIGE_RANK + 1)
    end
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") and descendant.Name == "Beacon" then
            descendant.Color = color
            descendant.Transparency = transparency
        end
    end
end

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

-- Presencia de las bases de los demás (la propia se queda en verde para encontrarla).
local function updatePrestige(plots: Instance)
    for _, child in plots:GetChildren() do
        if child:IsA("Model") and not isMine(child) then
            applyPrestige(child)
        end
    end
end

local function findPlot()
    local current = plotModel
    if current and current.Parent and isMine(current) then
        local map = Workspace:FindFirstChild("Map")
        local plots = if map then map:FindFirstChild("Plots") else nil
        if plots then
            updatePrestige(plots)
        end
        return
    end
    plotModel = nil
    plotCFrame = nil

    local map = Workspace:FindFirstChild("Map")
    local plots = if map then map:FindFirstChild("Plots") else nil
    if plots == nil then
        return
    end
    updatePrestige(plots)
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
