--!strict

-- Monta el HUD cuando llegan los datos del jugador, añade la etiqueta [VIP] en el chat
-- y pone los sonidos que dependen de cambios de datos. El ambiente del cielo lo lleva
-- AmbienceController.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local DataController = require(script.Parent.DataController)
local Effects = require(script.Parent.Parent.UI.Effects)
local EconomyPanel = require(script.Parent.Parent.UI.EconomyPanel)
local Hud = require(script.Parent.Parent.UI.Hud)
local InspectBase = require(script.Parent.Parent.UI.InspectBase)
local Sound = require(script.Parent.Parent.UI.Sound)
local UpdateNotes = require(script.Parent.Parent.UI.UpdateNotes)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local QuestsConfig = require(Shared:WaitForChild("Config"):WaitForChild("Quests"))
local Types = require(Shared:WaitForChild("Types"))

local VIP_TAG = "<font color='#FFD700'>[VIP]</font> "
local REBIRTH_COLOR = Color3.fromRGB(255, 200, 60)

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
    -- Rebirth: sonido propio, destello dorado y una sacudida corta.
    local lastRebirths: number? = nil
    DataController.OnChanged("rebirths", function(rebirths: number)
        if lastRebirths and rebirths > lastRebirths then
            Sound.Play("Rebirth", { duck = true })
            Effects.Flash(REBIRTH_COLOR, 0.35, 1.2)
            Effects.Shake(0.5, 0.5)
        end
        lastRebirths = rebirths
    end)

    -- Misión diaria completada: suena cuando una misión llega a su objetivo.
    local function completedQuests(quests: Types.QuestData): number
        local count = 0
        for _, quest in QuestsConfig.List do
            if (quests.progress[quest.id] or 0) >= quest.goal then
                count += 1
            end
        end
        return count
    end
    local lastQuests: number? = nil
    DataController.OnChanged("quests", function(quests: Types.QuestData)
        local count = completedQuests(quests)
        if lastQuests and count > lastQuests then
            Sound.Play("QuestComplete")
        end
        lastQuests = count
    end)

    -- Compra entregada (producto o pass).
    local lastPurchases: number? = nil
    DataController.OnChanged("purchases", function(purchases: { string })
        if lastPurchases and #purchases > lastPurchases then
            Sound.Play("Purchase", { duck = true })
        end
        lastPurchases = #purchases
    end)

    DataController.OnReady(function(data)
        lastCoins = data.coins
        lastInventory = #data.inventory
        lastRebirths = data.rebirths
        lastQuests = completedQuests(data.quests)
        lastPurchases = #data.purchases
    end)
end

function UIController.Start()
    setupDataSounds()
    setupVipTag()
    Sound.StartMusic()
    DataController.OnReady(function(data)
        Hud.Mount()
        InspectBase.Mount()
        UpdateNotes.Show(data)
        if RunService:IsStudio() then
            EconomyPanel.Mount()
        end
    end)
end

return UIController
