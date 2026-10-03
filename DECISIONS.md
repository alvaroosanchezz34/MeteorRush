# Decisiones de diseño

Decisiones tomadas donde el README no especifica, siguiendo la opción más simple.

## Fase 0

- **Paquete real de ProfileStore:** el README no da el nombre exacto del paquete Wally. Se verificó en el índice oficial (`UpliftGames/wally-index`) que el paquete publicado es `lm-loleris/profilestore` (no `madstudioroblox/profilestore`), versión `1.0.3`.
- **Versiones fijadas en `rokit.toml`:** últimas versiones estables verificadas en los releases de GitHub el 2026-10-02: Rojo 7.7.1, Wally 0.3.2, Selene 0.32.0, StyLua 2.5.2.
- **Nombre del paquete propio en `wally.toml`:** `theal/meteor-rush`, sin especificar en el README.
- **Carpeta de paquetes:** ~~`Packages/` única en `ReplicatedStorage`~~ — corregido en la Fase 2: Wally exige declarar ProfileStore (`realm = "server"`) en `[server-dependencies]`, que se descarga en `ServerPackages/` y se mapea a `ServerScriptService.ServerPackages`. Se quitó el mapeo de `Packages/` porque no hay dependencias compartidas (Rojo falla si la carpeta no existe); se volverá a añadir cuando haya alguna.
- **`Remotes.luau`:** todos los remotes se implementan como `RemoteEvent` (ninguno necesita respuesta síncrona bloqueante según la tabla de la sección 6). Se crean como hijos del propio `ModuleScript` (`script`), evitando una carpeta intermedia.
- **Intercambio (`Trade*`):** se concretan 5 remotes para cubrir el flujo descrito (solicitud, respuesta, actualizar oferta, confirmar, cancelar): `TradeRequest`, `TradeRespond`, `TradeUpdateOffer`, `TradeConfirm`, `TradeCancel`.
- **Arranque de servicios/controladores:** `Main.server.luau` y `Main.client.luau` leen una lista ordenada de nombres (`SERVICE_ORDER` / `CONTROLLER_ORDER`) y hacen `require` solo de esos módulos, llamando primero a todos los `Init()` y después a todos los `Start()`. La lista empieza vacía en la Fase 0 y se amplía en cada fase siguiente, en el orden de dependencia que corresponda.
- **`stylua.toml`:** ancho de columna 100, indentación de 4 espacios, comillas dobles preferidas, paréntesis siempre en llamadas — no especificado en el README, son valores por defecto razonables para Luau.
- **`selene.toml`:** `std = "roblox"` y se excluye `Packages/**` del lint.

## Fase 1

- **Medidas del mapa:** todas en `shared/Config/Map.luau`. Las que no da el README: suelo general de 1200x1200, rejilla de pedestales de 6 columnas x 4 filas con 8 studs de separación, zona de depósito de 20x8 en el borde de la parcela que mira al centro, y cartel a la izquierda de la entrada.
- **Orientación de las parcelas:** cada parcela usa `CFrame.lookAt(centroParcela, centroMapa)`, así que su -Z local es la entrada (hacia la zona de impacto). El punto de aparición está al fondo, mirando a la entrada.
- **Reparto MapService/PlotService:** `MapService` solo construye la geometría y expone `GetPlots()` (tipo `PlotLayout`). `PlotService` guarda quién es dueño de cada parcela. `MapService` hace todo en `Init`, por eso va antes que `PlotService` en `SERVICE_ORDER`.
- **Aparición:** hay un `SpawnLocation` central activo para quien aún no tiene parcela. Los de las parcelas están desactivados para que nadie aparezca en una ajena al azar. A cada dueño se le pone `RespawnLocation` y, además, `PlotService` mueve el personaje a su parcela en cada `CharacterAdded` (con `task.defer`), por si `RespawnLocation` no se aplica sobre un `SpawnLocation` desactivado.
- **Asignación:** se da la primera parcela libre por orden de índice. Si no queda ninguna (no debería pasar con 8 jugadores máximo), se avisa con `warn` y el jugador se queda en el centro.
- **Pedestales:** se crean los 24 posibles. Los bloqueados se sacan del árbol (`Parent = nil`), lo que vale tanto para placeholders como para modelos reales. Las parcelas libres muestran los 8 iniciales. `PlotService.SetUnlockedPedestals` queda listo para la mejora de la Fase 5.
- **Assets reales:** `Util/Assets.luau` busca `ReplicatedStorage/Assets/<Id>` (por ahora `Sign` y `Pedestal`) y, si no existe, usa el placeholder. Un cartel real debe incluir un `TextLabel` llamado `OwnerText`.
- **Zona segura:** `PlotService.IsInOwnPlot(player, posicion)` comprueba si la posición está dentro del cuadrado de la parcela, hasta 50 studs de altura. Se usará en la Fase 6.
- **Atributos:** cada modelo de parcela lleva los atributos `PlotIndex` y `OwnerUserId` (este último solo si tiene dueño), para que el cliente pueda encontrar su parcela más adelante.

## Fase 2

- **Plantilla del perfil:** vive en `shared/Config/Data.luau` junto al nombre del almacén (`PlayerData`) y el intervalo de guardado del tiempo de juego (60 s).
- **API de escritura de `DataService`:** los servicios leen con `GetData(player)` y escriben solo con `Set`, `Update` o `Increment`, que replican el campo de primer nivel modificado. Escribir directamente en la tabla devuelta por `GetData` no se replica.
- **Eventos de perfil:** `OnProfileLoaded` y `OnProfileReleasing` son listas de funciones (no `BindableEvent`). Se registran en `Init`. `OnProfileReleasing` se ejecuta de forma síncrona antes de `EndSession`, así que lo que se escriba ahí se guarda.
- **Formato de `DataUpdate`:** `("snapshot", datos)` con la copia completa al cargar y `("field", clave, valor)` por cada cambio.
- **Remote extra `DataRequest`:** el cliente lo envía en `Start` por si la copia inicial llegó antes de que se conectara el evento. Tiene límite de frecuencia.
- **Réplica en el cliente:** `DataController` guarda los datos congelados (`table.freeze` en profundidad); cada cambio de campo crea una tabla nueva.
- **`lastSeen` y `playtime`:** se actualizan al cerrar el perfil (salida o `BindToClose`); `playtime` también se suma cada 60 s para no perderlo si el servidor se cae. La carga **no** toca `lastSeen`, para que `IncomeService` (Fase 4) pueda calcular los ingresos offline.
- **`RateLimiter`:** ventana fija por jugador. Los límites salen de `shared/Config/Network.luau`. Tras 20 infracciones sin una pausa de 30 s entre ellas, se expulsa al jugador. El estado de cada jugador se limpia en `PlayerRemoving`.
- **Textos visibles:** `shared/Strings.luau` centraliza los textos en inglés (mensajes de expulsión por ahora).
- **Herramienta de prueba solo en Studio:** `DataService` crea un `BindableFunction` `DebugAddCoins` cuando `RunService:IsStudio()`, para cambiar las monedas desde la barra de comandos (que no comparte `require` con los scripts).

## Fase 3

- **Mochila en memoria:** los minerales transportados se guardan en `CarryService`, no en el perfil. Si el jugador sale mientras lleva minerales, los pierde (igual que si se los roban). En esta fase `CarryService` solo tiene almacenamiento, capacidad y réplica (remote `CarryUpdate`); la Fase 4 añade depósito, penalización de velocidad y visuales.
- **`Config/Upgrades.luau` adelantado:** la capacidad de la mochila, el tiempo de golpe y la suerte ya hacen falta para minar, así que el config de mejoras (datos y fórmulas) se crea ahora. `UpgradeService` y el menú siguen en la Fase 5.
- **Pico:** el "-5 % por nivel" se aplica sobre el tiempo base y es aditivo: `1,5 * (1 - 0,05 * nivel)`, con mínimo 0,3 s (se llega al mínimo en el nivel 16). Con la fórmula multiplicativa (`0,95^nivel`) nunca se llegaría a 0,3 s.
- **Suerte:** multiplicador aditivo `1 + 0,05 * nivel` sobre el peso de los minerales Raro o superior. Se multiplica por el del tipo de meteorito.
- **Mutaciones del gigante (x3):** se multiplica por 3 el peso de cada mutación distinta de `none`; las probabilidades se reparten de nuevo de forma automática.
- **Distancia de minado:** se mide desde el `HumanoidRootPart` hasta la **superficie** del meteorito (distancia al centro menos el radio), porque los meteoritos grandes miden más de 12 studs. El servidor da 2 studs de margen por la latencia.
- **Minado continuo:** mientras el jugador mantiene pulsado, el servidor encadena golpes. Se para al soltar, al salir del alcance, si desaparece el meteorito o si se llena la mochila.
- **Entrada:** `ContextActionService` con clic izquierdo, R2 y un botón táctil "Mine". Al pulsar se elige el meteorito más cercano dentro del alcance; si no hay ninguno, la pulsación sigue su curso normal (no se consume).
- **Remote extra `MineState`:** el servidor envía `("start", idMeteorito, duración)` en cada golpe y `("stop")` al parar, para que el cliente dibuje la barra de progreso sobre el meteorito.
- **Programación:** cada tipo de meteorito tiene su propio calendario independiente (normal cada 45 s, grande cada 5 min, gigante cada 30 min). Si coinciden, caen ambos. Primer impacto: normal a los 20 s de arrancar (para poder probar pronto); grande y gigante, tras su intervalo completo.
- **Posición de caída:** punto aleatorio uniforme dentro de la zona de impacto, evitando solaparse con meteoritos activos o ya avisados (10 intentos).
- **Hora del impacto:** el aviso envía la hora del impacto con `Workspace:GetServerTimeNow()`, para que la cuenta atrás del cliente no dependa de la latencia.
- **Efectos:** el marcador (anillo rojo, columna de luz y cuenta atrás), la bola de fuego y la explosión son solo de cliente. La explosión no empuja ni rompe nada. El meteorito real lo crea el servidor en el momento del impacto.
- **Nombres en inglés:** los nombres visibles de minerales, mutaciones y rarezas están en `Strings.luau` (Space Rock, Stellar Iron, Lunar Copper, Cosmic Crystal, Plasma Core, Nebula Gem, Dark Matter, Star Heart; Golden, Radioactive, Rainbow).
- **Avisos en pantalla:** `UI/Notifications.luau` (mensajes que desaparecen solos) y `NotificationController`, que escucha el remote `Notify`. Se avisa a todo el servidor al anunciarse un meteorito grande o gigante y al conseguir alguien un mineral Legendario o superior.
- **Índice:** todavía no se registran las combinaciones minadas; se hará con el sistema de índice en la Fase 7.
- **Herramienta de prueba solo en Studio:** `MeteorService.DebugSpawnMeteor` (`BindableFunction`) lanza un meteorito con su aviso de 10 s.

## Cambios de datos (Fases 4-10)

- **`pedestals` con claves de texto:** `[tostring(numero)] = idObjeto`. Las tablas numéricas con huecos se pierden al guardarlas en DataStore (JSON) y al enviarlas por remotes; con claves de texto no pasa.
- **`purchases` es una lista** (`{ string }`) de los últimos 100 `PurchaseId`, como dice el README; antes estaba tipada como diccionario.
- **Campos nuevos en el perfil:** `indexRewards` (filas del índice ya cobradas) y `tutorialStep` (0-3). `Reconcile()` los añade a perfiles antiguos; no hace falta subir `version`.
- **`DataService.OnFieldChanged(campo, fn)`:** los servicios reaccionan a cambios de datos en vez de llamarse entre sí. Por ejemplo, comprar una mejora solo escribe `upgrades`; `CarryService` (velocidad y capacidad) y `PedestalService` (pedestales visibles) se actualizan solos. Igual con rebirth, game passes y cosméticos.
- **`lastSeen`** se guarda también cada 60 s (junto a `playtime`) para que una caída del servidor no regale horas extra de ingresos sin conexión.
- **`Util/PlayerStats.luau`:** todas las estadísticas derivadas (capacidad, pedestales, velocidad, suerte, multiplicador e ingresos por segundo) se calculan en un módulo compartido, para que el HUD muestre exactamente lo que calcula el servidor.

## Fase 4

- **Servicios extra:** `PedestalService` (colocar y quitar minerales, y su dibujo sobre los pedestales) y `TutorialService` (Fase 10). No estaban en la lista del README; se separan para mantener "un servicio, una responsabilidad".
- **Colocar minerales:** un mineral colocado sigue en `inventory`; `pedestals` solo indica dónde está. Desde el menú "Base", "Place" lo pone en el primer pedestal libre y "Remove" lo quita.
- **30 pedestales en la rejilla (6x5):** 24 por mejoras + 6 del pass `extraPedestals`. El README pone "máximo 24" en la mejora y "+6" en el pass, así que la parcela necesita sitio para 30.
- **Depósito y cobro:** se detectan en el servidor por la posición del `HumanoidRootPart` sobre la zona (hasta 8 studs de altura), comprobando cada 0,2 s (depósito) y cada 0,25 s (cobro).
- **Placa de cobro:** amarilla, en la esquina del fondo de cada parcela, con un cartel que muestra las monedas pendientes. Se cobra la parte entera; los decimales se quedan acumulados.
- **Minerales en la espalda:** se dibujan en el servidor (los ven todos, necesario para el robo) soldados al torso, como máximo 12.
- **Al morir se pierde la mochila.** En el juego no hay daño, así que solo pasa si alguien hace reset.
- **Ingresos sin conexión:** se suman a `pendingIncome` (hay que cobrarlos en la placa) y se avisa con un mensaje.
- **HUD:** monedas, ingresos/s, mochila, boosts activos, cuenta atrás del próximo meteorito (atributo `NextMeteorAt` de `Workspace`, en hora del servidor) y flecha con la distancia al meteorito activo más cercano.
- **Interfaz por código:** `UIController` monta el HUD cuando llegan los datos. Las listas usan `UIGridLayout` con celdas a escala del área visible, sin píxeles fijos. No se añadió `UIScale`: con todo en escala no hace falta.

## Fase 5

- **Mejoras:** `UpgradeService` valida el nivel máximo y las monedas, y escribe `upgrades`; los efectos se aplican mediante `OnFieldChanged`. El menú muestra el valor actual → el siguiente y el coste (botón gris si no alcanza).

## Fase 6

- **Golpear:** tecla F, X en mando o botón táctil "Hit". El clic izquierdo también golpea si no hay ningún meteorito al alcance. Se golpea al jugador más cercano a 8 studs o menos (el servidor da 2 de margen).
- **Orden de comprobaciones:** enfriamiento → distancia → novato (atacante o víctima) → la víctima lleva algo → zona segura → inmunidad → escudo. El atacante recibe un mensaje explicando por qué no ha funcionado.
- **Minerales soltados:** se esparcen alrededor de la víctima apoyados en el suelo (raycast). Nadie puede recogerlos durante 1 s, para que la víctima no los recupere al instante; después cualquiera los recoge al pasar a 4 studs (20 con el boost "magnet") si tiene sitio en la mochila. Desaparecen a los 20 s.
- **Inmunidad visible:** la víctima lleva un `ForceField` visible durante los 5 s de inmunidad.
- **Protección de novato:** usa `DataService.GetPlaytime`, que incluye la parte de la sesión actual aún no guardada.

## Fase 7

- **Servicio extra `IndexService`.** Fila del índice = un mineral con sus 4 mutaciones. Completarla da, una sola vez y de forma automática, los ingresos de ese mineral sin mutación durante 30 minutos. Se registran combinaciones al minar, al recoger minerales soltados, al recibirlos por intercambio y con la recompensa diaria.
- **Racha diaria:** cobro cada 24 h. Si pasan más de 48 h vuelve al día 1, y tras el día 7 vuelve a empezar. Recompensas fijas en monedas (100 → 10.000); el día 7 da además una Gema Nebulosa (el único mineral Épico) sin mutación, directa al inventario de la base. Las monedas no escalan con los rebirths (opción más simple).
- **Rebirth:** también vacía la mochila ("minerales" incluye lo transportado). El menú de rebirth está en `UI/RebirthMenu.luau`.

## Fase 8

- **Cosméticos con Robux:** cada cosmético es un producto de desarrollador (id 0 = "Coming soon"). Al comprarlo se equipa automáticamente. Hay picos (modelo sencillo en la mano derecha, todos llevan uno gris por defecto), estelas (`Trail` en el `HumanoidRootPart`) y colores de base (suelo de la parcela). La estela dorada VIP no se compra: es del pass `vip`.
- **Paquetes de monedas:** dan el 2 %, 8 % y 25 % del coste del siguiente rebirth, así escalan con los rebirths.
- **Boosts:** se guardan en `boosts` como hora de caducidad; comprar uno activo suma 30 minutos.
- **Etiqueta VIP:** el servidor pone el atributo `VIP` al jugador y el cliente añade `[VIP]` en el chat con `TextChatService.OnIncomingMessage`.
- **Passes:** se comprueban al cargar el perfil (si la comprobación falla, se mantiene la caché) y al terminar una compra.

## Fase 9

- **Intercambio:**
  - Solo minerales del inventario de la base que no estén en un pedestal, hasta 20 por oferta.
  - Las solicitudes caducan a los 30 s.
  - Remote extra `TradeState` (servidor → cliente) con el estado completo del intercambio.
  - Si un objeto ofrecido se coloca en un pedestal o desaparece, se vacía esa oferta y se quitan las confirmaciones.
  - La ejecución vuelve a validar todo y hace las dos transferencias sin ceder el hilo.

## Fase 10

- **Sonidos:** `Config/Sounds.luau` tiene los ids vacíos con `-- TODO`. No se inventan ids de la Creator Store; mientras estén vacíos, el juego simplemente no suena.
- **Partículas:** polvo al impactar un meteorito y chispas en cada golpe de pico (solo cliente).
- **Tutorial:** tres pasos que avanza el servidor (minar → depositar → colocar en pedestal); el cliente muestra el texto del paso actual.
- **Evento gigante:** aviso global al anunciarse y al caer, y el cielo se tiñe de morado en todos los clientes mientras el gigante está en el suelo (atributo `GiantActive` de `Workspace`).
- **Herramientas de prueba solo en Studio:** `DebugService` (`SkipNewbie`, `ResetDaily`, `GiveMineral`), además de `DataService.DebugAddCoins` y `MeteorService.DebugSpawnMeteor`.

### Revisión de equilibrio

- **Valor esperado de un mineral minado:** 13,3 monedas/s de media (sin mutación). La mayor parte viene de la cola rara; la mediana es Roca o Hierro (1-3/s). Con mutaciones la media sube un 12 %.
- **Primeros minutos:** con 8 pedestales de comunes se ganan unas 10-20 monedas/s, así que la primera mejora del pico (100) llega en un par de minutos.
- **Primer rebirth (1M):** a 1.000 monedas/s cuesta unos 17 minutos; con 24 pedestales de Raros y Épicos (unos 3.000-6.000/s) bastan 3-6 minutos. Cada rebirth cuesta 5 veces más y suma +50 %, así que se alarga a propósito.
- **Recompensas de fila del índice:** van de 1.800 (Roca) a 14,4M (Corazón de Estrella). Esta última pide las 4 mutaciones de un mineral Mítico, así que es prácticamente un logro.
- **Valores a vigilar con datos reales:** la frecuencia del meteorito normal (45 s con 30 golpes repartidos entre 8 jugadores puede quedarse corta) y el tiempo de golpe del pico.
