--!strict

local TableUtil = {}

-- Copia profunda de una tabla. Los valores que no son tablas se devuelven tal cual.
function TableUtil.DeepCopy<T>(value: T): T
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, child in value :: any do
        copy[key] = TableUtil.DeepCopy(child)
    end
    return copy :: any
end

-- Congela una tabla y todas sus subtablas para que no se puedan modificar.
function TableUtil.DeepFreeze<T>(value: T): T
    if type(value) ~= "table" then
        return value
    end
    for _, child in value :: any do
        TableUtil.DeepFreeze(child)
    end
    if not table.isfrozen(value :: any) then
        table.freeze(value :: any)
    end
    return value
end

return TableUtil
