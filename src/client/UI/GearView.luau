--!strict

-- Vista previa de un pico, un arma o una caja: el modelo girando dentro de un visor, y los
-- textos de sus estadísticas. Lo usan el menú de equipamiento, el de cajas y la apertura.
-- El giro se para solo cuando el visor se destruye, así que no deja nada corriendo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Crates = require(Config:WaitForChild("Crates"))
local Equipment = require(Config:WaitForChild("Equipment"))
local EquipmentVisual = require(Shared:WaitForChild("Util"):WaitForChild("EquipmentVisual"))
local ShopConfig = require(Config:WaitForChild("Shop"))
local Strings = require(Shared:WaitForChild("Strings"))

-- Radianes por segundo.
local SPIN_SPEED = 1.4

local GearView = {}

-- Color de la rareza de una recompensa de cualquier tipo.
function GearView.RarityColor(rarity: string): Color3
    local entry = Equipment.Rarities[rarity]
    return if entry then entry.color else Color3.new(1, 1, 1)
end

-- Nombre visible de un pico, un arma o un cosmético.
function GearView.Name(kind: string, id: string): string
    if kind == "cosmetic" then
        return Strings.Shop.Names[id] or id
    end
    return Strings.Equipment.Names[id] or id
end

-- Texto de una estadística con su valor, p. ej. "Mining speed  +5%".
function GearView.StatText(stat: string, value: number): string
    local name = Strings.Equipment.Stats[stat] or stat
    local text
    if Equipment.PercentStats[stat] then
        text = `+{math.round(value * 100)}%`
    elseif stat == "cooldown" or stat == "stun" then
        text = string.format("%.1fs", value)
    else
        text = `+{math.round(value)}`
    end
    return `{name}  {text}`
end

-- Líneas de estadísticas de un objeto (solo las que tiene), ya con sus topes aplicados.
function GearView.Stats(item: Equipment.Item): { string }
    local lines: { string } = {}
    for _, stat in Equipment.StatOrder[item.kind] or {} do
        if item.stats[stat] ~= nil then
            table.insert(lines, GearView.StatText(stat, Equipment.GetItemStat(item, stat)))
        end
    end
    return lines
end

-- Visor con un modelo girando. `kind` es "pickaxe", "weapon", "crate" o "cosmetic" (este
-- último se enseña como una muestra de su color). Devuelve el visor (o el marco de color) y
-- el modelo, si lo hay.
function GearView.Create(props: {
    kind: string,
    id: string,
    size: UDim2,
    position: UDim2?,
    spin: boolean?,
    parent: Instance?,
}): (GuiObject, Model?)
    if props.kind == "cosmetic" then
        local cosmetic = ShopConfig.CosmeticsByKey[props.id]
        local swatch = Instance.new("Frame")
        swatch.Size = props.size
        swatch.Position = props.position or UDim2.new()
        swatch.BackgroundColor3 = if cosmetic then cosmetic.color else Color3.new(1, 1, 1)
        swatch.BorderSizePixel = 0
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = swatch
        local aspect = Instance.new("UIAspectRatioConstraint")
        aspect.Parent = swatch
        swatch.Parent = props.parent
        return swatch, nil
    end

    local viewport = Instance.new("ViewportFrame")
    viewport.Size = props.size
    viewport.Position = props.position or UDim2.new()
    viewport.BackgroundTransparency = 1
    viewport.Ambient = Color3.fromRGB(190, 190, 210)
    viewport.LightColor = Color3.new(1, 1, 1)
    viewport.LightDirection = Vector3.new(-1, -2, -1)

    local model = if props.kind == "crate"
        then EquipmentVisual.CreateCrate(props.id)
        else EquipmentVisual.Create(props.id)
    if model then
        local _, size = model:GetBoundingBox()
        local extent = math.max(size.X, size.Y, size.Z)
        local center = model:GetBoundingBox().Position
        -- Centrado en el origen, para que gire sobre sí mismo.
        model:PivotTo(model:GetPivot() - center)
        model.Parent = viewport

        local camera = Instance.new("Camera")
        camera.FieldOfView = 40
        camera.CFrame = CFrame.lookAt(Vector3.new(0, extent * 0.35, extent * 1.9), Vector3.zero)
        camera.Parent = viewport
        viewport.CurrentCamera = camera

        if props.spin == false then
            -- Sin giro: de tres cuartos, que se ve mejor que de frente.
            model:PivotTo(CFrame.Angles(0, 0.6, 0) * model:GetPivot())
        else
            local base = model:GetPivot()
            local angle = 0
            local connection: RBXScriptConnection
            connection = RunService.RenderStepped:Connect(function(delta: number)
                if viewport.Parent == nil or model.Parent == nil then
                    connection:Disconnect()
                    return
                end
                angle += delta * SPIN_SPEED
                model:PivotTo(CFrame.Angles(0, angle, 0) * base)
            end)
            viewport.Destroying:Connect(function()
                connection:Disconnect()
            end)
        end
    end
    viewport.Parent = props.parent
    return viewport, model
end

-- Texto de las probabilidades de una caja: "Common 62% · Uncommon 30% · ...".
function GearView.OddsText(crate: Crates.Crate): string
    local parts: { string } = {}
    for _, entry in Crates.GetOdds(crate) do
        local percent = entry.chance * 100
        table.insert(
            parts,
            `{Strings.Equipment.Rarities[entry.rarity]} {if percent < 10
                then string.format("%.1f", percent)
                else tostring(math.round(percent))}%`
        )
    end
    return table.concat(parts, "  ·  ")
end

return GearView
