--!strict

-- Equipamiento: los picos, las armas y los cosméticos del jugador. A la izquierda, la lista
-- del tipo elegido; a la derecha, la inspección del objeto seleccionado: el modelo girando,
-- su rareza, sus estadísticas, su rasgo y el botón de equipar o quitar.
-- Equipar lo decide el servidor (remote EquipGear); aquí solo se pide.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AudioManager = require(script.Parent.AudioManager)
local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local GearView = require(script.Parent.GearView)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Equipment = require(Config:WaitForChild("Equipment"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local PlayerStats = require(Shared:WaitForChild("Util"):WaitForChild("PlayerStats"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShopConfig = require(Config:WaitForChild("Shop"))
local Strings = require(Shared:WaitForChild("Strings"))

local KINDS = { "pickaxe", "weapon", "cosmetic" }
-- Latido del borde de la inspección en los objetos Legendarios y Míticos.
local PULSE = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local EquipmentMenu = {}

function EquipmentMenu.Mount(window: Components.Window)
    local root = window.content
    local kind = KINDS[1]
    -- Objeto seleccionado de cada tipo (se recuerda al cambiar de pestaña).
    local selected: { [string]: string } = {}

    local filters: { [string]: TextButton } = {}
    local list = Components.ScrollList({
        size = UDim2.fromScale(0.55, 0.88),
        position = UDim2.fromScale(0, 0.12),
        cellSize = UDim2.fromScale(0.48, 0.2),
        parent = root,
    })
    local detail = Components.Panel({
        size = UDim2.fromScale(0.43, 0.88),
        position = UDim2.fromScale(0.57, 0.12),
        parent = root,
    })
    -- El contenido de la inspección va en un marco propio, para poder vaciarlo sin llevarse
    -- el borde y las esquinas del panel.
    local body = Instance.new("Frame")
    body.BackgroundTransparency = 1
    body.Size = UDim2.fromScale(1, 1)
    body.Parent = detail
    local dustLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.3, 0.08),
        position = UDim2.fromScale(0.7, 0.01),
        alignment = Enum.TextXAlignment.Right,
        color = Components.Colors.Gold,
        parent = root,
    })

    local refresh: () -> ()

    -- Inspección de un pico o un arma.
    local function showItem(item: Equipment.Item, equipped: boolean)
        local rarity = Equipment.Rarities[item.rarity]
        local stroke = detail:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = rarity.color
            stroke.Transparency = 0.3
            if rarity.rank >= 5 then
                -- El tween se destruye con el contenido de la inspección al cambiar de objeto.
                local marker = Instance.new("Folder")
                marker.Name = "Pulse"
                marker.Parent = body
                local tween = TweenService:Create(stroke, PULSE, { Transparency = 0.75 })
                tween:Play()
                marker.Destroying:Connect(function()
                    tween:Cancel()
                end)
            end
        end
        GearView.Create({
            kind = item.kind,
            id = item.id,
            size = UDim2.fromScale(0.9, 0.36),
            position = UDim2.fromScale(0.05, 0.02),
            parent = body,
        })
        Components.Label({
            text = Strings.Equipment.Names[item.id] or item.id,
            size = UDim2.fromScale(0.92, 0.08),
            position = UDim2.fromScale(0.04, 0.39),
            color = rarity.color,
            heading = true,
            parent = body,
        })
        Components.Label({
            text = `{Strings.Upper(Strings.Equipment.Rarities[item.rarity])} {Strings.Upper(
                Strings.Equipment.KindNames[item.kind]
            )}`,
            size = UDim2.fromScale(0.92, 0.045),
            position = UDim2.fromScale(0.04, 0.47),
            color = Components.Colors.Muted,
            parent = body,
        })

        local lines = GearView.Stats(item)
        if #lines == 0 then
            lines = { Strings.Equipment.NoStats }
        end
        local ability = if item.ability then Strings.Equipment.Abilities[item.ability] else nil
        if ability then
            table.insert(lines, `★ {ability.name}: {ability.text}`)
        end
        local stats = Components.Label({
            text = table.concat(lines, "\n"),
            size = UDim2.fromScale(0.92, 0.24),
            position = UDim2.fromScale(0.04, 0.53),
            alignment = Enum.TextXAlignment.Left,
            parent = body,
        })
        stats.TextYAlignment = Enum.TextYAlignment.Top
        Components.Label({
            text = Strings.Equipment.Descriptions[item.id] or "",
            size = UDim2.fromScale(0.92, 0.07),
            position = UDim2.fromScale(0.04, 0.78),
            color = Components.Colors.Muted,
            parent = body,
        })

        -- Quitar un objeto es volver al inicial de su tipo; el inicial no se puede quitar.
        local default = Equipment.Defaults[item.kind]
        local isDefault = item.id == default
        Components.Button({
            text = if not equipped
                then Strings.Equipment.Equip
                elseif isDefault then Strings.Equipment.Equipped
                else Strings.Equipment.Unequip,
            size = UDim2.fromScale(0.7, 0.11),
            position = UDim2.fromScale(0.15, 0.87),
            color = if not equipped
                then Components.Colors.Success
                elseif isDefault then Components.Colors.Disabled
                else Components.Colors.PanelRaised,
            parent = body,
            onClick = function()
                if not equipped then
                    Remotes.EquipGear:FireServer(item.id)
                elseif not isDefault then
                    Remotes.EquipGear:FireServer(default)
                end
            end,
        })
    end

    -- Inspección de un cosmético: muestra de color y equipar con el remote de siempre.
    local function showCosmetic(cosmetic: ShopConfig.Cosmetic, equipped: boolean)
        GearView.Create({
            kind = "cosmetic",
            id = cosmetic.key,
            size = UDim2.fromScale(0.5, 0.3),
            position = UDim2.fromScale(0.25, 0.06),
            parent = body,
        })
        Components.Label({
            text = Strings.Shop.Names[cosmetic.key] or cosmetic.key,
            size = UDim2.fromScale(0.92, 0.08),
            position = UDim2.fromScale(0.04, 0.42),
            heading = true,
            parent = body,
        })
        Components.Label({
            text = Strings.Shop.Descriptions[cosmetic.kind] or "",
            size = UDim2.fromScale(0.92, 0.14),
            position = UDim2.fromScale(0.04, 0.54),
            color = Components.Colors.Muted,
            parent = body,
        })
        Components.Button({
            text = if equipped then Strings.Equipment.Unequip else Strings.Equipment.Equip,
            size = UDim2.fromScale(0.7, 0.11),
            position = UDim2.fromScale(0.15, 0.87),
            color = if equipped then Components.Colors.PanelRaised else Components.Colors.Success,
            parent = body,
            onClick = function()
                Remotes.EquipCosmetic:FireServer(cosmetic.key, not equipped)
            end,
        })
    end

    local function cell(
        order: number,
        text: string,
        color: Color3,
        isSelected: boolean,
        equipped: boolean,
        onClick: () -> ()
    )
        local button = Components.Button({
            text = if equipped then `{text}\n✔ {Strings.Equipment.Equipped}` else text,
            size = UDim2.new(),
            color = if isSelected then Components.Colors.PanelRaised else Components.Colors.Panel,
            layoutOrder = order,
            parent = list,
            onClick = onClick,
        })
        button.TextColor3 = color
    end

    refresh = function()
        if not window.IsOpen() then
            return
        end
        local data = DataController.GetData()
        Components.Clear(list)
        Components.Clear(body)
        local stroke = detail:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = Components.Colors.Stroke
            stroke.Transparency = 0.78
        end
        for key, button in filters do
            button.BackgroundColor3 = if key == kind
                then Components.Colors.Primary
                else Components.Colors.PanelRaised
        end
        if data == nil then
            return
        end
        dustLabel.Text = string.format(Strings.Equipment.Dust, Format.Number(data.equipment.dust))

        local shown = false
        if kind == "cosmetic" then
            local order = 0
            for _, cosmetic in ShopConfig.Cosmetics do
                if PlayerStats.OwnsCosmetic(data, cosmetic) then
                    order += 1
                    local equipped = data.cosmetics.equipped[cosmetic.kind] == cosmetic.key
                    selected[kind] = selected[kind] or cosmetic.key
                    local isSelected = selected[kind] == cosmetic.key
                    cell(
                        order,
                        Strings.Shop.Names[cosmetic.key] or cosmetic.key,
                        cosmetic.color,
                        isSelected,
                        equipped,
                        function()
                            selected[kind] = cosmetic.key
                            AudioManager.Play("UiClick")
                            refresh()
                        end
                    )
                    if isSelected then
                        shown = true
                        showCosmetic(cosmetic, equipped)
                    end
                end
            end
            if order == 0 then
                Components.Label({
                    text = Strings.Equipment.NoCosmetics,
                    size = UDim2.fromScale(0.9, 0.3),
                    position = UDim2.fromScale(0.05, 0.3),
                    color = Components.Colors.Muted,
                    parent = body,
                })
                return
            end
        else
            local equippedId = Equipment.GetEquipped(data, kind).id
            selected[kind] = selected[kind] or equippedId
            -- Los más raros primero.
            local items = Equipment.GetByKind(kind)
            for index = #items, 1, -1 do
                local item = items[index]
                if Equipment.Owns(data, item.id) then
                    local isSelected = selected[kind] == item.id
                    cell(
                        #items - index,
                        Strings.Equipment.Names[item.id] or item.id,
                        Equipment.Rarities[item.rarity].color,
                        isSelected,
                        item.id == equippedId,
                        function()
                            selected[kind] = item.id
                            refresh()
                        end
                    )
                    if isSelected then
                        shown = true
                        showItem(item, item.id == equippedId)
                    end
                end
            end
        end
        if not shown then
            -- Lo seleccionado ya no está (intercambiado o quitado): se vuelve a elegir.
            if selected[kind] ~= nil then
                selected[kind] = nil
                refresh()
                return
            end
            Components.Label({
                text = Strings.Equipment.Select,
                size = UDim2.fromScale(0.9, 0.3),
                position = UDim2.fromScale(0.05, 0.3),
                color = Components.Colors.Muted,
                parent = body,
            })
        end
    end

    for index, key in KINDS do
        filters[key] = Components.Button({
            text = function(): string
                return Strings.Equipment.Kinds[key]
            end,
            size = UDim2.fromScale(0.21, 0.09),
            position = UDim2.fromScale((index - 1) * 0.22, 0),
            color = Components.Colors.PanelRaised,
            parent = root,
            onClick = function()
                kind = key
                refresh()
            end,
        })
    end

    window.OnOpened(refresh)
    for _, key in { "equipment", "cosmetics", "passes", "rebirths" } do
        DataController.OnChanged(key, refresh)
    end
end

return EquipmentMenu
