--!strict

-- Piezas de interfaz reutilizables. Todo con tamaños relativos (escala), nunca píxeles fijos,
-- para que funcione igual en móvil, PC y consola.

local Components = {}

Components.Colors = {
    Background = Color3.fromRGB(24, 24, 34),
    Panel = Color3.fromRGB(38, 38, 52),
    Text = Color3.fromRGB(240, 240, 245),
    Muted = Color3.fromRGB(160, 160, 175),
    Primary = Color3.fromRGB(70, 140, 255),
    Success = Color3.fromRGB(70, 190, 100),
    Danger = Color3.fromRGB(220, 70, 70),
    Gold = Color3.fromRGB(255, 200, 60),
    Disabled = Color3.fromRGB(80, 80, 92),
}

local FONT = Enum.Font.GothamBold

local function corner(parent: Instance, scale: number?)
    local instance = Instance.new("UICorner")
    instance.CornerRadius = UDim.new(scale or 0.15, 0)
    instance.Parent = parent
end

-- Texto con tamaño automático.
function Components.Label(props: {
    text: string,
    size: UDim2,
    position: UDim2?,
    color: Color3?,
    alignment: Enum.TextXAlignment?,
    layoutOrder: number?,
    parent: Instance?,
}): TextLabel
    local label = Instance.new("TextLabel")
    label.Size = props.size
    label.Position = props.position or UDim2.new()
    label.BackgroundTransparency = 1
    label.Text = props.text
    label.TextColor3 = props.color or Components.Colors.Text
    label.TextScaled = true
    label.TextWrapped = true
    label.Font = FONT
    label.TextXAlignment = props.alignment or Enum.TextXAlignment.Center
    label.LayoutOrder = props.layoutOrder or 0
    label.Parent = props.parent
    return label
end

-- Botón con color de fondo y esquinas redondeadas.
function Components.Button(props: {
    text: string,
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
    button.BackgroundColor3 = props.color or Components.Colors.Primary
    button.AutoButtonColor = true
    button.Text = props.text
    button.TextColor3 = Components.Colors.Text
    button.TextScaled = true
    button.Font = FONT
    button.LayoutOrder = props.layoutOrder or 0
    corner(button)

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0.15, 0)
    padding.PaddingBottom = UDim.new(0.15, 0)
    padding.PaddingLeft = UDim.new(0.05, 0)
    padding.PaddingRight = UDim.new(0.05, 0)
    padding.Parent = button

    local onClick = props.onClick
    if onClick then
        button.Activated:Connect(onClick)
    end
    button.Parent = props.parent
    return button
end

-- Marco de fondo con esquinas redondeadas.
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
    frame.BackgroundColor3 = props.color or Components.Colors.Panel
    frame.BackgroundTransparency = props.transparency or 0
    frame.BorderSizePixel = 0
    frame.LayoutOrder = props.layoutOrder or 0
    corner(frame, 0.08)
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
    scroll.ScrollBarThickness = 6

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = props.cellSize
    grid.CellPadding = UDim2.fromScale(0.01, 0.01)
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

-- Ventana centrada con título y botón de cerrar.
function Components.Window(props: { title: string, closeText: string, parent: Instance }): Window
    local frame = Components.Panel({
        size = UDim2.fromScale(0.6, 0.72),
        position = UDim2.fromScale(0.5, 0.52),
        color = Components.Colors.Background,
        parent = props.parent,
    })
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Visible = false
    -- Por encima del resto del HUD (los hijos se dibujan sobre su padre).
    frame.ZIndex = 5

    Components.Label({
        text = props.title,
        size = UDim2.fromScale(0.8, 0.09),
        position = UDim2.fromScale(0.03, 0.02),
        alignment = Enum.TextXAlignment.Left,
        parent = frame,
    })

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.BackgroundTransparency = 1
    content.Size = UDim2.fromScale(0.94, 0.84)
    content.Position = UDim2.fromScale(0.03, 0.13)
    content.Parent = frame

    local openedCallbacks: { () -> () } = {}
    local window: Window

    local closeButton = Components.Button({
        text = props.closeText,
        size = UDim2.fromScale(0.08, 0.09),
        position = UDim2.fromScale(0.9, 0.02),
        color = Components.Colors.Danger,
        parent = frame,
        onClick = function()
            window.Close()
        end,
    })
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1
    aspect.Parent = closeButton

    window = {
        frame = frame,
        content = content,
        Open = function()
            frame.Visible = true
            for _, callback in openedCallbacks do
                task.spawn(callback)
            end
        end,
        Close = function()
            frame.Visible = false
        end,
        Toggle = function()
            if frame.Visible then
                window.Close()
            else
                window.Open()
            end
        end,
        IsOpen = function(): boolean
            return frame.Visible
        end,
        OnOpened = function(callback: () -> ())
            table.insert(openedCallbacks, callback)
        end,
    }
    return window
end

return Components
