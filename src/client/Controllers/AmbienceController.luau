--!strict

-- Ambiente del mapa: iluminación, niebla y corrección de color según lo que esté pasando.
-- El estado normal es el que hay en Lighting al arrancar (default.project.json); encima se
-- aplican "ambientes" con una transición suave:
--   * meteorito gigante anunciado → empieza a teñirse de morado
--   * eclipse (suceso ambiental) → el mapa se oscurece con un tono rojizo
--   * meteorito gigante en el suelo → morado cósmico
--   * Supernova → el mapa se va encendiendo poco a poco en tonos cálidos
--   * otros eventos con color propio (atributo `EventTint`) → tinte ligero
-- Solo cambia propiedades de efectos que ya existen; no crea luces ni partículas.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

type Mood = {
    ambient: Color3?,
    outdoorAmbient: Color3?,
    exposure: number?,
    tint: Color3?,
    saturation: number?,
    contrast: number?,
    atmosphereColor: Color3?,
    atmosphereDecay: Color3?,
    haze: number?,
    bloom: number?,
    -- Segundos de la transición hacia este ambiente.
    seconds: number,
}

local SUPERNOVA_EVENT = "supernova"

local MOODS: { [string]: Mood } = {
    -- Anuncio del gigante: un cambio ligero, que se completa cuando cae.
    giantIncoming = {
        tint = Color3.fromRGB(232, 215, 255),
        saturation = 0.22,
        atmosphereColor = Color3.fromRGB(140, 105, 215),
        haze = 2,
        seconds = 2.5,
    },
    giant = {
        ambient = Color3.fromRGB(95, 60, 150),
        outdoorAmbient = Color3.fromRGB(140, 100, 205),
        tint = Color3.fromRGB(215, 185, 255),
        saturation = 0.3,
        contrast = 0.2,
        atmosphereColor = Color3.fromRGB(150, 95, 230),
        atmosphereDecay = Color3.fromRGB(70, 35, 130),
        haze = 2.4,
        bloom = 1,
        seconds = 3,
    },
    eclipse = {
        ambient = Color3.fromRGB(40, 30, 50),
        outdoorAmbient = Color3.fromRGB(75, 55, 80),
        exposure = -0.25,
        tint = Color3.fromRGB(255, 200, 175),
        contrast = 0.22,
        atmosphereColor = Color3.fromRGB(120, 60, 60),
        seconds = 5,
    },
    -- Transición larga: el mapa se enciende progresivamente mientras dura el evento.
    supernova = {
        ambient = Color3.fromRGB(150, 110, 85),
        outdoorAmbient = Color3.fromRGB(230, 180, 140),
        exposure = 0.75,
        tint = Color3.fromRGB(255, 225, 195),
        saturation = 0.35,
        contrast = 0.18,
        atmosphereColor = Color3.fromRGB(255, 170, 110),
        atmosphereDecay = Color3.fromRGB(150, 70, 40),
        haze = 2.6,
        bloom = 1.15,
        seconds = 12,
    },
}

local AmbienceController = {}

local colorCorrection: ColorCorrectionEffect
local atmosphere: Atmosphere?
local bloom: BloomEffect?
-- Valores normales, leídos al arrancar.
local base: Mood
local currentKey = "default"
-- Ambientes pedidos por otros controladores (el anuncio de un meteorito gigante, un eclipse).
-- Si hay varios activos, gana el que va antes en esta lista.
local OVERRIDE_PRIORITY = { "giantIncoming", "eclipse" }
local overrides: { [string]: boolean } = {}

local function activeOverride(): string?
    for _, name in OVERRIDE_PRIORITY do
        if overrides[name] and MOODS[name] then
            return name
        end
    end
    return nil
end

local function apply(mood: Mood)
    local info = TweenInfo.new(mood.seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    TweenService:Create(Lighting, info, {
        Ambient = mood.ambient or base.ambient,
        OutdoorAmbient = mood.outdoorAmbient or base.outdoorAmbient,
        ExposureCompensation = mood.exposure or base.exposure,
    }):Play()
    TweenService:Create(colorCorrection, info, {
        TintColor = mood.tint or base.tint,
        Saturation = mood.saturation or base.saturation,
        Contrast = mood.contrast or base.contrast,
    }):Play()
    if atmosphere then
        TweenService:Create(atmosphere, info, {
            Color = mood.atmosphereColor or base.atmosphereColor,
            Decay = mood.atmosphereDecay or base.atmosphereDecay,
            Haze = mood.haze or base.haze,
        }):Play()
    end
    if bloom then
        TweenService:Create(bloom, info, { Intensity = mood.bloom or base.bloom }):Play()
    end
end

local function update()
    local eventTint = Workspace:GetAttribute("EventTint")
    local key = "default"
    local mood: Mood = { seconds = 4 }
    if Workspace:GetAttribute("GiantActive") == true then
        key = "giant"
        mood = MOODS.giant
    elseif activeOverride() then
        key = activeOverride() :: string
        mood = MOODS[key]
    elseif
        Workspace:GetAttribute("EventId") == SUPERNOVA_EVENT
        and Workspace:GetAttribute("EventEndsAt") ~= nil
    then
        key = "supernova"
        mood = MOODS.supernova
    elseif typeof(eventTint) == "Color3" then
        key = "tint"
        mood = { tint = eventTint, saturation = (base.saturation or 0) + 0.15, seconds = 3 }
    end
    if key ~= currentKey then
        currentKey = key
        apply(mood)
    end
end

-- Activa o desactiva un ambiente de MOODS por su nombre. El gigante en el suelo manda sobre todos.
function AmbienceController.SetOverride(key: string, isActive: boolean)
    overrides[key] = if isActive then true else nil
    if base then
        update()
    end
end

function AmbienceController.Start()
    local grade = Lighting:FindFirstChild("Grade")
    if grade and grade:IsA("ColorCorrectionEffect") then
        colorCorrection = grade
    else
        colorCorrection = Instance.new("ColorCorrectionEffect")
        colorCorrection.Name = "Grade"
        colorCorrection.Parent = Lighting
    end
    atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    bloom = Lighting:FindFirstChildOfClass("BloomEffect")

    base = {
        ambient = Lighting.Ambient,
        outdoorAmbient = Lighting.OutdoorAmbient,
        exposure = Lighting.ExposureCompensation,
        tint = colorCorrection.TintColor,
        saturation = colorCorrection.Saturation,
        contrast = colorCorrection.Contrast,
        atmosphereColor = if atmosphere then atmosphere.Color else nil,
        atmosphereDecay = if atmosphere then atmosphere.Decay else nil,
        haze = if atmosphere then atmosphere.Haze else nil,
        bloom = if bloom then bloom.Intensity else nil,
        seconds = 4,
    }

    for _, attribute in { "GiantActive", "EventTint", "EventId", "EventEndsAt" } do
        Workspace:GetAttributeChangedSignal(attribute):Connect(update)
    end
    update()
end

return AmbienceController
