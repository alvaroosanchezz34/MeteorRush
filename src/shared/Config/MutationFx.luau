--!strict

-- Secuencia que se ve y se oye al conseguir un mineral con mutación. No cambia
-- probabilidades ni multiplicadores, que siguen en Config/Mutations.
-- El efecto continuo del mineral mutado es una capa del sistema visual de rareza
-- (Config/RarityFx). Los textos están en Strings.MutationReveal.

export type Reveal = {
    sound: string,
    -- Altura del texto en studs.
    textHeight: number,
    -- Partículas de la ráfaga, ondas pequeñas y rayos que salen del mineral.
    burst: number,
    waves: number,
    rays: number,
    -- Destello de pantalla y sacudida, solo para quien la consigue (0 = nada).
    flash: number,
    shake: number,
}

local MutationFx = {}

-- Distancia a la que los demás jugadores ven la secuencia de una mutación anunciada.
MutationFx.AnnounceDistance = 400

MutationFx.Reveals = {
    gold = {
        sound = "MutationGold",
        textHeight = 2,
        burst = 20,
        waves = 0,
        rays = 0,
        flash = 0,
        shake = 0,
    },
    radioactive = {
        sound = "MutationRadioactive",
        textHeight = 2.4,
        burst = 26,
        waves = 2,
        rays = 4,
        flash = 0.1,
        shake = 0.2,
    },
    rainbow = {
        sound = "MutationRainbow",
        textHeight = 3.4,
        burst = 44,
        waves = 3,
        rays = 8,
        flash = 0.25,
        shake = 0.45,
    },
} :: { [string]: Reveal }

return MutationFx
