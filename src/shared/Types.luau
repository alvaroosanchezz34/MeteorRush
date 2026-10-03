--!strict

export type InventoryItem = {
    id: string,
    mineral: string,
    mutation: string,
}

export type UpgradeLevels = {
    pickaxe: number,
    backpack: number,
    speed: number,
    pedestals: number,
    luck: number,
    fortune: number,
    mutation: number,
    refinery: number,
    grip: number,
}

export type DailyData = {
    streak: number,
    lastClaim: number,
}

export type QuestData = {
    -- Día (Quests.GetDay) al que pertenecen el progreso y los cobros.
    day: number,
    progress: { [string]: number },
    claimed: { [string]: boolean },
}

export type CosmeticsData = {
    owned: { string },
    equipped: { [string]: string },
}

export type Profile = {
    version: number,
    coins: number,
    totalCoinsEarned: number,
    rebirths: number,
    playtime: number,
    lastSeen: number,
    upgrades: UpgradeLevels,
    inventory: { InventoryItem },
    -- [tostring(numeroDePedestal)] = id del objeto de inventory. Claves de texto para que
    -- DataStore y los remotes no pierdan entradas en tablas con huecos.
    pedestals: { [string]: string },
    pendingIncome: number,
    index: { [string]: boolean },
    -- [mineral] = true cuando ya se cobró la recompensa por completar su fila del índice.
    indexRewards: { [string]: boolean },
    daily: DailyData,
    passes: { [string]: boolean },
    -- Ids de recibos ya procesados (últimos 100).
    purchases: { string },
    boosts: { [string]: number },
    cosmetics: CosmeticsData,
    -- Paso del tutorial de primer uso: 0..3; 3 = terminado.
    tutorialStep: number,
    quests: QuestData,
    -- [código] = true para los códigos ya canjeados.
    codes: { [string]: boolean },
}

return {}
