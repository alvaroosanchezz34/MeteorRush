--!strict

-- Ventana con pestañas: varios menús normales en una sola ventana, para no añadir más
-- botones a la barra lateral. Cada pestaña se monta sobre su propia zona de contenido y solo
-- se considera abierta cuando es la activa.

local TweenService = game:GetService("TweenService")

local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))

export type MenuModule = {
    Mount: (window: Components.Window) -> (),
    -- Solo en los menús con pestañas: deja elegida esa pestaña.
    Select: ((tab: string) -> ())?,
}
export type Tab = { key: string, module: MenuModule }

-- Posición vertical de las páginas, debajo de la barra de pestañas.
local PAGE_Y = 0.12

local TabbedMenu = {}

-- Devuelve un menú que muestra esos menús como pestañas. Los nombres salen de Strings.Tabs.
function TabbedMenu.Create(tabs: { Tab }): MenuModule
    local selectTab: ((tab: string) -> ())? = nil
    local function mount(window: Components.Window)
        local currentTab = tabs[1].key
        local tabBar = Instance.new("Frame")
        tabBar.BackgroundTransparency = 1
        tabBar.Size = UDim2.fromScale(1, 0.1)
        tabBar.Parent = window.content
        local tabLayout = Instance.new("UIListLayout")
        tabLayout.FillDirection = Enum.FillDirection.Horizontal
        tabLayout.Padding = UDim.new(0.01, 0)
        tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
        tabLayout.Parent = tabBar

        local buttons: { [string]: TextButton } = {}
        local pages: { [string]: Frame } = {}
        local openedCallbacks: { [string]: { () -> () } } = {}

        local function show()
            for key, page in pages do
                local isCurrent = key == currentTab
                -- La página que aparece entra con un pequeño deslizamiento.
                if isCurrent and not page.Visible then
                    page.Position = UDim2.fromScale(0.03, PAGE_Y)
                    TweenService
                        :Create(page, Theme.Motion.Page, { Position = UDim2.fromScale(0, PAGE_Y) })
                        :Play()
                end
                page.Visible = isCurrent
                buttons[key].BackgroundColor3 = if isCurrent
                    then Components.Colors.Primary
                    else Components.Colors.PanelRaised
            end
            for _, callback in openedCallbacks[currentTab] do
                task.spawn(callback)
            end
        end

        for order, tab in tabs do
            local page = Instance.new("Frame")
            page.BackgroundTransparency = 1
            page.Size = UDim2.fromScale(1, 0.88)
            page.Position = UDim2.fromScale(0, PAGE_Y)
            page.Visible = false
            page.Parent = window.content
            pages[tab.key] = page
            openedCallbacks[tab.key] = {}

            buttons[tab.key] = Components.Button({
                text = function(): string
                    return Strings.Tabs[tab.key] or tab.key
                end,
                size = UDim2.fromScale(math.min(0.3, 0.99 / #tabs - 0.01), 1),
                layoutOrder = order,
                parent = tabBar,
                onClick = function()
                    currentTab = tab.key
                    show()
                end,
            })

            tab.module.Mount({
                frame = window.frame,
                content = page,
                Open = window.Open,
                Close = window.Close,
                Toggle = window.Toggle,
                IsOpen = function(): boolean
                    return window.IsOpen() and currentTab == tab.key
                end,
                OnOpened = function(callback: () -> ())
                    table.insert(openedCallbacks[tab.key], callback)
                end,
            })
        end

        window.OnOpened(show)
        selectTab = function(tab: string)
            if pages[tab] then
                currentTab = tab
                if window.IsOpen() then
                    show()
                end
            end
        end
    end
    return {
        Mount = mount,
        Select = function(tab: string)
            if selectTab then
                selectTab(tab)
            end
        end,
    }
end

return TabbedMenu
