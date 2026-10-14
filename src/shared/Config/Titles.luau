--!strict

-- Aspecto de los títulos y títulos especiales.
-- Los títulos normales salen de los logros (Config/Achievements, `title = true`) y son dorados.
-- Los especiales no se consiguen jugando:
--   owner  → solo las cuentas de AdminPermissions.OWNER_USER_IDS (y el creador de la experiencia)
--   admin  → los administradores
--   vip    → quien tiene el pase vip
--   staff, legend → los da un administrador desde el panel (Titles.Grantable)
-- Quién tiene cada especial lo decide siempre el servidor (`specialTitles` del perfil).
-- Los nombres están en Strings.Titles.

export type Effect = "rainbow" | "shine" | "pulse"

export type Style = {
    -- Color principal del texto (y de la etiqueta del chat).
    color: Color3,
    -- Colores del degradado animado del texto; sin ellos, color liso.
    colors: { Color3 }?,
    effect: Effect?,
    -- Destellos alrededor de la cabeza.
    sparkles: boolean?,
    -- Etiqueta delante del nombre en el chat (sin traducir: es corta y vale en los dos idiomas).
    chatTag: string?,
}

local Titles = {}

-- Títulos especiales, en el orden en que salen en el selector.
Titles.Specials = { "owner", "admin", "staff", "legend", "vip" }

-- Los que un administrador puede dar y quitar desde el panel.
Titles.Grantable = { staff = true, legend = true } :: { [string]: boolean }

-- Tamaño del cartel sobre la cabeza (ancho y alto en studs): los especiales, más grandes.
Titles.BillboardSize = Vector2.new(7, 0.9)
Titles.SpecialBillboardSize = Vector2.new(9, 1.25)

-- Segundos por vuelta del degradado animado.
Titles.EffectSeconds = 2.5

Titles.Default = {
    color = Color3.fromRGB(255, 200, 60),
} :: Style

Titles.Styles = {
    owner = {
        color = Color3.fromRGB(255, 215, 80),
        colors = {
            Color3.fromRGB(255, 80, 80),
            Color3.fromRGB(255, 200, 60),
            Color3.fromRGB(90, 255, 140),
            Color3.fromRGB(70, 200, 255),
            Color3.fromRGB(190, 110, 255),
            Color3.fromRGB(255, 80, 80),
        },
        effect = "rainbow",
        sparkles = true,
        chatTag = "👑 OWNER",
    },
    admin = {
        color = Color3.fromRGB(255, 90, 80),
        colors = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 170, 60) },
        effect = "pulse",
        sparkles = true,
        chatTag = "🛡️ ADMIN",
    },
    staff = {
        color = Color3.fromRGB(90, 200, 255),
        colors = { Color3.fromRGB(70, 160, 255), Color3.fromRGB(140, 240, 255) },
        effect = "shine",
        chatTag = "🔧 STAFF",
    },
    legend = {
        color = Color3.fromRGB(170, 120, 255),
        colors = { Color3.fromRGB(110, 230, 255), Color3.fromRGB(190, 110, 255) },
        effect = "shine",
        sparkles = true,
        chatTag = "💎 LEGEND",
    },
    vip = {
        color = Color3.fromRGB(255, 215, 0),
        colors = { Color3.fromRGB(255, 200, 40), Color3.fromRGB(255, 250, 200) },
        effect = "shine",
        chatTag = "⭐ VIP",
    },
} :: { [string]: Style }

local specialSet: { [string]: boolean } = {}
for _, id in Titles.Specials do
    specialSet[id] = true
end

-- Indica si es un título especial (no de logro).
function Titles.IsSpecial(titleId: string): boolean
    return specialSet[titleId] == true
end

-- Aspecto de un título.
function Titles.GetStyle(titleId: string): Style
    return Titles.Styles[titleId] or Titles.Default
end

return Titles
