--!strict

-- Programa la caída de meteoritos de cada tipo, avisa a los clientes y gestiona su vida en el suelo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Util.Assets)
local MapConfig = require(Shared.Config.Map)
local MeteorsConfig = require(Shared.Config.Meteors)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)

export type Meteor = {
    id: number,
    typeId: string,
    position: Vector3,
    radius: number,
    hitsLeft: number,
    model: Instance,
}

type Schedule = {
    typeId: string,
    nextImpact: number,
    announced: boolean,
}

local MeteorService = {}

local rng = Random.new()
local meteorFolder: Folder? = nil
local meteors: { [number]: Meteor } = {}
local schedules: { Schedule } = {}
-- Posiciones reservadas por meteoritos avisados que aún no han caído.
local pendingImpacts: { [number]: { position: Vector3, radius: number } } = {}
local nextId = 0

-- Tipo de meteorito que activa el evento (cielo especial en el cliente, aviso al caer).
local GIANT_TYPE = "giant"
-- Último impacto publicado en el atributo NextMeteorAt (se replica solo cuando cambia).
local publishedImpact: number? = nil

local function isFree(position: Vector3, radius: number): boolean
    local function clear(otherPosition: Vector3, otherRadius: number): boolean
        local distance = (otherPosition - position).Magnitude
        return distance >= radius + otherRadius + MeteorsConfig.MinSeparation
    end
    for _, meteor in meteors do
        if not clear(meteor.position, meteor.radius) then
            return false
        end
    end
    for _, pending in pendingImpacts do
        if not clear(pending.position, pending.radius) then
            return false
        end
    end
    return true
end

local function chooseImpactPosition(radius: number): Vector3
    local maxDistance = MapConfig.ImpactZoneRadius - radius
    local position = Vector3.zero
    for _ = 1, MeteorsConfig.PlacementAttempts do
        -- sqrt para que los puntos se repartan de forma uniforme por el círculo.
        local distance = maxDistance * math.sqrt(rng:NextNumber())
        local angle = rng:NextNumber() * math.pi * 2
        position = Vector3.new(math.cos(angle) * distance, radius, math.sin(angle) * distance)
        if isFree(position, radius) then
            break
        end
    end
    return position
end

local function makeMeteorPlaceholder(meteorType: MeteorsConfig.MeteorType): Instance
    local part = Instance.new("Part")
    part.Shape = Enum.PartType.Ball
    part.Anchored = true
    part.Size = Vector3.one * meteorType.radius * 2
    part.Color = meteorType.color
    part.Material = Enum.Material.Basalt
    return part
end

local function removeMeteor(id: number)
    local meteor = meteors[id]
    if meteor == nil then
        return
    end
    meteors[id] = nil
    meteor.model:Destroy()

    if meteor.typeId == GIANT_TYPE then
        local anotherGiant = false
        for _, other in meteors do
            if other.typeId == GIANT_TYPE then
                anotherGiant = true
            end
        end
        Workspace:SetAttribute("GiantActive", anotherGiant)
    end
end

local function spawnMeteor(id: number, typeId: string, position: Vector3)
    local meteorType = MeteorsConfig.Types[typeId]
    pendingImpacts[id] = nil

    local model = Assets.SpawnAt(`Meteor_{typeId}`, CFrame.new(position), function(): Instance
        return makeMeteorPlaceholder(meteorType)
    end)
    model.Name = `Meteor{id}`
    model:SetAttribute("MeteorId", id)
    model:SetAttribute("MeteorType", typeId)
    model:SetAttribute("Radius", meteorType.radius)
    model:SetAttribute("HitsLeft", meteorType.hits)
    model.Parent = meteorFolder

    meteors[id] = {
        id = id,
        typeId = typeId,
        position = position,
        radius = meteorType.radius,
        hitsLeft = meteorType.hits,
        model = model,
    }

    if typeId == GIANT_TYPE then
        Workspace:SetAttribute("GiantActive", true)
        Remotes.Notify:FireAllClients(Strings.Meteor.GiantLanded)
    end

    task.delay(meteorType.duration, removeMeteor, id)
end

local function announceMeteor(typeId: string, impactIn: number)
    local meteorType = MeteorsConfig.Types[typeId]
    nextId += 1
    local id = nextId
    local position = chooseImpactPosition(meteorType.radius)
    pendingImpacts[id] = { position = position, radius = meteorType.radius }

    local impactAt = Workspace:GetServerTimeNow() + impactIn
    Remotes.MeteorIncoming:FireAllClients(id, typeId, position, impactAt)
    if meteorType.announce then
        Remotes.Notify:FireAllClients(Strings.Meteor.Incoming[typeId])
    end

    task.delay(impactIn, spawnMeteor, id, typeId, position)
end

local function updateSchedules()
    local now = os.clock()
    local soonest = math.huge
    for _, schedule in schedules do
        local warnAt = schedule.nextImpact - MeteorsConfig.WarningTime
        if not schedule.announced and now >= warnAt then
            schedule.announced = true
            announceMeteor(schedule.typeId, math.max(schedule.nextImpact - now, 0))
        end
        if now >= schedule.nextImpact then
            schedule.nextImpact += MeteorsConfig.Types[schedule.typeId].interval
            schedule.announced = false
        end
        soonest = math.min(soonest, schedule.nextImpact)
    end
    -- Hora (del servidor) del próximo impacto, para la cuenta atrás del HUD.
    if soonest < math.huge and soonest ~= publishedImpact then
        publishedImpact = soonest
        Workspace:SetAttribute("NextMeteorAt", Workspace:GetServerTimeNow() + (soonest - now))
    end
end

-- Devuelve el meteorito activo con ese id, o nil si no existe o ya desapareció.
function MeteorService.GetMeteor(id: number): Meteor?
    return meteors[id]
end

-- Gasta un golpe del meteorito. Devuelve false si no existe o no le quedan golpes.
-- El meteorito desaparece al gastar el último golpe.
function MeteorService.ConsumeHit(id: number): boolean
    local meteor = meteors[id]
    if meteor == nil or meteor.hitsLeft <= 0 then
        return false
    end
    meteor.hitsLeft -= 1
    meteor.model:SetAttribute("HitsLeft", meteor.hitsLeft)
    if meteor.hitsLeft <= 0 then
        removeMeteor(id)
    end
    return true
end

function MeteorService.Init()
    local folder = Instance.new("Folder")
    folder.Name = "Meteors"
    folder.Parent = Workspace
    meteorFolder = folder

    if RunService:IsStudio() then
        -- Solo para pruebas en Studio: lanza un meteorito con aviso desde la barra de comandos.
        local debugSpawn = Instance.new("BindableFunction")
        debugSpawn.Name = "DebugSpawnMeteor"
        debugSpawn.OnInvoke = function(typeId: string?): boolean
            local id = typeId or "normal"
            if MeteorsConfig.Types[id] == nil then
                return false
            end
            announceMeteor(id, MeteorsConfig.WarningTime)
            return true
        end
        debugSpawn.Parent = script
    end
end

function MeteorService.Start()
    local now = os.clock()
    for typeId, meteorType in MeteorsConfig.Types do
        table.insert(schedules, {
            typeId = typeId,
            nextImpact = now + meteorType.firstImpact,
            announced = false,
        })
    end

    task.spawn(function()
        while true do
            updateSchedules()
            task.wait(0.25)
        end
    end)
end

return MeteorService
