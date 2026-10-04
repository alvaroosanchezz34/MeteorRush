--!strict

-- Equipamiento del jugador: los picos y las armas que tiene, cuál lleva equipado de cada
-- tipo, su colección y su Forge Dust. Todo vive en el campo `equipment` del perfil.
-- Los objetos son por tipo, no por unidad: se tiene un objeto o no se tiene. Un duplicado
-- se convierte en Forge Dust, así que nunca hay dos copias que se puedan duplicar.
--
-- Lo que hace cada estadística lo aplican MiningService (picos) y StealService (armas),
-- leyéndola con Config/Equipment. Aquí solo se gestiona qué se tiene y qué se lleva puesto.
-- Los atributos `Pickaxe` y `Weapon` del jugador dicen a los clientes qué lleva cada uno.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)

local Shared = ReplicatedStorage.Shared
local Equipment = require(Shared.Config.Equipment)
local EquipmentVisual = require(Shared.Util.EquipmentVisual)
local Log = require(Shared.Util.Log)
local Network = require(Shared.Config.Network)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local ShopConfig = require(Shared.Config.Shop)
local Types = require(Shared.Types)

local WEAPON_VISUAL = "WeaponVisual"
-- Tope de Forge Dust, para que el número nunca se desborde.
local MAX_DUST = 1e9

local EquipmentService = {}

local limiter = RateLimiter.new(Network.RateLimits.EquipGear)

-- Deja el campo en un estado válido sin borrar nada: los objetos iniciales siempre se
-- tienen, lo equipado tiene que existir y ser del jugador, y los números tienen que serlo.
-- Los ids que este servidor no conoce se dejan como están (pueden ser de otra versión).
local function sanitize(equipment: Types.EquipmentData): Types.EquipmentData
    for _, field in { "owned", "crates", "pity", "collection" } do
        if type((equipment :: any)[field]) ~= "table" then
            (equipment :: any)[field] = {}
        end
    end
    for kind, default in Equipment.Defaults do
        equipment.owned[default] = true
        local equipped = Equipment.ById[(equipment :: any)[kind]]
        if equipped == nil or equipped.kind ~= kind or not equipment.owned[equipped.id] then
            (equipment :: any)[kind] = default
        end
    end
    for itemId, owned in equipment.owned do
        if owned == true and Equipment.ById[itemId] then
            equipment.collection[itemId] = true
        end
    end
    if type(equipment.dust) ~= "number" or equipment.dust ~= equipment.dust then
        equipment.dust = 0
    end
    equipment.dust = math.clamp(math.floor(equipment.dust), 0, MAX_DUST)
    if type(equipment.opened) ~= "number" then
        equipment.opened = 0
    end
    return equipment
end

-- El arma se lleva colgada a un lado del torso (la espalda es para la carga).
local function applyWeapon(player: Player)
    local character = player.Character
    local data = DataService.GetData(player)
    if character == nil or data == nil then
        return
    end
    local weapon = Equipment.GetEquipped(data, "weapon")
    local old = character:FindFirstChild(WEAPON_VISUAL)
    if old then
        if old:GetAttribute("ItemId") == weapon.id then
            return
        end
        old:Destroy()
    end
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    local model = EquipmentVisual.Create(weapon.id)
    if model == nil or torso == nil or not torso:IsA("BasePart") then
        return
    end
    model.Name = WEAPON_VISUAL
    model:SetAttribute("ItemId", weapon.id)
    EquipmentVisual.Attach(
        model,
        torso,
        CFrame.new(-(torso.Size.X / 2 + 0.25), -1.1, 0.1) * CFrame.Angles(math.rad(18), 0, 0)
    )
    model.Parent = character
end

local function publish(player: Player)
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    player:SetAttribute("Pickaxe", Equipment.GetEquipped(data, "pickaxe").id)
    player:SetAttribute("Weapon", Equipment.GetEquipped(data, "weapon").id)
    applyWeapon(player)
end

-- Apunta un objeto en los datos de equipamiento. Devuelve true si es nuevo y, si es un
-- duplicado, el Forge Dust en que se convierte (que ya queda sumado).
-- Trabaja sobre la tabla, para poder usarse dentro de un DataService.Update.
function EquipmentService.ApplyGrant(
    equipment: Types.EquipmentData,
    item: Equipment.Item
): (boolean, number)
    if equipment.owned[item.id] then
        local dust = Equipment.Rarities[item.rarity].dust
        equipment.dust = math.min(equipment.dust + dust, MAX_DUST)
        return false, dust
    end
    equipment.owned[item.id] = true
    equipment.collection[item.id] = true
    return true, 0
end

-- Da un pico o un arma. Devuelve (hecho, esNuevo, forgeDustPorDuplicado).
function EquipmentService.Grant(player: Player, itemId: string): (boolean, boolean, number)
    local item = Equipment.ById[itemId]
    if item == nil or DataService.GetData(player) == nil then
        return false, false, 0
    end
    local isNew, dust = false, 0
    DataService.Update(player, "equipment", function(equipment: Types.EquipmentData)
        isNew, dust = EquipmentService.ApplyGrant(equipment, item)
        return equipment
    end)
    return true, isNew, dust
end

-- Quita un objeto (no el inicial). Si lo llevaba puesto, vuelve al inicial.
function EquipmentService.Remove(player: Player, itemId: string): boolean
    local item = Equipment.ById[itemId]
    local data = DataService.GetData(player)
    if item == nil or item.starter or data == nil or not Equipment.Owns(data, itemId) then
        return false
    end
    DataService.Update(player, "equipment", function(equipment: Types.EquipmentData)
        equipment.owned[itemId] = nil
        return sanitize(equipment)
    end)
    return true
end

-- Suma (o resta) Forge Dust. Devuelve false si no hay suficiente para restar.
function EquipmentService.AddDust(player: Player, amount: number): boolean
    local data = DataService.GetData(player)
    if data == nil or amount ~= amount or data.equipment.dust + amount < 0 then
        return false
    end
    DataService.Update(player, "equipment", function(equipment: Types.EquipmentData)
        equipment.dust = math.clamp(equipment.dust + math.floor(amount), 0, MAX_DUST)
        return equipment
    end)
    return true
end

-- Da un cosmético de caja. Devuelve (esNuevo, forgeDustPorDuplicado).
function EquipmentService.GrantCosmetic(
    player: Player,
    key: string,
    rarity: string
): (boolean, number)
    local data = DataService.GetData(player)
    local cosmetic = ShopConfig.CosmeticsByKey[key]
    if data == nil or cosmetic == nil then
        return false, 0
    end
    if table.find(data.cosmetics.owned, key) then
        local dust = Equipment.Rarities[rarity].dust
        EquipmentService.AddDust(player, dust)
        return false, dust
    end
    DataService.Update(player, "cosmetics", function(cosmetics: Types.CosmeticsData)
        table.insert(cosmetics.owned, key)
        return cosmetics
    end)
    return true, 0
end

-- Indica si el jugador puede ofrecer ese objeto en un intercambio: lo tiene, se puede
-- intercambiar y no lo lleva puesto.
function EquipmentService.CanTrade(player: Player, itemId: string): boolean
    local data = DataService.GetData(player)
    local item = Equipment.ById[itemId]
    if data == nil or item == nil or not Equipment.IsTradeable(item) then
        return false
    end
    return Equipment.Owns(data, itemId) and Equipment.GetEquipped(data, item.kind).id ~= itemId
end

-- Indica si el jugador puede recibir ese objeto en un intercambio (no lo tiene ya).
function EquipmentService.CanReceive(player: Player, itemId: string): boolean
    local data = DataService.GetData(player)
    return data ~= nil and Equipment.ById[itemId] ~= nil and not Equipment.Owns(data, itemId)
end

-- Pasa un objeto de un jugador a otro (intercambios). No cede el hilo: o se mueve entero o
-- no se mueve. Quien llama ya ha comprobado CanTrade y CanReceive.
function EquipmentService.Move(from: Player, to: Player, itemId: string): boolean
    if
        not EquipmentService.CanTrade(from, itemId) or not EquipmentService.CanReceive(to, itemId)
    then
        return false
    end
    DataService.Update(from, "equipment", function(equipment: Types.EquipmentData)
        equipment.owned[itemId] = nil
        return equipment
    end)
    DataService.Update(to, "equipment", function(equipment: Types.EquipmentData)
        equipment.owned[itemId] = true
        equipment.collection[itemId] = true
        return equipment
    end)
    return true
end

local function onEquip(player: Player, itemId: unknown)
    if not limiter.Check(player) then
        return
    end
    if type(itemId) ~= "string" then
        Log.Suspicious(player, "EquipGear", "tipo inválido")
        return
    end
    local item = Equipment.ById[itemId]
    local data = DataService.GetData(player)
    if item == nil or data == nil or not Equipment.Owns(data, itemId) then
        return
    end
    if Equipment.GetEquipped(data, item.kind).id == itemId then
        return
    end
    DataService.Update(player, "equipment", function(equipment: Types.EquipmentData)
        (equipment :: any)[item.kind] = itemId
        return equipment
    end)
end

function EquipmentService.Init()
    Remotes.EquipGear.OnServerEvent:Connect(onEquip)

    DataService.OnProfileLoaded(function(player: Player)
        -- Perfiles antiguos o con algo raro: se arreglan sin borrar nada. Si fallara, el
        -- campo se queda como estaba y GetEquipped sigue devolviendo el objeto inicial.
        local ok, err = pcall(DataService.Update, player, "equipment", sanitize)
        if not ok then
            Log.Warn("Equipment", `No se pudo revisar el equipamiento de {player.Name}: {err}`)
        end
        publish(player)
    end)
    DataService.OnFieldChanged("equipment", publish)
end

function EquipmentService.Start()
    local function onPlayer(player: Player)
        player.CharacterAdded:Connect(function(character: Model)
            if character:WaitForChild("HumanoidRootPart", 10) then
                -- Un instante para que el personaje termine de montarse.
                task.wait(0.2)
                applyWeapon(player)
            end
        end)
    end
    Players.PlayerAdded:Connect(onPlayer)
    for _, player in Players:GetPlayers() do
        onPlayer(player)
    end
end

return EquipmentService
