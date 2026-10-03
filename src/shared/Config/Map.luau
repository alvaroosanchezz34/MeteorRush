--!strict

-- Medidas y colores del mapa generado por MapService. Todas las distancias en studs.
-- En cada parcela, -Z local apunta al centro del mapa (la entrada) y +Z al fondo.

local Map = {}

Map.GroundSize = 1200
Map.GroundColor = Color3.fromRGB(60, 58, 70)

Map.ImpactZoneRadius = 300
Map.ImpactZoneColor = Color3.fromRGB(95, 70, 60)
-- Borde luminoso de la zona de impacto (número de tramos) y cráteres decorativos.
Map.ImpactRingSegments = 64
Map.ImpactRingColor = Color3.fromRGB(255, 120, 60)
Map.CraterCount = 16
Map.CraterMinRadius = 8
Map.CraterMaxRadius = 22
Map.CraterColor = Color3.fromRGB(70, 52, 46)

Map.PlotCount = 8
Map.PlotRingRadius = 380
Map.PlotSize = 60
Map.PlotFloorThickness = 1
Map.PlotFloorColor = Color3.fromRGB(110, 120, 140)
-- Bordillo, columnas de las esquinas y arco de la entrada.
Map.PlotTrimColor = Color3.fromRGB(55, 60, 75)
Map.PlotAccentColor = Color3.fromRGB(90, 200, 255)
-- Color con el que cada jugador ve la baliza y las luces de su propia base.
Map.OwnBaseColor = Color3.fromRGB(110, 255, 140)
Map.PlotPillarHeight = 6
Map.PlotGateHeight = 8
Map.PlotFenceSegments = 5
Map.PlotWallHeight = 9
Map.PlotBeaconHeight = 90
Map.CrateColor = Color3.fromRGB(120, 105, 85)
-- Altura sobre el suelo de la parcela que sigue contando como "dentro" (zona segura).
Map.PlotSafeHeight = 50

-- Distancia del punto de aparición al centro de la parcela, hacia el fondo.
Map.SpawnOffsetZ = 22

Map.DepositZoneWidth = 20
Map.DepositZoneDepth = 8
Map.DepositZoneColor = Color3.fromRGB(80, 200, 120)

Map.SignSize = Vector3.new(14, 5, 1)
Map.SignHeight = 6
Map.SignOffsetX = -20
Map.SignColor = Color3.fromRGB(40, 40, 48)

Map.InitialPedestals = 8
-- 24 por mejoras + 6 del game pass extraPedestals.
Map.MaxPedestals = 30
Map.PedestalColumns = 6
Map.PedestalSpacing = 8
-- Z local del centro de la rejilla de pedestales.
Map.PedestalGridCenterZ = 0
Map.PedestalSize = Vector3.new(4, 3, 4)
Map.PedestalColor = Color3.fromRGB(180, 180, 195)
Map.PedestalBaseColor = Color3.fromRGB(90, 92, 110)
Map.PedestalAccentColor = Color3.fromRGB(90, 200, 255)

-- Minerales expuestos: giran y flotan en el cliente (etiqueta de CollectionService).
Map.SpinTag = "SpinDisplay"
-- Segundos por vuelta, altura del vaivén (studs) y distancia máxima a la que se animan.
Map.SpinPeriod = 6
Map.SpinBobHeight = 0.25
Map.SpinMaxDistance = 140
-- Al colocar un mineral: segundos que tarda en crecer, partículas del destello y distancia
-- máxima a la que se oye.
Map.PlaceGrowSeconds = 0.35
Map.PlaceBurstCount = 24
Map.PlaceSoundDistance = 120

-- Placa de cobro de ingresos, en la esquina del fondo.
Map.CollectPadSize = 8
Map.CollectPadOffset = Vector3.new(-20, 0, 22)
Map.CollectPadColor = Color3.fromRGB(255, 200, 60)

-- Decorado (Builders/Scenery): no afecta a las reglas del juego.
Map.Scenery = {
    Seed = 2026,
    -- Ángulo (radianes) a cada lado del centro de una parcela que se deja libre de rocas.
    PlotClearAngle = 0.15,

    -- Montañas de terreno alrededor del mapa.
    MountainCount = 44,
    MountainRingRadius = 590,
    MountainMinSize = 60,
    MountainMaxSize = 100,
    MountainColor = Color3.fromRGB(78, 68, 100),
    -- Una de cada N montañas lleva una veta de lava.
    LavaEvery = 4,

    PathWidth = 14,
    PathColor = Color3.fromRGB(70, 74, 92),

    RockCount = 70,
    RockColor = Color3.fromRGB(96, 88, 110),
    SmallCrystalCount = 22,
    CrystalColors = {
        Color3.fromRGB(90, 220, 255),
        Color3.fromRGB(190, 110, 255),
        Color3.fromRGB(255, 110, 200),
        Color3.fromRGB(120, 255, 170),
    },
    FuelColor = Color3.fromRGB(120, 255, 170),

    LavaPoolCount = 10,
    LavaColor = Color3.fromRGB(255, 120, 40),

    PlanetPosition = Vector3.new(-900, 520, -1300),
    PlanetSize = 520,
    PlanetColor = Color3.fromRGB(215, 140, 110),
    AsteroidCount = 36,
}

-- Altura (studs) sobre una zona plana que sigue contando como "pisándola".
Map.ZoneHeight = 8

return Map
