--!strict

-- Estadísticas derivadas de los datos del jugador (mejoras, game passes, boosts y rebirths).
-- Se comparten entre servidor y cliente para que la interfaz muestre exactamente lo mismo
-- que calcula el servidor. `now` es la hora Unix del servidor (os.time() o GetServerTimeNow()).

local Config = script.Parent.Parent.Config
local Achievements = require(Config.Achievements)
local Competition = require(Config.Competition)
local Decor = require(Config.Decor)
local Equipment = require(Config.Equipment)
local Events = require(Config.Events)
local Carry = require(Config.Carry)
local Income = require(Config.Income)
local LiveOps = require(Config.LiveOps)
local Minerals = require(Config.Minerals)
local Mutations = require(Config.Mutations)
local Permanent = require(Config.Permanent)
local Quests = require(Config.Quests)
local Rebirth = require(Config.Rebirth)
local Shop = require(Config.Shop)
local Social = require(Config.Social)
local Steal = require(Config.Steal)
local Upgrades = require(Config.Upgrades)
local Types = require(script.Parent.Parent.Types)

local PlayerStats = {}

-- Indica si el jugador tiene ese game pass (según la caché del perfil).
function PlayerStats.HasPass(data: Types.Profile, passKey: string): boolean
    return data.passes[passKey] == true
end

-- Indica si un boost temporal está activo.
function PlayerStats.IsBoostActive(data: Types.Profile, boost: string, now: number): boolean
    local expiresAt = data.boosts[boost]
    return expiresAt ~= nil and expiresAt > now
end

-- Segundos que le quedan a un boost (0 si no está activo).
function PlayerStats.GetBoostRemaining(data: Types.Profile, boost: string, now: number): number
    local expiresAt = data.boosts[boost]
    return if expiresAt then math.max(expiresAt - now, 0) else 0
end

-- Nivel de una mejora permanente.
function PlayerStats.GetPermanentLevel(data: Types.Profile, nodeId: string): number
    local level = data.permanent[nodeId]
    return if type(level) == "number" then level else 0
end

-- Efecto total de una mejora permanente al nivel que tiene el jugador.
function PlayerStats.GetPermanentValue(data: Types.Profile, nodeId: string): number
    return Permanent.GetValue(nodeId, PlayerStats.GetPermanentLevel(data, nodeId))
end

-- Indica si el jugador cumple los requisitos de un nodo (rebirths y nodo del que depende).
function PlayerStats.IsPermanentUnlocked(data: Types.Profile, node: Permanent.Node): boolean
    if data.rebirths < (node.minRebirths or 0) then
        return false
    end
    local requires = node.requires
    return requires == nil or PlayerStats.GetPermanentLevel(data, requires.id) >= requires.level
end

function PlayerStats.GetBackpackCapacity(data: Types.Profile): number
    local capacity = Upgrades.GetBackpackCapacity(data.upgrades.backpack)
        + PlayerStats.GetPermanentValue(data, "capacity")
    if PlayerStats.HasPass(data, "vipBackpack") then
        capacity += Shop.VipBackpackBonus
    end
    return capacity
end

function PlayerStats.GetPedestalCount(data: Types.Profile): number
    local count = Upgrades.GetPedestalCount(data.upgrades.pedestals)
    if PlayerStats.HasPass(data, "extraPedestals") then
        count += Shop.ExtraPedestalsBonus
    end
    return count
end

-- Segundos por golpe: la mejora de pico y lo que ahorra el pico equipado.
function PlayerStats.GetMineTime(data: Types.Profile): number
    return Upgrades.GetMineTime(data.upgrades.pickaxe)
        * (1 - Equipment.GetStat(data, "pickaxe", "speed"))
end

-- WalkSpeed con la mejora, el pass vip y la penalización por carga.
function PlayerStats.GetWalkSpeed(data: Types.Profile, carriedCount: number): number
    local speed = Upgrades.GetWalkSpeed(data.upgrades.speed)
        + PlayerStats.GetPermanentValue(data, "speed")
    if PlayerStats.HasPass(data, "vip") then
        speed *= Shop.VipSpeedMultiplier
    end
    local slowdown = math.min(carriedCount * Carry.SlowdownPerItem, Carry.MaxSlowdown)
    return speed * (1 - slowdown)
end

-- Multiplicador de peso para minerales Raro o superior (mejora de suerte y boost).
function PlayerStats.GetLuckMultiplier(data: Types.Profile, now: number): number
    local luck = Upgrades.GetLuckMultiplier(data.upgrades.luck)
        + PlayerStats.GetPermanentValue(data, "luck")
        + Equipment.GetStat(data, "pickaxe", "rareFind")
    if PlayerStats.IsBoostActive(data, "luck", now) then
        luck *= Shop.LuckBoostMultiplier
    end
    return luck
end

-- Nivel de una mejora. Los perfiles antiguos pueden no tener aún las mejoras nuevas.
function PlayerStats.GetUpgradeLevel(data: Types.Profile, upgradeId: string): number
    local level = (data.upgrades :: any)[upgradeId]
    return if type(level) == "number" then level else 0
end

-- Probabilidad (0-1) de sacar un segundo mineral con el mismo golpe.
function PlayerStats.GetExtraMineralChance(data: Types.Profile): number
    return Upgrades.GetValue("fortune", PlayerStats.GetUpgradeLevel(data, "fortune"))
end

-- Multiplicador de la probabilidad de mutación.
function PlayerStats.GetMutationMultiplier(data: Types.Profile): number
    return Upgrades.GetValue("mutation", PlayerStats.GetUpgradeLevel(data, "mutation"))
        + PlayerStats.GetPermanentValue(data, "mutation")
        + Equipment.GetStat(data, "pickaxe", "mutation")
end

-- Fracción de la mochila que suelta el jugador al recibir un golpe.
function PlayerStats.GetDropFraction(data: Types.Profile): number
    return Upgrades.GetValue("grip", PlayerStats.GetUpgradeLevel(data, "grip"))
end

-- Fracción de la mochila que suelta la víctima con el arma del atacante, con su tope.
function PlayerStats.GetStealDropFraction(victim: Types.Profile, attacker: Types.Profile): number
    return math.min(
        PlayerStats.GetDropFraction(victim) + Equipment.GetStat(attacker, "weapon", "dropPower"),
        Steal.MaxDropFraction
    )
end

-- Alcance del golpe (studs) con el arma equipada.
function PlayerStats.GetHitRange(data: Types.Profile): number
    return Steal.HitRange + Equipment.GetStat(data, "weapon", "range")
end

-- Segundos entre golpes con el arma equipada.
function PlayerStats.GetHitCooldown(data: Types.Profile): number
    return Equipment.GetStat(data, "weapon", "cooldown", Steal.AttackerCooldown)
end

-- Fracción extra de ingresos por los amigos conectados en el mismo servidor (0,2 = +20 %).
function PlayerStats.GetFriendBonus(data: Types.Profile): number
    local friends = math.clamp(data.friendsOnline or 0, 0, Social.MaxFriends)
    return friends * Social.IncomeBonusPerFriend
end

-- Multiplicador de ingresos (rebirths, mejora de refinería, amigos y pass doubleCoins).
function PlayerStats.GetIncomeMultiplier(data: Types.Profile): number
    local multiplier = Rebirth.GetIncomeMultiplier(data.rebirths)
        * Upgrades.GetValue("refinery", PlayerStats.GetUpgradeLevel(data, "refinery"))
        * (1 + PlayerStats.GetFriendBonus(data))
        * (1 + PlayerStats.GetPermanentValue(data, "income"))
    if PlayerStats.HasPass(data, "doubleCoins") then
        multiplier *= Shop.DoubleCoinsMultiplier
    end
    return multiplier
end

-- Fracción del ritmo normal a la que se generan ingresos sin conexión.
function PlayerStats.GetOfflineRate(data: Types.Profile): number
    return math.min(Income.OfflineRate + PlayerStats.GetPermanentValue(data, "offline"), 1)
end

-- Monedas con las que empieza el jugador tras un rebirth: una fracción del coste del siguiente.
function PlayerStats.GetStartCoins(data: Types.Profile): number
    return math.floor(
        Rebirth.GetCost(data.rebirths) * PlayerStats.GetPermanentValue(data, "startCoins")
    )
end

-- Monedas por segundo de un mineral concreto, sin multiplicadores del jugador.
function PlayerStats.GetItemBaseIncome(item: Types.InventoryItem): number
    local mineral = Minerals.ById[item.mineral]
    local mutation = Mutations.ById[item.mutation]
    if mineral == nil then
        return 0
    end
    return mineral.coinsPerSecond * (if mutation then mutation.multiplier else 1)
end

-- Monedas que da vender un mineral.
function PlayerStats.GetSellPrice(item: Types.InventoryItem): number
    return math.floor(PlayerStats.GetItemBaseIncome(item) * Income.SellSeconds)
end

-- Monedas que cuesta fusionar ese mineral con otros iguales (0 si ya no se puede fusionar).
function PlayerStats.GetFuseCost(item: Types.InventoryItem): number
    local mineral = Minerals.ById[item.mineral]
    local nextMutation = Mutations.GetNext(item.mutation)
    if mineral == nil or nextMutation == nil then
        return 0
    end
    return math.floor(mineral.coinsPerSecond * nextMutation.multiplier * Mutations.FuseCostSeconds)
end

-- Indica si un mineral es "común": se vende con el botón de vender en bloque.
function PlayerStats.IsJunk(item: Types.InventoryItem): boolean
    return item.mutation == Mutations.NoneId and Minerals.GetRank(item.mineral) < Minerals.RareRank
end

-- Busca un objeto del inventario de la base por id.
function PlayerStats.FindItem(data: Types.Profile, itemId: string): (Types.InventoryItem?, number?)
    for index, item in data.inventory do
        if item.id == itemId then
            return item, index
        end
    end
    return nil, nil
end

-- Devuelve el número de pedestal en el que está colocado el objeto, o nil.
function PlayerStats.GetPedestalOf(data: Types.Profile, itemId: string): number?
    for key, placedId in data.pedestals do
        if placedId == itemId then
            return tonumber(key)
        end
    end
    return nil
end

-- Monedas por segundo que generan todos los pedestales del jugador.
function PlayerStats.GetIncomePerSecond(data: Types.Profile): number
    local unlocked = PlayerStats.GetPedestalCount(data)
    local total = 0
    for key, itemId in data.pedestals do
        local number = tonumber(key)
        if number and number <= unlocked then
            local item = PlayerStats.FindItem(data, itemId)
            if item then
                total += PlayerStats.GetItemBaseIncome(item)
            end
        end
    end
    return total * PlayerStats.GetIncomeMultiplier(data)
end

-- Monedas que da un paquete de monedas: una fracción del coste del siguiente rebirth.
function PlayerStats.GetCoinPackAmount(data: Types.Profile, product: Shop.Product): number
    return math.floor(Rebirth.GetCost(data.rebirths) * (product.rebirthCostFraction or 0))
end

-- Monedas que da una misión diaria: una fracción del coste del siguiente rebirth.
function PlayerStats.GetQuestReward(data: Types.Profile, quest: Quests.Quest): number
    return math.max(
        Quests.MinReward,
        math.floor(Rebirth.GetCost(data.rebirths) * quest.rewardFraction)
    )
end

-- Progreso de una misión hoy (0 si el progreso guardado es de otro día).
function PlayerStats.GetQuestProgress(data: Types.Profile, questId: string, now: number): number
    if data.quests.day ~= Quests.GetDay(now) then
        return 0
    end
    return data.quests.progress[questId] or 0
end

-- Indica si la recompensa de una misión ya se ha cobrado hoy.
function PlayerStats.IsQuestClaimed(data: Types.Profile, questId: string, now: number): boolean
    return data.quests.day == Quests.GetDay(now) and data.quests.claimed[questId] == true
end

-- Valor de una estadística del jugador: las que salen de otros campos del perfil se calculan
-- aquí y el resto son contadores de `stats`.
function PlayerStats.GetStat(data: Types.Profile, stat: string): number
    if stat == "rebirths" then
        return data.rebirths
    elseif stat == "totalCoinsEarned" then
        return data.totalCoinsEarned
    elseif stat == "playtime" then
        return data.playtime
    elseif stat == "streak" then
        return data.daily.streak
    elseif stat == "likes" then
        return data.social.likes
    end
    -- Las que son "cuántas entradas hay" en una tabla del perfil.
    local counted: { [string]: { [string]: any } } = {
        index = data.index,
        codes = data.codes,
        indexRows = data.indexRewards,
        likesGiven = data.social.liked,
        decorSlots = data.decor.slots,
    }
    local entries = counted[stat]
    if entries then
        local count = 0
        for _ in entries do
            count += 1
        end
        return count
    end
    return data.stats[stat] or 0
end

-- Monedas que da un logro: una fracción del coste del siguiente rebirth.
function PlayerStats.GetAchievementReward(
    data: Types.Profile,
    achievement: Achievements.Achievement
): number
    return math.max(
        Achievements.MinReward,
        math.floor(Rebirth.GetCost(data.rebirths) * achievement.rewardFraction)
    )
end

-- Monedas que da quedar en ese puesto de una competición: una fracción del coste del
-- siguiente rebirth, con un mínimo en proporción al del primer puesto.
function PlayerStats.GetCompetitionReward(data: Types.Profile, place: number): number
    local fraction = Competition.RewardFractions[place]
    if fraction == nil then
        return 0
    end
    return math.max(
        math.floor(Competition.MinReward * fraction / Competition.RewardFractions[1]),
        math.floor(Rebirth.GetCost(data.rebirths) * fraction)
    )
end

-- Monedas que da participar en un evento: una fracción del coste del siguiente rebirth.
function PlayerStats.GetEventReward(data: Types.Profile): number
    return math.max(
        Events.MinReward,
        math.floor(Rebirth.GetCost(data.rebirths) * Events.RewardFraction)
    )
end

-- Monedas de un escalón de temporada: una fracción del coste del siguiente rebirth.
function PlayerStats.GetSeasonCoins(data: Types.Profile, fraction: number): number
    return math.max(LiveOps.SeasonMinCoins, math.floor(Rebirth.GetCost(data.rebirths) * fraction))
end

-- Indica si el jugador ha desbloqueado ese título (el id es el del logro que lo da).
function PlayerStats.OwnsTitle(data: Types.Profile, titleId: string): boolean
    local achievement = Achievements.ById[titleId]
    return achievement ~= nil and achievement.title == true and data.achievements[titleId] == true
end

-- Indica si el jugador cumple la condición de desbloqueo de una decoración o un efecto.
function PlayerStats.IsUnlocked(data: Types.Profile, unlock: Decor.Unlock?): boolean
    if unlock == nil then
        return true
    end
    local achievement = unlock.achievement
    return data.rebirths >= (unlock.rebirths or 0)
        and PlayerStats.GetStat(data, "index") >= (unlock.index or 0)
        and (achievement == nil or data.achievements[achievement] == true)
end

-- Indica si el jugador puede equipar un cosmético (comprado, o exclusivo vip con el pass).
function PlayerStats.OwnsCosmetic(data: Types.Profile, cosmetic: Shop.Cosmetic): boolean
    if cosmetic.vipOnly then
        return PlayerStats.HasPass(data, "vip")
    end
    local rebirthsRequired = cosmetic.rebirthsRequired
    if rebirthsRequired then
        return data.rebirths >= rebirthsRequired
    end
    return table.find(data.cosmetics.owned, cosmetic.key) ~= nil
end

return PlayerStats
