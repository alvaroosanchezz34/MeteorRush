--!strict

-- Reproduce sonidos de Config/Sounds. Si un id está vacío, no hace nada.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds =
    require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Sounds"))

local Sound = {}

local cache: { [string]: Sound } = {}

-- Reproduce un sonido. Con `parent` (una Part) suena en 3D desde ahí; si no, en toda la pantalla.
function Sound.Play(name: string, parent: Instance?)
    local soundId = (Sounds :: any)[name]
    if type(soundId) ~= "string" or soundId == "" then
        return
    end

    if parent then
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
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
        created.Parent = SoundService
        cache[name] = created
        cached = created
    end
    if cached then
        SoundService:PlayLocalSound(cached)
    end
end

return Sound
