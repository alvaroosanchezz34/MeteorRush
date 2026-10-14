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
local DEPOSIT_COLOR = Color3.fromRGB(46, 196, 128)

local UIController = {}

-- Pies del personaje del jugador, o nil si no tiene.
local function feetPosition(): Vector3?
    local character = Players.LocalPlayer.Character
    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
    if root and root:IsA("BasePart") then
        return root.Position - Vector3.new(0, 2.8, 0)
    end
    return nil
end

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
            -- Anillo verde a los pies y destellos que suben: lo que llevabas ya está a salvo.
            local feet = feetPosition()
            if feet then
                Effects.Shockwave({ position = feet, radius = 6, color = DEPOSIT_COLOR })
                Effects.Burst({
                    position = feet + Vector3.new(0, 1.5, 0),
                    color = ColorSequence.new(DEPOSIT_COLOR, Color3.new(1, 1, 1)),
                    count = 6 + math.min(#inventory - lastInventory, 10) * 2,
                    speed = 8,
                    size = 0.4,
                })
            end
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
            -- Dos ondas doradas y una columna de destellos alrededor del personaje.
            local feet = feetPosition()
            if feet then
                for index = 1, 2 do
                    task.delay((index - 1) * 0.2, Effects.Shockwave, {
                        position = feet,
                        radius = 10 + index * 6,
                        color = if index == 1 then REBIRTH_COLOR else Color3.new(1, 1, 1),
                        duration = 0.8,
                        ignoreDistance = true,
                    })
                end
                Effects.Burst({
                    position = feet + Vector3.new(0, 3, 0),
                    color = ColorSequence.new(REBIRTH_COLOR, Color3.new(1, 1, 1)),
                    count = 40,
                    speed = 18,
                    size = 0.7,
                    lifetime = 1.4,
                    ignoreDistance = true,
                })
                Effects.Sparks({
                    position = feet + Vector3.new(0, 2, 0),
                    direction = Vector3.yAxis,
                    color = REBIRTH_COLOR,
                    count = 10,
                    length = 9,
                })
            end
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
