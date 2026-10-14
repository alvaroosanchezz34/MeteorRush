--!strict

-- Piezas de interfaz reutilizables. Todas las pantallas se montan con ellas, así que
-- comparten el mismo lenguaje visual, que sale del sistema de diseño (UI/Theme).
-- Todo con tamaños relativos (escala), nunca píxeles fijos, para que funcione igual en
-- móvil, PC y consola. Los botones se pueden recorrer con el mando.
-- Los textos pueden ser una función (p. ej. `function() return Strings.Hud.SafeZone end`):
-- entonces se vuelven a pintar solos al cambiar de idioma. Úsalo en lo que se pinta una sola
-- vez; lo que se repinta al abrir la ventana ya sale en el idioma nuevo.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AudioManager = require(script.Parent.AudioManager)
local Theme = require(script.Parent.Theme)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Locale = require(Shared:WaitForChild("Locale"))
local Strings = require(Shared:WaitForChild("Strings"))

-- Un texto fijo, o una función que lo devuelve en el idioma activo.
export type Text = string | () -> string

local Components = {}

-- Pone el texto en esa propiedad; si es una función, lo enlaza al idioma (Locale.Bind).
function Components.SetText(instance: Instance, property: string, text: Text)
    if type(text) == "function" then
        Locale.Bind(instance, property, text)
    else
        (instance :: any)[property] = text
    end
end

-- Los colores del tema, con los nombres que usan las pantallas.
Components.Colors = Theme.Colors

local blur: BlurEffect? = nil
local openWindows = 0
local windowCount = 0
local focusRing: Frame? = nil

-- Desenfoca el mundo cuando se abre la primera ventana y lo aclara al cerrarse la última.
local function setWindowOpen(open: boolean)
    openWindows = math.max(openWindows + (if open then 1 else -1), 0)
    local effect = blur
    if effect == nil then
        local created = Instance.new("BlurEffect")
        created.Name = "MenuBlur"
        created.Size = 0
        created.Parent = Lighting
        blur = created
        effect = created
    end
    TweenService:Create(
        effect,
        Theme.Motion.Fade,
        { Size = if openWindows > 0 then Theme.Motion.BlurSize else 0 }
    ):Play()
end

local function corner(parent: Instance, scale: number)
    local instance = Instance.new("UICorner")
    instance.CornerRadius = UDim.new(scale, 0)
    instance.Parent = parent
end

local function border(
    parent: Instance,
    color: Color3,
    thickness: number,
    transparency: number
): UIStroke
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = color
    stroke.Thickness = thickness
    stroke.Transparency = transparency
    stroke.Parent = parent
    return stroke
end

-- Degradado vertical: más claro arriba y más oscuro abajo, para dar volumen.
local function shade(parent: Instance, bottom: number): UIGradient
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(bottom, bottom, bottom))
    gradient.Parent = parent
    return gradient
end

-- Marco que se dibuja alrededor del botón seleccionado con el mando. Lo comparten todos.
local function getFocusRing(): Frame
    if focusRing then
        return focusRing
    end
    local ring = Instance.new("Frame")
    ring.Name = "FocusRing"
    ring.BackgroundTransparency = 1
    ring.Size = UDim2.fromScale(1, 1)
    corner(ring, Theme.Radius.Button)
    border(ring, Theme.Colors.Accent, Theme.Stroke.Focus, 0)
    focusRing = ring
    return ring
end

local function usingGamepad(): boolean
    local input = UserInputService:GetLastInputType()
    return input.Name:sub(1, 7) == "Gamepad"
end

-- Indica si la pantalla es pequeña (móvil): las ventanas ocupan más para que sea fácil tocar.
local function isCompact(): boolean
    local camera = Workspace.CurrentCamera
    return camera ~= nil and camera.ViewportSize.X < Theme.Sizes.CompactWidth
end

-- Comportamiento común de los botones: borde que se ilumina al pasar el ratón o al
-- seleccionarlo con el mando, encogimiento con rebote al pulsar, sonido y aspecto apagado
-- cuando su color de fondo es el de "desactivado".
local function addButtonFeedback(button: GuiButton, label: TextLabel | TextButton | nil)
    local stroke = border(button, Theme.Colors.Shadow, Theme.Stroke.Button, 0.55)
    shade(button, Theme.Gradients.Button)
    local scale = Instance.new("UIScale")
    scale.Parent = button
    button.AutoButtonColor = false
    button.SelectionImageObject = getFocusRing()

    local function isDisabled(): boolean
        return button.BackgroundColor3 == Theme.Colors.Disabled
    end

    -- El color del texto sigue al del fondo: apagado si está desactivado, oscuro si es claro.
    local function updateState()
        local disabled = isDisabled()
        button.Selectable = not disabled
        if label then
            label.TextColor3 = if disabled
                then Theme.Colors.DisabledText
                else Theme.TextOn(button.BackgroundColor3)
        end
    end
    button:GetPropertyChangedSignal("BackgroundColor3"):Connect(updateState)
    updateState()

    -- Dentro de una lista o una rejilla no se escala: cambiar de tamaño movería a los vecinos.
    local function setPressed(pressed: boolean)
        local parent = button.Parent
        if isDisabled() or (parent and parent:FindFirstChildWhichIsA("UILayout")) then
            return
        end
        TweenService:Create(
            scale,
            if pressed then Theme.Motion.Press else Theme.Motion.Release,
            { Scale = if pressed then Theme.Motion.PressScale else 1 }
        ):Play()
    end

    local function setHover(hover: boolean)
        local lit = hover and not isDisabled()
        TweenService:Create(stroke, Theme.Motion.Hover, {
            Color = if lit then Theme.Colors.Text else Theme.Colors.Shadow,
            Transparency = if lit then 0.1 else 0.55,
        }):Play()
    end

    button.MouseEnter:Connect(function()
        setHover(true)
    end)
    button.MouseLeave:Connect(function()
        setHover(false)
        setPressed(false)
    end)
    button.SelectionGained:Connect(function()
        setHover(true)
    end)
    button.SelectionLost:Connect(function()
        setHover(false)
    end)
    button.MouseButton1Down:Connect(function()
        setPressed(true)
    end)
    button.MouseButton1Up:Connect(function()
        setPressed(false)
    end)
    button.Activated:Connect(function()
        if not isDisabled() then
            AudioManager.Play(Theme.Sounds.click)
        end
    end)
end

-- Texto con tamaño automático. `heading` usa la tipografía de títulos.
function Components.Label(props: {
    text: Text,
    size: UDim2,
    position: UDim2?,
    color: Color3?,
    alignment: Enum.TextXAlignment?,
    layoutOrder: number?,
    heading: boolean?,
    parent: Instance?,
}): TextLabel
    local label = Instance.new("TextLabel")
    label.Size = props.size
    label.Position = props.position or UDim2.new()
    label.BackgroundTransparency = 1
    Components.SetText(label, "Text", props.text)
    label.TextColor3 = props.color or Theme.Colors.Text
    label.TextScaled = true
    label.TextWrapped = true
    label.Font = if props.heading then Theme.Fonts.Heading else Theme.Fonts.Body
    label.TextXAlignment = props.alignment or Enum.TextXAlignment.Center
    label.LayoutOrder = props.layoutOrder or 0
    label.Parent = props.parent
    return label
end

-- Botón con color de fondo y esquinas redondeadas. Si su color es Colors.Disabled (al
-- crearlo o más tarde) se muestra apagado.
function Components.Button(props: {
    text: Text,
    size: UDim2,
    position: UDim2?,
    color: Color3?,
    layoutOrder: number?,
    parent: Instance?,
    onClick: (() -> ())?,
}): TextButton
    local button = Instance.new("TextButton")
    button.Size = props.size
    button.Position = props.position or UDim2.new()
    button.BackgroundColor3 = props.color or Theme.Colors.Primary
    Components.SetText(button, "Text", props.text)
    button.TextScaled = true
    button.Font = Theme.Fonts.Body
    button.LayoutOrder = props.layoutOrder or 0
    corner(button, Theme.Radius.Button)
    addButtonFeedback(button, button)

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0.18, 0)
    padding.PaddingBottom = UDim.new(0.18, 0)
    padding.PaddingLeft = UDim.new(0.06, 0)
    padding.PaddingRight = UDim.new(0.06, 0)
    padding.Parent = button

    local onClick = props.onClick
    if onClick then
        button.Activated:Connect(onClick)
    end
    button.Parent = props.parent
    return button
end

-- Botón cuadrado con un icono grande y el nombre debajo (barra lateral del HUD).
function Components.IconButton(props: {
    icon: string,
    text: Text,
    color: Color3,
    layoutOrder: number?,
    parent: Instance?,
    onClick: (() -> ())?,
}): TextButton
    local button = Instance.new("TextButton")
    button.BackgroundColor3 = props.color
    button.Text = ""
    button.LayoutOrder = props.layoutOrder or 0
    corner(button, 0.22)

    local icon = Components.Label({
        text = props.icon,
        size = UDim2.fromScale(0.62, 0.56),
        position = UDim2.fromScale(0.19, 0.06),
        parent = button,
    })
    icon.Name = "Icon"
    local name = Components.Label({
        text = props.text,
        size = UDim2.fromScale(0.9, 0.26),
        position = UDim2.fromScale(0.05, 0.67),
        parent = button,
    })
    name.Name = "Name"
    addButtonFeedback(button, name)

    local onClick = props.onClick
    if onClick then
        button.Activated:Connect(onClick)
    end
    button.Parent = props.parent
    return button
end

-- Marco de fondo con esquinas redondeadas y una línea fina.
function Components.Panel(props: {
    size: UDim2,
    position: UDim2?,
    color: Color3?,
    transparency: number?,
    layoutOrder: number?,
    parent: Instance?,
}): Frame
    local frame = Instance.new("Frame")
    frame.Size = props.size
    frame.Position = props.position or UDim2.new()
    frame.BackgroundColor3 = props.color or Theme.Colors.Panel
    frame.BackgroundTransparency = props.transparency or 0
    frame.BorderSizePixel = 0
    frame.LayoutOrder = props.layoutOrder or 0
    corner(frame, Theme.Radius.Panel)
    border(frame, Theme.Colors.Stroke, Theme.Stroke.Panel, Theme.Stroke.PanelTransparency)
    frame.Parent = props.parent
    return frame
end

-- Lista vertical con desplazamiento. Las celdas se reparten con una rejilla cuyo tamaño
-- es relativo al área visible, así que crecen o encogen con la pantalla.
function Components.ScrollList(props: {
    size: UDim2,
    position: UDim2?,
    cellSize: UDim2,
    parent: Instance?,
}): ScrollingFrame
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = props.size
    scroll.Position = props.position or UDim2.new()
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.CanvasSize = UDim2.new()
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.ScrollBarThickness = Theme.Sizes.ScrollBar
    scroll.ScrollBarImageColor3 = Theme.Colors.Accent
    scroll.ScrollBarImageTransparency = 0.3
    -- Con el mando, la selección pasa a los botones de dentro, no a la lista.
    scroll.Selectable = false

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = props.cellSize
    grid.CellPadding = UDim2.fromScale(0.01, 0.012)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
    grid.Parent = scroll

    scroll.Parent = props.parent
    return scroll
end

-- Borra todo lo que hay en un contenedor excepto los layouts.
function Components.Clear(container: Instance)
    for _, child in container:GetChildren() do
        if not child:IsA("UIGridLayout") and not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
end

-- Casilla de texto con el aspecto del resto de la interfaz.
function Components.Input(props: {
    placeholder: Text,
    size: UDim2,
    position: UDim2?,
    parent: Instance?,
}): TextBox
    local box = Instance.new("TextBox")
    box.Size = props.size
    box.Position = props.position or UDim2.new()
    box.BackgroundColor3 = Theme.Colors.Panel
    box.TextColor3 = Theme.Colors.Text
    Components.SetText(box, "PlaceholderText", props.placeholder)
    box.PlaceholderColor3 = Theme.Colors.Muted
    box.Text = ""
    box.ClearTextOnFocus = false
    box.TextScaled = true
    box.Font = Theme.Fonts.Body
    box.SelectionImageObject = getFocusRing()
    corner(box, Theme.Radius.Button)
    local stroke =
        border(box, Theme.Colors.Stroke, Theme.Stroke.Button, Theme.Stroke.PanelTransparency)
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0.2, 0)
    padding.PaddingBottom = UDim.new(0.2, 0)
    padding.PaddingLeft = UDim.new(0.04, 0)
    padding.PaddingRight = UDim.new(0.04, 0)
    padding.Parent = box
    -- La línea se enciende mientras se escribe.
    box.Focused:Connect(function()
        TweenService
            :Create(stroke, Theme.Motion.Hover, { Color = Theme.Colors.Accent, Transparency = 0 })
            :Play()
    end)
    box.FocusLost:Connect(function()
        TweenService:Create(stroke, Theme.Motion.Hover, {
            Color = Theme.Colors.Stroke,
            Transparency = Theme.Stroke.PanelTransparency,
        }):Play()
    end)
    box.Parent = props.parent
    return box
end

-- Indicador de carga: un arco que gira. Se quita destruyéndolo.
function Components.Spinner(props: { size: UDim2, position: UDim2?, parent: Instance? }): TextLabel
    local spinner = Components.Label({
        text = Theme.Icons.loading,
        size = props.size,
        position = props.position,
        color = Theme.Colors.Accent,
        parent = props.parent,
    })
    spinner.Name = "Spinner"
    TweenService:Create(
        spinner,
        TweenInfo.new(
            Theme.Motion.SpinSeconds,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.In,
            -1
        ),
        { Rotation = 360 }
    ):Play()
    return spinner
end

-- Pone un botón "en espera" durante unos segundos: apagado y con puntos suspensivos, para
-- que se vea que la acción está en marcha y no se pulse dos veces. Vuelve solo a su estado.
function Components.SetBusy(button: TextButton, seconds: number)
    if button:GetAttribute("Busy") then
        return
    end
    local text, color = button.Text, button.BackgroundColor3
    button:SetAttribute("Busy", true)
    button.Text = "..."
    button.BackgroundColor3 = Theme.Colors.Disabled
    task.delay(seconds, function()
        if button.Parent then
            button.Text = text
            button.BackgroundColor3 = color
            button:SetAttribute("Busy", nil)
        end
    end)
end

export type Confirm = {
    -- Muestra el diálogo con ese texto.
    Show: (text: string) -> (),
    Hide: () -> (),
}

-- Diálogo de confirmación que tapa `parent`: un texto y dos botones. Para las acciones que
-- no se pueden deshacer.
function Components.Confirm(props: {
    parent: Instance,
    confirmText: Text,
    cancelText: Text,
    onConfirm: () -> (),
}): Confirm
    local overlay = Components.Panel({
        size = UDim2.fromScale(1, 1),
        color = Theme.Colors.Background,
        parent = props.parent,
    })
    overlay.Name = "Confirm"
    overlay.ZIndex = 10
    overlay.Visible = false
    -- Tapa los clics de lo que queda debajo.
    overlay.Active = true
    local scale = Instance.new("UIScale")
    scale.Parent = overlay

    local label = Components.Label({
        text = "",
        size = UDim2.fromScale(0.92, 0.7),
        position = UDim2.fromScale(0.04, 0.04),
        parent = overlay,
    })
    local confirm: Confirm
    local yes = Components.Button({
        text = props.confirmText,
        size = UDim2.fromScale(0.42, 0.16),
        position = UDim2.fromScale(0.06, 0.8),
        color = Theme.Colors.Gold,
        parent = overlay,
        onClick = function()
            confirm.Hide()
            AudioManager.Play(Theme.Sounds.confirm)
            props.onConfirm()
        end,
    })
    local no = Components.Button({
        text = props.cancelText,
        size = UDim2.fromScale(0.42, 0.16),
        position = UDim2.fromScale(0.52, 0.8),
        color = Theme.Colors.PanelRaised,
        parent = overlay,
        onClick = function()
            confirm.Hide()
        end,
    })

    confirm = {
        Show = function(text: string)
            label.Text = text
            overlay.Visible = true
            scale.Scale = Theme.Motion.OpenScale
            TweenService:Create(scale, Theme.Motion.Page, { Scale = 1 }):Play()
            -- Con el mando, la selección empieza en "cancelar": lo seguro.
            if usingGamepad() then
                GuiService.SelectedObject = no
            end
        end,
        Hide = function()
            overlay.Visible = false
            if GuiService.SelectedObject == yes or GuiService.SelectedObject == no then
                GuiService.SelectedObject = nil
            end
        end,
    }
    return confirm
end

export type Window = {
    frame: Frame,
    content: Frame,
    Open: () -> (),
    Close: () -> (),
    Toggle: () -> (),
    IsOpen: () -> boolean,
    -- Llama a la función cada vez que se abre la ventana.
    OnOpened: (callback: () -> ()) -> (),
}

-- Ventana centrada con cabecera (icono, título y botón de cerrar), sombra y animación de
-- entrada y salida. En pantallas pequeñas ocupa casi toda la pantalla. Con el mando, al
-- abrirla la selección pasa a su primer botón y B la cierra.
function Components.Window(props: {
    title: Text,
    closeText: string,
    parent: Instance,
    accent: Color3?,
    icon: string?,
}): Window
    local accent = props.accent or Theme.Colors.Accent
    windowCount += 1
    local closeAction = `CloseWindow{windowCount}`

    -- Raíz transparente: lleva el tamaño, la escala de la animación y, dentro, sombra y panel.
    local root = Instance.new("Frame")
    root.Name = "Window"
    root.BackgroundTransparency = 1
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.52)
    root.Visible = false
    -- Por encima del resto del HUD (los hijos se dibujan sobre su padre).
    root.ZIndex = 5
    root.Parent = props.parent
    local scale = Instance.new("UIScale")
    scale.Parent = root

    local function resize()
        root.Size = if isCompact() then Theme.Sizes.WindowCompact else Theme.Sizes.Window
    end
    resize()
    local camera = Workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
    end

    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.fromScale(1, 1)
    shadow.Position = UDim2.fromScale(Theme.Shadow.Offset.X, Theme.Shadow.Offset.Y)
    shadow.BackgroundColor3 = Theme.Colors.Shadow
    shadow.BackgroundTransparency = Theme.Shadow.Transparency
    shadow.BorderSizePixel = 0
    corner(shadow, Theme.Radius.Window)
    shadow.Parent = root

    local frame = Instance.new("Frame")
    frame.Name = "Panel"
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = Theme.Colors.Background
    frame.BorderSizePixel = 0
    -- Tapa los clics para que no lleguen al juego a través de la ventana.
    frame.Active = true
    corner(frame, Theme.Radius.Window)
    border(frame, accent, Theme.Stroke.Window, 0.35)
    shade(frame, Theme.Gradients.Window)
    frame.Parent = root

    -- Cabecera: icono, título y una línea del color del menú.
    local header = Theme.Sizes.Header
    if props.icon then
        Components.Label({
            text = props.icon,
            size = UDim2.fromScale(0.06, header * 0.7),
            position = UDim2.fromScale(0.025, 0.02),
            parent = frame,
        })
    end
    local title = props.title
    Components.Label({
        text = function(): string
            return Strings.Upper(if type(title) == "function" then title() else title)
        end,
        size = UDim2.fromScale(0.74, header * 0.6),
        position = UDim2.fromScale(if props.icon then 0.095 else 0.03, 0.03),
        alignment = Enum.TextXAlignment.Left,
        heading = true,
        parent = frame,
    })
    local line = Instance.new("Frame")
    line.Name = "AccentLine"
    line.Size = UDim2.fromScale(0.94, 0.004)
    line.Position = UDim2.fromScale(0.03, header)
    line.BackgroundColor3 = accent
    line.BackgroundTransparency = 0.3
    line.BorderSizePixel = 0
    line.Parent = frame

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.BackgroundTransparency = 1
    content.Size = UDim2.fromScale(0.94, 0.97 - header - 0.03)
    content.Position = UDim2.fromScale(0.03, header + 0.025)
    content.Parent = frame

    local openedCallbacks: { () -> () } = {}
    local window: Window
    -- Mientras se cierra sigue en pantalla un instante, pero ya cuenta como cerrada.
    local isOpen = false

    local closeButton = Components.Button({
        text = if props.closeText == "X" then Theme.Icons.close else props.closeText,
        size = UDim2.fromScale(0.09, header * 0.78),
        position = UDim2.fromScale(0.975, 0.015),
        color = Theme.Colors.Danger,
        parent = frame,
        onClick = function()
            window.Close()
        end,
    })
    closeButton.AnchorPoint = Vector2.new(1, 0)
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1
    aspect.Parent = closeButton

    -- Con el mando: la selección empieza en el primer botón del contenido.
    local function focusFirst()
        if not usingGamepad() then
            return
        end
        task.delay(0.1, function()
            if not isOpen then
                return
            end
            for _, descendant in content:GetDescendants() do
                if descendant:IsA("GuiButton") and descendant.Selectable and descendant.Visible then
                    GuiService.SelectedObject = descendant
                    return
                end
            end
            GuiService.SelectedObject = closeButton
        end)
    end

    window = {
        frame = root,
        content = content,
        Open = function()
            if not isOpen then
                isOpen = true
                scale.Scale = Theme.Motion.OpenScale
                TweenService:Create(scale, Theme.Motion.Open, { Scale = 1 }):Play()
                setWindowOpen(true)
                AudioManager.Play(Theme.Sounds.open)
                -- B del mando cierra la ventana mientras está abierta.
                ContextActionService:BindAction(
                    closeAction,
                    function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
                        if state == Enum.UserInputState.Begin then
                            window.Close()
                        end
                        return Enum.ContextActionResult.Sink
                    end,
                    false,
                    Enum.KeyCode.ButtonB
                )
                focusFirst()
            end
            root.Visible = true
            for _, callback in openedCallbacks do
                task.spawn(callback)
            end
        end,
        Close = function()
            if not isOpen then
                return
            end
            isOpen = false
            setWindowOpen(false)
            AudioManager.Play(Theme.Sounds.close)
            ContextActionService:UnbindAction(closeAction)
            local selected = GuiService.SelectedObject
            if selected and selected:IsDescendantOf(root) then
                GuiService.SelectedObject = nil
            end
            local tween =
                TweenService:Create(scale, Theme.Motion.Close, { Scale = Theme.Motion.OpenScale })
            tween.Completed:Connect(function()
                -- Si se ha vuelto a abrir mientras se cerraba, se queda visible.
                if not isOpen then
                    root.Visible = false
                end
            end)
            tween:Play()
        end,
        Toggle = function()
            if isOpen then
                window.Close()
            else
                window.Open()
            end
        end,
        IsOpen = function(): boolean
            return isOpen
        end,
        OnOpened = function(callback: () -> ())
            table.insert(openedCallbacks, callback)
        end,
    }
    -- Al cambiar de idioma, una ventana abierta se repinta igual que al abrirse.
    Locale.OnChanged(function()
        if isOpen then
            for _, callback in openedCallbacks do
                task.spawn(callback)
            end
        end
    end)
    return window
end

return Components
