--!strict

-- Idioma en el cliente: lo detecta al entrar, sigue lo que decide el servidor (atributo
-- `Language` del jugador), deja cambiarlo desde Ajustes y pinta en el idioma elegido los textos
-- del mundo que el servidor marca con Locale.Tag (carteles, nombres de NPC, avisos de acción).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared:WaitForChild("Locale"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local LanguageController = {}

local localPlayer = Players.LocalPlayer

-- Idioma de la cuenta de Roblox del jugador (o del sistema si no se puede leer).
local function detect(): string
    for _, read in
        {
            function(): string
                return localPlayer.LocaleId
            end,
            function(): string
                return LocalizationService.RobloxLocaleId
            end,
            function(): string
                return LocalizationService.SystemLocaleId
            end,
        }
    do
        local ok, localeId = pcall(read)
        if ok and type(localeId) == "string" and localeId ~= "" then
            return Locale.FromLocaleId(localeId)
        end
    end
    return Locale.Default
end

-- Textos del mundo ---------------------------------------------------------------------

local function decode(value: string): Locale.Message
    if string.sub(value, 1, 1) ~= "{" then
        return value
    end
    local ok, decoded = pcall(function(): any
        return HttpService:JSONDecode(value)
    end)
    return if ok then decoded else value
end

local function paint(instance: Instance)
    for name, value in instance:GetAttributes() do
        if
            type(value) == "string"
            and string.sub(name, 1, #Locale.AttributePrefix) == Locale.AttributePrefix
        then
            local property = string.sub(name, #Locale.AttributePrefix + 1)
            local text = Locale.Resolve(decode(value))
            local target: any = instance
            local ok, currentText = pcall(function(): any
                return target[property]
            end)
            if ok and currentText ~= text then
                pcall(function()
                    target[property] = text
                end)
            end
        end
    end
end

local watched: { [Instance]: { RBXScriptConnection } } = {}

local function watch(instance: Instance)
    if watched[instance] then
        return
    end
    local connections: { RBXScriptConnection } = {}
    watched[instance] = connections
    -- La traducción automática de Roblox no debe tocar un texto que ya está en el idioma
    -- elegido (si no, podría traducir el inglés de quien ha elegido inglés a mano).
    pcall(function()
        (instance :: any).AutoLocalize = false
    end)
    -- El servidor cambia el atributo (y el texto en inglés): se vuelve a pintar.
    table.insert(
        connections,
        instance.AttributeChanged:Connect(function(name: string)
            if string.sub(name, 1, #Locale.AttributePrefix) == Locale.AttributePrefix then
                paint(instance)
            end
        end)
    )
    for name in instance:GetAttributes() do
        if string.sub(name, 1, #Locale.AttributePrefix) == Locale.AttributePrefix then
            local property = string.sub(name, #Locale.AttributePrefix + 1)
            local ok, signal = pcall(function(): RBXScriptSignal
                return instance:GetPropertyChangedSignal(property)
            end)
            if ok then
                table.insert(
                    connections,
                    signal:Connect(function()
                        paint(instance)
                    end)
                )
            end
        end
    end
    paint(instance)
end

local function unwatch(instance: Instance)
    local connections = watched[instance]
    if connections then
        for _, connection in connections do
            connection:Disconnect()
        end
        watched[instance] = nil
    end
end

-- Cambio de idioma ---------------------------------------------------------------------

-- Cambia el idioma ya (sin esperar al servidor) y pide al servidor que lo guarde.
function LanguageController.SetLanguage(language: string)
    if not Locale.IsSupported(language) then
        return
    end
    Locale.SetCurrent(language)
    Remotes.SetLanguage:FireServer(language)
end

function LanguageController.GetLanguage(): string
    return Locale.GetCurrentLanguage()
end

function LanguageController.Init()
    -- Hasta que conteste el servidor, el de la cuenta (o el que ya haya publicado).
    local fromServer = localPlayer:GetAttribute(Locale.Attribute)
    local detected = detect()
    Locale.SetCurrent(if Locale.IsSupported(fromServer) then fromServer :: string else detected)
    Remotes.SetLanguage:FireServer(detected, true)

    localPlayer:GetAttributeChangedSignal(Locale.Attribute):Connect(function()
        local language = localPlayer:GetAttribute(Locale.Attribute)
        if Locale.IsSupported(language) then
            Locale.SetCurrent(language :: string)
        end
    end)

    for _, instance in CollectionService:GetTagged(Locale.WorldTag) do
        watch(instance)
    end
    CollectionService:GetInstanceAddedSignal(Locale.WorldTag):Connect(watch)
    CollectionService:GetInstanceRemovedSignal(Locale.WorldTag):Connect(unwatch)
    Locale.OnChanged(function()
        for instance in watched do
            paint(instance)
        end
    end)
end

return LanguageController
