--!strict

-- Piezas básicas para construir el mapa con Parts: rocas facetadas, cristales con punta, farolas...
-- Todo anclado. Los constructores devuelven un Model colocado en el CFrame indicado.

local Kit = {}

export type PartProps = {
    name: string?,
    size: Vector3,
    cframe: CFrame,
    color: Color3,
    material: Enum.Material?,
    shape: Enum.PartType?,
    canCollide: boolean?,
    transparency: number?,
    castShadow: boolean?,
    parent: Instance,
}

function Kit.Part(props: PartProps): Part
    local part = Instance.new("Part")
    part.Name = props.name or "Part"
    part.Anchored = true
    part.Shape = props.shape or Enum.PartType.Block
    part.Size = props.size
    part.CFrame = props.cframe
    part.Color = props.color
    part.Material = props.material or Enum.Material.SmoothPlastic
    part.CanCollide = if props.canCollide == nil then true else props.canCollide
    part.Transparency = props.transparency or 0
    part.CastShadow = if props.castShadow == nil then true else props.castShadow
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = props.parent
    return part
end

function Kit.Light(parent: Instance, color: Color3, range: number, brightness: number?): PointLight
    local light = Instance.new("PointLight")
    light.Color = color
    light.Range = range
    light.Brightness = brightness or 1
    light.Shadows = false
    light.Parent = parent
    return light
end

local function randomRotation(rng: Random, tilt: number): CFrame
    return CFrame.Angles(
        rng:NextNumber(-tilt, tilt),
        rng:NextNumber(0, math.pi * 2),
        rng:NextNumber(-tilt, tilt)
    )
end

-- Roca facetada: varios bloques y cuñas girados y medio hundidos. `cframe` es el punto del
-- suelo donde se apoya y `size` su anchura aproximada.
function Kit.Rock(props: {
    cframe: CFrame,
    size: number,
    color: Color3,
    rng: Random,
    material: Enum.Material?,
    canCollide: boolean?,
    parent: Instance,
}): Model
    local rng = props.rng
    local size = props.size
    local model = Instance.new("Model")
    model.Name = "Rock"

    local pieces = rng:NextInteger(3, 5)
    for index = 1, pieces do
        local scale = if index == 1 then 1 else rng:NextNumber(0.4, 0.75)
        local dimensions = Vector3.new(
            size * scale * rng:NextNumber(0.7, 1.1),
            size * scale * rng:NextNumber(0.5, 0.9),
            size * scale * rng:NextNumber(0.7, 1.1)
        )
        local offset = if index == 1
            then Vector3.new(0, dimensions.Y * 0.3, 0)
            else Vector3.new(
                rng:NextNumber(-0.45, 0.45) * size,
                dimensions.Y * rng:NextNumber(0.2, 0.5),
                rng:NextNumber(-0.45, 0.45) * size
            )
        Kit.Part({
            name = "Chunk",
            shape = if rng:NextNumber() < 0.35 then Enum.PartType.Wedge else Enum.PartType.Block,
            size = dimensions,
            cframe = props.cframe * CFrame.new(offset) * randomRotation(rng, 0.45),
            color = props.color:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.3)),
            material = props.material or Enum.Material.Rock,
            canCollide = props.canCollide,
            parent = model,
        })
    end
    model.Parent = props.parent
    return model
end

-- Cristal con punta: un prisma y una cuña encima. `cframe` es la base; crece hacia su +Y.
function Kit.Crystal(props: {
    cframe: CFrame,
    height: number,
    width: number,
    color: Color3,
    canCollide: boolean?,
    parent: Instance,
}): Part
    local shaftHeight = props.height * 0.7
    local tipHeight = props.height - shaftHeight
    local shaft = Kit.Part({
        name = "Crystal",
        size = Vector3.new(props.width, shaftHeight, props.width),
        cframe = props.cframe * CFrame.new(0, shaftHeight / 2, 0),
        color = props.color,
        material = Enum.Material.Neon,
        transparency = 0.15,
        canCollide = props.canCollide,
        castShadow = false,
        parent = props.parent,
    })
    Kit.Part({
        name = "CrystalTip",
        shape = Enum.PartType.Wedge,
        size = Vector3.new(props.width, tipHeight, props.width),
        cframe = props.cframe * CFrame.new(0, shaftHeight + tipHeight / 2, 0),
        color = props.color,
        material = Enum.Material.Neon,
        transparency = 0.15,
        canCollide = false,
        castShadow = false,
        parent = props.parent,
    })
    return shaft
end

-- Grupo de cristales que salen de un mismo punto, sobre unas rocas, con luz.
function Kit.CrystalCluster(props: {
    cframe: CFrame,
    height: number,
    count: number,
    color: Color3,
    rockColor: Color3,
    rng: Random,
    parent: Instance,
}): Model
    local rng = props.rng
    local model = Instance.new("Model")
    model.Name = "CrystalCluster"

    Kit.Rock({
        cframe = props.cframe,
        size = props.height * 0.5,
        color = props.rockColor,
        rng = rng,
        parent = model,
    })
    local first: Part? = nil
    for index = 1, props.count do
        local height = if index == 1 then props.height else props.height * rng:NextNumber(0.35, 0.8)
        local lean = if index == 1 then 0.1 else rng:NextNumber(0.3, 0.75)
        local crystal = Kit.Crystal({
            cframe = props.cframe
                * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
                * CFrame.Angles(lean, 0, 0),
            height = height,
            width = height * rng:NextNumber(0.14, 0.2),
            color = props.color:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.25)),
            parent = model,
        })
        first = first or crystal
    end
    if first then
        Kit.Light(first, props.color, math.clamp(props.height * 2.5, 12, 50), 1.5)
    end
    model.Parent = props.parent
    return model
end

-- Farola: poste metálico con una esfera luminosa. `lit` añade una luz real (son caras).
function Kit.Lamp(props: {
    cframe: CFrame,
    height: number,
    color: Color3,
    postColor: Color3,
    lit: boolean,
    parent: Instance,
}): Model
    local model = Instance.new("Model")
    model.Name = "Lamp"
    Kit.Part({
        name = "Post",
        size = Vector3.new(0.6, props.height, 0.6),
        cframe = props.cframe * CFrame.new(0, props.height / 2, 0),
        color = props.postColor,
        material = Enum.Material.Metal,
        parent = model,
    })
    Kit.Part({
        name = "Foot",
        size = Vector3.new(1.6, 0.5, 1.6),
        cframe = props.cframe * CFrame.new(0, 0.25, 0),
        color = props.postColor,
        material = Enum.Material.Metal,
        parent = model,
    })
    local bulb = Kit.Part({
        name = "Bulb",
        shape = Enum.PartType.Ball,
        size = Vector3.one * 1.6,
        cframe = props.cframe * CFrame.new(0, props.height + 0.6, 0),
        color = props.color,
        material = Enum.Material.Neon,
        canCollide = false,
        castShadow = false,
        parent = model,
    })
    if props.lit then
        Kit.Light(bulb, props.color, 22, 1.2)
    end
    model.Parent = props.parent
    return model
end

return Kit
