--!strict

-- Gestor central de audio del cliente: es el único sitio que crea y reproduce sonidos y
-- música. Lee todo de Config/Sounds (ids, volumen, tono, variación y espera mínima entre
-- repeticiones). Si un id está vacío, no hace nada.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sounds =
    require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Sounds"))

-- Segundos que se espera a que cargue una pista de música antes de pasar a la siguiente.
local MUSIC_LOAD_TIMEOUT = 15
local DUCK_TWEEN = TweenInfo.new(0.4)

export type Options = {
    -- Con una Part, suena en 3D desde ahí; si no, en toda la pantalla.
    parent: Instance?,
    -- Multiplicadores sobre el tono y el volumen de Config/Sounds.
    pitch: number?,
    volume: number?,
    -- Baja la música un momento para que este sonido destaque.
    duck: boolean?,
}

local AudioManager = {}

local random = Random.new()
local cache: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}
local music: Sound? = nil
local eventMusic: Sound? = nil
local eventActive = false
local duckToken = 0

local function getPitch(name: string, multiplier: number?): number
    local variation = Sounds.PitchVariation[name] or 0
    return (Sounds.Pitch[name] or 1)
        * (multiplier or 1)
        * (1 + random:NextNumber(-variation, variation))
end

-- Baja la música y la devuelve a su volumen pasados unos segundos.
local function duck()
    -- Con una pista de evento sonando, la que baja es esa.
    local track = if eventActive and eventMusic then eventMusic else music
    if track == nil then
        return
    end
    duckToken += 1
    local token = duckToken
    TweenService
        :Create(track, DUCK_TWEEN, { Volume = Sounds.Music.Volume * Sounds.Music.DuckVolume })
        :Play()
    task.delay(Sounds.Music.DuckSeconds, function()
        if token == duckToken then
            TweenService:Create(track, DUCK_TWEEN, { Volume = Sounds.Music.Volume }):Play()
        end
    end)
end

-- Reproduce un sonido de Config/Sounds. El segundo argumento puede ser directamente la Part
-- desde la que suena en 3D, o una tabla de opciones.
function AudioManager.Play(name: string, options: (Instance | Options)?)
    local soundId = Sounds.Ids[name]
    if soundId == nil or soundId == "" then
        return
    end
    local now = os.clock()
    local cooldown = Sounds.Cooldown[name]
    if cooldown and now - (lastPlayed[name] or -math.huge) < cooldown then
        return
    end
    lastPlayed[name] = now

    local settings: Options = if typeof(options) == "Instance"
        then { parent = options }
        else (options :: Options?) or {}
    local volume = (Sounds.Volume[name] or Sounds.DefaultVolume) * (settings.volume or 1)
    local pitch = getPitch(name, settings.pitch)
    if settings.duck then
        duck()
    end

    local parent = settings.parent
    if parent then
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = volume
        sound.PlaybackSpeed = pitch
        sound.RollOffMaxDistance = 400
        sound.Parent = parent
        sound.Ended:Connect(function()
            sound:Destroy()
        end)
        sound:Play()
        return
    end

    local cached: Sound? = cache[name]
    if cached == nil then
        local created = Instance.new("Sound")
        created.Name = name
        created.SoundId = soundId
        created.Parent = SoundService
        cache[name] = created
        cached = created
    end
    if cached then
        cached.Volume = volume
        cached.PlaybackSpeed = pitch
        SoundService:PlayLocalSound(cached)
    end
end

-- Sonido en bucle que suena en 3D desde una parte (ambiente de un objeto). Devuelve nil si
-- ese sonido no tiene id configurado. Se para destruyéndolo.
function AudioManager.Loop(name: string, parent: Instance): Sound?
    local soundId = Sounds.Ids[name]
    if soundId == nil or soundId == "" then
        return nil
    end
    local sound = Instance.new("Sound")
    sound.Name = name
    sound.SoundId = soundId
    sound.Volume = Sounds.Volume[name] or Sounds.DefaultVolume
    sound.PlaybackSpeed = Sounds.Pitch[name] or 1
    sound.Looped = true
    sound.RollOffMaxDistance = 70
    sound.Parent = parent
    sound:Play()
    return sound
end

-- Activa o desactiva la música de evento (Config/Sounds.Music): la pista de evento si hay
-- una configurada o, si no, la música normal más grave.
function AudioManager.SetEventMusic(isActive: boolean)
    if isActive == eventActive then
        return
    end
    eventActive = isActive
    local track = music
    local eventTrack = Sounds.Music.EventTrack
    if eventTrack == "" then
        if track then
            TweenService:Create(
                track,
                TweenInfo.new(2),
                { PlaybackSpeed = if isActive then Sounds.Music.EventPitch else 1 }
            ):Play()
        end
        return
    end

    local override = eventMusic
    if override == nil then
        local created = Instance.new("Sound")
        created.Name = "EventMusic"
        created.SoundId = eventTrack
        created.Looped = true
        created.Volume = 0
        created.Parent = SoundService
        eventMusic = created
        override = created
    end
    local fade = TweenInfo.new(2)
    if isActive then
        override:Play()
    else
        task.delay(2, function()
            if not eventActive then
                override:Stop()
            end
        end)
    end
    TweenService:Create(override, fade, { Volume = if isActive then Sounds.Music.Volume else 0 })
        :Play()
    if track then
        TweenService:Create(track, fade, { Volume = if isActive then 0 else Sounds.Music.Volume })
            :Play()
    end
end

-- Empieza la música de fondo: recorre las pistas en orden y vuelve a empezar.
function AudioManager.StartMusic()
    local tracks = Sounds.Music.Tracks
    if music or #tracks == 0 then
        return
    end

    local track = Instance.new("Sound")
    track.Name = "BackgroundMusic"
    track.Volume = Sounds.Music.Volume
    track.Parent = SoundService
    music = track

    task.spawn(function()
        local index = 0
        while true do
            index = index % #tracks + 1
            track.SoundId = tracks[index]
            track:Play()

            local waited = 0
            while not track.IsLoaded and waited < MUSIC_LOAD_TIMEOUT do
                waited += task.wait(0.5)
            end
            if track.IsLoaded then
                track.Ended:Wait()
            else
                -- La pista no ha cargado (id retirado o sin permiso): se salta.
                track:Stop()
            end
            task.wait(1)
        end
    end)
end

return AudioManager
