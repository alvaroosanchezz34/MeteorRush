--!strict

-- Estadísticas derivadas de los datos del jugador (mejoras, game passes, boosts y rebirths).
-- Se comparten entre servidor y cliente para que la interfaz muestre exactamente lo mismo
-- que calcula el servidor. `now` es la hora Unix del servidor (os.time() o GetServerTimeNow()).

local Config = script.Parent.Parent.Config
local Carry = require(Config.Carry)
local Income = require(Config.Income)
local Minerals = require(Config.Minerals)
local Mutations = require(Config.Mutations)
local Quests = require(Config.Quests)
local Rebirth = require(Config.Rebirth)
local Shop = require(Config.Shop)
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

function PlayerStats.GetBackpackCapacity(data: Types.Profile): number
    local capacity = Upgrades.GetBackpackCapacity(data.upgrades.backpack)
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

function PlayerStats.GetMineTime(data: Types.Profile): number
    return Upgrades.GetMineTime(data.upgrades.pickaxe)
end

-- WalkSpeed con la mejora, el pass vip y la penalización por carga.
function PlayerStats.GetWalkSpeed(data: Types.Profile, carriedCount: number): number
    local speed = Upgrades.GetWalkSpeed(data.upgrades.speed)
    if PlayerStats.HasPass(data, "vip") then
        speed *= Shop.VipSpeedMultiplier
    end
    local slowdown = math.min(carriedCount * Carry.SlowdownPerItem, Carry.MaxSlowdown)
    return speed * (1 - slowdown)
end

-- Multiplicador de peso para minerales Raro o superior (mejora de suerte y boost).
function PlayerStats.GetLuckMultiplier(data: Types.Profile, now: number): number
    local luck = Upgrades.GetLuckMultiplier(data.upgrades.luck)
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
end

-- Fracción de la mochila que suelta el jugador al recibir un golpe.
function PlayerStats.GetDropFraction(data: Types.Profile): number
    return Upgrades.GetValue("grip", PlayerStats.GetUpgradeLevel(data, "grip"))
end

-- Multiplicador de ingresos (rebirths, mejora de refinería y pass doubleCoins).
function PlayerStats.GetIncomeMultiplier(data: Types.Profile): number
    local multiplier = Rebirth.GetIncomeMultiplier(data.rebirths)
        * Upgrades.GetValue("refinery", PlayerStats.GetUpgradeLevel(data, "refinery"))
    if PlayerStats.HasPass(data, "doubleCoins") then
        multiplier *= Shop.DoubleCoinsMultiplier
    end
    return multiplier
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

-- Indica si el jugador puede equipar un cosmético (comprado, o exclusivo vip con el pass).
function PlayerStats.OwnsCosmetic(data: Types.Profile, cosmetic: Shop.Cosmetic): boolean
    if cosmetic.vipOnly then
        return PlayerStats.HasPass(data, "vip")
    end
    return table.find(data.cosmetics.owned, cosmetic.key) ~= nil
end

return PlayerStats
