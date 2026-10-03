--!strict

-- Asigna una parcela a cada jugador al entrar, lo hace aparecer en ella y la libera al salir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapService = require(script.Parent.MapService)

local Shared = ReplicatedStorage.Shared
local MapConfig = require(Shared.Config.Map)
local Strings = require(Shared.Strings)

local PlotService = {}

local plots: { MapService.PlotLayout } = {}
local plotOwners: { [number]: Player } = {}
local playerPlots: { [Player]: number } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}

local function setSign(plot: MapService.PlotLayout, owner: Player?)
    local label = plot.signLabel
    if label then
        label.Text = if owner
            then string.format(Strings.Plot.OwnerSign, owner.DisplayName)
            else Strings.Plot.FreeSign
    end
end

local function setUnlockedPedestals(plot: MapService.PlotLayout, count: number)
    local unlocked = math.clamp(count, 0, #plot.pedestals)
    for number, pedestal in plot.pedestals do
        pedestal.Parent = if number <= unlocked then plot.pedestalFolder else nil
    end
end

local function spawnCFrame(plot: MapService.PlotLayout): CFrame
    -- Mirando hacia la entrada; la altura deja al personaje de pie sobre el suelo.
    local position = plot.spawnLocation.Position + Vector3.new(0, 3, 0)
    return CFrame.lookAt(position, position + plot.cframe.LookVector)
end

local function moveCharacterToPlot(player: Player, character: Model)
    local root = character:WaitForChild("HumanoidRootPart", 10)
    if root == nil then
        return
    end
    -- Se aplaza para no competir con la colocación inicial del personaje que hace el motor.
    task.defer(function()
        local index = playerPlots[player]
        if index == nil or character.Parent == nil then
            return
        end
        character:PivotTo(spawnCFrame(plots[index]))
    end)
end

local function assignPlot(player: Player)
    if playerPlots[player] then
        return
    end

    local plot: MapService.PlotLayout? = nil
    for _, candidate in plots do
        if not plotOwners[candidate.index] then
            plot = candidate
            break
        end
    end
    if plot == nil then
        warn(`[PlotService] No quedan parcelas libres para {player.Name}`)
        return
    end

    plotOwners[plot.index] = player
    playerPlots[player] = plot.index
    plot.model:SetAttribute("OwnerUserId", player.UserId)
    setSign(plot, player)
    setUnlockedPedestals(plot, MapConfig.InitialPedestals)

    player.RespawnLocation = plot.spawnLocation
    characterConnections[player] = player.CharacterAdded:Connect(function(character: Model)
        moveCharacterToPlot(player, character)
    end)
    if player.Character then
        task.spawn(moveCharacterToPlot, player, player.Character)
    end
end

local function releasePlot(player: Player)
    local connection = characterConnections[player]
    if connection then
        connection:Disconnect()
        characterConnections[player] = nil
    end

    local index = playerPlots[player]
    if index == nil then
        return
    end
    playerPlots[player] = nil
    plotOwners[index] = nil

    local plot = plots[index]
    plot.model:SetAttribute("OwnerUserId", nil)
    plot.floor.Color = MapConfig.PlotFloorColor
    plot.collectLabel.Text = ""
    setSign(plot, nil)
    setUnlockedPedestals(plot, MapConfig.InitialPedestals)
end

-- Devuelve la parcela del jugador, o nil si no tiene.
function PlotService.GetPlot(player: Player): MapService.PlotLayout?
    local index = playerPlots[player]
    return if index then plots[index] else nil
end

-- Devuelve el dueño de la parcela con ese índice, o nil si está libre.
function PlotService.GetOwner(plotIndex: number): Player?
    return plotOwners[plotIndex]
end

-- Devuelve la parcela que contiene esa posición, o nil si está fuera de todas.
function PlotService.GetPlotAt(position: Vector3): MapService.PlotLayout?
    local half = MapConfig.PlotSize / 2
    for _, plot in plots do
        local localPosition = plot.cframe:PointToObjectSpace(position)
        if
            math.abs(localPosition.X) <= half
            and math.abs(localPosition.Z) <= half
            and localPosition.Y >= -MapConfig.PlotFloorThickness
            and localPosition.Y <= MapConfig.PlotSafeHeight
        then
            return plot
        end
    end
    return nil
end

-- Indica si la posición está dentro de la parcela del propio jugador (zona segura).
function PlotService.IsInOwnPlot(player: Player, position: Vector3): boolean
    local plot = PlotService.GetPlotAt(position)
    return plot ~= nil and plotOwners[plot.index] == player
end

-- Indica si la posición está sobre una zona plana (depósito, placa de cobro) contando
-- hasta Map.ZoneHeight studs por encima.
local function isOnZone(zone: BasePart, position: Vector3): boolean
    local localPosition = zone.CFrame:PointToObjectSpace(position)
    local half = zone.Size / 2
    return math.abs(localPosition.X) <= half.X
        and math.abs(localPosition.Z) <= half.Z
        and localPosition.Y >= -half.Y
        and localPosition.Y <= MapConfig.ZoneHeight
end

-- Indica si la posición está en la zona de depósito de la parcela del jugador.
function PlotService.IsInDepositZone(player: Player, position: Vector3): boolean
    local plot = PlotService.GetPlot(player)
    return plot ~= nil and isOnZone(plot.depositZone, position)
end

-- Indica si la posición está sobre la placa de cobro de la parcela del jugador.
function PlotService.IsOnCollectPad(player: Player, position: Vector3): boolean
    local plot = PlotService.GetPlot(player)
    return plot ~= nil and isOnZone(plot.collectPad, position)
end

-- Cambia el color del suelo de la parcela del jugador (nil = color por defecto).
function PlotService.SetFloorColor(player: Player, color: Color3?)
    local plot = PlotService.GetPlot(player)
    if plot then
        plot.floor.Color = color or MapConfig.PlotFloorColor
    end
end

-- Muestra los primeros `count` pedestales de la parcela del jugador.
function PlotService.SetUnlockedPedestals(player: Player, count: number)
    local plot = PlotService.GetPlot(player)
    if plot then
        setUnlockedPedestals(plot, count)
    end
end

function PlotService.Init()
    plots = MapService.GetPlots()
    for _, plot in plots do
        plot.collectLabel.Text = ""
        setSign(plot, nil)
        setUnlockedPedestals(plot, MapConfig.InitialPedestals)
    end
end

function PlotService.Start()
    Players.PlayerAdded:Connect(assignPlot)
    Players.PlayerRemoving:Connect(releasePlot)
    for _, player in Players:GetPlayers() do
        assignPlot(player)
    end
end

return PlotService
