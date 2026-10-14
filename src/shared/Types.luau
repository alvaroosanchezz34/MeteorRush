--!strict

export type InventoryItem = {
    id: string,
    mineral: string,
    mutation: string,
    -- Solo en las ofertas de intercambio: id del pico o arma que representa esta entrada.
    gear: string?,
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

export type RebirthInfo = {
    -- Tiempo de juego (segundos) que tenía el jugador al hacer el último rebirth.
    lastPlaytime: number,
    -- Segundos del rebirth más rápido; 0 si aún no ha hecho ninguno.
    fastest: number,
}

export type DecorData = {
    -- [tostring(hueco)] = id de la decoración colocada (Config/Decor).
    slots: { [string]: string },
    -- Efecto de partículas y luz de la base, o "" si no lleva ninguno.
    effect: string,
}

export type SeasonData = {
    -- Id de la temporada (Config/LiveOps) a la que pertenece este progreso.
    id: string,
    points: number,
    -- [misión] = progreso, [misión] = true si está completada.
    progress: { [string]: number },
    done: { [string]: boolean },
    -- [tostring(escalón)] = true si su recompensa ya está entregada.
    claimed: { [string]: boolean },
}

export type SocialData = {
    -- Visitas y likes que ha recibido la base del jugador (solo sociales).
    visits: number,
    likes: number,
    -- [tostring(UserId)] = true para las bases a las que este jugador ya ha dado like.
    liked: { [string]: boolean },
}

export type EquipmentData = {
    -- [objeto] = true para los picos y armas que tiene el jugador (Config/Equipment).
    owned: { [string]: boolean },
    -- Pico y arma equipados.
    pickaxe: string,
    weapon: string,
    -- [caja] = cuántas tiene sin abrir (Config/Crates).
    crates: { [string]: number },
    -- [caja] = aperturas seguidas sin el premio mínimo del seguro.
    pity: { [string]: number },
    -- [objeto] = true para todo lo que ha tenido alguna vez (colección de equipamiento).
    collection: { [string]: boolean },
    -- Forge Dust: lo dan los duplicados y algunos picos; compra cajas.
    dust: number,
    -- Cajas abiertas en total.
    opened: number,
}

-- Preferencias del jugador. Solo cambian la presentación, nunca las reglas.
export type SettingsData = {
    -- Idioma elegido a mano en Ajustes ("es", "en"), o "" si nunca ha elegido: entonces se usa
    -- el idioma de su cuenta de Roblox en cada sesión.
    language: string,
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
    -- [producto] = true para los productos de una sola vez ya comprados (oferta de bienvenida).
    offers: { [string]: boolean },
    boosts: { [string]: number },
    cosmetics: CosmeticsData,
    -- Paso del tutorial de primer uso: 0..3; 3 = terminado.
    tutorialStep: number,
    quests: QuestData,
    -- [código] = true para los códigos ya canjeados.
    codes: { [string]: boolean },
    -- Contadores de por vida (minerales minados, vendidos...). No se reinician con el rebirth.
    stats: { [string]: number },
    -- [logro] = true para los logros desbloqueados (su recompensa ya está dada).
    achievements: { [string]: boolean },
    -- Título equipado: id del logro que lo da (o de un título especial), o "" si no lleva ninguno.
    title: string,
    -- [título] = true para los títulos especiales (Config/Titles) que tiene. Solo lo cambia el
    -- servidor: los automáticos al entrar y los que da un administrador desde el panel.
    specialTitles: { [string]: boolean },
    -- Amigos de Roblox conectados en el mismo servidor. Es estado de la sesión: SocialService
    -- lo actualiza y lo deja a 0 al cerrar el perfil.
    friendsOnline: number,
    -- Meteor Shards: moneda permanente que da cada rebirth.
    shards: number,
    -- [nodo] = nivel de cada mejora permanente (Config/Permanent).
    permanent: { [string]: number },
    rebirthInfo: RebirthInfo,
    decor: DecorData,
    season: SeasonData,
    social: SocialData,
    equipment: EquipmentData,
    -- Última versión del juego (Config/LiveOps) cuyas notas ha visto el jugador.
    seenVersion: string,
    settings: SettingsData,
}

return {}
