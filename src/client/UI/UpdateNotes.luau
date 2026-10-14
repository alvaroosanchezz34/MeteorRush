--!strict

-- Notas de la actualización: al entrar con una versión que el jugador aún no ha visto se
-- muestran sus novedades una vez. A quien entra por primera vez no se le enseñan (ya tiene
-- el tutorial); solo se apunta la versión. `onClosed` se llama al cerrarlas, o enseguida si no
-- hay nada que enseñar: así las ofertas de bienvenida salen después.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveOps = require(Shared:WaitForChild("Config"):WaitForChild("LiveOps"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))

-- Segundos que se espera antes de `onClosed` cuando no hay notas que enseñar.
local NOTHING_TO_SHOW_DELAY = 3

local UpdateNotes = {}

-- Muestra las notas de la versión actual si el jugador no las ha visto.
function UpdateNotes.Show(data: Types.Profile, onClosed: (() -> ())?)
    local function done()
        if onClosed then
            task.spawn(onClosed)
        end
    end
    -- Sin notas que enseñar, lo siguiente espera un poco: que primero se vea el juego.
    local function doneLater()
        if onClosed then
            task.delay(NOTHING_TO_SHOW_DELAY, onClosed)
        end
    end
    if data.seenVersion == LiveOps.Version then
        doneLater()
        return
    end
    if data.playtime <= 0 then
        Remotes.AckVersion:FireServer()
        doneLater()
        return
    end

    local release = LiveOps.Releases[1]
    local gui = Instance.new("ScreenGui")
    -- Los textos ya salen en el idioma elegido: sin traducción automática de Roblox.
    gui.AutoLocalize = false
    gui.Name = "UpdateNotes"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 15

    local panel = Components.Glass({
        size = UDim2.fromScale(0.42, 0.5),
        position = UDim2.fromScale(0.5, 0.5),
        anchor = Vector2.new(0.5, 0.5),
        accent = Theme.Colors.Accent,
        radius = Theme.Radius.Window,
        parent = gui,
    })
    panel.BackgroundTransparency = 0.06
    panel.Active = true
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1.35
    aspect.Parent = panel
    -- Entra con un pequeño rebote.
    local scale = Instance.new("UIScale")
    scale.Scale = 0.6
    scale.Parent = panel
    TweenService:Create(
        scale,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    ):Play()
    Components.Label({
        text = "📰",
        size = UDim2.fromScale(0.12, 0.14),
        position = UDim2.fromScale(0.05, 0.05),
        parent = panel,
    })
    Components.Label({
        text = function(): string
            return Strings.Upper(string.format(Strings.LiveOps.WhatsNew, release.version))
        end,
        size = UDim2.fromScale(0.76, 0.12),
        position = UDim2.fromScale(0.19, 0.06),
        alignment = Enum.TextXAlignment.Left,
        color = Theme.Colors.Accent,
        heading = true,
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
            done()
        end,
    })

    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return UpdateNotes
