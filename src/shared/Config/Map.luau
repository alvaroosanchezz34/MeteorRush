--!strict

-- Medidas y colores del mapa generado por MapService. Todas las distancias en studs.
-- En cada parcela, -Z local apunta al centro del mapa (la entrada) y +Z al fondo.

local Map = {}

Map.GroundSize = 1200
Map.GroundColor = Color3.fromRGB(60, 58, 70)

Map.ImpactZoneRadius = 300
Map.ImpactZoneColor = Color3.fromRGB(95, 70, 60)

Map.PlotCount = 8
Map.PlotRingRadius = 380
Map.PlotSize = 60
Map.PlotFloorThickness = 1
Map.PlotFloorColor = Color3.fromRGB(110, 120, 140)
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

-- Placa de cobro de ingresos, en la esquina del fondo.
Map.CollectPadSize = 8
Map.CollectPadOffset = Vector3.new(-20, 0, 22)
Map.CollectPadColor = Color3.fromRGB(255, 200, 60)

-- Altura (studs) sobre una zona plana que sigue contando como "pisándola".
Map.ZoneHeight = 8

return Map
