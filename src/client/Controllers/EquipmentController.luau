--!strict

-- Lado cliente del equipamiento: presenta lo que decide el servidor.
--   * Resultado de abrir una caja → UI/CrateOpening.
--   * Golpe crítico del pico y Forge Dust encontrado → texto, chispas y sonido.
--   * Habilidad de un arma usada cerca → onda y sonido (lo ven todos).
--   * Robo de algo muy raro → aviso grande solo para quien se lo lleva.
--   * Cambio de pico o de arma → sonido y un destello en el personaje.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioManager = require(script.Parent.Parent.UI.AudioManager)
local Banner = require(script.Parent.Parent.UI.Banner)
local CrateOpening = require(script.Parent.Parent.UI.CrateOpening)
local DataController = require(script.Parent.DataController)
local Effects = require(script.Parent.Parent.UI.Effects)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Equipment = require(Config:WaitForChild("Equipment"))
local Minerals = require(Config:WaitForChild("Minerals"))
local Mutations = require(Config:WaitForChild("Mutations"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local CRIT_COLOR = Color3.fromRGB(255, 230, 120)
local DUST_COLOR = Color3.fromRGB(190, 200, 215)

local EquipmentController = {}

local function onCrateResult(
    crateId: any,
    kind: any,
    id: any,
    rarity: any,
    isNew: any,
    dust: any,
    preview: any
)
    if
        type(crateId) ~= "string"
        or type(kind) ~= "string"
        or type(id) ~= "string"
        or type(rarity) ~= "string"
    then
        return
    end
    CrateOpening.Play({
        crateId = crateId,
        kind = kind,
        id = id,
        rarity = rarity,
        isNew = isNew == true,
        dust = if type(dust) == "number" then dust else 0,
        preview = preview == true,
    })
end

local function onMineBonus(kind: any, position: any, radius: any, amount: any)
    if typeof(position) ~= "Vector3" or type(radius) ~= "number" then
        return
    end
    local origin = position + Vector3.new(0, radius + 3, 0)
    if kind == "crit" then
        -- El color del golpe crítico es el del pico que lo da.
        local data = DataController.GetData()
        local pickaxe = if data then Equipment.GetEquipped(data, "pickaxe") else nil
        local color = if pickaxe then pickaxe.accent or pickaxe.color else CRIT_COLOR
        AudioManager.Play("CritHit")
        Effects.Burst({ position = origin, color = color, count = 26, speed = 18, size = 0.6 })
        Effects.Popup({
            position = origin + Vector3.new(0, 2, 0),
            text = Strings.Mining.Critical,
            color = CRIT_COLOR,
            height = 2,
        })
        Effects.Shake(0.25, 0.2)
    elseif kind == "dust" and type(amount) == "number" then
        AudioManager.Play("DustFound")
        Effects.Popup({
            position = origin - Vector3.new(0, 1.5, 0),
            text = string.format(Strings.Mining.DustFound, amount),
            color = DUST_COLOR,
            height = 1.2,
        })
    end
end

local function onAbilityFx(user: any, position: any, abilityId: any, radius: any)
    if
        typeof(user) ~= "Instance"
        or typeof(position) ~= "Vector3"
        or type(abilityId) ~= "string"
        or type(radius) ~= "number"
    then
        return
    end
    local weaponId = user:GetAttribute("Weapon")
    local weapon = if type(weaponId) == "string" then Equipment.ById[weaponId] else nil
    local color = if weapon then weapon.accent or weapon.color else Color3.fromRGB(255, 70, 130)
    Effects.Shockwave({ position = position, radius = radius, color = color, duration = 0.6 })
    Effects.Burst({
        position = position + Vector3.new(0, 2, 0),
        color = color,
        count = 40,
        speed = 30,
        size = 0.9,
    })
    local anchor = Effects.Anchor(position, 2)
    AudioManager.Play("VoidPulse", anchor)
    if user == Players.LocalPlayer then
        Effects.Shake(0.5, 0.3)
    end
end

local function onStealMoment(mineralId: any, mutationId: any, fromName: any)
    local mineral = if type(mineralId) == "string" then Minerals.ById[mineralId] else nil
    local mutation = if type(mutationId) == "string" then Mutations.ById[mutationId] else nil
    if mineral == nil or mutation == nil then
        return
    end
    Banner.Show({
        heading = string.format(
            Strings.Steal.Stolen,
            string.upper(Strings.MineralName(mineral.id, mutation.id))
        ),
        title = Strings.MineralName(mineral.id, mutation.id),
        subtitle = if type(fromName) == "string"
            then string.format(Strings.Steal.StolenFrom, fromName)
            else nil,
        color = mutation.color or Minerals.Rarities[mineral.rarity].color,
        mineral = mineral.id,
        mutation = mutation.id,
        sound = "StealMoment",
    })
end

function EquipmentController.Init()
    Remotes.CrateResult.OnClientEvent:Connect(onCrateResult)
    Remotes.MineBonus.OnClientEvent:Connect(onMineBonus)
    Remotes.AbilityFx.OnClientEvent:Connect(onAbilityFx)
    Remotes.StealMoment.OnClientEvent:Connect(onStealMoment)
end

function EquipmentController.Start()
    -- Equipar: sonido y destello del color del objeto sobre el propio personaje.
    local last: { [string]: string } = {}
    local function onEquipment()
        local data = DataController.GetData()
        if data == nil then
            return
        end
        for _, kind in Equipment.Kinds do
            local item = Equipment.GetEquipped(data, kind)
            local previous = last[kind]
            last[kind] = item.id
            if previous ~= nil and previous ~= item.id then
                AudioManager.Play("EquipGear")
                local character = Players.LocalPlayer.Character
                local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
                if root and root:IsA("BasePart") then
                    Effects.Burst({
                        position = root.Position,
                        color = item.accent or Equipment.Rarities[item.rarity].color,
                        count = 10 + Equipment.GetRank(item) * 5,
                        speed = 9,
                        size = 0.45,
                    })
                end
            end
        end
    end
    DataController.OnReady(onEquipment)
    DataController.OnChanged("equipment", onEquipment)
end

return EquipmentController
