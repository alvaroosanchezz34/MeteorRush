--!strict

-- Secuencia de aparición de una mutación: texto, ráfaga, ondas, rayos, sonido y, para quien
-- la consigue, destello y sacudida (Config/MutationFx). Las mutaciones que se anuncian las
-- ven también los demás jugadores.
-- El efecto continuo del mineral mutado lo lleva RarityVisualController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent.Parent.UI.Effects)
local Sound = require(script.Parent.Parent.UI.Sound)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MutationFx = require(Config:WaitForChild("MutationFx"))
local Mutations = require(Config:WaitForChild("Mutations"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local RAINBOW = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.8, 1)),
    ColorSequenceKeypoint.new(0.25, Color3.fromHSV(0.2, 0.8, 1)),
    ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.45, 0.8, 1)),
    ColorSequenceKeypoint.new(0.75, Color3.fromHSV(0.7, 0.8, 1)),
    ColorSequenceKeypoint.new(1, Color3.fromHSV(0.9, 0.8, 1)),
})

local MutationFxController = {}

-- Secuencia al conseguir una mutación. `own` indica que la ha conseguido el jugador local:
-- solo entonces hay destello de pantalla y sacudida.
function MutationFxController.Reveal(position: Vector3, mutationId: string, own: boolean)
    local mutation = Mutations.ById[mutationId]
    local reveal = MutationFx.Reveals[mutationId]
    local text = Strings.MutationReveal[mutationId]
    if mutation == nil or reveal == nil or text == nil then
        return
    end
    local color = mutation.color or Color3.new(1, 1, 1)
    local isRainbow = mutation.style == "rainbow"

    Sound.Play(reveal.sound, { duck = own and reveal.flash > 0.2 })
    Effects.Popup({
        position = position + Vector3.new(0, 2.6, 0),
        text = text,
        color = color,
        height = reveal.textHeight,
        duration = 1.8,
        rise = 4,
    })
    Effects.Burst({
        position = position,
        color = if isRainbow then RAINBOW else color,
        count = reveal.burst,
        speed = 14,
        size = 0.6,
        lifetime = 1,
    })
    for index = 1, reveal.waves do
        task.delay((index - 1) * 0.18, Effects.Shockwave, {
            position = position,
            radius = 3 + index * 2,
            color = if isRainbow then Color3.fromHSV((index * 0.3) % 1, 0.8, 1) else color,
            duration = 0.5,
        })
    end
    for index = 1, reveal.rays do
        local angle = index / reveal.rays * math.pi * 2
        Effects.Ray({
            position = position,
            direction = Vector3.new(math.cos(angle), 0.35, math.sin(angle)).Unit,
            length = 7,
            color = if isRainbow then Color3.fromHSV(index / reveal.rays, 0.8, 1) else color,
        })
    end
    if own then
        if reveal.flash > 0 then
            Effects.Flash(color, reveal.flash, 0.7)
        end
        if reveal.shake > 0 then
            Effects.Shake(reveal.shake, 0.4)
        end
    end
end

-- Otro jugador ha conseguido una mutación de las que se anuncian: se ve su secuencia.
local function onMutationFound(player: any, position: any, mutationId: any)
    if
        player == Players.LocalPlayer
        or typeof(position) ~= "Vector3"
        or type(mutationId) ~= "string"
    then
        return
    end
    local camera = Workspace.CurrentCamera
    if camera and (camera.CFrame.Position - position).Magnitude <= MutationFx.AnnounceDistance then
        MutationFxController.Reveal(position, mutationId, false)
    end
end

function MutationFxController.Init()
    Remotes.MutationFound.OnClientEvent:Connect(onMutationFound)
end

return MutationFxController
