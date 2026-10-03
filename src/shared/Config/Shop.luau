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

-- El creador de la experiencia posee todos sus game passes. Con esto a true, en Studio se
-- empieza sin ninguno para probar el juego como un jugador normal; comprarlos en Studio
-- (compra simulada) los activa durante esa partida.
Shop.IgnoreOwnedPassesInStudio = true

-- Máximo de ids de recibo guardados para la idempotencia de ProcessReceipt.
Shop.MaxStoredPurchases = 100

Shop.GamePasses = {
    { key = "doubleCoins", id = 2006582930, price = 199 },
    { key = "vipBackpack", id = 2004542931, price = 149 },
    { key = "autoCollect", id = 2006018882, price = 249 },
    { key = "extraPedestals", id = 2007626854, price = 299 },
    { key = "vip", id = 2006738869, price = 399 },
} :: { GamePass }

Shop.Products = {
    {
        key = "carryShield30",
        id = 3716263146,
        price = 49,
        kind = "boost",
        boost = "carryShield",
        duration = 30 * 60,
    },
    {
        key = "magnet30",
        id = 3716263152,
        price = 39,
        kind = "boost",
        boost = "magnet",
        duration = 30 * 60,
    },
    {
        key = "luck30",
        id = 3716263154,
        price = 79,
        kind = "boost",
        boost = "luck",
        duration = 30 * 60,
    },
    { key = "coinsSmall", id = 3716263157, price = 49, kind = "coins", rebirthCostFraction = 0.02 },
    {
        key = "coinsMedium",
        id = 3716263162,
        price = 149,
        kind = "coins",
        rebirthCostFraction = 0.08,
    },
    {
        key = "coinsLarge",
        id = 3716263169,
        price = 399,
        kind = "coins",
        rebirthCostFraction = 0.25,
    },
} :: { Product }

-- Cosméticos: compra directa con Robux (producto de desarrollador). El jugador ve el color antes de pagar.
Shop.Cosmetics = {
    {
        key = "pickaxeGold",
        id = 3716263174,
        price = 99,
        kind = "pickaxe",
        color = Color3.fromRGB(255, 200, 50),
    },
    {
        key = "pickaxeCrystal",
        id = 3716263178,
        price = 149,
        kind = "pickaxe",
        color = Color3.fromRGB(120, 220, 255),
    },
    {
        key = "trailFire",
        id = 3716263182,
        price = 99,
        kind = "trail",
        color = Color3.fromRGB(255, 110, 30),
    },
    {
        key = "trailCosmic",
        id = 3716263186,
        price = 149,
        kind = "trail",
        color = Color3.fromRGB(160, 90, 255),
    },
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
        id = 3716263191,
        price = 79,
        kind = "baseColor",
        color = Color3.fromRGB(60, 120, 200),
    },
    {
        key = "baseForest",
        id = 3716263197,
        price = 79,
        kind = "baseColor",
        color = Color3.fromRGB(70, 150, 80),
    },
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
