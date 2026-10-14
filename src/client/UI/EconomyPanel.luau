--!strict

-- Panel de estadísticas económicas para pruebas. Solo existe en Studio: lo monta UIController
-- y los datos los envía EconomyService. Los textos van aquí y no en Strings porque ningún
-- jugador los ve.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local DataController = require(script.Parent.Parent.Controllers.DataController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Minerals = require(Shared:WaitForChild("Config"):WaitForChild("Minerals"))
local PlayerStats = require(Shared:WaitForChild("Util"):WaitForChild("PlayerStats"))
local RebirthConfig = require(Shared:WaitForChild("Config"):WaitForChild("Rebirth"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Upgrades = require(Shared:WaitForChild("Config"):WaitForChild("Upgrades"))

type Stats = {
    seconds: number,
    earned: { [string]: number },
    spent: { [string]: number },
    mined: number,
    mutated: number,
    minedByRarity: { [string]: number },
}

local EconomyPanel = {}

-- "origen $cantidad (porcentaje)" de cada entrada, de mayor a menor, y el total.
local function breakdown(amounts: { [string]: number }): (string, number)
    local total = 0
    local keys: { string } = {}
    for key, amount in amounts do
        total += amount
        table.insert(keys, key)
    end
    table.sort(keys, function(a: string, b: string): boolean
        return amounts[a] > amounts[b]
    end)
    local parts: { string } = {}
    for _, key in keys do
        table.insert(
            parts,
            string.format(
                "  %s $%s (%d%%)",
                key,
                Format.Number(amounts[key]),
                math.round(amounts[key] / total * 100)
            )
        )
    end
    return table.concat(parts, "\n"), total
end

-- Tiempo que falta para pagar algo con los ingresos actuales.
local function eta(cost: number, coins: number, income: number): string
    if coins >= cost then
        return "ya"
    end
    return if income > 0 then Format.Duration((cost - coins) / income) else "sin ingresos"
end

local function describe(stats: Stats): string
    local data = DataController.GetData()
    if data == nil then
        return ""
    end
    local minutes = math.max(stats.seconds / 60, 1 / 60)
    local income = PlayerStats.GetIncomePerSecond(data)
    local earnedText, earned = breakdown(stats.earned)
    local spentText, spent = breakdown(stats.spent)

    -- Minados por rareza, de la más común a la más rara.
    local rarities: { string } = {}
    for rarityId in stats.minedByRarity do
        table.insert(rarities, rarityId)
    end
    table.sort(rarities, function(a: string, b: string): boolean
        return Minerals.Rarities[a].rank < Minerals.Rarities[b].rank
    end)
    for index, rarityId in rarities do
        rarities[index] = `{rarityId} {stats.minedByRarity[rarityId]}`
    end

    local cheapest: Upgrades.Upgrade? = nil
    local cheapestCost = math.huge
    for _, upgrade in Upgrades.List do
        local level = PlayerStats.GetUpgradeLevel(data, upgrade.id)
        local cost = Upgrades.GetCost(upgrade.id, level)
        if level < upgrade.maxLevel and cost < cheapestCost then
            cheapest = upgrade
            cheapestCost = cost
        end
    end
    local rebirthCost = RebirthConfig.GetCost(data.rebirths)

    local lines = {
        `ECONOMÍA · sesión {Format.Duration(stats.seconds)}`,
        `Monedas ${Format.Number(data.coins)} · ingresos ${Format.Number(income)}/s`,
        `Ganado ${Format.Number(earned)} (${Format.Number(earned / minutes)}/min)`,
        earnedText,
        `Gastado ${Format.Number(spent)}`,
        spentText,
        string.format(
            "Minados %d (%.1f/min) · con mutación %d",
            stats.mined,
            stats.mined / minutes,
            stats.mutated
        ),
        "  " .. table.concat(rarities, " · "),
        `Rebirth {data.rebirths + 1}: ${Format.Number(rebirthCost)} · {eta(
            rebirthCost,
            data.coins,
            income
        )}`,
        if cheapest
            then `Mejora más barata: {cheapest.id} ${Format.Number(cheapestCost)} · {eta(
                cheapestCost,
                data.coins,
                income
            )}`
            else "Todas las mejoras al máximo",
    }
    -- Las líneas vacías (sin ganancias o sin gastos todavía) no se muestran.
    local text: { string } = {}
    for _, line in lines do
        if string.match(line, "%S") then
            table.insert(text, line)
        end
    end
    return table.concat(text, "\n")
end

function EconomyPanel.Mount()
    local gui = Instance.new("ScreenGui")
    -- Los textos ya salen en el idioma elegido: sin traducción automática de Roblox.
    gui.AutoLocalize = false
    gui.Name = "EconomyPanel"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 10

    local panel = Components.Panel({
        size = UDim2.fromScale(0.26, 0.42),
        position = UDim2.fromScale(0.73, 0.3),
        color = Components.Colors.Background,
        transparency = 0.15,
        parent = gui,
    })
    panel.Visible = false
    local label = Components.Label({
        text = "",
        size = UDim2.fromScale(0.94, 0.94),
        position = UDim2.fromScale(0.03, 0.03),
        alignment = Enum.TextXAlignment.Left,
        parent = panel,
    })
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Font = Enum.Font.RobotoMono

    Components.Button({
        text = "$ stats",
        size = UDim2.fromScale(0.06, 0.04),
        position = UDim2.fromScale(0.93, 0.25),
        color = Components.Colors.Disabled,
        parent = gui,
        onClick = function()
            panel.Visible = not panel.Visible
        end,
    })

    Remotes.EconomyStats.OnClientEvent:Connect(function(stats: Stats)
        if panel.Visible then
            label.Text = describe(stats)
        end
    end)

    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return EconomyPanel
