--!strict

-- Productos de la tienda. Los ids reales se crean en el panel de creador de Roblox.
-- Un id 0 hace que la tienda muestre el producto como "Próximamente" y no lance la compra.
-- Los precios son orientativos y solo se usan para mostrarlos; el precio real lo fija Roblox.

export type GamePass = {
    key: string,
    id: number,
    price: number,
}

export type Product = {
    key: string,
    id: number,
    price: number,
    kind: "boost" | "coins",
    -- kind = "boost"
    boost: string?,
    duration: number?,
    -- kind = "coins": fracción del coste del siguiente rebirth (escala con los rebirths)
    rebirthCostFraction: number?,
}

export type Cosmetic = {
    key: string,
    id: number,
    price: number,
    kind: "pickaxe" | "trail" | "baseColor",
    color: Color3,
    -- Solo para quien tiene el game pass vip; no se compra.
    vipOnly: boolean?,
}

local Shop = {}

-- Efectos de los game passes.
Shop.DoubleCoinsMultiplier = 2
Shop.VipBackpackBonus = 10
Shop.ExtraPedestalsBonus = 6
Shop.VipSpeedMultiplier = 1.1

-- Efectos de los boosts.
Shop.LuckBoostMultiplier = 2

-- Máximo de ids de recibo guardados para la idempotencia de ProcessReceipt.
Shop.MaxStoredPurchases = 100

Shop.GamePasses = {
    { key = "doubleCoins", id = 0, price = 199 }, -- TODO: id real
    { key = "vipBackpack", id = 0, price = 149 }, -- TODO: id real
    { key = "autoCollect", id = 0, price = 249 }, -- TODO: id real
    { key = "extraPedestals", id = 0, price = 299 }, -- TODO: id real
    { key = "vip", id = 0, price = 399 }, -- TODO: id real
} :: { GamePass }

Shop.Products = {
    {
        key = "carryShield30",
        id = 0,
        price = 49,
        kind = "boost",
        boost = "carryShield",
        duration = 30 * 60,
    }, -- TODO: id real
    { key = "magnet30", id = 0, price = 39, kind = "boost", boost = "magnet", duration = 30 * 60 }, -- TODO: id real
    { key = "luck30", id = 0, price = 79, kind = "boost", boost = "luck", duration = 30 * 60 }, -- TODO: id real
    { key = "coinsSmall", id = 0, price = 49, kind = "coins", rebirthCostFraction = 0.02 }, -- TODO: id real
    { key = "coinsMedium", id = 0, price = 149, kind = "coins", rebirthCostFraction = 0.08 }, -- TODO: id real
    { key = "coinsLarge", id = 0, price = 399, kind = "coins", rebirthCostFraction = 0.25 }, -- TODO: id real
} :: { Product }

-- Cosméticos: compra directa con Robux (producto de desarrollador). El jugador ve el color antes de pagar.
Shop.Cosmetics = {
    {
        key = "pickaxeGold",
        id = 0,
        price = 99,
        kind = "pickaxe",
        color = Color3.fromRGB(255, 200, 50),
    }, -- TODO: id real
    {
        key = "pickaxeCrystal",
        id = 0,
        price = 149,
        kind = "pickaxe",
        color = Color3.fromRGB(120, 220, 255),
    }, -- TODO: id real
    { key = "trailFire", id = 0, price = 99, kind = "trail", color = Color3.fromRGB(255, 110, 30) }, -- TODO: id real
    {
        key = "trailCosmic",
        id = 0,
        price = 149,
        kind = "trail",
        color = Color3.fromRGB(160, 90, 255),
    }, -- TODO: id real
    {
        key = "trailVip",
        id = 0,
        price = 0,
        kind = "trail",
        color = Color3.fromRGB(255, 215, 0),
        vipOnly = true,
    },
    {
        key = "baseOcean",
        id = 0,
        price = 79,
        kind = "baseColor",
        color = Color3.fromRGB(60, 120, 200),
    }, -- TODO: id real
    {
        key = "baseForest",
        id = 0,
        price = 79,
        kind = "baseColor",
        color = Color3.fromRGB(70, 150, 80),
    }, -- TODO: id real
} :: { Cosmetic }

-- Color del pico por defecto.
Shop.DefaultPickaxeColor = Color3.fromRGB(150, 150, 160)

local passesByKey: { [string]: GamePass } = {}
for _, pass in Shop.GamePasses do
    passesByKey[pass.key] = pass
end
Shop.GamePassesByKey = passesByKey

local productsByKey: { [string]: Product } = {}
for _, product in Shop.Products do
    productsByKey[product.key] = product
end
Shop.ProductsByKey = productsByKey

local cosmeticsByKey: { [string]: Cosmetic } = {}
for _, cosmetic in Shop.Cosmetics do
    cosmeticsByKey[cosmetic.key] = cosmetic
end
Shop.CosmeticsByKey = cosmeticsByKey

return Shop
