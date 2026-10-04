--!strict

-- Mochila de cada jugador: los minerales que lleva encima y aún no ha depositado.
-- Vive solo en memoria (no se guarda): lo que se transporta se pierde al salir.
-- También aplica la velocidad (mejora, pass vip y penalización por carga), dibuja los
-- minerales en la espalda y detecta la entrada en la zona de depósito.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AchievementService = require(script.Parent.AchievementService)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local QuestService = require(script.Parent.QuestService)
local TutorialService = require(script.Parent.TutorialService)

local Shared = ReplicatedStorage.Shared
local AchievementsConfig = require(Shared.Config.Achievements)
local Minerals = require(Shared.Config.Minerals)
local CarryConfig = require(Shared.Config.Carry)
local MineralVisual = require(Shared.Util.MineralVisual)
local PlayerStats = require(Shared.Util.PlayerStats)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)

local CarryService = {}

local backpacks: { [Player]: { Types.InventoryItem } } = {}
local stacks: { [Player]: Model } = {}
local rng = Random.new()
-- Segundos tras salir un jugador a los que se borra su mochila si nadie lo ha hecho antes.
local CLEANUP_DELAY = 5
-- Aturdimientos y ralentizaciones del robo: factor de velocidad y hasta cuándo dura.
local speedModifiers: { [Player]: { factor: number, untilTime: number } } = {}

local function getTorso(character: Model): BasePart?
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    return if torso and torso:IsA("BasePart") then torso else nil
end

local function getVisualPart(visual: Instance): BasePart?
    if visual:IsA("BasePart") then
        return visual
    end
    if visual:IsA("Model") then
        return visual.PrimaryPart or visual:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

-- Dibuja los minerales transportados pegados a la espalda del personaje (visible para todos).
local function updateStack(player: Player)
    local old = stacks[player]
    if old then
        old:Destroy()
        stacks[player] = nil
    end

    local items = backpacks[player]
    local character = player.Character
    local torso = if character then getTorso(character) else nil
    if items == nil or #items == 0 or character == nil or torso == nil then
        return
    end

    local stack = Instance.new("Model")
    stack.Name = "CarryStack"
    local size = CarryConfig.VisibleItemSize
    local columns = CarryConfig.VisibleColumns
    for index = 1, math.min(#items, CarryConfig.MaxVisibleItems) do
        local item = items[index]
        local visual = MineralVisual.Create(item.mineral, item.mutation, size)
        local part = getVisualPart(visual)
        if part then
            local column = (index - 1) % columns
            local row = (index - 1) // columns
            local x = (column - (columns - 1) / 2) * size
            local y = -torso.Size.Y / 2 + size / 2 + row * size
            -- +Z local del torso es la espalda.
            local offset = CFrame.new(x, y, torso.Size.Z / 2 + size / 2)
            if visual:IsA("Model") then
                visual:PivotTo(torso.CFrame * offset)
            else
                part.CFrame = torso.CFrame * offset
            end
            for _, descendant in visual:GetDescendants() do
                if descendant:IsA("BasePart") then
                    descendant.Anchored = false
                end
            end
            part.Anchored = false
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = torso
            weld.Part1 = part
            weld.Parent = part
            visual.Parent = stack
        else
            visual:Destroy()
        end
    end
    -- Mochila llena: la carga brilla, para que se note desde lejos que va hasta arriba.
    local data = DataService.GetData(player)
    if data and #items >= PlayerStats.GetBackpackCapacity(data) then
        local glow = Instance.new("PointLight")
        glow.Name = "FullGlow"
        glow.Color = CarryConfig.FullGlowColor
        glow.Range = CarryConfig.FullGlowRange
        glow.Brightness = 1.5
        glow.Shadows = false
        local sparks = Instance.new("ParticleEmitter")
        sparks.Name = "FullSparks"
        sparks.Color = ColorSequence.new(CarryConfig.FullGlowColor)
        sparks.Size = NumberSequence.new(0.3, 0)
        sparks.Lifetime = NumberRange.new(0.5, 0.9)
        sparks.Speed = NumberRange.new(2, 4)
        sparks.SpreadAngle = Vector2.new(60, 60)
        sparks.LightEmission = 1
        sparks.Rate = CarryConfig.FullGlowRate
        -- Dentro de la pila, así desaparecen con ella.
        local holder = stack:FindFirstChildWhichIsA("BasePart", true)
        if holder then
            glow.Parent = holder
            sparks.Parent = holder
        else
            glow:Destroy()
            sparks:Destroy()
        end
    end

    stack.Parent = character
    stacks[player] = stack
end

-- Aplica WalkSpeed según mejoras, game passes y lo que lleva encima.
function CarryService.RefreshSpeed(player: Player)
    local data = DataService.GetData(player)
    local character = player.Character
    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
    if data == nil or humanoid == nil then
        return
    end
    local speed = PlayerStats.GetWalkSpeed(data, CarryService.GetCount(player))
    local modifier = speedModifiers[player]
    if modifier and os.clock() < modifier.untilTime then
        speed *= modifier.factor
    end
    humanoid.WalkSpeed = speed
end

-- Multiplica la velocidad del jugador durante unos segundos (0 = aturdido). Después vuelve
-- sola a la normal. Un modificador nuevo sustituye al anterior.
function CarryService.SetSpeedModifier(player: Player, factor: number, seconds: number)
    local modifier = { factor = math.clamp(factor, 0, 1), untilTime = os.clock() + seconds }
    speedModifiers[player] = modifier
    CarryService.RefreshSpeed(player)
    task.delay(seconds + 0.05, function()
        if speedModifiers[player] == modifier then
            speedModifiers[player] = nil
            if player.Parent == Players then
                CarryService.RefreshSpeed(player)
            end
        end
    end)
end

local function changed(player: Player)
    Remotes.CarryUpdate:FireClient(
        player,
        backpacks[player] or {},
        CarryService.GetCapacity(player)
    )
    CarryService.RefreshSpeed(player)
    updateStack(player)
end

-- Capacidad de la mochila. 0 si el perfil del jugador no está cargado.
function CarryService.GetCapacity(player: Player): number
    local data = DataService.GetData(player)
    return if data then PlayerStats.GetBackpackCapacity(data) else 0
end

-- Número de minerales que lleva el jugador.
function CarryService.GetCount(player: Player): number
    local backpack = backpacks[player]
    return if backpack then #backpack else 0
end

-- Indica si cabe al menos un mineral más.
function CarryService.HasRoom(player: Player): boolean
    return CarryService.GetCount(player) < CarryService.GetCapacity(player)
end

-- Devuelve una copia de los minerales que lleva el jugador.
function CarryService.GetItems(player: Player): { Types.InventoryItem }
    return table.clone(backpacks[player] or {})
end

-- Añade un mineral a la mochila. Devuelve false si no cabe.
function CarryService.Add(player: Player, item: Types.InventoryItem): boolean
    if not CarryService.HasRoom(player) then
        return false
    end
    local backpack = backpacks[player]
    if backpack == nil then
        backpack = {}
        backpacks[player] = backpack
    end
    table.insert(backpack, item)
    changed(player)
    return true
end

-- Quita `count` minerales al azar de la mochila y los devuelve.
function CarryService.RemoveRandom(player: Player, count: number): { Types.InventoryItem }
    local backpack = backpacks[player]
    local removed: { Types.InventoryItem } = {}
    if backpack == nil then
        return removed
    end
    for _ = 1, math.min(count, #backpack) do
        table.insert(
            removed,
            table.remove(backpack, rng:NextInteger(1, #backpack)) :: Types.InventoryItem
        )
    end
    if #removed > 0 then
        changed(player)
    end
    return removed
end

-- Vacía la mochila sin depositar (por ejemplo, al hacer rebirth).
function CarryService.Clear(player: Player)
    backpacks[player] = nil
    changed(player)
end

local function deposit(player: Player)
    local items = backpacks[player]
    if items == nil or #items == 0 then
        return
    end
    local ok = DataService.Update(player, "inventory", function(inventory: { Types.InventoryItem })
        for _, item in items do
            table.insert(inventory, item)
        end
        return inventory
    end)
    if not ok then
        return
    end
    backpacks[player] = nil
    changed(player)
    Remotes.Notify:FireClient(player, string.format(Strings.Carry.Deposited, #items))
    TutorialService.Advance(player, 2)
    QuestService.Progress(player, "deposit", #items)
    -- Objetivos secretos: llegar a la base poco después de un robo, y depositar una mochila
    -- llena en la que todo es Raro o superior.
    local lastHit = player:GetAttribute("LastHitAt")
    local escaped = type(lastHit) == "number"
        and Workspace:GetServerTimeNow() - lastHit <= AchievementsConfig.EscapeSeconds
    if escaped then
        player:SetAttribute("LastHitAt", nil)
    end
    local data = DataService.GetData(player)
    local allRare = data ~= nil and #items >= PlayerStats.GetBackpackCapacity(data)
    for _, item in items do
        if Minerals.GetRank(item.mineral) < Minerals.RareRank then
            allRare = false
        end
    end
    AchievementService.AddStats(player, {
        deposited = #items,
        escapes = if escaped then 1 else 0,
        rareBackpacks = if allRare then 1 else 0,
    })
end

local function checkDeposits()
    for player, items in backpacks do
        if #items > 0 then
            local character = player.Character
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            if
                root
                and root:IsA("BasePart")
                and PlotService.IsInDepositZone(player, root.Position)
            then
                deposit(player)
            end
        end
    end
end

local function onCharacterAdded(player: Player, character: Model)
    -- Al morir se pierde lo que se llevaba encima.
    backpacks[player] = nil
    character:WaitForChild("Humanoid", 10)
    if character.Parent then
        changed(player)
    end
end

function CarryService.Init()
    DataService.OnProfileLoaded(function(player: Player)
        changed(player)
    end)
    for _, key in { "upgrades", "passes", "permanent" } do
        DataService.OnFieldChanged(key, function(player: Player)
            changed(player)
        end)
    end

    -- Al cerrar el perfil se vacía la mochila. Si el jugador se va por su cuenta pierde lo que
    -- llevaba (igual que si se lo roban, y así no sirve para esquivar un golpe); si es el
    -- servidor el que se cierra no es culpa suya, así que se deposita en su base.
    DataService.OnProfileReleasing(function(player: Player, data: Types.Profile)
        local items = backpacks[player]
        backpacks[player] = nil
        if items and #items > 0 and DataService.IsShuttingDown() then
            for _, item in items do
                table.insert(data.inventory, item)
            end
        end
    end)
end

function CarryService.Start()
    local connections: { [Player]: RBXScriptConnection } = {}

    local function onPlayerAdded(player: Player)
        connections[player] = player.CharacterAdded:Connect(function(character: Model)
            onCharacterAdded(player, character)
        end)
    end
    Players.PlayerAdded:Connect(onPlayerAdded)
    for _, player in Players:GetPlayers() do
        onPlayerAdded(player)
    end

    Players.PlayerRemoving:Connect(function(player: Player)
        -- La mochila la vacía OnProfileReleasing (que necesita leerla antes); esto es solo
        -- por si el perfil ya no estaba cargado y esa función no llega a ejecutarse.
        task.delay(CLEANUP_DELAY, function()
            backpacks[player] = nil
        end)
        stacks[player] = nil
        speedModifiers[player] = nil
        local connection = connections[player]
        if connection then
            connection:Disconnect()
            connections[player] = nil
        end
    end)

    task.spawn(function()
        while true do
            task.wait(CarryConfig.DepositCheckInterval)
            checkDeposits()
        end
    end)
end

return CarryService
