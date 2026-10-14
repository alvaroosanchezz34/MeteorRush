--!strict

-- Sistema de diseño de la interfaz: el único sitio donde se definen colores, tipografías,
-- tamaños, bordes, sombras, degradados, iconos, animaciones y sonidos. Todo lo que se ve en
-- pantalla sale de aquí a través de UI/Components, así que cambiar el aspecto del juego es
-- cambiar valores en este archivo.

local Theme = {}

-- Colores ------------------------------------------------------------------------------
Theme.Colors = {
    -- Fondos, del más profundo al más cercano.
    Background = Color3.fromRGB(14, 17, 30),
    Panel = Color3.fromRGB(27, 32, 52),
    PanelRaised = Color3.fromRGB(38, 45, 72),
    -- Líneas y bordes.
    Stroke = Color3.fromRGB(96, 118, 170),
    -- Texto.
    Text = Color3.fromRGB(238, 242, 255),
    Muted = Color3.fromRGB(142, 152, 184),
    -- Texto sobre un fondo claro (botones dorados o blancos).
    TextDark = Color3.fromRGB(20, 22, 32),
    -- Acción principal, acento de ciencia ficción y estados.
    Primary = Color3.fromRGB(58, 142, 255),
    Accent = Color3.fromRGB(70, 222, 255),
    Success = Color3.fromRGB(46, 196, 128),
    Danger = Color3.fromRGB(236, 76, 92),
    Gold = Color3.fromRGB(255, 200, 70),
    -- Botón que ahora no se puede usar.
    Disabled = Color3.fromRGB(56, 62, 84),
    DisabledText = Color3.fromRGB(122, 130, 156),
    Shadow = Color3.fromRGB(0, 0, 0),
}

-- Color de acento de cada menú (botón de la barra lateral y línea de su ventana).
Theme.Accents = {
    inventory = Color3.fromRGB(64, 190, 220),
    upgrades = Color3.fromRGB(70, 200, 120),
    shop = Color3.fromRGB(240, 96, 160),
    index = Color3.fromRGB(150, 110, 250),
    daily = Color3.fromRGB(250, 150, 60),
    quests = Color3.fromRGB(236, 96, 96),
    rebirth = Color3.fromRGB(255, 200, 70),
    trade = Color3.fromRGB(80, 140, 255),
} :: { [string]: Color3 }

-- Color de los tres tipos de aviso.
Theme.Feedback = {
    info = Theme.Colors.Accent,
    success = Theme.Colors.Success,
    error = Theme.Colors.Danger,
} :: { [string]: Color3 }

-- Tipografías ------------------------------------------------------------------------------
Theme.Fonts = {
    -- Títulos de ventana y avisos grandes.
    Heading = Enum.Font.GothamBlack,
    -- Todo lo demás.
    Body = Enum.Font.GothamBold,
}

-- Tamaños ----------------------------------------------------------------------------------
-- Ventanas: fracción de la pantalla en escritorio y en pantallas pequeñas (móvil), y ancho en
-- píxeles por debajo del cual una pantalla cuenta como pequeña.
Theme.Sizes = {
    Window = UDim2.fromScale(0.6, 0.74),
    WindowCompact = UDim2.fromScale(0.92, 0.84),
    CompactWidth = 1000,
    -- Altura de la cabecera de una ventana y de la barra de pestañas (fracción de la ventana).
    Header = 0.11,
    ScrollBar = 5,
}

-- Bordes -------------------------------------------------------------------------------------
-- Radio de las esquinas (fracción del lado menor) y grosor de las líneas.
Theme.Radius = {
    Panel = 0.08,
    Window = 0.045,
    Button = 0.26,
    Pill = 0.5,
}
Theme.Stroke = {
    Panel = 1.5,
    Button = 2,
    Window = 2,
    Focus = 3,
    -- Transparencia de la línea de un panel en reposo.
    PanelTransparency = 0.78,
}

-- Sombras -------------------------------------------------------------------------------------
-- Desplazamiento (fracción de la ventana) y transparencia de la sombra de una ventana.
Theme.Shadow = {
    Offset = Vector2.new(0.008, 0.014),
    Transparency = 0.55,
}

-- Degradados ----------------------------------------------------------------------------------
-- Cuánto se oscurece la parte de abajo (1 = nada): da volumen sin recargar.
Theme.Gradients = {
    Button = 0.8,
    Window = 0.82,
}

-- Iconos --------------------------------------------------------------------------------------
Theme.Icons = {
    close = "✕",
    coins = "💰",
    shards = "💎",
    lock = "🔒",
    success = "✔",
    error = "✖",
    info = "ℹ",
    loading = "◠",
    inventory = "🏠",
    upgrades = "⚡",
    shop = "🛒",
    index = "📖",
    daily = "🎁",
    quests = "📜",
    rebirth = "⭐",
    trade = "🤝",
    settings = "⚙",
} :: { [string]: string }

-- Animaciones ---------------------------------------------------------------------------------
local Back = Enum.EasingStyle.Back
local Quad = Enum.EasingStyle.Quad
local Out = Enum.EasingDirection.Out

Theme.Motion = {
    Open = TweenInfo.new(0.22, Back, Out),
    Close = TweenInfo.new(0.12, Quad, Enum.EasingDirection.In),
    Hover = TweenInfo.new(0.1, Quad, Out),
    Press = TweenInfo.new(0.08, Quad, Out),
    Release = TweenInfo.new(0.18, Back, Out),
    -- Cambio de pestaña y aparición de un diálogo.
    Page = TweenInfo.new(0.16, Quad, Out),
    Fade = TweenInfo.new(0.3, Quad, Out),
    -- Escala desde la que entra una ventana y a la que se encoge un botón al pulsarlo.
    OpenScale = 0.9,
    PressScale = 0.94,
    -- Escala de un botón con el ratón encima o seleccionado con el mando.
    HoverScale = 1.04,
    -- Cuánto baja (fracción de la pantalla) una ventana al entrar, desde donde sube a su sitio.
    WindowSlide = 0.03,
    -- Segundos entre cada punto de un botón en espera.
    BusyDotSeconds = 0.3,
    -- Segundos por vuelta del indicador de carga.
    SpinSeconds = 0.9,
    -- Desenfoque del mundo mientras hay una ventana abierta.
    BlurSize = 10,
}

-- Sonidos (claves de Config/Sounds, las reproduce AudioManager) --------------------------------
Theme.Sounds = {
    click = "UiClick",
    open = "UiOpen",
    close = "UiClose",
    success = "UiSuccess",
    error = "UiError",
    confirm = "UiConfirm",
} :: { [string]: string }

-- Color de texto que se lee bien sobre un fondo de ese color.
function Theme.TextOn(background: Color3): Color3
    local luminance = background.R * 0.299 + background.G * 0.587 + background.B * 0.114
    return if luminance > 0.68 then Theme.Colors.TextDark else Theme.Colors.Text
end

return Theme
