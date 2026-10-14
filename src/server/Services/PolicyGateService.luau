--!strict

-- Política de Roblox de cada jugador (PolicyService): qué puede hacer según su país, su edad
-- y su plataforma. Aquí se consulta una vez al entrar (con reintentos) y se guarda; el resto
-- de servicios preguntan sin esperar:
--   * CanBuyRandomItems   → comprar cajas (objetos aleatorios de pago).
--   * CanTradePaidItems   → intercambiar objetos de pago con otros jugadores.
-- Mientras no se conoce la respuesta, las dos devuelven nil y quien pregunta lo trata como
-- "no permitido": ante la duda, se bloquea.
-- Los atributos `CratesRestricted` y `TradingAllowed` del jugador solo sirven para que su
-- interfaz muestre el motivo; las decisiones se toman siempre aquí, en el servidor.

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

-- Intentos de consulta al entrar y segundos entre ellos.
local ATTEMPTS = 6
local RETRY_SECONDS = 5

type Policy = {
    randomItemsRestricted: boolean,
    paidTradingAllowed: boolean,
}

local PolicyGateService = {}

local policies: { [Player]: Policy } = {}
local fetching: { [Player]: boolean } = {}

local function fetch(player: Player)
    if fetching[player] or policies[player] then
        return
    end
    fetching[player] = true
    for attempt = 1, ATTEMPTS do
        local ok, info = pcall(function(): any
            return PolicyService:GetPolicyInfoForPlayerAsync(player)
        end)
        if player.Parent ~= Players then
            break
        end
        if ok and type(info) == "table" then
            local policy: Policy = {
                randomItemsRestricted = info.ArePaidRandomItemsRestricted == true,
                -- Solo cuenta un "sí" explícito.
                paidTradingAllowed = info.IsPaidItemTradingAllowed == true,
            }
            policies[player] = policy
            player:SetAttribute("CratesRestricted", policy.randomItemsRestricted)
            player:SetAttribute("TradingAllowed", policy.paidTradingAllowed)
            break
        end
        if attempt == ATTEMPTS then
            Log.Warn("Policy", `No se pudo leer la política de {player.Name}: {info}`)
        else
            task.wait(RETRY_SECONDS)
        end
    end
    fetching[player] = nil
end

-- Indica si el jugador puede comprar objetos aleatorios de pago. nil = todavía no se sabe.
function PolicyGateService.CanBuyRandomItems(player: Player): boolean?
    local policy = policies[player]
    return if policy then not policy.randomItemsRestricted else nil
end

-- Indica si el jugador puede intercambiar objetos de pago. nil = todavía no se sabe.
function PolicyGateService.CanTradePaidItems(player: Player): boolean?
    local policy = policies[player]
    return if policy then policy.paidTradingAllowed else nil
end

-- Vuelve a intentar la consulta en segundo plano si aún no hay respuesta.
function PolicyGateService.Refresh(player: Player)
    if policies[player] == nil then
        task.spawn(fetch, player)
    end
end

function PolicyGateService.Start()
    Players.PlayerAdded:Connect(function(player: Player)
        task.spawn(fetch, player)
    end)
    for _, player in Players:GetPlayers() do
        task.spawn(fetch, player)
    end
    Players.PlayerRemoving:Connect(function(player: Player)
        policies[player] = nil
        fetching[player] = nil
    end)
end

return PolicyGateService
