--!strict

-- Notas de la actualización: al entrar con una versión que el jugador aún no ha visto se
-- muestran sus novedades una vez. A quien entra por primera vez no se le enseñan (ya tiene
-- el tutorial); solo se apunta la versión.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveOps = require(Shared:WaitForChild("Config"):WaitForChild("LiveOps"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))

local UpdateNotes = {}

-- Muestra las notas de la versión actual si el jugador no las ha visto.
function UpdateNotes.Show(data: Types.Profile)
    if data.seenVersion == LiveOps.Version then
        return
    end
    if data.playtime <= 0 then
        Remotes.AckVersion:FireServer()
        return
    end

    local release = LiveOps.Releases[1]
    local gui = Instance.new("ScreenGui")
    -- Los textos ya salen en el idioma elegido: sin traducción automática de Roblox.
    gui.AutoLocalize = false
    gui.Name = "UpdateNotes"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 15

    local panel = Components.Panel({
        size = UDim2.fromScale(0.42, 0.5),
        position = UDim2.fromScale(0.5, 0.5),
        color = Components.Colors.Background,
        parent = gui,
    })
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    Components.Label({
        text = function(): string
            return string.format(Strings.LiveOps.WhatsNew, release.version)
        end,
        size = UDim2.fromScale(0.9, 0.14),
        position = UDim2.fromScale(0.05, 0.04),
        color = Components.Colors.Gold,
        parent = panel,
    })

    -- Las notas traducidas están en Strings.Releases; si faltan, las de Config/LiveOps.
    local notes = Components.Label({
        text = function(): string
            local lines: { string } = {}
            for _, note in Strings.Releases[release.version] or release.notes do
                table.insert(lines, "• " .. note)
            end
            return table.concat(lines, "\n")
        end,
        size = UDim2.fromScale(0.86, 0.5),
        position = UDim2.fromScale(0.07, 0.22),
        alignment = Enum.TextXAlignment.Left,
        parent = panel,
    })
    notes.TextYAlignment = Enum.TextYAlignment.Top

    Components.Button({
        text = function(): string
            return Strings.LiveOps.Ok
        end,
        size = UDim2.fromScale(0.4, 0.16),
        position = UDim2.fromScale(0.3, 0.78),
        color = Components.Colors.Success,
        parent = panel,
        onClick = function()
            gui:Destroy()
            Remotes.AckVersion:FireServer()
        end,
    })

    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return UpdateNotes
