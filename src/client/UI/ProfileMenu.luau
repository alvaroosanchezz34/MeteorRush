--!strict

-- Perfil: nombre, título puesto y dos pestañas: estadísticas de por vida y selector de títulos.
-- El selector enseña los títulos que tiene el jugador (especiales y de logros) para ponerse
-- cualquiera, y los de logros que le faltan con el logro que los da. Los especiales que no
-- tiene no salen (salvo VIP, que se puede comprar). El servidor comprueba cada cambio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementsMenu = require(script.Parent.AchievementsMenu)
local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AchievementsConfig = require(Config:WaitForChild("Achievements"))
local Minerals = require(Config:WaitForChild("Minerals"))
local Mutations = require(Config:WaitForChild("Mutations"))
local TitlesConfig = require(Config:WaitForChild("Titles"))
local PlayerStats = require(Shared:WaitForChild("Util"):WaitForChild("PlayerStats"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))

type TitleEntry = {
    id: string,
    owned: boolean,
    -- Por qué no lo tiene (solo si no lo tiene).
    lockedText: string?,
}

local ProfileMenu = {}

-- Pinta un texto con el aspecto de un título: su color o su degradado (quieto).
local function paintTitle(label: TextLabel, titleId: string)
    local style = TitlesConfig.GetStyle(titleId)
    local old = label:FindFirstChild("TitleGradient")
    if old then
        old:Destroy()
    end
    local colors = style.colors
    if colors then
        label.TextColor3 = Color3.new(1, 1, 1)
        local gradient = Instance.new("UIGradient")
        gradient.Name = "TitleGradient"
        local points: { ColorSequenceKeypoint } = {}
        for index, color in colors do
            table.insert(
                points,
                ColorSequenceKeypoint.new((index - 1) / math.max(#colors - 1, 1), color)
            )
        end
        gradient.Color = ColorSequence.new(points)
        gradient.Parent = label
    else
        label.TextColor3 = style.color
    end
    label.TextStrokeTransparency = if TitlesConfig.IsSpecial(titleId) then 0.2 else 0.6
end

-- Títulos que se enseñan en el selector, en orden: especiales que tiene (y VIP si no), luego
-- los de logros conseguidos y por último los que le faltan.
local function titleEntries(data: Types.Profile): { TitleEntry }
    local entries: { TitleEntry } = {}
    for _, id in TitlesConfig.Specials do
        if PlayerStats.OwnsTitle(data, id) then
            table.insert(entries, { id = id, owned = true })
        elseif id == "vip" then
            table.insert(
                entries,
                { id = id, owned = false, lockedText = Strings.Profile.VipLocked }
            )
        end
    end
    local locked: { TitleEntry } = {}
    for _, achievement in AchievementsConfig.List do
        if achievement.title then
            if PlayerStats.OwnsTitle(data, achievement.id) then
                table.insert(entries, { id = achievement.id, owned = true })
            elseif not achievement.secret then
                table.insert(locked, {
                    id = achievement.id,
                    owned = false,
                    lockedText = string.format(
                        Strings.Profile.Locked,
                        Strings.Achievements.Names[achievement.id] or achievement.id
                    ),
                })
            end
        end
    end
    for _, entry in locked do
        table.insert(entries, entry)
    end
    return entries
end

function ProfileMenu.Mount(window: Components.Window)
    Components.Label({
        text = Players.LocalPlayer.DisplayName,
        size = UDim2.fromScale(0.58, 0.1),
        alignment = Enum.TextXAlignment.Left,
        heading = true,
        parent = window.content,
    })
    local titleLabel = Components.Label({
        text = "",
        size = UDim2.fromScale(0.58, 0.075),
        position = UDim2.fromScale(0, 0.105),
        alignment = Enum.TextXAlignment.Left,
        heading = true,
        parent = window.content,
    })

    local currentTab = "titles"
    local tabButtons: { [string]: TextButton } = {}
    local refresh: () -> ()
    for index, tab in { "titles", "stats" } do
        tabButtons[tab] = Components.Button({
            text = function(): string
                return Strings.Profile.Tabs[tab]
            end,
            size = UDim2.fromScale(0.19, 0.1),
            position = UDim2.fromScale(0.6 + (index - 1) * 0.205, 0.04),
            parent = window.content,
            onClick = function()
                currentTab = tab
                refresh()
            end,
        })
    end

    local hint = Components.Label({
        text = function(): string
            return Strings.Profile.TitlesHint
        end,
        size = UDim2.fromScale(1, 0.05),
        position = UDim2.fromScale(0, 0.195),
        alignment = Enum.TextXAlignment.Left,
        color = Components.Colors.Muted,
        parent = window.content,
    })
    local statsList = Components.ScrollList({
        size = UDim2.fromScale(1, 0.75),
        position = UDim2.fromScale(0, 0.25),
        cellSize = UDim2.fromScale(0.485, 0.14),
        parent = window.content,
    })
    local titlesList = Components.ScrollList({
        size = UDim2.fromScale(1, 0.75),
        position = UDim2.fromScale(0, 0.25),
        cellSize = UDim2.fromScale(0.485, 0.17),
        parent = window.content,
    })

    local function fillStats(data: Types.Profile)
        for order, stat in AchievementsConfig.ProfileStats do
            local value = AchievementsMenu.FormatStat(stat, PlayerStats.GetStat(data, stat))
            if stat == "index" then
                value = `{value}/{#Minerals.List * #Mutations.List}`
            end
            local row =
                Components.Panel({ size = UDim2.new(), layoutOrder = order, parent = statsList })
            Components.Label({
                text = Strings.Profile.Stats[stat] or stat,
                size = UDim2.fromScale(0.6, 0.6),
                position = UDim2.fromScale(0.04, 0.2),
                alignment = Enum.TextXAlignment.Left,
                color = Components.Colors.Muted,
                parent = row,
            })
            Components.Label({
                text = value,
                size = UDim2.fromScale(0.32, 0.6),
                position = UDim2.fromScale(0.64, 0.2),
                alignment = Enum.TextXAlignment.Right,
                parent = row,
            })
        end
    end

    local function fillTitles(data: Types.Profile)
        for order, entry in titleEntries(data) do
            local equipped = entry.owned and data.title == entry.id
            local row =
                Components.Panel({ size = UDim2.new(), layoutOrder = order, parent = titlesList })
            if equipped then
                row.BackgroundColor3 = Components.Colors.PanelRaised
                local stroke = row:FindFirstChildOfClass("UIStroke")
                if stroke then
                    stroke.Color = TitlesConfig.GetStyle(entry.id).color
                    stroke.Transparency = 0
                end
            end
            local name = Components.Label({
                text = Strings.Titles[entry.id] or entry.id,
                size = UDim2.fromScale(0.56, 0.5),
                position = UDim2.fromScale(0.04, 0.25),
                alignment = Enum.TextXAlignment.Left,
                heading = true,
                parent = row,
            })
            if entry.owned then
                paintTitle(name, entry.id)
                Components.Button({
                    text = if equipped then Strings.Profile.Equipped else Strings.Profile.Equip,
                    size = UDim2.fromScale(0.34, 0.6),
                    position = UDim2.fromScale(0.63, 0.2),
                    color = if equipped then Components.Colors.Gold else Components.Colors.Primary,
                    parent = row,
                    onClick = function()
                        -- Pulsar el que ya está puesto lo quita.
                        Remotes.EquipTitle:FireServer(if equipped then "" else entry.id)
                    end,
                })
            else
                name.TextColor3 = Components.Colors.Muted
                Components.Label({
                    text = entry.lockedText or "",
                    size = UDim2.fromScale(0.36, 0.5),
                    position = UDim2.fromScale(0.62, 0.25),
                    alignment = Enum.TextXAlignment.Right,
                    color = Components.Colors.Muted,
                    parent = row,
                })
            end
        end
    end

    refresh = function()
        if not window.IsOpen() then
            return
        end
        for tab, button in tabButtons do
            button.BackgroundColor3 = if tab == currentTab
                then Components.Colors.Primary
                else Components.Colors.PanelRaised
        end
        local showTitles = currentTab == "titles"
        hint.Visible = showTitles
        titlesList.Visible = showTitles
        statsList.Visible = not showTitles
        local data = DataController.GetData()
        Components.Clear(statsList)
        Components.Clear(titlesList)
        if data == nil then
            return
        end

        local hasTitle = PlayerStats.OwnsTitle(data, data.title)
        titleLabel.Text = if hasTitle then Strings.Titles[data.title] else Strings.Profile.NoTitle
        if hasTitle then
            paintTitle(titleLabel, data.title)
        else
            paintTitle(titleLabel, "")
            titleLabel.TextColor3 = Components.Colors.Muted
        end

        if showTitles then
            fillTitles(data)
        else
            fillStats(data)
        end
    end

    window.OnOpened(refresh)
    for _, key in
        {
            "stats",
            "title",
            "specialTitles",
            "achievements",
            "passes",
            "rebirths",
            "index",
            "daily",
            "playtime",
            "totalCoinsEarned",
        }
    do
        DataController.OnChanged(key, refresh)
    end
end

return ProfileMenu
