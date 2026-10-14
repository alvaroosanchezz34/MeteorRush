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
    kind: "boost" | "coins" | "bundle" | "meteor",
    -- kind = "boost"
    boost: string?,
    duration: number?,
    -- kind = "coins" o "bundle": fracción del coste del siguiente rebirth (escala con los rebirths)
    rebirthCostFraction: number?,
    -- kind = "bundle": segundos de cada boost que incluye y cosméticos que regala.
    boosts: { [string]: number }?,
    cosmetics: { string }?,
    -- Solo se puede comprar una vez por cuenta (oferta de bienvenida).
    oncePerAccount: boolean?,
    -- kind = "meteor": tipo de meteorito (Config/Meteors) que cae para todo el servidor.
    meteorType: string?,
}

export type Cosmetic = {
    key: string,
    id: number,
    price: number,
    kind: "pickaxe" | "trail" | "baseColor",
    color: Color3,
    -- Solo para quien tiene el game pass vip; no se compra.
    vipOnly: boolean?,
    -- Se desbloquea gratis al llegar a ese número de rebirths; no se compra.
    rebirthsRequired: number?,
    -- Recompensa de esa temporada (Config/LiveOps): solo se consigue mientras dura; no se compra.
    season: string?,
    -- Solo sale de las cajas de equipamiento (Config/Crates); no se compra.
    crate: boolean?,
    -- Solo viene dentro de ese paquete (clave de Shop.Products); no se compra suelto.
    bundle: string?,
}

local Shop = {}

-- Efectos de los game passes.
Shop.DoubleCoinsMultiplier = 2
Shop.VipBackpackBonus = 10
Shop.ExtraPedestalsBonus = 6
Shop.VipSpeedMultiplier = 1.1
-- Minado rápido: fracción que se ahorra de cada golpe.
Shop.FastMiningReduction = 0.3
-- Súper suerte: multiplicador permanente de la suerte con raros.
Shop.SuperLuckMultiplier = 1.5
Shop.MegaBackpackBonus = 20

-- Efectos de los boosts.
Shop.LuckBoostMultiplier = 2
Shop.CoinsBoostMultiplier = 2

-- Ofertas grandes que salen al entrar, en este orden, después de las notas de versión. Las de
-- una sola vez (oncePerAccount) dejan de salir al comprarlas.
Shop.BigOffers = { "starterPack", "megaPack" }
-- Ofertas pequeñas en la esquina: segundos mínimos entre dos, y segundos que se quedan a la
-- vista si no se tocan. Cada una sale como mucho una vez por sesión.
Shop.CornerOfferGap = 240
Shop.CornerOfferSeconds = 14
-- Segundos desde que se entra hasta que puede salir la primera oferta de esquina.
Shop.CornerOfferDelay = 90
-- En Studio se enseñan también las ofertas cuyo producto aún tiene id 0 (con el botón en
-- "Próximamente"), para poder probar cómo se ven antes de crear los productos.
Shop.ShowUnreleasedOffersInStudio = true

-- Ofertas de la esquina: qué se ofrece (clave de un pass o un producto) y cuándo.
--   backpackFull → al llenarse la mochila      meteor → al anunciarse un meteorito grande
--   timer        → de vez en cuando, en este orden
-- Un pass que ya se tiene no se ofrece; si hay varias para el mismo momento, gana la primera.
export type CornerOffer = { key: string, trigger: "backpackFull" | "meteor" | "timer" }
Shop.CornerOffers = {
    { key = "megaBackpack", trigger = "backpackFull" },
    { key = "vipBackpack", trigger = "backpackFull" },
    { key = "luck60", trigger = "meteor" },
    { key = "megaPack", trigger = "timer" },
    { key = "coins2x30", trigger = "timer" },
    { key = "fastMining", trigger = "timer" },
    { key = "serverMeteor", trigger = "timer" },
} :: { CornerOffer }

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
    { key = "fastMining", id = 2037176455, price = 249 },
    { key = "superLuck", id = 2038346476, price = 349 },
    { key = "megaBackpack", id = 2039504305, price = 299 },
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
    {
        key = "coins2x30",
        id = 3718633117,
        price = 99,
        kind = "boost",
        boost = "coins2x",
        duration = 30 * 60,
    },
    -- Versiones de 1 hora: más baratas por minuto que dos de 30.
    {
        key = "carryShield60",
        id = 3718633119,
        price = 79,
        kind = "boost",
        boost = "carryShield",
        duration = 60 * 60,
    },
    {
        key = "magnet60",
        id = 3718633122,
        price = 65,
        kind = "boost",
        boost = "magnet",
        duration = 60 * 60,
    },
    {
        key = "luck60",
        id = 3718633127,
        price = 129,
        kind = "boost",
        boost = "luck",
        duration = 60 * 60,
    },
    {
        key = "coins2x60",
        id = 3718633129,
        price = 169,
        kind = "boost",
        boost = "coins2x",
        duration = 60 * 60,
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
    -- Paquetes: varias cosas juntas por menos de lo que cuestan sueltas.
    {
        key = "starterPack",
        id = 3718633131,
        price = 99,
        kind = "bundle",
        rebirthCostFraction = 0.15,
        boosts = { luck = 60 * 60, carryShield = 60 * 60 },
        cosmetics = { "trailStarter" },
        oncePerAccount = true,
    },
    {
        key = "megaPack",
        id = 3718633137,
        price = 499,
        kind = "bundle",
        rebirthCostFraction = 0.25,
        boosts = {
            luck = 60 * 60,
            magnet = 60 * 60,
            carryShield = 60 * 60,
            coins2x = 60 * 60,
        },
    },
    -- Meteorito grande que cae para todo el servidor, con aviso de quién lo ha invocado.
    { key = "serverMeteor", id = 3718633143, price = 149, kind = "meteor", meteorType = "big" },
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
        key = "trailRebirth",
        id = 0,
        price = 0,
        kind = "trail",
        color = Color3.fromRGB(120, 255, 230),
        rebirthsRequired = 3,
    },
    {
        key = "baseRebirth",
        id = 0,
        price = 0,
        kind = "baseColor",
        color = Color3.fromRGB(70, 40, 110),
        rebirthsRequired = 5,
    },
    {
        key = "pickaxeRebirth",
        id = 0,
        price = 0,
        kind = "pickaxe",
        color = Color3.fromRGB(255, 120, 200),
        rebirthsRequired = 7,
    },
    {
        key = "trailSeason1",
        id = 0,
        price = 0,
        kind = "trail",
        color = Color3.fromRGB(255, 140, 60),
        season = "s1",
    },
    {
        key = "baseSeason1",
        id = 0,
        price = 0,
        kind = "baseColor",
        color = Color3.fromRGB(150, 70, 40),
        season = "s1",
    },
    {
        key = "trailPlasma",
        id = 0,
        price = 0,
        kind = "trail",
        color = Color3.fromRGB(90, 160, 255),
        crate = true,
    },
    {
        key = "trailVoid",
        id = 0,
        price = 0,
        kind = "trail",
        color = Color3.fromRGB(190, 70, 255),
        crate = true,
    },
    {
        key = "baseNebula",
        id = 0,
        price = 0,
        kind = "baseColor",
        color = Color3.fromRGB(95, 45, 130),
        crate = true,
    },
    {
        key = "trailStarter",
        id = 0,
        price = 0,
        kind = "trail",
        color = Color3.fromRGB(80, 255, 170),
        bundle = "starterPack",
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
