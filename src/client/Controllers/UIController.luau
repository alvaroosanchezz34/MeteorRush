--!strict

-- Monta el HUD cuando llegan los datos del jugador, añade la etiqueta [VIP] en el chat
-- y activa el cielo especial durante el evento del meteorito gigante.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DataController = require(script.Parent.DataController)
local Hud = require(script.Parent.Parent.UI.Hud)
local Sound = require(script.Parent.Parent.UI.Sound)

local VIP_TAG = "<font color='#FFD700'>[VIP]</font> "
local GIANT_TINT = Color3.fromRGB(205, 170, 255)

local UIController = {}

local function setupVipTag()
    TextChatService.OnIncomingMessage = function(
        message: TextChatMessage
    ): TextChatMessageProperties?
        local source = message.TextSource
        if not source then
            return nil
        end
        local player = Players:GetPlayerByUserId(source.UserId)
        if player == nil or player:GetAttribute("VIP") ~= true then
            return nil
        end
        local properties = Instance.new("TextChatMessageProperties")
        properties.PrefixText = VIP_TAG .. message.PrefixText
        return properties
    end
end

local function setupGiantSky()
    local effect = Instance.new("ColorCorrectionEffect")
    effect.Name = "GiantMeteorTint"
    effect.TintColor = Color3.new(1, 1, 1)
    effect.Parent = Lighting

    local function update()
        local active = Workspace:GetAttribute("GiantActive") == true
        TweenService:Create(effect, TweenInfo.new(2), {
            TintColor = if active then GIANT_TINT else Color3.new(1, 1, 1),
            Saturation = if active then 0.2 else 0,
        }):Play()
    end
    Workspace:GetAttributeChangedSignal("GiantActive"):Connect(update)
    update()
end

local function setupDataSounds()
    local lastCoins: number? = nil
    local lastInventory: number? = nil
    DataController.OnChanged("coins", function(coins: number)
        if lastCoins and coins > lastCoins then
            Sound.Play("Collect")
        end
        lastCoins = coins
    end)
    DataController.OnChanged("inventory", function(inventory: { any })
        if lastInventory and #inventory > lastInventory then
            Sound.Play("Deposit")
        end
        lastInventory = #inventory
    end)
    DataController.OnReady(function(data)
        lastCoins = data.coins
        lastInventory = #data.inventory
    end)
end

function UIController.Start()
    setupDataSounds()
    setupVipTag()
    setupGiantSky()
    Sound.StartMusic()
    DataController.OnReady(function()
        Hud.Mount()
    end)
end

return UIController
