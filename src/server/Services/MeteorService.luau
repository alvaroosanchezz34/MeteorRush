--!strict

-- Programa la caída de meteoritos de cada tipo, avisa a los clientes y gestiona su vida en el suelo.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.Parent.Builders.Kit)

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Util.Assets)
local MapConfig = require(Shared.Config.Map)
local MeteorFx = require(Shared.Config.MeteorFx)
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
    -- Placas de la corteza que quedan y cuántas había al caer: se van rompiendo al minarlo.
    plates: { BasePart },
    plateTotal: number,
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
-- Nombre de las placas de la corteza dentro del modelo generado.
local PLATE_NAME = "Plate"
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

local function randomDirection(): Vector3
    return rng:NextUnitVector()
end

-- Corteza de roca oscura agrietada sobre un núcleo incandescente, con cráter, ascuas y humo.
-- Se construye centrada en el origen; la parte principal es el núcleo.
local function makeMeteorPlaceholder(meteorType: MeteorsConfig.MeteorType): Instance
    local radius = meteorType.radius
    local model = Instance.new("Model")

    local function addPart(
        shape: Enum.PartType,
        size: Vector3,
        cframe: CFrame,
        color: Color3,
        material: Enum.Material
    ): Part
        local part = Instance.new("Part")
        part.Shape = shape
        part.Anchored = true
        part.Size = size
        part.CFrame = cframe
        part.Color = color
        part.Material = material
        part.TopSurface = Enum.SurfaceType.Smooth
        part.BottomSurface = Enum.SurfaceType.Smooth
        part.Parent = model
        return part
    end

    -- Núcleo incandescente: solo se ve por las rendijas entre las placas de la corteza.
    local core = addPart(
        Enum.PartType.Ball,
        Vector3.one * radius * 1.68,
        CFrame.identity,
        meteorType.glowColor,
        Enum.Material.Neon
    )
    model.PrimaryPart = core

    -- Corteza: placas de roca oscura repartidas de forma uniforme por la esfera (espiral de
    -- Fibonacci), cada una con su giro, tamaño y altura, para que queden juntas irregulares.
    -- No sobresalen del radio, que es el que se usa para medir la distancia de minado.
    local plateCount = math.round(MeteorsConfig.PlateCount * math.sqrt(radius / 4))
    local plateSide = math.sqrt(4 * math.pi / plateCount) * radius * 0.83
    local goldenAngle = math.pi * (3 - math.sqrt(5))
    for index = 0, plateCount - 1 do
        local y = 1 - 2 * (index + 0.5) / plateCount
        local ring = math.sqrt(1 - y * y)
        local theta = index * goldenAngle
        local direction = Vector3.new(math.cos(theta) * ring, y, math.sin(theta) * ring)

        local thickness = radius * rng:NextNumber(0.16, 0.3)
        local distance = radius * rng:NextNumber(0.8, 0.86)
        local plate = addPart(
            Enum.PartType.Block,
            Vector3.new(
                plateSide * rng:NextNumber(0.8, 0.95),
                plateSide * rng:NextNumber(0.8, 0.95),
                thickness
            ),
            CFrame.lookAt(direction * distance, direction * radius * 2)
                * CFrame.Angles(
                    rng:NextNumber(-0.12, 0.12),
                    rng:NextNumber(-0.12, 0.12),
                    rng:NextNumber(0, math.pi)
                ),
            meteorType.color:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.4)),
            if rng:NextNumber() < 0.3 then Enum.Material.Slate else Enum.Material.Basalt
        )
        plate.CastShadow = false
        plate.Name = PLATE_NAME
    end

    -- Salientes: unas cuantas cuñas grandes que rompen la silueta redonda.
    for _ = 1, MeteorsConfig.OutcropCount do
        local direction = randomDirection()
        addPart(
            Enum.PartType.Wedge,
            Vector3.new(
                radius * rng:NextNumber(0.3, 0.45),
                radius * rng:NextNumber(0.25, 0.4),
                radius * rng:NextNumber(0.3, 0.45)
            ),
            CFrame.new(direction * radius * 0.82)
                * CFrame.Angles(
                    rng:NextNumber(0, math.pi),
                    rng:NextNumber(0, math.pi),
                    rng:NextNumber(0, math.pi)
                ),
            meteorType.color:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0.1, 0.4)),
            Enum.Material.Basalt
        )
    end

    -- Detalle según el nivel del meteorito (Config/MeteorFx): cuanto más grande, más cráteres,
    -- más zonas incandescentes y más fuego.
    local tier = MeteorFx.GetTier(meteorType.id)
    local function decorate(part: BasePart, name: string)
        part.Name = name
        part.CanCollide = false
        part.CanQuery = false
        part.CastShadow = false
    end
    -- Cráteres: discos oscuros en la corteza.
    for _ = 1, tier.craters do
        local direction = randomDirection()
        local diameter = radius * rng:NextNumber(0.28, 0.5)
        decorate(
            addPart(
                Enum.PartType.Cylinder,
                Vector3.new(radius * 0.05, diameter, diameter),
                -- El eje del cilindro es X: se gira para que mire hacia fuera.
                CFrame.lookAt(direction * radius * 0.94, direction * radius * 2)
                    * CFrame.Angles(0, math.pi / 2, 0),
                Color3.fromRGB(14, 12, 12),
                Enum.Material.Slate
            ),
            "Crater"
        )
    end
    -- Zonas incandescentes: roca al rojo que asoma entre las placas.
    for _ = 1, tier.hotSpots do
        local direction = randomDirection()
        local side = radius * rng:NextNumber(0.1, 0.2)
        decorate(
            addPart(
                Enum.PartType.Block,
                Vector3.new(side, side, radius * 0.1),
                CFrame.lookAt(direction * radius * 0.9, direction * radius * 2)
                    * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi)),
                meteorType.glowColor:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.3)),
                Enum.Material.Neon
            ),
            "HotSpot"
        )
    end
    -- Púas de energía (solo los de evento): cristales grandes del color del núcleo.
    for _ = 1, tier.spikes do
        local direction = randomDirection()
        direction = Vector3.new(direction.X, math.abs(direction.Y) * 0.7 + 0.2, direction.Z).Unit
        local base = direction * radius * 0.8
        Kit.Crystal({
            cframe = CFrame.lookAt(base, base + direction) * CFrame.Angles(-math.pi / 2, 0, 0),
            height = radius * rng:NextNumber(0.55, 0.85),
            width = radius * rng:NextNumber(0.12, 0.18),
            color = meteorType.glowColor,
            canCollide = false,
            parent = model,
        })
    end
    -- Llamas que suben de la parte de arriba.
    if tier.flameRate > 0 then
        local flames = Instance.new("ParticleEmitter")
        flames.Name = "Flames"
        flames.Color = ColorSequence.new(Color3.new(1, 1, 1), meteorType.glowColor)
        flames.LightEmission = 1
        flames.Rate = tier.flameRate
        flames.Lifetime = NumberRange.new(0.5, 1.1)
        flames.Speed = NumberRange.new(radius * 0.8, radius * 1.6)
        flames.EmissionDirection = Enum.NormalId.Top
        flames.SpreadAngle = Vector2.new(30, 30)
        flames.Size = NumberSequence.new(radius * 0.45, 0)
        flames.Transparency = NumberSequence.new(0.3, 1)
        flames.Parent = core
    end

    -- Unos pocos cristales pequeños asomando por la mitad superior.
    for _ = 1, MeteorsConfig.CrystalCount do
        local direction = randomDirection()
        direction = Vector3.new(direction.X, math.abs(direction.Y) * 0.8 + 0.1, direction.Z).Unit
        local base = direction * radius * 0.85
        Kit.Crystal({
            -- lookAt apunta -Z hacia fuera; el giro deja +Y (el eje del cristal) en esa dirección.
            cframe = CFrame.lookAt(base, base + direction) * CFrame.Angles(-math.pi / 2, 0, 0),
            height = radius * rng:NextNumber(0.3, 0.5),
            width = radius * rng:NextNumber(0.08, 0.12),
            color = meteorType.glowColor:Lerp(Color3.new(1, 1, 1), 0.35),
            canCollide = false,
            parent = model,
        })
    end

    -- Grietas en el suelo que salen de la base.
    for index = 1, MeteorsConfig.GroundCrackCount do
        local angle = index / MeteorsConfig.GroundCrackCount * math.pi * 2
            + rng:NextNumber(-0.3, 0.3)
        local length = radius * rng:NextNumber(0.7, 1.4)
        local crack = addPart(
            Enum.PartType.Block,
            Vector3.new(radius * 0.07, 0.1, length),
            CFrame.new(0, -radius + 0.32, 0)
                * CFrame.Angles(0, angle, 0)
                * CFrame.new(0, 0, -(radius * 0.7 + length / 2)),
            meteorType.glowColor,
            Enum.Material.Neon
        )
        crack.CanCollide = false
        crack.CanQuery = false
        crack.CastShadow = false
    end

    -- Borde del cráter: rocas sueltas alrededor de la base, sin colisión para no estorbar.
    for index = 1, MeteorsConfig.RimRockCount do
        local angle = index / MeteorsConfig.RimRockCount * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
        local distance = radius * rng:NextNumber(1.15, 1.45)
        Kit.Rock({
            cframe = CFrame.new(math.cos(angle) * distance, -radius, math.sin(angle) * distance),
            size = radius * rng:NextNumber(0.25, 0.45),
            color = meteorType.color:Lerp(Color3.new(0, 0, 0), 0.3),
            material = Enum.Material.Basalt,
            rng = rng,
            canCollide = false,
            parent = model,
        })
    end

    local scorch = addPart(
        Enum.PartType.Cylinder,
        Vector3.new(0.1, radius * 3.2, radius * 3.2),
        -- El eje del cilindro es X; se gira para que quede tumbado sobre el suelo.
        CFrame.new(0, -radius + 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)),
        Color3.fromRGB(20, 16, 16),
        Enum.Material.Slate
    )
    scorch.CanCollide = false
    scorch.CanQuery = false

    local light = Instance.new("PointLight")
    light.Color = meteorType.glowColor
    light.Brightness = 1.2
    light.Range = math.min(radius * 4, 60)
    light.Shadows = false
    light.Parent = core

    local embers = Instance.new("ParticleEmitter")
    embers.Name = "Embers"
    embers.Color = ColorSequence.new(meteorType.glowColor)
    embers.LightEmission = 1
    embers.Rate = radius * 2
    embers.Lifetime = NumberRange.new(1.5, 3)
    embers.Speed = NumberRange.new(radius * 0.3, radius * 0.6)
    embers.SpreadAngle = Vector2.new(40, 40)
    embers.Size = NumberSequence.new(radius * 0.12, 0)
    embers.Parent = core

    local smoke = Instance.new("ParticleEmitter")
    smoke.Name = "Smoke"
    smoke.Color = ColorSequence.new(Color3.fromRGB(50, 45, 55))
    smoke.Transparency = NumberSequence.new(0.6, 1)
    smoke.Rate = 3
    smoke.Lifetime = NumberRange.new(3, 5)
    smoke.Speed = NumberRange.new(radius * 0.4, radius * 0.7)
    smoke.SpreadAngle = Vector2.new(20, 20)
    smoke.Size = NumberSequence.new(radius * 0.5, radius * 1.4)
    smoke.Parent = core

    return model
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

-- Rompe placas de la corteza según se gastan los golpes: saltan hacia fuera y desaparecen,
-- dejando cada vez más núcleo a la vista.
local function breakPlates(meteor: Meteor)
    local maxHits = MeteorsConfig.Types[meteor.typeId].hits
    local keep = MeteorsConfig.MinPlateFraction
    local target =
        math.ceil(meteor.plateTotal * (keep + (1 - keep) * math.max(meteor.hitsLeft, 0) / maxHits))
    while #meteor.plates > target do
        local plate = table.remove(meteor.plates, rng:NextInteger(1, #meteor.plates))
        if plate and plate.Parent then
            local outward = plate.Position - meteor.position
            plate.Anchored = false
            plate.CanCollide = false
            plate.AssemblyLinearVelocity = outward.Unit * MeteorsConfig.DebrisSpeed
                + Vector3.new(0, MeteorsConfig.DebrisSpeed * 0.6, 0)
            plate.AssemblyAngularVelocity = rng:NextUnitVector() * 8
            Debris:AddItem(plate, MeteorsConfig.DebrisLifetime)
        end
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

    local plates: { BasePart } = {}
    for _, child in model:GetChildren() do
        if child.Name == PLATE_NAME and child:IsA("BasePart") then
            table.insert(plates, child)
        end
    end

    meteors[id] = {
        id = id,
        typeId = typeId,
        position = position,
        radius = meteorType.radius,
        hitsLeft = meteorType.hits,
        model = model,
        plates = plates,
        plateTotal = #plates,
    }

    if typeId == GIANT_TYPE then
        Workspace:SetAttribute("GiantActive", true)
        Remotes.Notify:FireAllClients(Strings.Meteor.GiantLanded)
    end

    task.delay(meteorType.duration, removeMeteor, id)
end

local function announceMeteor(typeId: string, impactIn: number, at: Vector3?)
    local meteorType = MeteorsConfig.Types[typeId]
    nextId += 1
    local id = nextId
    -- Con un punto pedido, cae ahí (apoyado en el suelo); si no, donde haya sitio.
    local position = if at
        then Vector3.new(at.X, meteorType.radius, at.Z)
        else chooseImpactPosition(meteorType.radius)
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

-- Hace caer un meteorito de ese tipo dentro de `impactIn` segundos, con su aviso.
-- Lo usan los eventos (EventService) para los meteoritos especiales y las lluvias, y el
-- panel de administración, que además puede elegir el punto (`position`).
function MeteorService.Spawn(typeId: string, impactIn: number, position: Vector3?)
    announceMeteor(typeId, impactIn, position)
end

-- Todos los meteoritos que hay ahora en el suelo.
function MeteorService.GetAll(): { Meteor }
    local list: { Meteor } = {}
    for _, meteor in meteors do
        table.insert(list, meteor)
    end
    return list
end

-- Quita un meteorito del suelo sin dar nada (panel de administración).
function MeteorService.Remove(id: number)
    removeMeteor(id)
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
    breakPlates(meteor)
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
        -- Los especiales no tienen calendario propio: solo caen en eventos.
        if not meteorType.special then
            table.insert(schedules, {
                typeId = typeId,
                nextImpact = now + meteorType.firstImpact,
                announced = false,
            })
        end
    end

    task.spawn(function()
        while true do
            updateSchedules()
            task.wait(0.25)
        end
    end)
end

return MeteorService
