--!strict

-- Temporada en curso: tiempo que le queda, puntos del jugador, escalones de recompensa y
-- misiones de temporada. Debajo del título, la próxima cita del calendario de eventos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local LiveOps = require(Shared:WaitForChild("Config"):WaitForChild("LiveOps"))
local PlayerStats = require(Shared:WaitForChild("Util"):WaitForChild("PlayerStats"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))

local SeasonMenu = {}

local function describeTier(data: Types.Profile, tier: LiveOps.Tier): string
    if tier.coinsFraction then
        return string.format(
            Strings.Season.RewardCoins,
            Format.Number(PlayerStats.GetSeasonCoins(data, tier.coinsFraction))
        )
    elseif tier.shards then
        return string.format(Strings.Season.RewardShards, tier.shards)
    elseif tier.cosmetic then
        return Strings.Shop.Names[tier.cosmetic] or tier.cosmetic
    end
    return ""
end

function SeasonMenu.Mount(window: Components.Window)
    local header = Components.Label({
        text = "",
        size = UDim2.fromScale(1, 0.09),
        alignment = Enum.TextXAlignment.Left,
        parent = window.content,
    })
    local subheader = Components.Label({
        text = "",
        size = UDim2.fromScale(1, 0.06),
        position = UDim2.fromScale(0, 0.1),
        alignment = Enum.TextXAlignment.Left,
        color = Components.Colors.Muted,
        parent = window.content,
    })
    local list = Components.ScrollList({
        size = UDim2.fromScale(1, 0.82),
        position = UDim2.fromScale(0, 0.18),
        cellSize = UDim2.fromScale(0.98, 0.17),
        parent = window.content,
    })

    local function updateHeader(season: LiveOps.Season?, points: number)
        local now = Workspace:GetServerTimeNow()
        if season then
            header.Text = string.format(
                Strings.Season.Header,
                season.name,
                Format.LongDuration(LiveOps.GetSeasonRemaining(season, now)),
                points
            )
            header.TextColor3 = season.color
        else
            header.Text = Strings.Season.None
            header.TextColor3 = Components.Colors.Muted
        end
        local entry, at = LiveOps.GetNextScheduled(now)
        subheader.Text = if entry and at
            then string.format(
                Strings.Season.NextEvent,
                Strings.Events.Names[entry.eventId] or entry.eventId,
                Format.LongDuration(at - now)
            )
            else ""
    end

    local function refresh()
        if not window.IsOpen() then
            return
        end
        local data = DataController.GetData()
        Components.Clear(list)
        if data == nil then
            return
        end
        local season = if Workspace:GetAttribute("Feature_seasons") == false
            then nil
            else LiveOps.GetSeason(Workspace:GetServerTimeNow())
        -- El progreso guardado solo vale si es de esta temporada.
        local current = season ~= nil and data.season.id == season.id
        local points = if current then data.season.points else 0
        updateHeader(season, points)
        if season == nil then
            return
        end

        local order = 0
        for index, tier in season.tiers do
            order += 1
            local claimed = current and data.season.claimed[tostring(index)] == true
            local row = Components.Panel({
                size = UDim2.new(),
                layoutOrder = order,
                color = if claimed then Components.Colors.Panel else Components.Colors.Background,
                parent = list,
            })
            Components.Label({
                text = string.format(Strings.Season.Tier, index, tier.points),
                size = UDim2.fromScale(0.3, 0.6),
                position = UDim2.fromScale(0.03, 0.2),
                alignment = Enum.TextXAlignment.Left,
                color = season.color,
                parent = row,
            })
            Components.Label({
                text = describeTier(data, tier),
                size = UDim2.fromScale(0.4, 0.6),
                position = UDim2.fromScale(0.34, 0.2),
                alignment = Enum.TextXAlignment.Left,
                color = Components.Colors.Gold,
                parent = row,
            })
            Components.Label({
                text = if claimed
                    then Strings.Achievements.Done
                    else string.format(
                        Strings.Quests.Progress,
                        math.min(points, tier.points),
                        tier.points
                    ),
                size = UDim2.fromScale(0.2, 0.6),
                position = UDim2.fromScale(0.77, 0.2),
                color = if claimed then Components.Colors.Success else Components.Colors.Muted,
                parent = row,
            })
        end

        for _, mission in season.missions do
            order += 1
            local done = current and data.season.done[mission.id] == true
            local progress = if current then data.season.progress[mission.id] or 0 else 0
            local row = Components.Panel({ size = UDim2.new(), layoutOrder = order, parent = list })
            Components.Label({
                text = string.format(mission.text, Format.Number(mission.goal)),
                size = UDim2.fromScale(0.62, 0.42),
                position = UDim2.fromScale(0.03, 0.08),
                alignment = Enum.TextXAlignment.Left,
                parent = row,
            })
            local bar = Components.Panel({
                size = UDim2.fromScale(0.62, 0.3),
                position = UDim2.fromScale(0.03, 0.58),
                color = Components.Colors.Background,
                parent = row,
            })
            if progress > 0 then
                Components.Panel({
                    size = UDim2.fromScale(math.clamp(progress / mission.goal, 0, 1), 1),
                    color = if done then Components.Colors.Success else Components.Colors.Primary,
                    parent = bar,
                })
            end
            local count = Components.Label({
                text = string.format(
                    Strings.Achievements.Count,
                    Format.Number(progress),
                    Format.Number(mission.goal)
                ),
                size = UDim2.fromScale(1, 0.9),
                position = UDim2.fromScale(0, 0.05),
                parent = bar,
            })
            count.ZIndex = 2
            Components.Label({
                text = if done
                    then Strings.Achievements.Done
                    else string.format(Strings.Season.Points, mission.points),
                size = UDim2.fromScale(0.28, 0.6),
                position = UDim2.fromScale(0.69, 0.2),
                color = if done then Components.Colors.Success else season.color,
                parent = row,
            })
        end
    end

    window.OnOpened(refresh)
    for _, key in { "season", "rebirths" } do
        DataController.OnChanged(key, refresh)
    end
    Workspace:GetAttributeChangedSignal("Feature_seasons"):Connect(refresh)
end

return SeasonMenu
