--!strict

-- Idioma de cada jugador. Solo decide en qué idioma se muestran los textos: ninguna regla,
-- recompensa ni precio depende de él.
--
-- - Si el jugador eligió idioma en Ajustes, se usa ese (guardado en settings.language).
-- - Si no, el de su cuenta de Roblox en esta sesión: español → "es", cualquier otro → "en".
--   No se guarda, así que si cambia el idioma de su cuenta, el juego lo sigue.
-- - Elegir a mano siempre gana a lo detectado, y la última elección es la que vale.
--
-- El idioma efectivo se publica en el atributo `Language` del jugador (Locale.Attribute), que
-- lee su cliente y que usa el servidor para los mensajes de expulsión.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)

local Shared = ReplicatedStorage.Shared
local Locale = require(Shared.Locale)
local Log = require(Shared.Util.Log)
local Network = require(Shared.Config.Network)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local LanguageService = {}

local limiter = RateLimiter.new(Network.RateLimits.SetLanguage)
-- Idioma que manda el cliente al entrar (el de su cuenta), por si el servidor no puede leerlo.
local detected: { [Player]: string } = {}
-- Elección hecha antes de que cargue el perfil: se guarda al cargar.
local pending: { [Player]: string } = {}

local function savedLanguage(data: Types.Profile?): string?
    local settings = if data then data.settings else nil
    local language = if settings then settings.language else nil
    return if Locale.IsSupported(language) then language else nil
end

local function detectedLanguage(player: Player): string
    local hint = detected[player]
    if hint then
        return hint
    end
    local ok, localeId = pcall(function(): string
        return player.LocaleId
    end)
    return Locale.FromLocaleId(if ok then localeId else nil)
end

local function publish(player: Player, language: string)
    if player:GetAttribute(Locale.Attribute) ~= language then
        player:SetAttribute(Locale.Attribute, language)
    end
end

local function save(player: Player, language: string): boolean
    return DataService.Update(player, "settings", function(settings: Types.SettingsData?)
        local updated = if type(settings) == "table" then settings else { language = "" }
        updated.language = language
        return updated
    end)
end

-- Idioma efectivo de ese jugador ahora mismo.
function LanguageService.Get(player: Player): string
    return Locale.GetCurrentLanguage(player)
end

-- Guarda la elección del jugador y la aplica. Devuelve false si el idioma no es válido.
function LanguageService.Set(player: Player, language: any): boolean
    if not Locale.IsSupported(language) then
        return false
    end
    if not save(player, language) then
        pending[player] = language
    end
    publish(player, language)
    return true
end

function LanguageService.Init()
    Players.PlayerAdded:Connect(function(player: Player)
        -- Antes de cargar el perfil: el de la cuenta, para que hasta los avisos de carga salgan
        -- en su idioma.
        publish(player, detectedLanguage(player))
    end)
    for _, player in Players:GetPlayers() do
        publish(player, detectedLanguage(player))
    end
    Players.PlayerRemoving:Connect(function(player: Player)
        detected[player] = nil
        pending[player] = nil
    end)

    DataService.OnProfileLoaded(function(player: Player, data: Types.Profile)
        local chosen = pending[player]
        pending[player] = nil
        if chosen then
            save(player, chosen)
            publish(player, chosen)
            return
        end
        publish(player, savedLanguage(data) or detectedLanguage(player))
    end)

    -- language: "es" / "en". auto = true cuando es el idioma de la cuenta que el cliente
    -- manda al entrar; solo se usa si el jugador no ha elegido ninguno.
    Remotes.SetLanguage.OnServerEvent:Connect(function(player: Player, language: any, auto: any)
        if not limiter.Check(player) then
            return
        end
        if not Locale.IsSupported(language) then
            Log.Suspicious(player, "SetLanguage", tostring(language))
            return
        end
        if auto == true then
            detected[player] = language
            if pending[player] == nil and savedLanguage(DataService.GetData(player)) == nil then
                publish(player, language)
            end
            return
        end
        LanguageService.Set(player, language)
    end)
end

return LanguageService
