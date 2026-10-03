--!strict

-- Tienda: game passes, productos de desarrollador (boosts y monedas) y cosméticos.
-- ProcessReceipt es idempotente: guarda el PurchaseId y solo devuelve PurchaseGranted
-- después de aplicar la recompensa en el perfil.
-- No hay compras aleatorias: todo lo que se compra con Robux es concreto y visible antes de pagar.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local PlotService = require(script.Parent.PlotService)

local Shared = ReplicatedStorage.Shared
local Network = require(Shared.Config.Network)
local PlayerStats = require(Shared.Util.PlayerStats)
local RateLimiter = require(Shared.Util.RateLimiter)
local Remotes = require(Shared.Remotes)
local ShopConfig = require(Shared.Config.Shop)
local Strings = require(Shared.Strings)
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
                warn(`[ShopService] No se pudo comprobar el pass {pass.key}: {owns}`)
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

local function applyPickaxe(character: Model, color: Color3)
    local old = character:FindFirstChild("PickaxeVisual")
    if old then
        old:Destroy()
    end
    local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
    if hand == nil or not hand:IsA("BasePart") then
        return
    end

    local model = Instance.new("Model")
    model.Name = "PickaxeVisual"
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.3, 3, 0.3)
    handle.Color = Color3.fromRGB(110, 80, 50)
    handle.Material = Enum.Material.Wood
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(2.2, 0.4, 0.4)
    head.Color = color
    head.Material = Enum.Material.Metal
    for _, part in { handle, head } do
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Massless = true
        part.Parent = model
    end

    handle.CFrame = hand.CFrame
        * CFrame.new(0, -hand.Size.Y / 2, -0.6)
        * CFrame.Angles(math.rad(90), 0, 0)
    head.CFrame = handle.CFrame * CFrame.new(0, 1.5, 0)
    local headWeld = Instance.new("WeldConstraint")
    headWeld.Part0 = handle
    headWeld.Part1 = head
    headWeld.Parent = head
    local handWeld = Instance.new("WeldConstraint")
    handWeld.Part0 = hand
    handWeld.Part1 = handle
    handWeld.Parent = handle
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
    applyPickaxe(character, if pickaxe then pickaxe.color else ShopConfig.DefaultPickaxeColor)
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
        IncomeService.AddCoins(player, PlayerStats.GetCoinPackAmount(data, product))
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

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    local data = if player then DataService.GetData(player) else nil
    if player == nil or data == nil then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local purchaseId = tostring(receiptInfo.PurchaseId)
    if table.find(data.purchases, purchaseId) then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    local product, cosmetic = findProductById(receiptInfo.ProductId)
    if product == nil and cosmetic == nil then
        warn(`[ShopService] Producto desconocido: {receiptInfo.ProductId}`)
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
        warn(`[ShopService] Error al entregar la compra {purchaseId}: {err}`)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    Remotes.Notify:FireClient(player, Strings.Shop.Thanks)
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.Init()
    DataService.OnProfileLoaded(function(player: Player)
        checkGamePasses(player)
        applyCosmetics(player)
    end)
    for _, key in { "cosmetics", "passes" } do
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
                    Remotes.Notify:FireClient(player, Strings.Shop.Thanks)
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
