--!strict

-- Tienda: game passes, productos de desarrollador (boosts y monedas) y cosméticos.
-- ProcessReceipt es idempotente: guarda el PurchaseId y solo devuelve PurchaseGranted
-- cuando la compra está entregada y el perfil, guardado en el DataStore.
-- No hay compras aleatorias: todo lo que se compra con Robux es concreto y visible antes de pagar.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local PlotService = require(script.Parent.PlotService)

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Util.Log)
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local Equipment = require(Shared.Config.Equipment)
local EquipmentVisual = require(Shared.Util.EquipmentVisual)
local ShopConfig = require(Shared.Config.Shop)
local Locale = require(Shared.Locale)
local Types = require(Shared.Types)

local ShopService = {}

local equipLimiter = RateLimiter.new(Network.RateLimits.EquipCosmetic)
local characterConnections: { [Player]: RBXScriptConnection } = {}

-- Indica si el jugador tiene el game pass (según la caché del perfil).
function ShopService.HasPass(player: Player, passKey: string): boolean
    local data = DataService.GetData(player)
    return data ~= nil and PlayerStats.HasPass(data, passKey)
end

local function setPass(player: Player, passKey: string, owned: boolean)
    local data = DataService.GetData(player)
    if data == nil or (data.passes[passKey] == true) == owned then
        return
    end
    DataService.Update(player, "passes", function(passes: { [string]: boolean? })
        passes[passKey] = if owned then true else nil
        return passes
    end)
end

local function checkGamePasses(player: Player)
    if RunService:IsStudio() and ShopConfig.IgnoreOwnedPassesInStudio then
        for _, pass in ShopConfig.GamePasses do
            setPass(player, pass.key, false)
        end
        return
    end
    for _, pass in ShopConfig.GamePasses do
        if pass.id ~= 0 then
            local ok, owns = pcall(function(): boolean
                return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
            end)
            if ok then
                setPass(player, pass.key, owns)
            else
                -- Si la comprobación falla se mantiene lo que había en la caché.
                Log.Warn("Shop", `No se pudo comprobar el pass {pass.key}: {owns}`)
            end
        end
    end
end

-- Cosméticos ---------------------------------------------------------------

local function getEquipped(data: Types.Profile, kind: string): ShopConfig.Cosmetic?
    local key = data.cosmetics.equipped[kind]
    local cosmetic = if key then ShopConfig.CosmeticsByKey[key] else nil
    if cosmetic and cosmetic.kind == kind and PlayerStats.OwnsCosmetic(data, cosmetic) then
        return cosmetic
    end
    return nil
end

-- El pico que lleva el personaje en la mano: el modelo del pico equipado (Config/Equipment)
-- y, si tiene un cosmético de pico puesto, con su color en la cabeza.
local function applyPickaxe(character: Model, itemId: string, color: Color3?)
    local signature = `{itemId}:{if color then color:ToHex() else ""}`
    local old = character:FindFirstChild("PickaxeVisual")
    if old then
        if old:GetAttribute("Signature") == signature then
            return
        end
        old:Destroy()
    end
    local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
    local model = EquipmentVisual.Create(itemId, color)
    if model == nil or hand == nil or not hand:IsA("BasePart") then
        return
    end
    model.Name = "PickaxeVisual"
    model:SetAttribute("Signature", signature)
    EquipmentVisual.Attach(
        model,
        hand,
        CFrame.new(0, -hand.Size.Y / 2, -0.6) * CFrame.Angles(math.rad(90), 0, 0)
    )
    model.Parent = character
end

local function applyTrail(character: Model, color: Color3?)
    local root = character:FindFirstChild("HumanoidRootPart")
    if root == nil then
        return
    end
    for _, name in { "CosmeticTrail", "TrailTop", "TrailBottom" } do
        local old = root:FindFirstChild(name)
        if old then
            old:Destroy()
        end
    end
    if color == nil then
        return
    end
    local top = Instance.new("Attachment")
    top.Name = "TrailTop"
    top.Position = Vector3.new(0, 0.8, 0.5)
    top.Parent = root
    local bottom = Instance.new("Attachment")
    bottom.Name = "TrailBottom"
    bottom.Position = Vector3.new(0, -0.8, 0.5)
    bottom.Parent = root
    local trail = Instance.new("Trail")
    trail.Name = "CosmeticTrail"
    trail.Attachment0 = top
    trail.Attachment1 = bottom
    trail.Color = ColorSequence.new(color)
    trail.Transparency = NumberSequence.new(0.2, 1)
    trail.Lifetime = 0.6
    trail.LightEmission = 0.5
    trail.Parent = root
end

local function applyCosmetics(player: Player)
    local data = DataService.GetData(player)
    if data == nil then
        return
    end
    player:SetAttribute("VIP", PlayerStats.HasPass(data, "vip"))

    local base = getEquipped(data, "baseColor")
    PlotService.SetFloorColor(player, if base then base.color else nil)

    local character = player.Character
    if character == nil then
        return
    end
    local pickaxe = getEquipped(data, "pickaxe")
    applyPickaxe(
        character,
        Equipment.GetEquipped(data, "pickaxe").id,
        if pickaxe then pickaxe.color else nil
    )
    local trail = getEquipped(data, "trail")
    applyTrail(character, if trail then trail.color else nil)
end

local function onEquipCosmetic(player: Player, cosmeticKey: unknown, equip: unknown)
    if not equipLimiter.Check(player) then
        return
    end
    if type(cosmeticKey) ~= "string" or type(equip) ~= "boolean" then
        return
    end
    local cosmetic = ShopConfig.CosmeticsByKey[cosmeticKey]
    local data = DataService.GetData(player)
    if cosmetic == nil or data == nil or not PlayerStats.OwnsCosmetic(data, cosmetic) then
        return
    end
    DataService.Update(player, "cosmetics", function(cosmetics: Types.CosmeticsData)
        if equip then
            cosmetics.equipped[cosmetic.kind] = cosmetic.key
        elseif cosmetics.equipped[cosmetic.kind] == cosmetic.key then
            cosmetics.equipped[cosmetic.kind] = nil
        end
        return cosmetics
    end)
end

-- Compras --------------------------------------------------------------------

local function findProductById(productId: number): (ShopConfig.Product?, ShopConfig.Cosmetic?)
    if productId == 0 then
        return nil, nil
    end
    for _, product in ShopConfig.Products do
        if product.id == productId then
            return product, nil
        end
    end
    for _, cosmetic in ShopConfig.Cosmetics do
        if cosmetic.id == productId then
            return nil, cosmetic
        end
    end
    return nil, nil
end

local function grantProduct(player: Player, data: Types.Profile, product: ShopConfig.Product)
    if product.kind == "boost" and product.boost and product.duration then
        local boost = product.boost
        local duration = product.duration
        DataService.Update(player, "boosts", function(boosts: { [string]: number })
            -- Si ya estaba activo, se suma el tiempo.
            boosts[boost] = math.max(boosts[boost] or 0, os.time()) + duration
            return boosts
        end)
    elseif product.kind == "coins" then
        IncomeService.AddCoins(player, PlayerStats.GetCoinPackAmount(data, product), "shop")
    end
end

local function grantCosmetic(player: Player, cosmetic: ShopConfig.Cosmetic)
    DataService.Update(player, "cosmetics", function(cosmetics: Types.CosmeticsData)
        if not table.find(cosmetics.owned, cosmetic.key) then
            table.insert(cosmetics.owned, cosmetic.key)
        end
        cosmetics.equipped[cosmetic.kind] = cosmetic.key
        return cosmetics
    end)
end

-- Entrega una compra exactamente una vez y solo la da por buena cuando está guardada:
--   1. Si el PurchaseId no está en el perfil, se entrega y se apunta, sin ceder el hilo entre
--      las dos cosas.
--   2. Se guarda el perfil y se espera a ver el PurchaseId en los datos guardados.
-- Si el servidor se cae antes del guardado, Roblox vuelve a enviar el recibo y, como el
-- PurchaseId no llegó a guardarse, se entrega entonces. Si el jugador se va antes de
-- confirmarlo, el recibo vuelve al entrar y el PurchaseId ya guardado evita entregarlo dos veces.
local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    local data = if player then DataService.WaitForData(player) else nil
    if player == nil or data == nil then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local purchaseId = tostring(receiptInfo.PurchaseId)
    if not table.find(data.purchases, purchaseId) then
        local product, cosmetic = findProductById(receiptInfo.ProductId)
        if product == nil and cosmetic == nil then
            Log.Warn("Shop", `Producto desconocido: {receiptInfo.ProductId}`)
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        local ok, err = pcall(function()
            if product then
                grantProduct(player, data, product)
            elseif cosmetic then
                grantCosmetic(player, cosmetic)
            end
            DataService.Update(player, "purchases", function(purchases: { string })
                table.insert(purchases, purchaseId)
                while #purchases > ShopConfig.MaxStoredPurchases do
                    table.remove(purchases, 1)
                end
                return purchases
            end)
        end)
        if not ok then
            Log.Warn("Shop", `Error al entregar la compra {purchaseId}: {err}`)
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        Remotes.Notify:FireClient(player, Locale.Msg("Shop.Thanks"))
    end

    local saved = DataService.SaveAndWait(player, function(savedData: Types.Profile): boolean
        return table.find(savedData.purchases or {}, purchaseId) ~= nil
    end)
    if not saved then
        Log.Warn("Shop", `Compra {purchaseId} entregada pero sin confirmar el guardado`)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Solo para pruebas: procesa un recibo inventado de ese producto o cosmético. Repetir el
-- mismo `purchaseId` permite comprobar que no se entrega dos veces.
function ShopService.DebugProcessReceipt(player: Player, key: string, purchaseId: string): string
    local product = ShopConfig.ProductsByKey[key]
    local cosmetic = ShopConfig.CosmeticsByKey[key]
    local productId = if product then product.id elseif cosmetic then cosmetic.id else 0
    return processReceipt({
        PlayerId = player.UserId,
        ProductId = productId,
        PurchaseId = purchaseId,
    }).Name
end

function ShopService.Init()
    DataService.OnProfileLoaded(function(player: Player)
        checkGamePasses(player)
        applyCosmetics(player)
    end)
    for _, key in { "cosmetics", "passes", "equipment" } do
        DataService.OnFieldChanged(key, function(player: Player)
            applyCosmetics(player)
        end)
    end
    Remotes.EquipCosmetic.OnServerEvent:Connect(onEquipCosmetic)
end

function ShopService.Start()
    MarketplaceService.ProcessReceipt = processReceipt

    MarketplaceService.PromptGamePassPurchaseFinished:Connect(
        function(player: Player, passId: number, purchased: boolean)
            if not purchased then
                return
            end
            for _, pass in ShopConfig.GamePasses do
                if pass.id ~= 0 and pass.id == passId then
                    setPass(player, pass.key, true)
                    Remotes.Notify:FireClient(player, Locale.Msg("Shop.Thanks"))
                end
            end
        end
    )

    local function onPlayerAdded(player: Player)
        characterConnections[player] = player.CharacterAdded:Connect(function(character: Model)
            character:WaitForChild("HumanoidRootPart", 10)
            applyCosmetics(player)
        end)
    end
    Players.PlayerAdded:Connect(onPlayerAdded)
    for _, player in Players:GetPlayers() do
        onPlayerAdded(player)
    end
    Players.PlayerRemoving:Connect(function(player: Player)
        local connection = characterConnections[player]
        if connection then
            connection:Disconnect()
            characterConnections[player] = nil
        end
    end)
end

return ShopService
