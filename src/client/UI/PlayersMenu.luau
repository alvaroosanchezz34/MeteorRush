--!strict

-- Jugadores del servidor: título, rebirths y progreso del índice de cada uno, con un botón
-- para visitar su base y ver su colección en el panel del muro.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local InspectBase = require(script.Parent.InspectBase)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Minerals = require(Config:WaitForChild("Minerals"))
local Mutations = require(Config:WaitForChild("Mutations"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local PlayersMenu = {}

local function numberAttribute(player: Player, name: string): number
    local value = player:GetAttribute(name)
    return if type(value) == "number" then value else 0
end

function PlayersMenu.Mount(window: Components.Window)
    local list = Components.ScrollList({
        size = UDim2.fromScale(1, 1),
        cellSize = UDim2.fromScale(0.98, 0.2),
        parent = window.content,
    })

    local function refresh()
        if not window.IsOpen() then
            return
        end
        Components.Clear(list)

        local order = 0
        for _, player in Players:GetPlayers() do
            if player ~= Players.LocalPlayer then
                order += 1
                local title = Strings.TitleOf(player)
                local row =
                    Components.Panel({ size = UDim2.new(), layoutOrder = order, parent = list })
                Components.Label({
                    text = if type(title) == "string"
                        then string.format(Strings.Visit.NameTitle, player.DisplayName, title)
                        else player.DisplayName,
                    size = UDim2.fromScale(0.62, 0.45),
                    position = UDim2.fromScale(0.03, 0.08),
                    alignment = Enum.TextXAlignment.Left,
                    parent = row,
                })
                Components.Label({
                    text = string.format(
                        Strings.Visit.Summary,
                        numberAttribute(player, "Rebirths"),
                        numberAttribute(player, "IndexCount"),
                        #Minerals.List * #Mutations.List
                    ),
                    size = UDim2.fromScale(0.62, 0.36),
                    position = UDim2.fromScale(0.03, 0.55),
                    alignment = Enum.TextXAlignment.Left,
                    color = Components.Colors.Muted,
                    parent = row,
                })
                Components.Button({
                    text = Strings.Inspect.Button,
                    size = UDim2.fromScale(0.15, 0.66),
                    position = UDim2.fromScale(0.66, 0.17),
                    color = Components.Colors.Primary,
                    parent = row,
                    onClick = function()
                        window.Close()
                        InspectBase.Open(player)
                    end,
                })
                Components.Button({
                    text = Strings.Visit.Short,
                    size = UDim2.fromScale(0.15, 0.66),
                    position = UDim2.fromScale(0.82, 0.17),
                    color = Components.Colors.Success,
                    parent = row,
                    onClick = function()
                        Remotes.VisitBase:FireServer(player)
                        window.Close()
                    end,
                })
            end
        end
        if order == 0 then
            Components.Label({
                text = Strings.Trade.NoPlayers,
                size = UDim2.fromScale(1, 1),
                color = Components.Colors.Muted,
                parent = list,
            })
        end
    end

    window.OnOpened(refresh)
    Players.PlayerAdded:Connect(refresh)
    Players.PlayerRemoving:Connect(function()
        -- El jugador sigue en la lista mientras se dispara el evento.
        task.defer(refresh)
    end)
end

return PlayersMenu
