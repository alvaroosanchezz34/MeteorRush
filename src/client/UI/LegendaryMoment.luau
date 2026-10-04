--!strict

-- Aviso de momento legendario: lo ve todo el servidor cuando alguien consigue algo
-- extremadamente raro. Tres líneas en la parte alta de la pantalla (qué ha pasado, quién y
-- qué), con sonido, un destello leve y destellos alrededor. Si llegan varios, van en cola.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Components = require(script.Parent.Components)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)
local Theme = require(script.Parent.Theme)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Minerals = require(Config:WaitForChild("Minerals"))
local MomentsConfig = require(Config:WaitForChild("Moments"))
local Mutations = require(Config:WaitForChild("Mutations"))
local Strings = require(Shared:WaitForChild("Strings"))

type Moment = { heading: string, who: string, what: string, color: Color3 }

local SHOWN_Y = 0.13
local HIDDEN_Y = -0.2
local SPARKS = 12

local LegendaryMoment = {}

local gui: ScreenGui? = nil
local queue: { Moment } = {}
local showing = false

local function getGui(): ScreenGui
    if gui then
        return gui
    end
    local created = Instance.new("ScreenGui")
    created.Name = "LegendaryMoment"
    created.ResetOnSpawn = false
    created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    created.DisplayOrder = 25
    created.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    gui = created
    return created
end

local function display(moment: Moment)
    local screen = getGui()
    local panel = Components.Panel({
        size = UDim2.fromScale(0.5, 0.19),
        position = UDim2.fromScale(0.5, HIDDEN_Y),
        color = Theme.Colors.Background,
        transparency = 0.08,
        parent = screen,
    })
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    local stroke = panel:FindFirstChildOfClass("UIStroke")
    if stroke then
        stroke.Color = moment.color
        stroke.Thickness = 4
        stroke.Transparency = 0
    end

    Components.Label({
        text = moment.heading,
        size = UDim2.fromScale(0.92, 0.26),
        position = UDim2.fromScale(0.04, 0.07),
        color = Theme.Colors.Gold,
        heading = true,
        parent = panel,
    })
    Components.Label({
        text = moment.who,
        size = UDim2.fromScale(0.92, 0.2),
        position = UDim2.fromScale(0.04, 0.35),
        parent = panel,
    })
    Components.Label({
        text = moment.what,
        size = UDim2.fromScale(0.92, 0.36),
        position = UDim2.fromScale(0.04, 0.57),
        color = moment.color,
        heading = true,
        parent = panel,
    })

    Sound.Play("LegendaryMoment", { duck = true })
    Effects.Flash(moment.color, 0.12, 0.8)
    TweenService:Create(panel, Theme.Motion.Open, { Position = UDim2.fromScale(0.5, SHOWN_Y) })
        :Play()
    -- Destellos que salen del aviso.
    for index = 1, SPARKS do
        local angle = index / SPARKS * math.pi * 2
        local spark = Components.Label({
            text = "✦",
            size = UDim2.fromScale(0.025, 0.045),
            position = UDim2.fromScale(0.5, SHOWN_Y),
            color = moment.color,
            parent = screen,
        })
        spark.AnchorPoint = Vector2.new(0.5, 0.5)
        local tween = TweenService:Create(
            spark,
            TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                Position = UDim2.fromScale(
                    0.5 + math.cos(angle) * 0.3,
                    SHOWN_Y + math.sin(angle) * 0.16
                ),
                TextTransparency = 1,
                Rotation = 180,
            }
        )
        tween.Completed:Connect(function()
            spark:Destroy()
        end)
        tween:Play()
    end

    task.wait(MomentsConfig.BannerSeconds)
    local out = TweenService:Create(
        panel,
        Theme.Motion.Close,
        { Position = UDim2.fromScale(0.5, HIDDEN_Y) }
    )
    out:Play()
    out.Completed:Wait()
    panel:Destroy()
end

-- Muestra el momento que envía el servidor.
function LegendaryMoment.Show(playerName: any, kind: any, mineralId: any, mutationId: any)
    if type(playerName) ~= "string" or type(kind) ~= "string" then
        return
    end
    local text = Strings.Moments[kind]
    if text == nil then
        return
    end
    local color = Theme.Colors.Gold
    local what = text.What
    if kind == "discovery" then
        local mineral = if type(mineralId) == "string" then Minerals.ById[mineralId] else nil
        local mutation = if type(mutationId) == "string" then Mutations.ById[mutationId] else nil
        if mineral == nil then
            return
        end
        color = (if mutation then mutation.color else nil)
            or Minerals.Rarities[mineral.rarity].color
        what =
            string.upper(Strings.MineralName(mineral.id, if mutation then mutation.id else "none"))
    end
    table.insert(queue, {
        heading = text.Heading,
        who = string.format(text.Who, playerName),
        what = what,
        color = color,
    })
    if showing then
        return
    end
    showing = true
    task.spawn(function()
        while #queue > 0 do
            display(table.remove(queue, 1) :: Moment)
        end
        showing = false
    end)
end

return LegendaryMoment
