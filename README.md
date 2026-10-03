# Meteor Rush

Juego multijugador para Roblox. Cada pocos minutos caen meteoritos en un mapa compartido; los jugadores corren a minarlos, cargan los minerales hasta su base y allí generan dinero pasivo. Mientras transportas el botín, otros jugadores pueden robártelo.

Este documento es la especificación completa del proyecto. **Claude Code: léelo entero antes de escribir código y trabaja fase por fase, en el orden indicado en "Hoja de ruta".**

---

## 1. Stack y herramientas

| Herramienta | Uso |
|---|---|
| **Luau** (modo `--!strict`) | Todo el código del juego |
| **Rojo** | Sincroniza `src/` con Roblox Studio |
| **Wally** | Gestor de paquetes |
| **Rokit** | Instala y fija versiones de Rojo, Wally, Selene y StyLua |
| **ProfileStore** | Guardado de datos con bloqueo de sesión |
| **Selene + StyLua** | Linter y formateador |

Usa siempre la última versión estable de cada herramienta y compruébala antes de fijarla en `rokit.toml` y `wally.toml`. No inventes nombres de paquete ni versiones: si no puedes verificarlos, dilo.

### Comandos

```bash
rokit install          # instala las herramientas fijadas
wally install          # descarga paquetes a Packages/
rojo serve             # sincroniza con Studio (plugin de Rojo conectado)
rojo build -o MeteorRush.rbxlx   # genera el archivo de lugar
selene src             # lint
stylua src             # formato
```

---

## 2. Estructura del proyecto

```
meteor-rush/
├── default.project.json
├── rokit.toml
├── wally.toml
├── selene.toml
├── stylua.toml
├── README.md
└── src/
    ├── server/                      -> ServerScriptService/Server
    │   ├── Main.server.luau         (arranca los servicios en orden)
    │   └── Services/
    │       ├── DataService.luau
    │       ├── MapService.luau
    │       ├── PlotService.luau
    │       ├── MeteorService.luau
    │       ├── MiningService.luau
    │       ├── CarryService.luau
    │       ├── StealService.luau
    │       ├── IncomeService.luau
    │       ├── UpgradeService.luau
    │       ├── RebirthService.luau
    │       ├── DailyService.luau
    │       ├── ShopService.luau
    │       └── TradeService.luau
    ├── client/                      -> StarterPlayer/StarterPlayerScripts/Client
    │   ├── Main.client.luau
    │   ├── Controllers/
    │   │   ├── InputController.luau
    │   │   ├── MeteorController.luau   (efectos, avisos, marcadores)
    │   │   ├── CarryController.luau
    │   │   └── DataController.luau     (réplica local de los datos del jugador)
    │   └── UI/
    │       ├── Hud.luau
    │       ├── UpgradesMenu.luau
    │       ├── ShopMenu.luau
    │       ├── IndexMenu.luau
    │       ├── DailyMenu.luau
    │       └── TradeMenu.luau
    └── shared/                      -> ReplicatedStorage/Shared
        ├── Config/
        │   ├── Minerals.luau
        │   ├── Mutations.luau
        │   ├── Meteors.luau
        │   ├── Upgrades.luau
        │   ├── Rebirth.luau
        │   ├── Daily.luau
        │   └── Shop.luau
        ├── Remotes.luau             (crea y expone todos los RemoteEvent/RemoteFunction)
        ├── Types.luau
        └── Util/
            ├── Format.luau          (1.2K, 3.4M, etc.)
            ├── WeightedRandom.luau
            └── RateLimiter.luau
```

Cada servicio es un `ModuleScript` con `Init()` y `Start()`. `Main.server.luau` llama primero a todos los `Init()` y después a todos los `Start()`.

---

## 3. El mapa se genera por código

No dependas de modelos hechos a mano en Studio. `MapService` construye todo con `Part` al arrancar el servidor, para que el juego sea jugable solo con `rojo serve`:

- **Zona de impacto:** círculo central de 300 studs de radio donde caen los meteoritos.
- **Parcelas:** 8 bases en anillo alrededor de la zona de impacto, a 380 studs del centro. Una por jugador (servidor de 8 jugadores máximo).
- **Cada parcela:** suelo de 60x60, cartel con el nombre del dueño, punto de aparición, una "zona de depósito" en la entrada y una rejilla de pedestales (8 iniciales, hasta 24).
- **Zona segura:** dentro de tu propia parcela no pueden robarte lo que llevas encima.

Los modelos son placeholders (bloques de color según rareza). Deja el código preparado para sustituirlos por modelos reales: busca primero un modelo en `ReplicatedStorage/Assets/<Id>` y, si no existe, genera el placeholder.

---

## 4. Diseño del juego

### 4.1 Bucle principal

1. Cae un meteorito (aviso global 10 s antes, con marcador en pantalla).
2. El jugador lo mina manteniendo pulsado (clic, toque o botón de mando).
3. Cada golpe completado da un mineral, que va a la mochila.
4. Con mochila cargada el jugador se mueve más lento y los minerales se ven sobre su espalda.
5. Al entrar en la zona de depósito de su parcela, los minerales pasan al inventario de la base.
6. Coloca minerales en pedestales; cada pedestal genera monedas por segundo.
7. Recoge las monedas, compra mejoras y repite.

### 4.2 Minerales (`Config/Minerals.luau`)

| Id | Nombre | Rareza | Peso | Monedas/s |
|---|---|---|---|---|
| `stone` | Roca Espacial | Común | 5000 | 1 |
| `iron` | Hierro Estelar | Común | 3000 | 3 |
| `copper` | Cobre Lunar | Poco común | 1200 | 8 |
| `crystal` | Cristal Cósmico | Poco común | 500 | 20 |
| `plasma` | Núcleo de Plasma | Raro | 200 | 60 |
| `nebula` | Gema Nebulosa | Épico | 70 | 250 |
| `darkmatter` | Materia Oscura | Legendario | 25 | 1200 |
| `starheart` | Corazón de Estrella | Mítico | 5 | 8000 |

### 4.3 Mutaciones (`Config/Mutations.luau`)

Cada mineral minado puede salir con una mutación que multiplica sus ingresos.

| Id | Nombre | Probabilidad | Multiplicador |
|---|---|---|---|
| `none` | Normal | 93,4 % | x1 |
| `gold` | Dorado | 5 % | x2 |
| `radioactive` | Radiactivo | 1,5 % | x5 |
| `rainbow` | Arcoíris | 0,1 % | x15 |

La combinación mineral + mutación es una entrada del **Índice** (32 en total). Completar filas del índice da recompensas en monedas.

### 4.4 Meteoritos (`Config/Meteors.luau`)

| Tipo | Frecuencia | Golpes disponibles | Efecto |
|---|---|---|---|
| Normal | cada 45 s | 30 | Tabla de pesos estándar |
| Grande | cada 5 min | 80 | Pesos de rareza x2 para Raro o superior |
| Gigante (evento) | cada 30 min | 300 | Pesos x5 para Raro o superior, mutaciones x3, dura 3 min |

Un meteorito desaparece al agotar sus golpes o a los 2 minutos (3 el gigante). Los golpes se reparten entre todos los jugadores que lo minan.

### 4.5 Mejoras (`Config/Upgrades.luau`)

Coste de cada nivel: `costeBase * factor ^ nivel`, redondeado.

| Mejora | Niveles | Efecto por nivel | Coste base | Factor |
|---|---|---|---|---|
| Pico | 20 | -5 % de tiempo por golpe (base 1,5 s, mínimo 0,3 s) | 100 | 1,6 |
| Mochila | 15 | +2 de capacidad (base 5) | 150 | 1,7 |
| Velocidad | 10 | +1 de WalkSpeed (base 16) | 200 | 1,8 |
| Pedestales | 16 | +1 pedestal (base 8, máximo 24) | 500 | 1,9 |
| Suerte | 10 | +5 % al peso de rarezas Raro o superior | 1000 | 2,2 |

**Penalización de carga:** la velocidad baja un 3 % por cada mineral que llevas, con un máximo del 40 %.

### 4.6 Robo (`StealService`)

- Un jugador que lleva minerales puede ser golpeado por otro (cuerpo a cuerpo, enfriamiento de 2 s para el atacante).
- Al recibir el golpe suelta el 50 % de lo que lleva (redondeado hacia arriba) como objetos en el suelo; cualquiera puede recogerlos. Los objetos desaparecen a los 20 s.
- Tras ser golpeado, la víctima tiene 5 s de inmunidad.
- Dentro de la propia parcela no se puede ser golpeado.
- Los minerales ya colocados en pedestales **no** se pueden robar. El robo afecta solo a lo que se transporta, para que nadie pierda su progreso guardado.
- Jugadores con menos de 10 minutos de juego total tienen protección de novato: no pueden ser golpeados ni golpear.

### 4.7 Ingresos pasivos y offline (`IncomeService`)

- Cada pedestal acumula monedas por segundo en un contador de la base. El jugador las cobra pisando la placa de cobro.
- Al volver a entrar se abonan los ingresos generados sin conexión, con un tope de 8 horas y al 50 % del ritmo normal. Se calcula con `os.time()` del servidor y `lastSeen` guardado.

### 4.8 Rebirth (`Config/Rebirth.luau`)

- Requisito: `1.000.000 * 5 ^ rebirths` monedas.
- Reinicia monedas, mejoras y minerales del inventario y de los pedestales.
- Conserva: índice, rebirths, cosméticos, game passes y racha diaria.
- Recompensa: +50 % de ingresos permanente por rebirth (acumulativo de forma aditiva).

### 4.9 Racha diaria (`Config/Daily.luau`)

Siete días de recompensa creciente en monedas; el día 7 da un mineral Épico garantizado. Si pasan más de 48 h desde el último cobro, la racha vuelve al día 1.

### 4.10 Intercambio (`TradeService`)

Intercambio de minerales entre dos jugadores del mismo servidor: solicitud, ventana con ofertas de ambos, doble confirmación y cuenta atrás de 5 s que se reinicia si alguien cambia su oferta. La transacción se ejecuta en el servidor de forma atómica: o se aplican los dos lados o ninguno.

---

## 5. Datos del jugador (`DataService`)

Plantilla del perfil en ProfileStore:

```lua
{
    version = 1,
    coins = 0,
    totalCoinsEarned = 0,
    rebirths = 0,
    playtime = 0,
    lastSeen = 0,
    upgrades = { pickaxe = 0, backpack = 0, speed = 0, pedestals = 0, luck = 0 },
    inventory = {},        -- lista de { id = string, mineral = string, mutation = string }
    pedestals = {},        -- [numeroDePedestal] = id del objeto de inventory
    pendingIncome = 0,
    index = {},            -- ["mineral:mutation"] = true
    daily = { streak = 0, lastClaim = 0 },
    passes = {},           -- caché de game passes comprobados
    purchases = {},        -- ids de recibos ya procesados (últimos 100)
    boosts = {},           -- [nombreBoost] = marca de tiempo de expiración
    cosmetics = { owned = {}, equipped = {} },
}
```

Reglas:

- Carga con bloqueo de sesión; si el perfil no carga, expulsa al jugador con un mensaje claro.
- Usa `Reconcile()` para añadir campos nuevos a perfiles antiguos.
- Guarda al salir y en `game:BindToClose`.
- El cliente recibe una copia de solo lectura y actualizaciones por campo mediante un remote. El cliente nunca escribe datos.

---

## 6. Red y seguridad

**El servidor es la única autoridad.** El cliente solo envía intenciones.

- Todos los remotes se declaran en `shared/Remotes.luau`. Ningún otro script crea remotes.
- Cada handler del servidor valida tipos, rangos y estado antes de actuar. Nunca aceptes del cliente cantidades de monedas, ids de mineral obtenidos ni resultados de azar.
- **Minado:** el cliente envía "empiezo a minar el meteorito X" y "dejo de minar". El servidor comprueba la distancia (máximo 12 studs), lleva él mismo el temporizador y concede el mineral.
- **Depósito y cobro:** se detectan en el servidor por posición del personaje, no por un aviso del cliente.
- **Golpes:** el servidor comprueba distancia, enfriamiento, inmunidad, zona segura y protección de novato.
- Limitador de frecuencia por jugador y por remote (`Util/RateLimiter.luau`). Superarlo repetidamente expulsa al jugador.
- Todo el azar se resuelve en el servidor con `Random.new()`.

Remotes previstos:

| Remote | Dirección | Uso |
|---|---|---|
| `DataUpdate` | servidor → cliente | Cambios en los datos del jugador |
| `MeteorIncoming` | servidor → todos | Aviso de impacto con posición y tipo |
| `MineStart` / `MineStop` | cliente → servidor | Intención de minar |
| `HitPlayer` | cliente → servidor | Intento de golpe |
| `PlaceMineral` / `RemoveMineral` | cliente → servidor | Gestión de pedestales |
| `BuyUpgrade` | cliente → servidor | Compra de mejora |
| `Rebirth` | cliente → servidor | Solicitud de rebirth |
| `ClaimDaily` | cliente → servidor | Cobro de la racha |
| `Trade*` | ambos | Flujo de intercambio |
| `Notify` | servidor → cliente | Mensajes en pantalla |

---

## 7. Monetización (`ShopService`, `Config/Shop.luau`)

Los ids reales se crean en el panel de creador de Roblox. En el config déjalos como `0` con un comentario `-- TODO: id real`; si un id es `0`, la tienda muestra el producto como "Próximamente" y no lanza la compra.

### Game passes (compra única)

| Clave | Efecto | Precio orientativo |
|---|---|---|
| `doubleCoins` | x2 ingresos de pedestales | 199 R$ |
| `vipBackpack` | +10 de capacidad de mochila | 149 R$ |
| `autoCollect` | Cobra los ingresos de la base automáticamente | 249 R$ |
| `extraPedestals` | +6 pedestales | 299 R$ |
| `vip` | Etiqueta VIP en el chat, estela exclusiva, +10 % de velocidad | 399 R$ |

### Productos de desarrollador (consumibles)

| Clave | Efecto | Precio orientativo |
|---|---|---|
| `carryShield30` | 30 min sin poder ser golpeado mientras transportas | 49 R$ |
| `magnet30` | 30 min recogiendo minerales del suelo a 20 studs | 39 R$ |
| `luck30` | 30 min con suerte x2 | 79 R$ |
| `coinsSmall` / `coinsMedium` / `coinsLarge` | Paquetes de monedas escalados con los rebirths del jugador | 49 / 149 / 399 R$ |

### Cosméticos

Skins de pico, estelas y colores de base. Compra directa: el jugador ve exactamente lo que compra.

### Reglas de monetización

- `MarketplaceService.ProcessReceipt` debe ser idempotente: guarda el `PurchaseId` en `purchases` y devuelve `PurchaseGranted` solo después de aplicar la recompensa en el perfil. Si el perfil no está cargado, devuelve `NotProcessedYet`.
- Comprueba los game passes al entrar con `UserOwnsGamePassAsync` y escucha `PromptGamePassPurchaseFinished`.
- **Prohibido implementar cajas de pago, huevos o cualquier compra con Robux cuyo resultado sea aleatorio.** Toda compra con dinero real entrega algo concreto y visible antes de pagar.
- Nada de temporizadores de oferta falsos ni ventanas emergentes de compra que interrumpan el juego. La tienda se abre solo cuando el jugador pulsa su botón.
- Todo lo que afecta al progreso debe poder conseguirse también jugando.

---

## 8. Interfaz

Toda la UI se crea por código (sin depender de `StarterGui` hecho a mano) y debe funcionar en móvil, PC y mando.

- **HUD:** monedas, ingresos por segundo, mochila (`3/5`), cuenta atrás del próximo meteorito y flecha hacia el meteorito activo más cercano.
- **Botones laterales:** Mejoras, Tienda, Índice, Diario, Rebirth.
- **Avisos:** mensaje global al caer un meteorito grande o gigante y al conseguir alguien un mineral Legendario o superior.
- Botones grandes para pantalla táctil; usa `UIScale` y anclajes relativos, nunca tamaños fijos en píxeles.
- Textos del juego en inglés (mercado global de Roblox), centralizados en un módulo para poder traducirlos después.

---

## 9. Hoja de ruta

Trabaja una fase cada vez. Al terminar cada fase: pasa `selene` y `stylua`, confirma que `rojo build` funciona, resume lo hecho y **para a esperar confirmación** antes de seguir.

### Fase 0 — Base del proyecto
- `rokit.toml`, `wally.toml`, `default.project.json`, `selene.toml`, `stylua.toml`, `.gitignore`.
- Estructura de carpetas completa, `Main.server.luau`, `Main.client.luau`, `Remotes.luau`, `Types.luau`.
- **Hecho cuando:** `rojo build` genera el lugar y al ejecutarlo en Studio no hay errores en la consola.

### Fase 1 — Mapa y parcelas
- `MapService` y `PlotService`: mapa generado, asignación de parcela al entrar y liberación al salir.
- **Hecho cuando:** dos jugadores de prueba aparecen cada uno en su parcela.

### Fase 2 — Datos
- `DataService` con ProfileStore, réplica al cliente, `DataController`.
- **Hecho cuando:** las monedas persisten entre sesiones en una prueba de Studio con acceso a API activado.

### Fase 3 — Meteoritos y minado
- `MeteorService`, `MiningService`, configs de minerales, mutaciones y meteoritos, efectos de caída y aviso.
- **Hecho cuando:** cae un meteorito, se mina y los minerales entran en la mochila respetando la capacidad.

### Fase 4 — Transporte, base e ingresos
- `CarryService`, depósito, pedestales, `IncomeService`, cobro, ingresos offline, HUD.
- **Hecho cuando:** el bucle completo minar → llevar → colocar → cobrar funciona.

### Fase 5 — Mejoras
- `UpgradeService` y menú de mejoras.

### Fase 6 — Robo
- `StealService`, objetos soltados, zona segura, inmunidad y protección de novato.

### Fase 7 — Índice, racha diaria y rebirth
- `DailyService`, `RebirthService`, menús correspondientes.

### Fase 8 — Tienda
- `ShopService`, game passes, productos, boosts temporales y cosméticos.

### Fase 9 — Intercambio
- `TradeService` y su interfaz.

### Fase 10 — Pulido
- Sonidos, partículas, tutorial de primer uso (tres pasos guiados), evento del meteorito gigante y revisión de equilibrio.

---

## 10. Normas de trabajo para Claude Code

- `--!strict` en todos los archivos y tipos explícitos en las funciones públicas.
- Ningún número de equilibrio escrito directamente en la lógica: todo sale de `shared/Config`.
- Un servicio, una responsabilidad. Los servicios se comunican por sus funciones públicas, no accediendo a tablas internas de otros.
- Limpia siempre las conexiones y el estado de un jugador en `PlayerRemoving`.
- Envuelve en `pcall` todas las llamadas a servicios de Roblox que pueden fallar (DataStore, Marketplace).
- No uses APIs obsoletas (`wait`, `spawn`, `delay`): usa la librería `task`.
- No puedes ejecutar Roblox Studio. Cuando algo necesite prueba manual, escribe los pasos exactos para probarlo.
- Si una decisión de diseño no está en este documento, elige la opción más simple, anótala en `DECISIONS.md` y continúa.
- Commits pequeños, uno por funcionalidad, con mensajes en español.

---

## 11. Pasos manuales (los hace el desarrollador)

1. Instalar Roblox Studio y el plugin de Rojo.
2. Crear la experiencia en el panel de creador y publicarla.
3. Activar "Enable Studio Access to API Services" para probar el guardado.
4. Poner el máximo de jugadores por servidor en 8.
5. Crear los game passes y productos, y copiar sus ids en `Config/Shop.luau`.
6. Rellenar el cuestionario de clasificación de contenido de la experiencia.
