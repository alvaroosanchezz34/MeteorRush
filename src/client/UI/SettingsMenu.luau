--!strict

-- Ajustes: por ahora, el idioma. Cambiarlo repinta el juego al momento, sin reiniciar, y el
-- servidor lo guarda para las próximas sesiones. Solo cambia los textos, nunca el progreso.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local Notifications = require(script.Parent.Notifications)
local LanguageController = require(script.Parent.Parent.Controllers.LanguageController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared:WaitForChild("Locale"))
local Strings = require(Shared:WaitForChild("Strings"))

local SettingsMenu = {}

function SettingsMenu.Mount(window: Components.Window)
    Components.Label({
        text = function(): string
            return Strings.Settings.Language
        end,
        size = UDim2.fromScale(1, 0.09),
        alignment = Enum.TextXAlignment.Left,
        heading = true,
        parent = window.content,
    })
    Components.Label({
        text = function(): string
            return Strings.Settings.LanguageHint
        end,
        size = UDim2.fromScale(1, 0.07),
        position = UDim2.fromScale(0, 0.1),
        alignment = Enum.TextXAlignment.Left,
        color = Components.Colors.Muted,
        parent = window.content,
    })

    -- Un botón por idioma; el activo, resaltado y con la marca de activo debajo.
    local buttons: { [string]: TextButton } = {}
    local marks: { [string]: TextLabel } = {}
    for index, language in Locale.Languages do
        local x = 0.02 + (index - 1) * 0.5
        buttons[language] = Components.Button({
            -- El nombre de cada idioma se escribe siempre en ese idioma.
            text = Locale.LanguageNames[language] or language,
            size = UDim2.fromScale(0.46, 0.16),
            position = UDim2.fromScale(x, 0.22),
            color = Components.Colors.PanelRaised,
            parent = window.content,
            onClick = function()
                if language == Locale.GetCurrentLanguage() then
                    return
                end
                LanguageController.SetLanguage(language)
                -- Confirmación ya en el idioma nuevo.
                Notifications.Show(
                    string.format(
                        Strings.Settings.Changed,
                        Locale.LanguageNames[language] or language
                    ),
                    nil,
                    "success"
                )
            end,
        })
        marks[language] = Components.Label({
            text = function(): string
                return Strings.Settings.Active
            end,
            size = UDim2.fromScale(0.46, 0.06),
            position = UDim2.fromScale(x, 0.39),
            color = Components.Colors.Success,
            parent = window.content,
        })
    end

    local function refresh()
        local current = Locale.GetCurrentLanguage()
        for language, button in buttons do
            local active = language == current
            button.BackgroundColor3 = if active
                then Components.Colors.Primary
                else Components.Colors.PanelRaised
            marks[language].Visible = active
        end
    end
    refresh()
    window.OnOpened(refresh)
    Locale.OnChanged(refresh)
end

return SettingsMenu
