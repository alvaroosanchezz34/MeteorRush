--!strict

-- Personalización de la base: qué decoración va en cada hueco y qué efecto de partículas y
-- luz lleva la base. Lo bloqueado muestra qué hace falta para conseguirlo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DecorConfig = require(Shared:WaitForChild("Config"):WaitForChild("Decor"))
local PlayerStats = require(Shared:WaitForChild("Util"):WaitForChild("PlayerStats"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local DecorMenu = {}

-- Texto de lo que hace falta para desbloquear algo.
local function describeUnlock(unlock: DecorConfig.Unlock?): string
    if unlock == nil then
        return ""
    elseif unlock.rebirths then
        return string.format(Strings.Decor.NeedsRebirths, unlock.rebirths)
    elseif unlock.index then
        return string.format(Strings.Decor.NeedsIndex, unlock.index)
    elseif unlock.achievement then
        return string.format(
            Strings.Decor.NeedsAchievement,
            Strings.Achievements.Names[unlock.achievement] or unlock.achievement
        )
    end
    return ""
end

function DecorMenu.Mount(window: Components.Window)
    local selectedSlot = 1
    local slotBar = Instance.new("Frame")
    slotBar.BackgroundTransparency = 1
    slotBar.Size = UDim2.fromScale(1, 0.1)
    slotBar.Parent = window.content
    local slotLayout = Instance.new("UIListLayout")
    slotLayout.FillDirection = Enum.FillDirection.Horizontal
    slotLayout.Padding = UDim.new(0.01, 0)
    slotLayout.SortOrder = Enum.SortOrder.LayoutOrder
    slotLayout.Parent = slotBar

    local list = Components.ScrollList({
        size = UDim2.fromScale(1, 0.88),
        position = UDim2.fromScale(0, 0.12),
        cellSize = UDim2.fromScale(0.98, 0.17),
        parent = window.content,
    })

    local slotButtons: { TextButton } = {}
    local refresh: () -> ()
    for slot in DecorConfig.Slots do
        slotButtons[slot] = Components.Button({
            text = string.format(Strings.Decor.Slot, slot),
            size = UDim2.fromScale(0.98 / #DecorConfig.Slots - 0.01, 1),
            layoutOrder = slot,
            parent = slotBar,
            onClick = function()
                selectedSlot = slot
                refresh()
            end,
        })
    end

    -- Fila con una muestra de color, el nombre, el requisito si está bloqueado y el botón.
    local function addRow(
        order: number,
        name: string,
        color: Color3?,
        unlock: DecorConfig.Unlock?,
        unlocked: boolean,
        active: boolean,
        onClick: () -> ()
    )
        local row = Components.Panel({
            size = UDim2.new(),
            layoutOrder = order,
            color = if unlocked then Components.Colors.Panel else Components.Colors.Background,
            parent = list,
        })
        if color then
            local swatch = Components.Panel({
                size = UDim2.fromScale(0.08, 0.7),
                position = UDim2.fromScale(0.02, 0.15),
                color = color,
                parent = row,
            })
            local aspect = Instance.new("UIAspectRatioConstraint")
            aspect.AspectRatio = 1
            aspect.Parent = swatch
        end
        Components.Label({
            text = name,
            size = UDim2.fromScale(0.5, if unlocked then 0.6 else 0.42),
            position = UDim2.fromScale(0.12, if unlocked then 0.2 else 0.08),
            alignment = Enum.TextXAlignment.Left,
            parent = row,
        })
        if not unlocked then
            Components.Label({
                text = describeUnlock(unlock),
                size = UDim2.fromScale(0.52, 0.36),
                position = UDim2.fromScale(0.12, 0.54),
                alignment = Enum.TextXAlignment.Left,
                color = Components.Colors.Muted,
                parent = row,
            })
        end
        local text = Strings.Decor.Use
        if not unlocked then
            text = Strings.Decor.Locked
        elseif active then
            text = Strings.Decor.InUse
        end
        Components.Button({
            text = text,
            size = UDim2.fromScale(0.3, 0.66),
            position = UDim2.fromScale(0.67, 0.17),
            color = if not unlocked
                then Components.Colors.Disabled
                elseif active then Components.Colors.Gold
                else Components.Colors.Primary,
            parent = row,
            onClick = function()
                if unlocked then
                    onClick()
                end
            end,
        })
    end

    local function addHeader(order: number, text: string)
        Components.Label({
            text = text,
            size = UDim2.new(),
            layoutOrder = order,
            alignment = Enum.TextXAlignment.Left,
            color = Components.Colors.Muted,
            parent = list,
        })
    end

    refresh = function()
        if not window.IsOpen() then
            return
        end
        local data = DataController.GetData()
        Components.Clear(list)
        if data == nil then
            return
        end
        for slot, button in slotButtons do
            button.BackgroundColor3 = if slot == selectedSlot
                then Components.Colors.Primary
                else Components.Colors.Panel
        end

        local order = 1
        local key = tostring(selectedSlot)
        local placed = data.decor.slots[key]
        addHeader(order, string.format(Strings.Decor.SlotHeader, selectedSlot))
        for _, decoration in DecorConfig.Decorations do
            order += 1
            local active = placed == decoration.id
            addRow(
                order,
                Strings.Decor.Names[decoration.id] or decoration.id,
                decoration.color,
                decoration.unlock,
                PlayerStats.IsUnlocked(data, decoration.unlock),
                active,
                function()
                    -- Pulsar la que ya está puesta la quita.
                    Remotes.SetDecoration:FireServer(
                        selectedSlot,
                        if active then "" else decoration.id
                    )
                end
            )
        end

        order += 1
        addHeader(order, Strings.Decor.EffectHeader)
        for _, effect in DecorConfig.Effects do
            order += 1
            local active = data.decor.effect == effect.id
            addRow(
                order,
                Strings.Decor.EffectNames[effect.id] or effect.id,
                effect.colors[1],
                effect.unlock,
                PlayerStats.IsUnlocked(data, effect.unlock),
                active,
                function()
                    Remotes.SetBaseEffect:FireServer(if active then "" else effect.id)
                end
            )
        end
    end

    window.OnOpened(refresh)
    for _, key in { "decor", "rebirths", "index", "achievements" } do
        DataController.OnChanged(key, refresh)
    end
end

return DecorMenu
