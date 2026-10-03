--!strict

-- Entrada del jugador.
-- Minar: mantener pulsado clic izquierdo, R2 en mando o el botón táctil "Mine".
-- Golpear: F, X en mando o el botón táctil "Hit". El clic izquierdo también golpea
-- cuando no hay ningún meteorito al alcance.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeteorController = require(script.Parent.MeteorController)
local Sound = require(script.Parent.Parent.UI.Sound)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MeteorsConfig = require(Config:WaitForChild("Meteors"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local StealConfig = require(Config:WaitForChild("Steal"))
local Strings = require(Shared:WaitForChild("Strings"))

local MINE_ACTION = "Mine"
local HIT_ACTION = "Hit"

local InputController = {}

local mining = false
local lastHitAttempt = 0

local function getRootPosition(player: Player): Vector3?
    local character = player.Character
    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
    return if root and root:IsA("BasePart") then root.Position else nil
end

-- Intenta golpear al jugador más cercano dentro del alcance. Devuelve true si había alguno.
local function tryHit(): boolean
    local position = getRootPosition(Players.LocalPlayer)
    if position == nil then
        return false
    end
    local target: Player? = nil
    local bestDistance = StealConfig.HitRange
    for _, player in Players:GetPlayers() do
        if player ~= Players.LocalPlayer then
            local otherPosition = getRootPosition(player)
            if otherPosition then
                local distance = (otherPosition - position).Magnitude
                if distance <= bestDistance then
                    target = player
                    bestDistance = distance
                end
            end
        end
    end
    if target == nil then
        return false
    end
    -- El servidor aplica el enfriamiento real; esto solo evita enviar golpes inútiles.
    local now = os.clock()
    if now - lastHitAttempt >= StealConfig.AttackerCooldown then
        lastHitAttempt = now
        Remotes.HitPlayer:FireServer(target)
        Sound.Play("Hit")
    end
    return true
end

local function onMineAction(_: string, inputState: Enum.UserInputState): Enum.ContextActionResult
    if inputState == Enum.UserInputState.Begin then
        local position = getRootPosition(Players.LocalPlayer)
        local meteorId = if position
            then MeteorController.GetNearestMeteor(position, MeteorsConfig.MineRange)
            else nil
        if meteorId == nil then
            return if tryHit() then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
        end
        mining = true
        Remotes.MineStart:FireServer(meteorId)
        return Enum.ContextActionResult.Sink
    end

    if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
        if mining then
            mining = false
            Remotes.MineStop:FireServer()
            return Enum.ContextActionResult.Sink
        end
    end
    return Enum.ContextActionResult.Pass
end

local function onHitAction(_: string, inputState: Enum.UserInputState): Enum.ContextActionResult
    if inputState == Enum.UserInputState.Begin then
        tryHit()
        return Enum.ContextActionResult.Sink
    end
    return Enum.ContextActionResult.Pass
end

function InputController.Start()
    ContextActionService:BindAction(
        MINE_ACTION,
        onMineAction,
        true,
        Enum.UserInputType.MouseButton1,
        Enum.KeyCode.ButtonR2
    )
    ContextActionService:SetTitle(MINE_ACTION, Strings.Mining.MineButton)

    ContextActionService:BindAction(
        HIT_ACTION,
        onHitAction,
        true,
        Enum.KeyCode.F,
        Enum.KeyCode.ButtonX
    )
    ContextActionService:SetTitle(HIT_ACTION, Strings.Steal.HitButton)
    ContextActionService:SetPosition(HIT_ACTION, UDim2.fromScale(0.55, 0.3))
end

return InputController
