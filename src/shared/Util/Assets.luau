--!strict

-- Busca modelos reales en ReplicatedStorage/Assets/<Id>. Si no existen, el llamador genera un placeholder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = {}

-- Devuelve una copia del asset con ese id, o nil si no existe.
function Assets.Clone(id: string): Instance?
    local folder = ReplicatedStorage:FindFirstChild("Assets")
    local asset = if folder then folder:FindFirstChild(id) else nil
    return if asset then asset:Clone() else nil
end

-- Coloca un Model o BasePart en la posición indicada.
function Assets.PlaceAt(instance: Instance, cframe: CFrame)
    if instance:IsA("Model") then
        instance:PivotTo(cframe)
    elseif instance:IsA("BasePart") then
        instance.CFrame = cframe
    end
end

-- Devuelve el asset con ese id colocado en `cframe`, o el placeholder creado por `makePlaceholder`.
function Assets.SpawnAt(id: string, cframe: CFrame, makePlaceholder: () -> Instance): Instance
    local instance = Assets.Clone(id) or makePlaceholder()
    Assets.PlaceAt(instance, cframe)
    return instance
end

return Assets
