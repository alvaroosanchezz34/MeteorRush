--!strict

-- Robo: golpear a quien transporta minerales le hace soltar la mitad en el suelo.
-- El servidor valida distancia, enfriamiento, inmunidad, zona segura, escudo y protección de novato.
-- Los minerales de los pedestales y del inventario de la base nunca se pueden robar.
--
-- El arma equipada del atacante (Config/Weapons) cambia cómo es el golpe: alcance, tiempo
-- entre golpes, cuánto suelta la víctima, empujón y aturdimiento. Nunca hace daño. Contra la
-- frustración: la víctima es inmune unos segundos tras cada golpe (más que cualquier
-- aturdimiento), no se la puede aturdir dos veces seguidas, y los golpes repetidos a la
-- misma víctima sueltan cada vez menos. Las habilidades activas pasan por las mismas reglas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AchievementService = require(script.Parent.AchievementService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)
local LiveOpsService = require(script.Parent.LiveOpsService)
local PlotService = require(script.Parent.PlotService)

local Shared = ReplicatedStorage.Shared
local AchievementsConfig = require(Shared.Config.Achievements)
local Equipment = require(Shared.Config.Equipment)
local Minerals = require(Shared.Config.Minerals)
local Mutations = require(Shared.Config.Mutations)
local Log = require(Shared.Util.Log)
local Assets = require(Shared.Util.Assets)
local MineralVisual = require(Shared.Util.MineralVisual)
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local StealConfig = require(Shared.Config.Steal)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)
local Weapons = require(Shared.Config.Weapons)

local DROP_SIZE = 1.2

type Drop = {
    item: Types.InventoryItem,
    instance: Instance,
    position: Vector3,
    pickableAt: number,
    expiresAt: number,
    -- A quién se le cayó (para avisar si otro se lo lleva).
    owner: Player,
}

local StealService = {}

local rng = Random.new()
local limiter = RateLimiter.new(Network.RateLimits.HitPlayer)
local lastHitAt: { [Player]: number } = {}
local immuneUntil: { [Player]: number } = {}
local stunImmuneUntil: { [Player]: number } = {}
-- Golpes recibidos hace poco por cada jugador: cuántos y cuándo fue el último.
local recentHits: { [Player]: { count: number, lastAt: number } } = {}
local abilityLimiter = RateLimiter.new(Network.RateLimits.UseAbility)
local abilityReadyAt: { [Player]: number } = {}
local drops: { Drop } = {}
local dropFolder: Folder? = nil

local function getRoot(player: Player): BasePart?
    local character = player.Character
    if character == nil then
        return nil
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
        return nil
    end
    return root
end

local function isNewbie(player: Player): boolean
    return DataService.GetPlaytime(player) < StealConfig.NewbieProtectionSeconds
end

local function findGround(position: Vector3): Vector3
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local excluded: { Instance } = {}
    for _, player in Players:GetPlayers() do
        if player.Character then
            table.insert(excluded, player.Character)
        end
    end
    if dropFolder then
        table.insert(excluded, dropFolder)
    end
    params.FilterDescendantsInstances = excluded
    local result =
        Workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -50, 0), params)
    return if result then result.Position else position
end

local function spawnDrops(items: { Types.InventoryItem }, origin: Vector3, owner: Player)
    local now = os.clock()
    for _, item in items do
        local angle = rng:NextNumber() * math.pi * 2
        local distance = rng:NextNumber(2, StealConfig.DropScatterRadius)
        local ground =
            findGround(origin + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance)
        -- Los especiales son más grandes y llevan su cartel: que se vea lo que hay en juego.
        local size = DROP_SIZE * MineralVisual.GetDisplayScale(item.mineral, item.mutation)
        local position = ground + Vector3.new(0, size / 2 + 0.2, 0)

        local visual = MineralVisual.Create(item.mineral, item.mutation, size)
        if MineralVisual.IsSpecial(item.mineral, item.mutation) then
            MineralVisual.AddSign(visual, item.mineral, item.mutation, size, false)
        end
        Assets.PlaceAt(visual, CFrame.new(position))
        visual.Parent = dropFolder

        table.insert(drops, {
            item = item,
            instance = visual,
            position = position,
            pickableAt = now + StealConfig.DropPickupDelay,
            expiresAt = now + StealConfig.DropLifetime,
            owner = owner,
        })
    end
end

local function showImmunity(player: Player)
    local character = player.Character
    if character == nil then
        return
    end
    local forceField = Instance.new("ForceField")
    forceField.Visible = true
    forceField.Parent = character
    task.delay(StealConfig.VictimImmunity, function()
        forceField:Destroy()
    end)
end

-- Motivo por el que no se puede hacer soltar la carga a ese jugador ahora mismo, o nil si
-- se puede. Las mismas reglas para un golpe y para una habilidad.
local function getProtection(victim: Player, victimRoot: BasePart, now: number): Locale.Message?
    local victimData = DataService.GetData(victim)
    if victimData == nil or isNewbie(victim) then
        return Locale.Msg("Steal.Newbie")
    end
    if PlotService.IsInOwnPlot(victim, victimRoot.Position) then
        return Locale.Msg("Steal.TargetSafe")
    end
    if now < (immuneUntil[victim] or 0) then
        return Locale.Msg("Steal.TargetImmune")
    end
    if PlayerStats.IsBoostActive(victimData, "carryShield", os.time()) then
        return Locale.Msg("Steal.TargetShielded")
    end
    return nil
end

-- Factor por golpes repetidos: cuantos más ha recibido la víctima hace poco, menos suelta.
-- Apunta además este golpe.
local function takeRepeatFactor(victim: Player, now: number): number
    local recent = recentHits[victim]
    if recent == nil or now - recent.lastAt > StealConfig.RepeatWindow then
        recent = { count = 0, lastAt = now }
        recentHits[victim] = recent
    end
    local factor = math.max(StealConfig.RepeatFactor ^ recent.count, StealConfig.MinRepeatFactor)
    recent.count += 1
    recent.lastAt = now
    return factor
end

-- Empujón desde `from` hacia la víctima, con algo de altura. Lo aplica el cliente de la
-- víctima (es quien mueve su personaje); si lo ignorase, solo se libra del empujón.
local function getKnockback(from: Vector3, victimRoot: BasePart, speed: number): Vector3
    if speed <= 0 then
        return Vector3.zero
    end
    local flat = Vector3.new(victimRoot.Position.X - from.X, 0, victimRoot.Position.Z - from.Z)
    local direction = if flat.Magnitude > 0.1 then flat.Unit else victimRoot.CFrame.LookVector
    return direction * speed + Vector3.new(0, speed * 0.45, 0)
end

-- Estadísticas del robo y aviso de objetivo secreto, comunes al golpe y a la habilidad.
local function recordHit(attacker: Player, victim: Player, dropped: { Types.InventoryItem })
    local valuable = false
    for _, item in dropped do
        if
            Minerals.GetRank(item.mineral) >= AchievementsConfig.ValuableRank
            or item.mutation ~= Mutations.NoneId
        then
            valuable = true
        end
    end
    -- Para el objetivo de "sobrevivir" a un robo (CarryService lo comprueba al depositar).
    victim:SetAttribute("LastHitAt", Workspace:GetServerTimeNow())
    AchievementService.AddStats(attacker, {
        hitsLanded = 1,
        valuableSteals = if valuable then 1 else 0,
    })
    AchievementService.AddStat(victim, "timesHit", 1)
end

local function onHitPlayer(attacker: Player, target: unknown)
    if not limiter.Check(attacker) then
        return
    end
    if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Player") then
        Log.Suspicious(attacker, "HitPlayer", "tipo inválido")
        return
    end
    local victim = target :: Player
    if victim == attacker or victim.Parent ~= Players then
        return
    end

    local now = os.clock()
    local attackerData = DataService.GetData(attacker)
    local attackerRoot = getRoot(attacker)
    local victimRoot = getRoot(victim)
    local victimData = DataService.GetData(victim)
    if attackerData == nil or attackerRoot == nil or victimRoot == nil or victimData == nil then
        return
    end
    -- Alcance y tiempo entre golpes salen del arma equipada, siempre leída en el servidor.
    if now - (lastHitAt[attacker] or -math.huge) < PlayerStats.GetHitCooldown(attackerData) then
        return
    end
    local distance = (attackerRoot.Position - victimRoot.Position).Magnitude
    if distance > PlayerStats.GetHitRange(attackerData) + StealConfig.HitRangeTolerance then
        return
    end

    local function reject(message: Locale.Message)
        Remotes.Notify:FireClient(attacker, message)
    end
    if not LiveOpsService.IsEnabled("stealing") then
        return reject(Locale.Msg("LiveOps.Disabled"))
    end
    if isNewbie(attacker) then
        return reject(Locale.Msg("Steal.Newbie"))
    end
    if CarryService.GetCount(victim) == 0 then
        return reject(Locale.Msg("Steal.NothingToSteal"))
    end
    local protection = getProtection(victim, victimRoot, now)
    if protection then
        return reject(protection)
    end

    lastHitAt[attacker] = now
    immuneUntil[victim] = now + StealConfig.VictimImmunity

    local weapon = Equipment.GetEquipped(attackerData, "weapon")
    local fraction = PlayerStats.GetStealDropFraction(victimData, attackerData)
        * takeRepeatFactor(victim, now)
    local dropCount = math.max(math.ceil(CarryService.GetCount(victim) * fraction), 1)
    local dropped = CarryService.RemoveRandom(victim, dropCount)
    spawnDrops(dropped, victimRoot.Position, victim)
    showImmunity(victim)

    -- Aturdimiento: dura menos que la inmunidad y no se repite hasta pasado un buen rato,
    -- así que no se puede encadenar.
    local stunSeconds = 0
    local stunChance = Equipment.GetItemStat(weapon, "stunChance")
    if
        stunChance > 0
        and now >= (stunImmuneUntil[victim] or 0)
        and rng:NextNumber() < stunChance
    then
        stunSeconds = Equipment.GetItemStat(weapon, "stun")
        stunImmuneUntil[victim] = now + StealConfig.StunImmunity
        CarryService.SetSpeedModifier(victim, 0, stunSeconds)
    end
    local knockback =
        getKnockback(attackerRoot.Position, victimRoot, Equipment.GetItemStat(weapon, "knockback"))

    -- Efectos del golpe en todos los clientes (StealController).
    Remotes.StealHit:FireAllClients(
        victim,
        victimRoot.Position,
        #dropped,
        attacker,
        weapon.id,
        knockback,
        stunSeconds
    )
    Remotes.Notify:FireClient(attacker, Locale.Msg("Steal.YouHit", victim.DisplayName))
    Remotes.Notify:FireClient(
        victim,
        Locale.Msg("Steal.YouWereHit", attacker.DisplayName, #dropped)
    )
    recordHit(attacker, victim, dropped)
end

-- Habilidad activa del arma equipada (por ahora, Void Pulse): afecta a los jugadores
-- cercanos con las mismas protecciones que un golpe. Cada uno suelta una cantidad fija y
-- pequeña, nunca una fracción de la mochila.
local function onUseAbility(attacker: Player)
    if not abilityLimiter.Check(attacker) then
        return
    end
    local attackerData = DataService.GetData(attacker)
    local attackerRoot = getRoot(attacker)
    if attackerData == nil or attackerRoot == nil then
        return
    end
    local weapon = Equipment.GetEquipped(attackerData, "weapon")
    local abilityId = weapon.ability
    local ability = if abilityId then Weapons.Abilities[abilityId] else nil
    if abilityId == nil or ability == nil then
        return
    end
    local now = os.clock()
    local readyAt = abilityReadyAt[attacker] or 0
    if now < readyAt then
        Remotes.Notify:FireClient(
            attacker,
            Locale.Msg("Steal.AbilityCooldown", tostring(math.ceil(readyAt - now)))
        )
        return
    end
    if not LiveOpsService.IsEnabled("stealing") then
        Remotes.Notify:FireClient(attacker, Locale.Msg("LiveOps.Disabled"))
        return
    end
    if isNewbie(attacker) then
        Remotes.Notify:FireClient(attacker, Locale.Msg("Steal.Newbie"))
        return
    end
    -- Desde la propia base no se ataca: la zona segura no es una trinchera.
    if PlotService.IsInOwnPlot(attacker, attackerRoot.Position) then
        return
    end

    abilityReadyAt[attacker] = now + ability.cooldown
    attacker:SetAttribute("AbilityReadyAt", Workspace:GetServerTimeNow() + ability.cooldown)
    Remotes.AbilityFx:FireAllClients(attacker, attackerRoot.Position, abilityId, ability.radius)

    -- Los más cercanos primero, hasta el máximo de objetivos.
    local targets: { { player: Player, root: BasePart, distance: number } } = {}
    for _, other in Players:GetPlayers() do
        local root = if other ~= attacker then getRoot(other) else nil
        if root then
            local distance = (root.Position - attackerRoot.Position).Magnitude
            if distance <= ability.radius then
                table.insert(targets, { player = other, root = root, distance = distance })
            end
        end
    end
    table.sort(targets, function(a, b): boolean
        return a.distance < b.distance
    end)
    for index, entry in targets do
        if index > ability.maxTargets then
            break
        end
        local victim = entry.player
        if getProtection(victim, entry.root, now) == nil then
            immuneUntil[victim] = now + StealConfig.VictimImmunity
            takeRepeatFactor(victim, now)
            local dropped = CarryService.RemoveRandom(
                victim,
                math.min(ability.drop, CarryService.GetCount(victim))
            )
            spawnDrops(dropped, entry.root.Position, victim)
            showImmunity(victim)
            CarryService.SetSpeedModifier(victim, ability.slow, ability.slowSeconds)
            Remotes.StealHit:FireAllClients(
                victim,
                entry.root.Position,
                #dropped,
                attacker,
                weapon.id,
                getKnockback(attackerRoot.Position, entry.root, ability.knockback),
                0
            )
            if #dropped > 0 then
                recordHit(attacker, victim, dropped)
            end
        end
    end
end

local function updateDrops()
    local now = os.clock()
    local unixNow = os.time()
    for index = #drops, 1, -1 do
        local drop = drops[index]
        local taken = false
        if now >= drop.expiresAt then
            taken = true
        elseif now >= drop.pickableAt then
            for _, player in Players:GetPlayers() do
                local root = getRoot(player)
                local data = DataService.GetData(player)
                if root and data and CarryService.HasRoom(player) then
                    local radius = if PlayerStats.IsBoostActive(data, "magnet", unixNow)
                        then StealConfig.MagnetPickupRadius
                        else StealConfig.PickupRadius
                    if (root.Position - drop.position).Magnitude <= radius then
                        CarryService.Add(player, drop.item)
                        IndexService.Register(player, drop.item.mineral, drop.item.mutation)
                        taken = true
                        -- Alguien se lleva algo muy raro que se le cayó a otro: aviso solo
                        -- para los dos, no para todo el servidor.
                        local owner = drop.owner
                        if
                            player ~= owner
                            and (
                                Minerals.GetRank(drop.item.mineral) >= StealConfig.MomentRank
                                or drop.item.mutation == Mutations.List[#Mutations.List].id
                            )
                        then
                            Remotes.StealMoment:FireClient(
                                player,
                                drop.item.mineral,
                                drop.item.mutation,
                                owner.DisplayName
                            )
                            if owner.Parent == Players then
                                Remotes.Notify:FireClient(
                                    owner,
                                    Locale.Msg(
                                        "Steal.LootTaken",
                                        player.DisplayName,
                                        Locale.Mineral(drop.item.mineral, drop.item.mutation)
                                    )
                                )
                            end
                        end
                        break
                    end
                end
            end
        end
        if taken then
            drop.instance:Destroy()
            table.remove(drops, index)
        end
    end
end

function StealService.Init()
    local folder = Instance.new("Folder")
    folder.Name = "Drops"
    folder.Parent = Workspace
    dropFolder = folder

    Remotes.HitPlayer.OnServerEvent:Connect(onHitPlayer)
    Remotes.UseAbility.OnServerEvent:Connect(onUseAbility)
end

function StealService.Start()
    Players.PlayerRemoving:Connect(function(player: Player)
        lastHitAt[player] = nil
        immuneUntil[player] = nil
        stunImmuneUntil[player] = nil
        recentHits[player] = nil
        abilityReadyAt[player] = nil
    end)
    task.spawn(function()
        while true do
            task.wait(StealConfig.PickupCheckInterval)
            updateDrops()
        end
    end)
end

return StealService
