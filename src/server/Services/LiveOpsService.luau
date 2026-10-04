--!strict

-- Interruptores de contenido en caliente. Cada interruptor empieza con su valor de
-- Config/LiveOps; un administrador puede cambiarlo desde el panel de administración, y el cambio
-- se guarda en un DataStore que todos los servidores consultan cada poco, así que se puede
-- apagar un sistema sin publicar una versión nueva.
-- Los valores se replican como atributos `Feature_<nombre>` de Workspace.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local LiveOps = require(Shared.Config.LiveOps)
local Log = require(Shared.Util.Log)

local LiveOpsService = {}

local features: { [string]: boolean } = table.clone(LiveOps.Features)
local store: DataStore? = nil
-- Para avisar una sola vez si el DataStore no está disponible (p. ej. en Studio sin acceso).
local warned = false

local function publish()
    for name, enabled in features do
        Workspace:SetAttribute(`Feature_{name}`, enabled)
    end
end

-- Aplica los valores guardados: solo los interruptores que existen y con valor booleano.
local function apply(saved: any)
    if type(saved) ~= "table" then
        return
    end
    for name in LiveOps.Features do
        if type(saved[name]) == "boolean" then
            features[name] = saved[name]
        end
    end
    publish()
end

local function getStore(): DataStore?
    if store == nil then
        local ok, result = pcall(function(): DataStore
            return DataStoreService:GetDataStore(LiveOps.FeatureStore)
        end)
        if ok then
            store = result
        end
    end
    return store
end

local function load()
    local dataStore = getStore()
    if dataStore == nil then
        return
    end
    local ok, result = pcall(function(): any
        return dataStore:GetAsync(LiveOps.FeatureKey)
    end)
    if ok then
        apply(result)
    elseif not warned then
        warned = true
        Log.Warn("LiveOps", `No se pudieron leer los interruptores: {result}`)
    end
end

-- Indica si ese contenido está activado ahora mismo.
function LiveOpsService.IsEnabled(feature: string): boolean
    return features[feature] == true
end

-- Cambia un interruptor en este servidor y lo guarda para los demás. Solo lo llama el
-- panel de administración (AdminService), que ya ha comprobado el permiso y los valores.
function LiveOpsService.SetFeature(feature: string, enabled: boolean)
    if LiveOps.Features[feature] == nil then
        return
    end
    features[feature] = enabled
    publish()

    local dataStore = getStore()
    if dataStore == nil then
        return
    end
    task.spawn(function()
        local ok, err = pcall(function()
            dataStore:UpdateAsync(LiveOps.FeatureKey, function(saved: any): any
                local updated = if type(saved) == "table" then saved else {}
                updated[feature] = enabled
                return updated
            end)
        end)
        if not ok then
            Log.Warn("LiveOps", `No se pudo guardar {feature}: {err}`)
        end
    end)
end

function LiveOpsService.Init()
    publish()
    Workspace:SetAttribute("Version", LiveOps.Version)
end

function LiveOpsService.Start()
    task.spawn(function()
        while true do
            load()
            task.wait(LiveOps.FeaturePollSeconds)
        end
    end)
end

return LiveOpsService
