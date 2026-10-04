--!strict

local Income = {}

-- Segundos entre cada suma de ingresos al contador de la base.
Income.TickSeconds = 1

-- Segundos entre comprobaciones de la placa de cobro.
Income.CollectCheckInterval = 0.25

-- Ingresos sin conexión: tope de tiempo y fracción del ritmo normal.
Income.OfflineCapSeconds = 8 * 60 * 60
Income.OfflineRate = 0.5

-- Vender un mineral da lo que generaría en un pedestal durante estos segundos (sin multiplicadores).
Income.SellSeconds = 90

-- Segundos entre envíos de las estadísticas económicas al panel de pruebas (solo en Studio).
Income.StatsInterval = 2

return Income
