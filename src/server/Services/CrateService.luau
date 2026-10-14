--!strict

-- Cajas de equipamiento: comprarlas y abrirlas. El cliente solo pide "compra esta caja" o
-- "abre esta caja"; el servidor comprueba que la tiene, la gasta, tira el resultado, lo
-- guarda en el perfil y solo entonces se lo dice al cliente, que pone la animación.
-- Saltarse la animación no cambia nada: cuando empieza, el objeto ya está guardado.
--
-- Contra duplicaciones: gastar la caja, tirar el resultado y apuntarlo ocurre dentro de un
-- único DataService.Update, sin ceder el hilo, así que dos peticiones a la vez no pueden
-- abrir la misma caja dos veces. Además hay un intervalo mínimo entre aperturas.
--
-- Las cajas que se compran con monedas son "objetos aleatorios de pago" para Roblox (las
-- monedas se pueden comprar con Robux): el menú enseña las probabilidades y, donde la
-- política del jugador lo restringe (PolicyService), no se pueden comprar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementService = require(script.Parent.AchievementService)
local DataService = require(script.Parent.DataService)
local EquipmentService = require(script.Parent.EquipmentService)
local IncomeService = require(script.Parent.IncomeService)
local PolicyGateService = require(script.Parent.PolicyGateService)

local Shared = ReplicatedStorage.Shared
local Crates = require(Shared.Config.Crates)
local Equipment = require(Shared.Config.Equipment)
local Log = require(Shared.Util.Log)
local Network = require(Shared.Config.Network)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)

local CrateService = {}

local rng = Random.new()
local buyLimiter = RateLimiter.new(Network.RateLimits.BuyCrate)
local openLimiter = RateLimiter.new(Network.RateLimits.OpenCrate)
local lastOpenAt: { [Player]: number } = {}
local function rank(rarity: string): number
    local entry = Equipment.Rarities[rarity]
    return if entry then entry.rank else 0
end

-- Tira una caja. `pityCount` son las aperturas seguidas sin premio mínimo. Devuelve la
-- recompensa (nil si la caja no tiene nada que dar) y si ha saltado el seguro.
local function roll(crate: Crates.Crate, pityCount: number): (Crates.Reward?, boolean)
    local pool = Crates.GetPool(crate)
    local pity = crate.pity
    local guaranteed = pity.enabled and pityCount + 1 >= pity.threshold
    local minRank = if guaranteed then rank(pity.minimum) else 0

    local function pick(minimum: number): Crates.Reward?
        local total = 0
        for rarity, weight in crate.weights do
            if pool[rarity] and rank(rarity) >= minimum then
                total += weight
            end
        end
        if total <= 0 then
            return nil
        end
        local value = rng:NextNumber() * total
        local last: Crates.Reward? = nil
        -- En orden fijo de rareza, para que el recorrido no dependa del orden de la tabla.
        for _, rarity in Equipment.RarityOrder do
            local weight = crate.weights[rarity]
            local rewards = pool[rarity]
            if weight and rewards and rank(rarity) >= minimum then
                value -= weight
                last = rewards[rng:NextInteger(1, #rewards)]
                if value <= 0 then
                    return last
                end
            end
        end
        return last
    end

    local reward = pick(minRank)
    if reward == nil and minRank > 0 then
        -- La caja no tiene nada de esa rareza: tirada normal.
        return pick(0), false
    end
    return reward, guaranteed
end

-- Envía el resultado al cliente para que lo presente.
-- `preview` = prueba de administración: no se ha dado nada.
function CrateService.ShowReveal(
    player: Player,
    crateId: string,
    reward: Crates.Reward,
    isNew: boolean,
    dust: number,
    preview: boolean?
)
    Remotes.CrateResult:FireClient(
        player,
        crateId,
        reward.kind,
        reward.id,
        reward.rarity,
        isNew,
        dust,
        preview == true
    )
end

-- Tira una caja sin gastar ni dar nada (prueba de administración).
function CrateService.Preview(crateId: string): Crates.Reward?
    local crate = Crates.ById[crateId]
    return if crate then (roll(crate, 0)) else nil
end

-- Da cajas sin cobrar (administración, eventos, recompensas). Devuelve cuántas ha dado.
function CrateService.Give(player: Player, crateId: string, count: number): number
    if Crates.ById[crateId] == nil or DataService.GetData(player) == nil or count < 1 then
        return 0
    end
    local given = 0
    DataService.Update(player, "equipment", function(equipment: Types.EquipmentData)
        local stored = equipment.crates[crateId] or 0
        given = math.clamp(math.floor(count), 0, Crates.MaxStored - stored)
        equipment.crates[crateId] = stored + given
        return equipment
    end)
    return given
end

-- Fija el contador del seguro de una caja (administración).
function CrateService.SetPity(player: Player, crateId: string, count: number): boolean
    local crate = Crates.ById[crateId]
    if crate == nil or DataService.GetData(player) == nil then
        return false
    end
    DataService.Update(player, "equipment", function(equipment: Types.EquipmentData)
        equipment.pity[crateId] = math.clamp(math.floor(count), 0, crate.pity.threshold)
        return equipment
    end)
    return true
end

local function onBuy(player: Player, crateId: unknown)
    if not buyLimiter.Check(player) then
        return
    end
    if type(crateId) ~= "string" then
        Log.Suspicious(player, "BuyCrate", "tipo inválido")
        return
    end
    local crate = Crates.ById[crateId]
    local data = DataService.GetData(player)
    if crate == nil or data == nil then
        return
    end
    local currency, price = Crates.GetCost(crate, data)
    if currency == nil then
        return
    end
    if (data.equipment.crates[crateId] or 0) >= Crates.MaxStored then
        Remotes.Notify:FireClient(player, Strings.Crates.Full)
        return
    end
    -- Política del jugador: si no puede comprar objetos aleatorios de pago, no compra
    -- ninguna caja, tampoco con Forge Dust (que sale de cajas). Mientras no se sepa, tampoco.
    local allowed = PolicyGateService.CanBuyRandomItems(player)
    if allowed ~= true then
        PolicyGateService.Refresh(player)
        Remotes.Notify:FireClient(
            player,
            if allowed == false then Strings.Crates.Restricted else Strings.Crates.TryAgain
        )
        return
    end
    if currency == "coins" then
        if not IncomeService.SpendCoins(player, price, "crates") then
            Remotes.Notify:FireClient(player, Strings.Crates.NotEnoughCoins)
            return
        end
    elseif not EquipmentService.AddDust(player, -price) then
        Remotes.Notify:FireClient(player, Strings.Crates.NotEnoughDust)
        return
    end
    CrateService.Give(player, crateId, 1)
end

local function onOpen(player: Player, crateId: unknown)
    if not openLimiter.Check(player) then
        return
    end
    if type(crateId) ~= "string" then
        Log.Suspicious(player, "OpenCrate", "tipo inválido")
        return
    end
    local crate = Crates.ById[crateId]
    local data = DataService.GetData(player)
    if crate == nil or data == nil then
        return
    end
    local now = os.clock()
    if now - (lastOpenAt[player] or -math.huge) < Crates.OpenInterval then
        return
    end
    if (data.equipment.crates[crateId] or 0) < 1 then
        return
    end
    lastOpenAt[player] = now

    -- Gastar la caja, tirar y apuntar el resultado: todo en una sola modificación del perfil.
    local reward: Crates.Reward? = nil
    local isNew, dust = false, 0
    local cosmeticOwned = data.cosmetics.owned
    DataService.Update(player, "equipment", function(equipment: Types.EquipmentData)
        local stored = equipment.crates[crateId] or 0
        if stored < 1 then
            return equipment
        end
        local rolled = roll(crate, equipment.pity[crateId] or 0)
        if rolled == nil then
            -- Caja sin contenido (error de configuración): no se gasta.
            return equipment
        end
        reward = rolled
        equipment.crates[crateId] = if stored > 1 then stored - 1 else nil
        equipment.opened += 1
        equipment.pity[crateId] = if rank(rolled.rarity) >= rank(crate.pity.minimum)
            then 0
            else (equipment.pity[crateId] or 0) + 1

        local item = Equipment.ById[rolled.id]
        if rolled.kind ~= "cosmetic" and item then
            isNew, dust = EquipmentService.ApplyGrant(equipment, item)
        elseif table.find(cosmeticOwned, rolled.id) then
            -- Cosmético repetido: Forge Dust, igual que un objeto repetido.
            dust = Equipment.Rarities[rolled.rarity].dust
            equipment.dust += dust
        else
            isNew = true
        end
        return equipment
    end)

    local result = reward
    if result == nil then
        Log.Warn("Crates", `La caja {crateId} no tiene nada que dar`)
        return
    end
    if result.kind == "cosmetic" and isNew then
        DataService.Update(player, "cosmetics", function(cosmetics: Types.CosmeticsData)
            if not table.find(cosmetics.owned, result.id) then
                table.insert(cosmetics.owned, result.id)
            end
            return cosmetics
        end)
    end
    AchievementService.AddStat(player, "cratesOpened", 1)
    CrateService.ShowReveal(player, crateId, result, isNew, dust)
end

function CrateService.Init()
    -- Las probabilidades que ve el jugador salen de estos pesos: tienen que cuadrar.
    for _, crate in Crates.List do
        local problem = Crates.Validate(crate)
        if problem then
            Log.Warn("Crates", `Caja "{crate.id}" mal configurada: {problem}`)
        end
    end
    Remotes.BuyCrate.OnServerEvent:Connect(onBuy)
    Remotes.OpenCrate.OnServerEvent:Connect(onOpen)
end

function CrateService.Start()
    Players.PlayerRemoving:Connect(function(player: Player)
        lastOpenAt[player] = nil
    end)
end

return CrateService
