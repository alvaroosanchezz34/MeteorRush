--!strict

-- Clasificaciones globales de bases: las más visitadas y las que tienen más likes.
-- El servidor las publica como texto JSON en atributos de Workspace (BaseSocialService).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Components)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local SocialConfig = require(Shared:WaitForChild("Config"):WaitForChild("Social"))
local Strings = require(Shared:WaitForChild("Strings"))

-- Clasificaciones que se muestran, de izquierda a derecha.
local KINDS = { "visits", "likes" }

local BasesMenu = {}

-- Lee una clasificación del atributo de Workspace. Devuelve nil si aún no ha llegado y una
-- lista vacía si no hay datos.
local function readRanking(kind: string): { { name: string, value: number } }?
    local raw = Workspace:GetAttribute(`BaseRanking_{kind}`)
    if type(raw) ~= "string" then
        return nil
    end
    local ok, decoded = pcall(function(): any
        return HttpService:JSONDecode(raw)
    end)
    return if ok and type(decoded) == "table" then decoded else {}
end

function BasesMenu.Mount(window: Components.Window)
    local lists: { [string]: ScrollingFrame } = {}
    for index, kind in KINDS do
        local x = (index - 1) * 0.51
        Components.Label({
            text = Strings.Bases.Titles[kind] or kind,
            size = UDim2.fromScale(0.49, 0.1),
            position = UDim2.fromScale(x, 0),
            color = Components.Colors.Gold,
            parent = window.content,
        })
        lists[kind] = Components.ScrollList({
            size = UDim2.fromScale(0.49, 0.88),
            position = UDim2.fromScale(x, 0.12),
            cellSize = UDim2.fromScale(0.96, 1 / SocialConfig.RankingSize - 0.012),
            parent = window.content,
        })
    end

    local function refresh()
        if not window.IsOpen() then
            return
        end
        for kind, list in lists do
            Components.Clear(list)
            local loaded = readRanking(kind)
            if loaded == nil then
                -- Todavía cargando: el servidor aún no ha publicado esta clasificación.
                local holder = Instance.new("Frame")
                holder.BackgroundTransparency = 1
                holder.Parent = list
                Components.Spinner({
                    size = UDim2.fromScale(0.3, 0.8),
                    position = UDim2.fromScale(0.35, 0.1),
                    parent = holder,
                })
            end
            local entries = loaded or {}
            if loaded and #entries == 0 then
                Components.Label({
                    text = Strings.Leaderboard.Empty,
                    size = UDim2.new(),
                    color = Components.Colors.Muted,
                    parent = list,
                })
            end
            for rank, entry in entries do
                local row =
                    Components.Panel({ size = UDim2.new(), layoutOrder = rank, parent = list })
                Components.Label({
                    text = string.format(Strings.Bases.Row, rank, tostring(entry.name)),
                    size = UDim2.fromScale(0.66, 0.7),
                    position = UDim2.fromScale(0.04, 0.15),
                    alignment = Enum.TextXAlignment.Left,
                    color = if rank <= 3 then Components.Colors.Gold else Components.Colors.Text,
                    parent = row,
                })
                Components.Label({
                    text = Format.Number(tonumber(entry.value) or 0),
                    size = UDim2.fromScale(0.26, 0.7),
                    position = UDim2.fromScale(0.7, 0.15),
                    alignment = Enum.TextXAlignment.Right,
                    parent = row,
                })
            end
        end
    end

    window.OnOpened(refresh)
    for _, kind in KINDS do
        Workspace:GetAttributeChangedSignal(`BaseRanking_{kind}`):Connect(refresh)
    end
end

return BasesMenu
