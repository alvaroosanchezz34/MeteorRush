--!strict

-- Reproduce los sonidos y la música de Config/Sounds. Si un id está vacío, no hace nada.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds =
    require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Sounds"))

-- Segundos que se espera a que cargue una pista de música antes de pasar a la siguiente.
local MUSIC_LOAD_TIMEOUT = 15

local Sound = {}

local cache: { [string]: Sound } = {}
local musicStarted = false

-- Reproduce un sonido. Con `parent` (una Part) suena en 3D desde ahí; si no, en toda la pantalla.
function Sound.Play(name: string, parent: Instance?)
    local soundId = Sounds.Ids[name]
    if soundId == nil or soundId == "" then
        return
    end
    local volume = Sounds.Volume[name] or Sounds.DefaultVolume

    if parent then
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = volume
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
        created.SoundId = soundId
        created.Volume = volume
        created.Parent = SoundService
        cache[name] = created
        cached = created
    end
    if cached then
        SoundService:PlayLocalSound(cached)
    end
end

-- Empieza la música de fondo: recorre las pistas en orden y vuelve a empezar.
function Sound.StartMusic()
    local tracks = Sounds.Music.Tracks
    if musicStarted or #tracks == 0 then
        return
    end
    musicStarted = true

    local music = Instance.new("Sound")
    music.Name = "BackgroundMusic"
    music.Volume = Sounds.Music.Volume
    music.Parent = SoundService

    task.spawn(function()
        local index = 0
        while true do
            index = index % #tracks + 1
            music.SoundId = tracks[index]
            music:Play()

            local waited = 0
            while not music.IsLoaded and waited < MUSIC_LOAD_TIMEOUT do
                waited += task.wait(0.5)
            end
            if music.IsLoaded then
                music.Ended:Wait()
            else
                -- La pista no ha cargado (id retirado o sin permiso): se salta.
                music:Stop()
            end
            task.wait(1)
        end
    end)
end

return Sound
