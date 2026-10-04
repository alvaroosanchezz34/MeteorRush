--!strict

-- Sonidos del juego. Un id tiene el formato "rbxassetid://123" (Creator Store) o
-- "rbxasset://sounds/..." (sonidos que trae el cliente de Roblox, provisionales).
-- Si un id está vacío o no existe, ese sonido simplemente no suena.
-- Los reproduce AudioManager (cliente), que es el único sitio que crea sonidos.

local Sounds = {
    MeteorWarning = "rbxasset://sounds/electronicpingshort.wav",
    -- Aviso de meteorito grande o especial, y alarma del gigante.
    BigWarning = "rbxasset://sounds/electronicpingshort.wav",
    GiantWarning = "rbxasset://sounds/bass.wav",
    -- Rayos en el cielo durante el gigante y su rotura final.
    Lightning = "rbxasset://sounds/flashbulb.wav",
    GiantBreak = "rbxasset://sounds/impact_explosion_03.mp3",
    MeteorImpact = "rbxasset://sounds/impact_explosion_03.mp3",
    -- Impacto del meteorito gigante: el mismo, más grave y más fuerte.
    GiantImpact = "rbxasset://sounds/impact_explosion_03.mp3",
    -- Meteorito agotado, que se deshace.
    MeteorBreak = "rbxasset://sounds/collide.wav",
    -- "Pickaxe Hit", de la Creator Store.
    MineHit = "rbxassetid://9120146349",
    -- "gem collect", de la Creator Store.
    MineralObtained = "rbxassetid://11439707919",
    -- Mineral Raro o superior, mutación, mineral doble y Star Heart.
    -- Cada rareza suena más especial que la anterior: Raro, Épico, Legendario y Mítico.
    RareFind = "rbxasset://sounds/electronicpingshort.wav",
    EpicFind = "rbxasset://sounds/electronicpingshort.wav",
    LegendaryFind = "rbxasset://sounds/victory.wav",
    -- Aviso a todo el servidor de un momento legendario.
    LegendaryMoment = "rbxasset://sounds/victory.wav",
    -- Temblor lejano antes de que caiga un meteorito de evento.
    GiantRumble = "rbxasset://sounds/bass.wav",
    -- Sonido ambiental en bucle de los minerales más raros. Vacíos: hace falta un sonido
    -- pensado para sonar en bucle, y entre los que trae Roblox no hay ninguno.
    AmbientEpic = "",
    AmbientLegendary = "",
    AmbientMythic = "",
    -- Una por mutación: brillante, electrónica y, para el Arcoíris, la más especial.
    MutationGold = "rbxasset://sounds/flashbulb.wav",
    MutationRadioactive = "rbxasset://sounds/electronicpingshort.wav",
    MutationRainbow = "rbxasset://sounds/victory.wav",
    DoubleMineral = "rbxasset://sounds/snap.wav",
    MythicFind = "rbxasset://sounds/victory.wav",
    Deposit = "rbxasset://sounds/unsheath.wav",
    -- Recoger un mineral del suelo y colocar uno en un pedestal: uno para lo corriente y otro
    -- para lo especial, con el tono más agudo cuanto más raro (Config/RarityFx.Audio).
    Pickup = "rbxasset://sounds/clickfast.wav",
    PickupSpecial = "rbxasset://sounds/electronicpingshort.wav",
    PlaceSpecial = "rbxasset://sounds/flashbulb.wav",
    -- Mochila casi llena y llena del todo.
    BackpackNearFull = "rbxasset://sounds/button.wav",
    BackpackFull = "rbxasset://sounds/bass.wav",
    -- "bling_diamond_pickup_2", de la Creator Store: al colocar un mineral en un pedestal.
    Place = "rbxassetid://4612374393",
    Collect = "rbxasset://sounds/clickfast.wav",
    Hit = "rbxasset://sounds/swordslash.wav",
    Purchase = "rbxasset://sounds/victory.wav",
    Rebirth = "rbxasset://sounds/victory.wav",
    QuestComplete = "rbxasset://sounds/electronicpingshort.wav",
    EventStart = "rbxasset://sounds/bass.wav",
    UiClick = "rbxasset://sounds/switch.wav",
    UiOpen = "rbxasset://sounds/switch.wav",
    UiClose = "rbxasset://sounds/switch.wav",
    -- Aviso de éxito, aviso de error y confirmación de una acción importante.
    UiSuccess = "rbxasset://sounds/electronicpingshort.wav",
    UiError = "rbxasset://sounds/button.wav",
    UiConfirm = "rbxasset://sounds/snap.wav",
    -- Objetivo secreto conseguido.
    Secret = "rbxasset://sounds/victory.wav",
    -- Equipamiento y cajas (provisionales, como el resto de sonidos del cliente de Roblox).
    EquipGear = "rbxasset://sounds/snap.wav",
    CritHit = "rbxasset://sounds/flashbulb.wav",
    DustFound = "rbxasset://sounds/electronicpingshort.wav",
    CrateAppear = "rbxasset://sounds/switch.wav",
    CrateShake = "rbxasset://sounds/collide.wav",
    CrateCharge = "rbxasset://sounds/bass.wav",
    CrateOpen = "rbxasset://sounds/impact_explosion_03.mp3",
    RevealCommon = "rbxasset://sounds/electronicpingshort.wav",
    RevealRare = "rbxasset://sounds/electronicpingshort.wav",
    RevealEpic = "rbxasset://sounds/flashbulb.wav",
    RevealLegendary = "rbxasset://sounds/victory.wav",
    RevealMythic = "rbxasset://sounds/victory.wav",
    Stun = "rbxasset://sounds/flashbulb.wav",
    VoidPulse = "rbxasset://sounds/bass.wav",
    StealMoment = "rbxasset://sounds/victory.wav",
    -- Aviso grande de nuevo descubrimiento o de logro.
    Banner = "rbxasset://sounds/victory.wav",
}

-- Volumen de cada sonido (0-1). Los que no aparecen usan DefaultVolume.
local Volume: { [string]: number } = {
    MeteorImpact = 0.8,
    BigWarning = 0.7,
    GiantWarning = 1,
    Lightning = 0.2,
    GiantBreak = 0.9,
    GiantImpact = 1,
    MeteorBreak = 0.6,
    MineHit = 0.7,
    MineralObtained = 0.3,
    RareFind = 0.5,
    EpicFind = 0.65,
    LegendaryFind = 0.8,
    LegendaryMoment = 1,
    GiantRumble = 0.8,
    AmbientEpic = 0.15,
    AmbientLegendary = 0.2,
    AmbientMythic = 0.3,
    MutationGold = 0.5,
    MutationRadioactive = 0.6,
    MutationRainbow = 0.85,
    DoubleMineral = 0.5,
    MythicFind = 0.9,
    BackpackNearFull = 0.35,
    BackpackFull = 0.6,
    Collect = 0.3,
    Pickup = 0.4,
    PickupSpecial = 0.5,
    PlaceSpecial = 0.5,
    Place = 0.4,
    Rebirth = 0.8,
    QuestComplete = 0.5,
    EventStart = 0.7,
    UiClick = 0.4,
    UiOpen = 0.3,
    UiClose = 0.25,
    UiSuccess = 0.3,
    UiError = 0.35,
    UiConfirm = 0.5,
}

-- Tono (PlaybackSpeed). Permite distinguir sonidos que comparten archivo. Los que no
-- aparecen suenan a su tono normal.
local Pitch: { [string]: number } = {
    GiantImpact = 0.65,
    BigWarning = 0.75,
    GiantWarning = 0.6,
    Lightning = 0.7,
    GiantBreak = 0.85,
    MeteorBreak = 0.7,
    RareFind = 1.35,
    EpicFind = 1,
    LegendaryFind = 1.15,
    LegendaryMoment = 0.6,
    GiantRumble = 0.45,
    MutationGold = 1.3,
    MutationRadioactive = 0.55,
    MutationRainbow = 1.35,
    DoubleMineral = 1.4,
    MythicFind = 0.8,
    BackpackNearFull = 1.3,
    BackpackFull = 0.9,
    Rebirth = 0.7,
    Secret = 0.9,
    QuestComplete = 1.6,
    EventStart = 0.8,
    UiOpen = 1.25,
    UiClose = 0.8,
    UiSuccess = 1.5,
    UiError = 0.6,
    UiConfirm = 1.1,
    Banner = 1.1,
}

-- Variación aleatoria del tono (±fracción) para que los sonidos muy repetidos no cansen.
local PitchVariation: { [string]: number } = {
    MineHit = 0.12,
    MineralObtained = 0.08,
    Collect = 0.1,
    UiClick = 0.05,
    UiSuccess = 0.4,
    UiError = 0.4,
}

-- Segundos mínimos entre dos reproducciones del mismo sonido (evita que se amontonen).
local Cooldown: { [string]: number } = {
    MineralObtained = 0.05,
    Lightning = 0.5,
    Collect = 0.12,
    Place = 0.25,
    PlaceSpecial = 0.25,
    RareFind = 0.3,
    EpicFind = 0.3,
    MutationGold = 0.3,
    MutationRadioactive = 0.3,
    UiClick = 0.05,
}

-- Música de fondo: las pistas suenan una detrás de otra, en bucle.
-- Son pistas con licencia de la Creator Store (DistroKid).
local Music = {
    Volume = 0.2,
    -- Fracción del volumen a la que baja la música durante un sonido importante, y segundos.
    DuckVolume = 0.35,
    DuckSeconds = 2.5,
    -- Música de evento (meteorito gigante). Con un id aquí, suena esa pista en bucle mientras
    -- dura; si está vacío, la música normal baja de tono para sonar más grave y tensa.
    EventTrack = "",
    EventPitch = 0.82,
    Tracks = {
        "rbxassetid://85922328966318", -- Galactic Market
        "rbxassetid://136898642923218", -- Cosmic Cafe
        "rbxassetid://102039057339088", -- Zero Gravity
    },
}

return {
    Ids = Sounds :: { [string]: string },
    Volume = Volume,
    Pitch = Pitch,
    PitchVariation = PitchVariation,
    Cooldown = Cooldown,
    DefaultVolume = 0.5,
    Music = Music,
}
