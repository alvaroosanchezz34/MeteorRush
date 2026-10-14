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

## Modelos generados por código

Sustituyen a los bloques lisos. Siguen siendo el "placeholder": un modelo real en `ReplicatedStorage/Assets/<Id>` tiene prioridad.

- **Minerales:** cada uno tiene forma, material y color propios (`Minerals.List[].color` y la tabla de formas de `Util/MineralVisual.luau`), con 2-4 partes soldadas entre sí. De Raro en adelante llevan una luz. El color de rareza se sigue usando en la interfaz.
- **Mutaciones:** campo `style` en `Config/Mutations.luau`. Dorado = metal dorado, Radiactivo = neón verde, Arcoíris = cada parte de un tono distinto. Todas añaden destellos y luz. Se quitó el contorno (`SelectionBox`).
- **Meteoritos:** núcleo con bultos de roca al azar, vetas de neón, luz, ascuas y una marca quemada en el suelo. El color de brillo es `glowColor` en `Config/Meteors.luau`. Los bultos no sobresalen del radio, que es el que se usa para la distancia de minado.
- **Pedestales:** base, columna, plato y filo luminoso; ocupan lo mismo que antes (`PedestalSize`).
- **Parcelas:** bordillo, columnas con luz en las esquinas, arco verde sobre la zona de depósito y cartel con postes. El color de base cosmético sigue cambiando solo el suelo.
- **Zona de impacto:** borde luminoso (64 tramos) y 16 cráteres decorativos sin colisión, con semilla fija para que el mapa sea siempre igual.
- **Barras y etiquetas flotantes:** como ahora los meteoritos y minerales son `Model`, los `BillboardGui` se enganchan a su parte principal.
- **Sin probar en Studio:** las proporciones están calculadas, no vistas. Puede hacer falta retocar tamaños o colores.

## Segunda pasada de aspecto

- **Ambiente:** noche espacial definida en `default.project.json` (Lighting con tecnología Future, cielo estrellado, neblina y bloom). `Technology` no se puede cambiar desde un script, por eso va en el proyecto de Rojo.
- **Decorado (`server/Builders/Scenery.luau`):** montañas de terreno (`Terrain:FillBall`) alrededor del mapa con vetas de lava, caminos iluminados de cada parcela a la zona de impacto, formaciones de cristal, rocas, tres tipos de estructura entre parcelas (torre de radar, cápsula estrellada, depósito de combustible), charcos de lava sin colisión en la zona de impacto, un planeta con anillo y asteroides flotando. Todo sale de `Map.Scenery` y usa una semilla fija. Dentro de la zona de impacto no hay nada con colisión, para no estorbar a los meteoritos.
- **`server/Builders/Kit.luau`:** piezas reutilizables (roca facetada, cristal con punta, farola). No son servicios: no tienen `Init`/`Start`.
- **Parcelas:** pasillo central, valla de energía sin colisión en los lados, muro al fondo con ventanas, baliza de luz vertical, rótulo "DEPOSIT" en el arco, cajas y barriles, y marco en la placa de cobro. Pedestales con columna redonda.
- **Meteoritos:** bultos de formas mezcladas, grietas de neón, cristales que asoman, rocas alrededor de la base y humo.
- **Minerales:** modelos de 5 a 11 partes; Legendario y Mítico sueltan destellos. Los expuestos en pedestales giran y flotan en cada cliente (`DisplayController`, etiqueta `SpinDisplay`).
- **Interfaz:** fuente FredokaOne, botones con degradado, borde y respuesta al pasar el ratón y pulsar, barra lateral de botones cuadrados con icono (emoji) y color propio, ventanas con borde y animación al abrir.
- **Game passes en Studio:** `Shop.IgnoreOwnedPassesInStudio`. El creador posee todos sus passes, así que en Studio se empieza sin ninguno para probar como un jugador normal.

## Sensación de juego

- **Sonidos provisionales:** `Config/Sounds.luau` usa los sonidos que trae el cliente de Roblox (`rbxasset://sounds/...`), que no necesitan ids de la Creator Store. Los nombres de archivo no se han podido comprobar; si alguno no existe, ese sonido no suena y Studio lo avisa en la Salida.
- **Mineral obtenido:** remote extra `MineReward` (servidor → cliente) con la posición del meteorito y el mineral. El cliente lo muestra como texto flotante con chispas, en vez del aviso de pantalla de antes.
- **Barra de golpes:** cada cliente dibuja sobre los meteoritos cuántos golpes les quedan, leyendo el atributo `HitsLeft`.
- **Sacudida de cámara** al impactar un meteorito, según su tamaño y la distancia.
- **Monedas:** texto "+$X" junto al panel cada vez que entran monedas.
- **`LeaderboardService`:** `leaderstats` con Rebirths y Coins en la lista de jugadores.

## Más contenido

- **Cuatro mejoras nuevas** (con monedas, se reinician con el rebirth como las demás):
  - `fortune`: +4 % por nivel de sacar un segundo mineral con el mismo golpe (máx. 40 %). El segundo no gasta golpe del meteorito.
  - `mutation`: +10 % por nivel a la probabilidad de mutación (máx. x2), multiplicado por el del meteorito.
  - `refinery`: +5 % por nivel a los ingresos de los pedestales (máx. x2), multiplicado por rebirths y passes.
  - `grip`: al recibir un golpe se suelta un 3 % menos por nivel (del 50 % al 20 %).
- **Campos nuevos en `upgrades`:** `Reconcile()` los añade a perfiles antiguos; además se leen con `PlayerStats.GetUpgradeLevel`, que devuelve 0 si faltan.
- **`InventoryService`** (servicio extra): vender y fusionar. Solo actúa sobre minerales que no están en un pedestal.
  - **Vender:** un mineral da lo que generaría en 90 s sin multiplicadores (`Income.SellSeconds`). "Sell Commons" vende de golpe los Comunes y Poco comunes sin mutación, para no vender algo valioso por error.
  - **Fusionar:** 3 minerales iguales (mismo mineral y mutación) dan 1 con la mutación siguiente (Normal → Dorado → Radiactivo → Arcoíris). Registra la combinación en el índice.
- **"Place Best":** recoloca todo poniendo en los pedestales los minerales que más generan (`PedestalService`).
- **Meteoritos que se rompen:** al gastarse los golpes se le caen placas de la corteza (hasta quedarse con el 30 %), que saltan y desaparecen. Lo hace el servidor para que todos vean el mismo meteorito.
- **Animación de picar:** `SwingController` gira el hombro derecho (`Motor6D.Transform`) de los personajes con el atributo `Mining`, que pone `MiningService`. Ritmo fijo, no sincronizado con cada golpe.

## Misiones, códigos y clasificación global

- **Misiones diarias (`QuestService`, `Config/Quests.luau`):** las mismas cinco para todos, se reinician a medianoche UTC. Los servicios donde ocurre la acción llaman a `QuestService.Progress` (minar, minar Raro o superior, depositar, comprar mejoras). La recompensa es una fracción del coste del siguiente rebirth (mínimo 500), para que siga valiendo la pena al avanzar. Se cobra a mano desde el menú.
- **Datos nuevos:** `quests` (`day`, `progress`, `claimed`) y `codes`. Si el día guardado no es el de hoy, el progreso cuenta como cero.
- **Códigos (`CodeService`, `Config/Codes.luau`):** un uso por jugador, sin distinguir mayúsculas. Dan monedas o un mineral. La casilla está en el menú de misiones para no añadir un noveno botón al HUD.
- **Clasificación global (`LeaderboardService`, `Config/Leaderboard.luau`):** `OrderedDataStore` con `totalCoinsEarned`. Se guarda al entrar, al salir y cada 5 minutos; se lee cada 2 minutos. Hay dos tableros en el mapa, justo fuera de la zona de impacto. En Studio también escribe en la clasificación real.

## Roadmap de producción — Fase 0 (auditoría)

A partir de aquí el trabajo sigue `ROADMAP.md`, una fase cada vez.

- **Registro (`Util/Log.luau`):** `Log.Warn` para fallos de sistemas y `Log.Suspicious` para lo que un cliente legítimo nunca envía (tipos inválidos, exceso de peticiones). Solo deja constancia; no expulsa. El limitador de frecuencia registra la primera infracción de cada racha y la expulsión.
- **Errores de guardado:** `DataService` escucha `ProfileStore.OnError`, `OnOverwrite` y `OnCriticalToggle`.
- **Mochila al cerrarse el servidor:** si el jugador se va por su cuenta pierde lo que llevaba (así salir no sirve para esquivar un golpe); si es el servidor el que se cierra, se deposita en su base. Depende de que Roblox avise del cierre antes de sacar a los jugadores, así que es un "mejor esfuerzo".
- **Riesgo anotado para la Fase 8:** `ProcessReceipt` confirma la compra en cuanto la aplica al perfil en memoria, sin esperar a que se guarde. Si el servidor se cae justo después, la compra se pierde.

## Roadmap de producción — Fase 1 (core gameplay)

- **`BaseController` (cliente):** localiza la parcela del jugador por el atributo `OwnerUserId`. Solo informa a la interfaz; la zona segura y el depósito los sigue decidiendo el servidor.
- **Base propia resaltada:** cada jugador ve la baliza y las luces de su base en verde (cambio local, los demás no lo ven).
- **Flecha a la base:** aparece solo al llevar minerales fuera de la base. Con la mochila llena parpadea y el contador se pone en rojo.
- **Freno por carga:** el HUD muestra el porcentaje de velocidad que resta la carga.
- **Zona segura:** aviso en el HUD mientras se está dentro de la base propia.
- **Colocar minerales:** el mineral aparece creciendo, con un destello y un sonido (como mucho uno cada 0,25 s, para que `Place Best` no suene treinta veces).
- **Mochila al desconectarse:** se mantiene la decisión de que se pierde si el jugador se va por su cuenta.

### Revisión de equilibrio

- **Valor esperado de un mineral minado:** 13,3 monedas/s de media (sin mutación). La mayor parte viene de la cola rara; la mediana es Roca o Hierro (1-3/s). Con mutaciones la media sube un 12 %.
- **Primeros minutos:** con 8 pedestales de comunes se ganan unas 10-20 monedas/s, así que la primera mejora del pico (100) llega en un par de minutos.
- **Primer rebirth (1M):** a 1.000 monedas/s cuesta unos 17 minutos; con 24 pedestales de Raros y Épicos (unos 3.000-6.000/s) bastan 3-6 minutos. Cada rebirth cuesta 5 veces más y suma +50 %, así que se alarga a propósito.
- **Recompensas de fila del índice:** van de 1.800 (Roca) a 14,4M (Corazón de Estrella). Esta última pide las 4 mutaciones de un mineral Mítico, así que es prácticamente un logro.
- **Valores a vigilar con datos reales:** la frecuencia del meteorito normal (45 s con 30 golpes repartidos entre 8 jugadores puede quedarse corta) y el tiempo de golpe del pico.

## Roadmap de producción — Fase 2 (economía y progresión)

- **Simulador (`Util/EconomySim.luau`):** juega solo el bucle minar → volver → colocar → vender/fusionar → mejorar → rebirth con los valores de `Config` y las fórmulas de `PlayerStats`, y apunta el estado a 1, 5, 10 y 30 horas. Se lanza en Studio con `DebugService.SimulateEconomy:Invoke(jugadores, partidas)` y escribe el informe en la Salida, con avisos si el mejor mineral sale antes de 1 h en más del 25 % de las partidas o si faltan más de 3 horas para el siguiente rebirth.
- **Qué no modela:** robos, misiones, racha, índice ni ingresos sin conexión. El jugador simulado no pierde tiempo y juega el 80 % del tiempo, así que va más rápido que uno real: los tiempos son un suelo, no una media.
- **`Util/Loot.luau`:** las tiradas de mineral y de mutación salen de `MiningService` a un módulo compartido para que el simulador use exactamente las mismas probabilidades.
- **Origen y destino de las monedas:** todas las entradas pasan por `IncomeService.AddCoins(jugador, cantidad, origen)` y todas las salidas por `IncomeService.SpendCoins(jugador, cantidad, destino)`, que comprueba el saldo. `EconomyService` lleva la cuenta por sesión (en memoria, no se guarda).
- **Panel de estadísticas:** botón `$ stats` a la derecha de la pantalla, solo en Studio (el servidor no envía nada fuera de Studio). Muestra ganado y gastado por origen, minerales por rareza y el tiempo que falta para el rebirth y para la mejora más barata. `DebugService.EconomyReport:Invoke(jugador)` escribe lo mismo en la Salida.
- **Coste de fusión (sink nuevo):** fusionar cuesta lo que generaría el mineral resultante en 60 s (`Mutations.FuseCostSeconds`; 0 lo deja gratis). Se cobra antes de tocar el inventario. En la simulación es un gasto pequeño (menos del 0,1 %); su función es que fusionar sea una decisión, no gratis.
- **Refinería hasta el nivel 40** (antes 20; ingresos hasta x3). Es el sink de fondo: con 20 niveles, a partir del 5.º rebirth todas las mejoras estaban al máximo y las monedas se acumulaban horas sin nada que comprar.

### Ajuste de equilibrio

Resultados del modelo con 4 jugadores (mediana de 300 partidas). Están calculados con una copia del simulador en JavaScript, porque aquí no se puede ejecutar Luau; hay que confirmarlos en Studio con `SimulateEconomy`.

| | Antes | Después |
|---|---|---|
| Rebirths a 1 h / 5 h / 10 h / 30 h | 1 / 4 / 6 / 7 | 1 / 4 / 6 / 9 |
| Espera hasta el siguiente rebirth a las 10 h y a las 30 h | 12,8 h y 9,4 h | 1,4 h y 5,6 h |
| Corazón de Estrella antes de 1 h | 45 % de las partidas | 9 % |
| Primer Corazón de Estrella (mediana) | 1,1 h | 5,4 h |
| Mejoras al máximo | desde las 10 h | nunca (queda refinería) |

- **Pesos de las rarezas altas:** Gema Nebulosa 70 → 50, Materia Oscura 25 → 8, Corazón de Estrella 5 → 1. El meteorito gigante (x5) y la suerte hacían que el mejor mineral saliera en la primera hora en casi la mitad de las partidas.
- **Rebirth:** coste `2.000.000 * 2,5 ^ rebirths` (antes `1.000.000 * 5 ^ rebirths`). Con +50 % aditivo por rebirth, un factor 5 creaba un muro de más de 10 horas a partir del 6.º rebirth. El primero cuesta el doble para que no llegue en la primera media hora.
- **Con 8 jugadores** se va más lento que en solitario (5 rebirths a las 10 h frente a 7), porque los golpes de meteorito se reparten (unos 7 s por golpe y jugador): con el servidor lleno, la mejora del pico apenas sirve. No se ha tocado; hay que decidirlo con la prueba real de 8 jugadores (una opción es que el meteorito normal caiga más a menudo cuantos más jugadores haya).

## Roadmap de producción — Fase 3 (colección y retención)

- **Datos nuevos:** `stats` (contadores de por vida), `achievements` (logros desbloqueados) y `title` (título equipado). `Reconcile()` los añade a perfiles antiguos. No se reinician con el rebirth.
- **Logros (`Config/Achievements.luau`, `AchievementService`):** cada logro es una estadística y un objetivo. Se desbloquean solos y dan la recompensa en ese momento, una única vez (se marcan antes de dar las monedas), así que no hay nada que reclamar dos veces. La recompensa es una fracción del coste del siguiente rebirth (mínimo 1.000), como las misiones.
- **Estadísticas:** los servicios donde ocurre la acción llaman a `AchievementService.AddStat` (minar, depositar, vender, fusionar, mejorar, golpear, intercambiar, cobrar misiones). Las que ya están en otro campo del perfil (rebirths, índice, monedas ganadas, racha, códigos, tiempo de juego) se calculan en `PlayerStats.GetStat` y no se guardan dos veces.
- **Logros ocultos:** son las "misiones secretas" del roadmap. Seis logros con `hidden = true` que el menú muestra como "???" hasta conseguirlos (primer mineral Arcoíris, primer Corazón de Estrella, fusionar un Arcoíris, golpear a 25 jugadores, recibir 10 golpes y canjear un código).
- **Títulos:** los dan 13 de los logros; el id del título es el del logro, así que no hay lista aparte de títulos conseguidos. Se equipan desde la pestaña de logros (el servidor comprueba que el logro está desbloqueado). El servidor pone el texto en el atributo `Title` del jugador, lo muestra sobre la cabeza y `PlotService` lo añade al cartel de la base.
- **Nuevo descubrimiento:** `IndexService` ya no envía un aviso de texto sino el remote `IndexDiscovered`; el cliente muestra un aviso grande (`UI/Banner.luau`) con el modelo del mineral girando, su nombre y el progreso del índice. Los logros usan el mismo aviso. Si llegan varios, se muestran en cola.
- **Ventana Collection:** el botón "Index" pasa a llamarse "Collection" y la ventana tiene tres pestañas (índice, logros y perfil), para no añadir un noveno botón a la barra lateral, que en móvil ya llega hasta la zona del joystick.
- **Herramientas de prueba solo en Studio:** `DebugService.AddStat` y `ResetAchievements`.
- **Sin probar en Studio:** el visor 3D del aviso y los tamaños de las pestañas están calculados, no vistos.

## Roadmap de producción — Fase 4 (PvP y juego social)

- **Feedback del robo (`StealController`):** el servidor envía a todos `StealHit` (víctima, posición y minerales soltados). Todos ven chispas rojas y un "-N" que sube; la víctima, además, un destello rojo, una sacudida de cámara y el sonido del golpe. Se mantienen el campo de fuerza de la inmunidad y los minerales en el suelo.
- **Competiciones (`CompetitionService`, `Config/Competition.luau`):** la primera a los 6 minutos de arrancar el servidor y después cada 12; duran 3 minutos y hacen falta 2 jugadores (si no, se reintenta cada minuto). Se turnan cuatro: minar, depositar, minar Raro o superior y golpear. Los puntos salen de las mismas estadísticas que los logros (`AchievementService.OnStat`), así que no hay un segundo sitio donde contar. Los tres primeros ganan el 3 %, 1,5 % y 0,75 % del coste de su siguiente rebirth; en caso de empate gana quien llegó antes a esa puntuación. Quien se va a mitad no cuenta.
- **Estado de la competición por atributos:** `CompetitionKind` y `CompetitionEndsAt` en Workspace y `CompetitionScore` en cada jugador; el HUD calcula el puesto con eso, sin remotes nuevos. No es más que información: las recompensas las decide el servidor con su propia tabla de puntos.
- **Ganar una competición** cuenta como estadística (`competitionsWon`) y da el logro y el título "Champion" (28 logros y 14 títulos en total).
- **Bonus de amigos (`SocialService`, `Config/Social.luau`):** +10 % de ingresos por cada amigo de Roblox en el mismo servidor, hasta 3. La amistad se consulta en el servidor con `Player:IsFriendsWith` al entrar cada jugador. El número de amigos se guarda en `friendsOnline` del perfil para que `PlayerStats` (servidor y cliente) lo use como cualquier otro multiplicador; se pone a 0 al cerrar el perfil, así que no cuenta sin conexión. Si el servidor se cae sin cerrar el perfil, el valor viejo puede contar una vez para los ingresos sin conexión (como mucho +30 %).
- **Herramientas de prueba solo en Studio:** `DebugService.SetFriends` (en Studio los jugadores de prueba no tienen amigos) y `StartCompetition`.
- **Ya estaba hecho y no se ha tocado:** robo con pérdida parcial, enfriamiento, protección en la base y de novatos, e intercambio con doble confirmación.

## Roadmap de producción — Fase 5 (rebirth y meta-progresión)

- **Progreso temporal y permanente:** el rebirth reinicia `coins`, `pendingIncome`, `upgrades`, `inventory`, `pedestals` y la mochila. Todo lo demás es permanente; los campos nuevos son `shards`, `permanent` (nivel de cada nodo) y `rebirthInfo`.
- **Meteor Shards:** cada rebirth da `5 + 2 * rebirths hechos` (5, 7, 9...). Solo se consiguen así; no se compran ni se intercambian.
- **Árbol permanente (`Config/Permanent.luau`, `PermanentService`):** siete nodos en tres ramas. Ingresos (+10 % por nivel, 10 niveles) → monedas iniciales tras el rebirth (2 rebirths) → ingresos sin conexión (5 rebirths). Mochila (+2) → velocidad (+1). Suerte (+5 %) → mutación (+10 %, 3 rebirths). El coste es lineal (`baseCost + costStep * nivel`) y el árbol entero cuesta 355 shards; con 10 rebirths se han ganado 140. Es una lista con requisitos, no un árbol dibujado.
- **Efectos en `PlayerStats`:** los nodos se suman a las mismas funciones que usan las mejoras normales, así que servidor, cliente y simulador calculan lo mismo. El multiplicador de ingresos queda `rebirths * refinería * amigos * nodo de ingresos * pass`: cada factor entra una sola vez.
- **Monedas iniciales:** fracción del coste del siguiente rebirth (0,2 % por nivel, hasta el 1 %). No cuentan como monedas ganadas.
- **Desbloqueos por rebirths:** además de los nodos, tres cosméticos gratis con `rebirthsRequired` en `Config/Shop.luau` (estela a los 3, color de base a los 5 y pico a los 7), y los títulos de los logros de 1 y 10 rebirths. El menú de rebirth muestra cuál es el siguiente desbloqueo.
- **Confirmación en dos pasos:** es del cliente (el botón abre un panel con lo que se pierde, se conserva y se gana); el servidor sigue validando el coste al recibir el remote.
- **Estadísticas de rebirth:** `rebirthInfo.lastPlaytime` (tiempo de juego al hacer el último) y `fastest` (el más rápido). La duración del rebirth actual se calcula restando.
- **Ventanas con pestañas:** `UI/CollectionMenu` pasa a ser `UI/TabbedMenu`, genérico; lo usan Collection (índice, logros, perfil) y Rebirth (rebirth, Shard Tree).
- **Simulador:** el jugador simulado gasta los shards en el nodo desbloqueado más barato.
- **Herramienta de prueba solo en Studio:** `DebugService.AddShards`.

## Roadmap de producción — Fase 6 (bases y personalización)

- **Sin editor libre:** la base tiene 6 huecos fijos (`Decor.Slots`), en los pasillos laterales entre los pedestales y la valla, y una lista cerrada de 9 decoraciones (`Config/Decor.luau`). El número de huecos es el límite de objetos. Se montan con las piezas de `Builders/Kit` (cristales, farolas, rocas y trofeos).
- **Efecto de base:** uno a la vez, de una lista de 6. Son partículas que suben por toda la parcela (8 por segundo) y una luz de su color. Con 8 bases son 8 emisores y 8 luces sin sombras.
- **Desbloqueos (`PlayerStats.IsUnlocked`):** cada decoración o efecto es gratis o pide rebirths, combinaciones del índice o un logro. No se guardan: se calculan del progreso, así que no hay nada que comprar ni que duplicar.
- **Cosmético separado del juego:** `DecorService` pone todo sin colisión y fuera de raycasts y toques (`CanCollide`, `CanQuery` y `CanTouch` a false), así que no estorba al moverse, ni a los minerales que caen al suelo, ni a las zonas de depósito y cobro. No toca ingresos ni estadísticas.
- **Datos:** campo `decor` (`slots` con claves de texto y `effect`). El servidor valida el hueco, que el id exista y que esté desbloqueado. Al cambiar algo se reconstruye la carpeta `Decor` de la parcela entera, que es poco trabajo y pasa pocas veces.
- **Área de exposición:** un panel en el muro del fondo de cada base con las 32 combinaciones (columna por mineral, fila por mutación; las descubiertas, iluminadas), el nombre, los rebirths y los logros. Lo dibuja el servidor, así que lo ve cualquiera que pase por la base. No se usan 32 modelos de mineral por base por rendimiento.
- **Visitar bases (`VisitService`):** la pestaña Players de la ventana Collection lista a los demás con su título, rebirths e índice (atributos `Title`, `Rebirths` e `IndexCount` del jugador) y un botón que te lleva delante de la entrada de su base. No se puede usar llevando minerales (no sirve de atajo ni para huir de un robo) y tiene 30 s de enfriamiento. Apareces fuera de la parcela.
- **Pestañas:** la ventana Base pasa a tener Minerals y Decor.
- **Sin probar en Studio:** las posiciones de los huecos y del panel están calculadas sobre las medidas del mapa, no vistas; puede que alguna decoración roce la valla o que el panel tape parte de las ventanas del muro.

## Roadmap de producción — Fase 7 (eventos y contenido)

- **Framework (`EventService`, `Config/Events.luau`):** un bucle elige el siguiente evento, lo anuncia, espera la cuenta atrás (30 s), lo empieza, espera su duración, lo termina y reparte las recompensas. Cada tipo de evento (`kind`) es un par de funciones `start`/`finish`; los eventos concretos son solo datos. Hay tres tipos: `meteor` (cae un meteorito especial), `shower` (caen varios seguidos) y `supernova` (multiplicadores globales).
- **El servidor no se queda atascado:** las funciones de cada evento van con `pcall` y todo el ciclo va dentro de otro; el final depende de un `task.wait` de la duración, no de que pase nada en el juego, y al acabar se limpia siempre el estado. Solo hay un evento a la vez.
- **Calendario:** primer evento a los 8 minutos y después uno cada 10 minutos desde que acaba el anterior. Se elige por peso entre los que tienen `enabled = true` y ya han pasado su `cooldown` propio (los más fuertes, 40 minutos). Sin jugadores no empieza ninguno.
- **Meteoritos especiales:** son tipos nuevos de `Config/Meteors.luau` con `special = true`: no tienen calendario propio y solo caen en eventos. Reglas: Dorado (todo sale al menos Dorado, `minMutation`), Corrupto (raros x3 y mutaciones x5, pero se mina un 50 % más lento, `mineTimeMultiplier`), Negro (25 golpes y 75 s, raros x12), Arcoíris (mutaciones x12) y Alienígena (dos minerales por golpe, `mineralsPerHit`). El cliente los dibuja con el mismo código que los demás, con sus colores.
- **Lluvia de Meteoritos:** 8 meteoritos normales, uno cada 8 s. **Supernova:** durante 150 s todos los meteoritos dan raros x3 y mutaciones x3, cae un meteorito grande y el cielo se tiñe (atributo `EventTint`).
- **Estado por atributos de Workspace:** `EventId`, `EventStartsAt` (cuenta atrás) y `EventEndsAt` (activo). El HUD los muestra debajo de la competición y enseña un aviso grande al empezar. Quien entra a mitad ve el mismo estado.
- **Recompensa:** quien mina al menos un mineral mientras el evento está activo recibe al acabar el 0,5 % del coste de su siguiente rebirth (mínimo 1.000), una sola vez por evento, y le cuenta para la estadística `eventsJoined` (logro y título "Stargazer" a los 10; 29 logros y 15 títulos en total). Quien se va antes del final no recibe nada.
- **Los siete eventos están activados.** El roadmap pedía probar el framework con dos antes de crear el resto; como los otros cinco son solo datos sobre el mismo tipo `meteor`, están escritos, pero si la prueba del framework falla basta con dejar `enabled = true` solo en `meteorShower` y `supernova`.
- **El simulador no modela los eventos**, así que la progresión real será algo más rápida que la simulada.
- **Herramientas de prueba solo en Studio:** `DebugService.StartEvent` (cuenta atrás de 5 s) y `MeteorService.DebugSpawnMeteor`, que ya acepta los tipos especiales.

## Roadmap de producción — Fase 8 (monetización)

La tienda ya estaba hecha (5 passes, 3 boosts, 3 paquetes de monedas y cosméticos). Esta fase es una auditoría y el arreglo del riesgo anotado en la Fase 0.

- **Entrega exactamente una vez (`ShopService.processReceipt`):** si el `PurchaseId` no está en el perfil, se entrega la compra y se apunta el id sin ceder el hilo entre las dos cosas. Después se guarda el perfil y solo se devuelve `PurchaseGranted` cuando el id aparece en los datos guardados (`DataService.SaveAndWait`, con `Profile:Save`, `OnAfterSave` y `LastSavedData` de ProfileStore, como recomienda su guía de productos).
- **Servidor caído durante una compra:** si se cae antes del guardado, Roblox reenvía el recibo al volver a entrar y, como el id no llegó a guardarse, se entrega entonces. Si el jugador se va antes de confirmarse el guardado, se devuelve `NotProcessedYet`; el guardado final incluye el id, así que al reenviarse el recibo no se entrega otra vez y se confirma.
- **Recibo repetido mientras se espera el guardado:** no vuelve a entregar; espera al mismo guardado.
- **Perfil aún sin cargar:** `ProcessReceipt` espera a que cargue (o a que el jugador se vaya) en vez de rechazar el recibo.
- **El jugador recibe su compra al momento:** el aviso de gracias y el efecto llegan en cuanto se entrega; lo que espera al guardado es solo la confirmación a Roblox.
- **Nada llega del cliente:** los productos se identifican por el `ProductId` del recibo de Roblox y los passes por `UserOwnsGamePassAsync`, que se vuelve a comprobar cada vez que carga el perfil. La cantidad de un paquete de monedas la calcula el servidor al entregarlo.
- **Sin compras aleatorias:** passes, boosts, monedas y cosméticos son concretos y visibles antes de pagar. No hay cajas ni tiradas con Robux.
- **Los cosméticos no dan ventaja:** solo cambian colores. La única ventaja del pass VIP (+10 % de velocidad) es del pass, no del cosmético, y está indicada en su descripción.
- **Riesgo que queda — passes comprados dentro del juego:** al comprar un pass, el servidor lo activa por el evento `PromptGamePassPurchaseFinished`, que un cliente modificado podría falsear. El efecto duraría solo esa sesión: al volver a entrar se comprueba la propiedad real con Roblox y se corrige. No se verifica en el momento porque `UserOwnsGamePassAsync` guarda en caché la respuesta y dejaría sin su pass durante un rato a quien lo acaba de comprar de verdad.
- **Herramienta de prueba solo en Studio:** `DebugService.FakeReceipt` procesa un recibo inventado; con el mismo id dos veces se comprueba que no se entrega dos veces.

## Roadmap de producción — Fase 9 (Live Ops)

- **Un solo archivo para cada actualización (`Config/LiveOps.luau`):** interruptores de contenido, temporadas, calendario de eventos y registro de versiones. Lanzar una temporada o una versión nueva es añadir una entrada a una lista.
- **Interruptores en caliente (`LiveOpsService`, ahora se cambian desde el centro de control de administración):** `events`, `competitions`, `seasons`, `codes`, `trading` y `stealing`. Cada sistema pregunta `LiveOpsService.IsEnabled` antes de actuar. Un administrador (el creador de la experiencia o los UserIds de `LiveOps.Admins`; en Studio, cualquiera) los cambia desde el panel `⚙ ops`; el servidor comprueba el permiso en cada cambio. El cambio se aplica al momento en ese servidor, se guarda en el DataStore `LiveOps` y los demás servidores lo leen cada 60 s, así que se puede apagar un sistema roto sin publicar. Lo que ya está en marcha (un evento, un intercambio abierto) termina normalmente.
- **Temporadas (`SeasonService`):** la temporada activa sale de la hora del servidor (`startsAt` y `days`, en UTC). Mientras dura, ciertas acciones dan puntos de temporada (cobrar misiones diarias, participar en eventos, ganar competiciones) y hay seis misiones propias; los puntos desbloquean seis escalones de recompensa (monedas, shards y dos cosméticos). Las recompensas se entregan solas al llegar, una vez (se marcan antes de entregar). Usa las mismas estadísticas que los logros (`AchievementService.OnStat`).
- **Datos de temporada versionados por id:** el perfil guarda `season = { id, points, progress, done, claimed }`. Si el id guardado no es el de la temporada activa, el progreso empieza de cero; eso cubre el cambio de temporada con el servidor en marcha y al jugador que vuelve tras varios días. Sin temporada activa, el progreso viejo se queda como está y no se usa.
- **Cosméticos temporales:** llevan `season = "s1"` en `Config/Shop.luau`. No se compran; se consiguen en su temporada y se conservan para siempre. Pasada la temporada, la tienda solo se los enseña a quien los tiene. Si un día se borra un cosmético de la configuración, quien lo tuviera equipado vuelve al aspecto por defecto sin errores.
- **Temática:** cada temporada tiene nombre y color, que se usan en su pestaña. No cambia el mapa.
- **Códigos con caducidad:** campo `expiresAt` (hora Unix UTC). El servidor lo comprueba al canjear.
- **Calendario de eventos:** citas semanales (día, hora y minuto UTC) que lanzan un evento de `Config/Events` a la vez en todos los servidores, además de los que salen solos. La pestaña Season muestra la próxima. Si a esa hora hay otro evento en marcha, la cita se pierde.
- **Registro de versión:** `LiveOps.Releases` (la primera es la actual). El perfil guarda `seenVersion`; al entrar con una versión no vista se muestran sus notas una vez y el cliente avisa con `AckVersion`. A quien entra por primera vez no se le muestran. La versión aparece en una esquina del HUD.
- **Ventana Quests:** pasa a tener dos pestañas, Daily Quests y Season.
- **La Temporada 1 empieza el 1 de octubre de 2026** para que esté activa durante las pruebas; hay que poner la fecha real antes de publicar.
- **Herramienta de prueba solo en Studio:** `DebugService.ResetSeason`.

## Pasada de pulido visual

Solo aspecto, sonido y sensación de juego. No cambia economía, probabilidades, datos, progresión ni reglas.

- **`UI/Effects.luau` (cliente):** efectos reutilizables y de corta duración (ráfaga, onda expansiva, fragmentos, texto flotante, destello de pantalla y sacudida). Tiene un tope de 40 efectos de mundo a la vez y no crea los pequeños a más de 220 studs de la cámara.
- **`UI/AudioManager.luau` (cliente):** único sitio que crea sonidos y música. `Config/Sounds.luau` define id, volumen, tono, variación de tono y espera mínima entre repeticiones. Puede bajar la música un momento para los sonidos importantes. `UI/Sound.luau` queda como alias para el código anterior.
- **Sonidos provisionales:** los nuevos reutilizan archivos que trae el cliente de Roblox con distinto tono (raro, mutación, doble, Star Heart, mochila, rebirth, misión, evento, interfaz). No se han inventado ids de la Creator Store; si un archivo no existe, ese sonido no suena.
- **Iluminación (`AmbienceController`):** el estado normal es el de `default.project.json` (ahora con corrección de color y profundidad de campo lejana). Encima hay ambientes con transición: morado con el gigante en el suelo, Supernova que enciende el mapa en 12 s, y tinte para eventos con color. Sustituye al tinte que hacía `UIController`. No crea luces.
- **Desenfoque de menús:** el mundo se desenfoca mientras hay una ventana abierta (`Components`).
- **Cielo (`SkyController`):** el anillo del planeta gira, una luna lo orbita, los asteroides derivan (6 por fotograma, por turnos), cinco nebulosas de unas 6 partículas cada una y una estrella fugaz cada 7-18 s. No hay skybox con texturas propias: harían falta imágenes subidas a Roblox.
- **Zona central (`Scenery.buildImpactZone`):** rocas en el borde del cráter (con hueco en los caminos), vetas de energía desde el centro, cristales cerca del borde, 14 rocas flotantes y polvo luminoso (14 partículas por segundo en toda la zona). Todo sin colisión. Se construye lo último para que el resto del mapa no cambie con la misma semilla.
- **Meteoritos (`MeteorController`):** anillos que laten en el aviso; entrada con estela, ascuas y luz del color del tipo, más larga en los grandes y el gigante; impacto con onda expansiva (doble en los grandes), destello de luz y, en el gigante, destello de pantalla y sonido propio. Se quita la `Explosion` de Roblox. Al desaparecer se deshace en una ráfaga y deja una marca quemada 45 s (máximo 8).
- **Minería:** fragmentos y tono según el tamaño del meteorito en cada golpe; texto más grande cuanto más raro; sonido y ráfaga para Raro o superior; onda del color de la mutación; aviso "DOUBLE!" para el segundo mineral del mismo golpe; destello, sacudida y sonido propio para Star Heart.
- **Transporte:** el HUD avisa al 80 % (naranja y sonido) y al llenarse (sonido, destello y texto sobre la cabeza). Con la mochila llena, la carga brilla y suelta chispas; eso lo dibuja el servidor para que lo vean todos. Las partículas por rareza las llevan ya los propios minerales de la espalda.
- **Pedestales (`DisplayController`):** aura por nivel, solo en los pedestales cercanos a la cámara: pocas partículas para lo normal, más y de su color para Dorado, Radiactivo y Arcoíris (multicolor), aro luminoso para raros y mutaciones, y haz de luz para Star Heart.
- **Bases:** línea de energía a ras de suelo por dentro del bordillo (en verde en la propia), cartel con marco, degradado y contorno, y panel de colección con marco luminoso.
- **Interfaz:** los botones se encogen al pulsar y rebotan al soltar, y suenan todos; las ventanas se cierran con animación; avisos con rebote, en la parte baja del centro; monedas que vuelan al contador (como mucho cada 1,5 s); destellos alrededor de los avisos grandes.
- **Sin probar en Studio:** no se ha podido ver nada de esto ni medir el rendimiento; los tamaños, colores e intensidades están calculados.

## Identidad de los meteoritos

Solo presentación. No cambian golpes, duración, probabilidades ni valores: todo eso sigue en `Config/Meteors.luau`.

- **`Config/MeteorFx.luau`:** cada tipo de meteorito pertenece a un nivel de espectáculo (`normal`, `big` o `giant`; los cinco especiales usan `big`). El nivel fija el haz del aviso, los anillos, la duración de la entrada, las ascuas de la estela, el sonido, las ondas expansivas, las rocas despedidas, el destello, la sacudida de cámara (fuerza, alcance y duración) y la rotura. Cambiar cómo se siente un meteorito es cambiar números ahí.
- **Normal:** discreto. Haz fino, una onda, sin destello, y el sonido del impacto se apaga con la distancia (`HearRange`).
- **Grande y especiales:** haz más alto y ancho, entrada más lenta, dos ondas, sonido para todo el servidor, sacudida que llega más lejos y un charco de energía bajo el meteorito.
- **Gigante (evento):** al anunciarse, aviso grande "☄️ GIANT METEOR DETECTED", cuenta atrás en pantalla, el cielo empieza a teñirse de morado (`AmbienceController.SetOverride`), rayos en el cielo y música de evento. Al caer, tres ondas, destello y la sacudida más fuerte. Al romperse, destello, sonido propio, sacudida y más recompensas flotando.
- **Música de evento:** `Sounds.Music.EventTrack` admite el id de una pista propia; mientras esté vacío, la música normal baja de tono durante el evento. No se ha inventado ningún id.
- **Energía en el suelo:** la luz de cada meteorito late y sube de intensidad a medida que se gasta (junto a las placas que ya rompía el servidor).
- **Fragmentos:** cada golpe, lo dé quien lo dé, hace saltar fragmentos; antes solo los veía quien golpeaba.
- **Rotura:** si se ha minado entero, revienta (ráfaga, fragmentos, onda, sonido y destellos de recompensa que suben); si se le acaba el tiempo, se apaga con un poco de polvo. En los dos casos deja un cráter temporal de 45 s (máximo 8 a la vez).
- **Reutilización de piezas:** los soportes de efectos, los fragmentos y los tramos de los rayos salen de un pool y vuelven a él; no se crean y destruyen en cada golpe.
- **Sin destellos repetidos:** los rayos son solo geometría en el cielo y un sonido bajo; no hacen parpadear la pantalla. Los destellos de pantalla de meteoritos que no son evento solo se ven a menos de 160 studs.
- **Textos en inglés**, como el resto del juego: el aviso es "☄️ GIANT METEOR DETECTED" (`Strings.Meteor`).

## Identidad de las mutaciones

Solo presentación: no cambian probabilidades ni multiplicadores (x2, x5 y x15 siguen en `Config/Mutations.luau`).

- **`Config/MutationFx.luau`:** por mutación, la secuencia al conseguirla (sonido, tamaño del texto, ráfaga, ondas, rayos, destello y sacudida) y el efecto continuo (partículas, destellos, luz, pulso, onda de energía, color animado y rayos pequeños).
- **Dorado:** material metálico dorado, partículas pequeñas, destellos sueltos y luz cálida. Texto "✨ GOLDEN!".
- **Radiactivo:** energía verde alrededor, luz que late y ondas que crecen desde el mineral. Sonido electrónico grave. Texto "☢️ RADIOACTIVE!".
- **Arcoíris:** el color recorre el mineral de forma continua, partículas multicolor, luz que cambia de color, onda de energía y pequeños rayos cada pocos segundos. Al conseguirlo: texto grande "🌈 RAINBOW!", tres ondas de colores, ocho rayos, destello y sacudida para quien lo consigue, y una ráfaga al aparecer en un pedestal o en el suelo.
- **Anuncio a todos:** las mutaciones con `announce = true` (solo Arcoíris) las ve todo el servidor: el remote `MutationFound` hace que los demás vean la secuencia en el meteorito (a menos de 400 studs y sin destello ni sacudida) y se envía el aviso de texto "X found Rainbow ...", que antes solo salía con minerales Legendarios o superiores.
- **Registro:** no cambia. Cada mineral conseguido se registra en el índice y en las estadísticas (`mutatedMined`, `rainbowMined`) como antes, también al fusionar.
- **El efecto continúa en el pedestal:** los efectos van en el propio mineral, así que los lleva en el pedestal, en la espalda y en el suelo.
- **Niveles de calidad por distancia (`MutationFxController`):** el servidor ya solo pone el material y el color (`MineralVisual` deja de crear partículas y luz para las mutaciones). Cada cliente añade lo demás según la distancia a la cámara: completo hasta 45 studs, unas pocas partículas hasta 130 y nada más lejos. Como mucho 20 minerales a la vez en calidad completa; el resto de los cercanos se quedan en la barata. Las animaciones (color y pulso de luz) se actualizan 15 veces por segundo y solo en los de calidad completa.
- **Textos en inglés**, como el resto del juego (`Strings.MutationReveal`).

## Mapa vivo: sucesos ambientales

Solo visual. Ningún suceso da recompensas ni cambia probabilidades.

- **`Config/Ambient.luau`:** frecuencias, pesos, duración de cada suceso raro y límites (luces que laten, polvo, escala en móvil).
- **Sucesos corrientes (`AmbientController`):** cada cliente genera uno cada 14-32 s, nunca varios a la vez: meteorito pequeño que se quema en el cielo, satélite con una luz que parpadea y nave lejana con el motor encendido. Las estrellas fugaces sueltas, las nebulosas animadas y las rocas flotantes ya estaban en `SkyController`; ahora además el planeta se desplaza muy despacio con su anillo y su luna.
- **Sucesos raros (`AmbientService`):** el servidor elige uno cada 140-260 s (el primero a los 90 s), sin repetir el mismo dos veces seguidas, y lo publica en atributos de Workspace (`AmbientEvent`, `AmbientEventStart`, `AmbientEventSeed`). Así todos los jugadores ven lo mismo a la vez y con las mismas posiciones; quien entra a mitad ve lo que queda. Son cinco: lluvia de estrellas, cometa, eclipse (oscurece el mapa con un tono rojizo), anomalía espacial (esfera con anillos que colapsa con un destello) y portal temporal (se abre un disco de energía, sale una nave y se cierra). Cada uno deja un aviso de texto discreto.
- **Luces que laten:** las luces del decorado (cristales, farolas) varían su brillo; solo las 16 más cercanas a la cámara y 10 veces por segundo.
- **Polvo espacial:** un único emisor que sigue a la cámara, con 5 partículas por segundo.
- **Móvil:** en dispositivos táctiles sin teclado las cantidades (estrellas de la lluvia, partículas, luces que laten) se reducen a la mitad.
- **Ambientes de iluminación:** `AmbienceController.SetOverride(nombre, activo)` admite ahora varios a la vez con prioridad (el anuncio del gigante por delante del eclipse).
- **Interruptor:** `ambient` en los interruptores de Live Ops apaga los sucesos ambientales sin publicar.
- **Herramienta de prueba solo en Studio:** `DebugService.StartAmbient`.

## NPCs ambientales

Decoración con voz. No venden nada, no dan misiones ni recompensas y no cambian ninguna regla.

- **Sistema modular (`Config/Npcs.luau`):** cada NPC es una entrada con su sitio, sus colores, su animación (`idle` o `mine`), si gira el cuerpo o solo la cabeza y su decorado. Sus frases están en `Strings.Npcs`. Añadir uno nuevo es añadir una entrada y sus frases; si además debe comentar lo que está pasando, se le pone un proveedor en `UI/NpcDialogue.luau`.
- **Los cuatro iniciales:** Meteorologist (junto al cráter, con su estación; comenta el gigante, los eventos, los sucesos del cielo y el próximo impacto, y explica los tres tipos de meteorito con sus tiempos reales), Scientist (mesa de laboratorio con muestras de las tres mutaciones; explica los multiplicadores y la fusión y comenta el índice del jugador), Trader (puesto junto a un tablero de clasificación; explica el intercambio y avisa si está desactivado) y Old Miner (pica una roca en el borde del cráter; es sobre todo decoración).
- **Sitio:** en los huecos entre parcelas, a la altura del borde del cráter y fuera de los caminos de las bases.
- **Figuras (`NpcService`):** hechas con piezas ancladas, sin colisión, sin raycasts y sin `Humanoid`, así que no bloquean el paso ni los clics de minar y cuestan muy poco. Su decorado tampoco tiene colisión.
- **Animación (`NpcController`):** la hace cada cliente moviendo las piezas: respiran, balancean los brazos, gesticulan al hablar, y el minero pica con chispas en cada golpe. Giran hacia el jugador más cercano a menos de 28 studs (el minero solo la cabeza). A más de 160 studs de la cámara no se animan.
- **Diálogo opcional:** una opción de proximidad "Talk" (tecla E, toque en móvil, botón Y en mando, porque X ya es golpear). Cada pulsación muestra la frase siguiente en un bocadillo sobre la cabeza durante 5 s, empezando por lo que esté pasando en ese momento. Además sueltan un comentario corto cada 25-55 s si el jugador está a menos de 30 studs. No hay ventanas ni menús de diálogo.
- **Sin probar en Studio:** las figuras y su decorado están hechos a ciegas; puede que haya que retocar proporciones o que alguno coincida con una roca del decorado.

## Bases sociales: visitas, likes y clasificaciones

Solo social y competitivo. Las visitas y los likes no dan monedas ni ninguna ventaja.

- **Datos:** campo `social` del perfil (`visits`, `likes` y `liked`). `Reconcile()` lo añade a los perfiles antiguos.
- **Visitas (`BaseSocialService`):** cuenta una visita cuando un jugador entra en la base de otro. El servidor lo comprueba cada 2 s con la posición del personaje, y cada pareja de jugadores cuenta como mucho una vez cada 10 minutos, para que no se pueda inflar entrando y saliendo.
- **Likes:** un jugador puede dar un solo like a cada base, para siempre. Quién ha dado like a quién se guarda en el perfil de quien lo da (`liked[UserId del dueño]`) y el total en el del dueño. Como solo se puede dar like a alguien que está en el servidor, los dos perfiles están cargados y se cambian seguidos, sin ceder el hilo: no hay likes a medias ni duplicados.
- **Contra exploits y spam:** el remote tiene límite de frecuencia; el servidor comprueba que el destino es un jugador con base, que no es uno mismo y que no se le había dado like; para dar likes hace falta 10 minutos de juego total (frena las cuentas recién creadas) y hay un tope de 2.000 bases marcadas por jugador. El cliente no envía ninguna cantidad.
- **Ventana "🏠 INSPECT BASE" (`UI/InspectBase.luau`):** dueño, título, rebirths, índice, mejor mineral (el que más genera, con el color de su mutación o rareza), pedestales usados, decoraciones y efecto, visitas y likes, con los botones "❤️ Like" y "Visit base". Se abre desde el cartel de cada base (opción de proximidad; botón Y en mando) o desde la lista de jugadores. En la propia base no aparecen los botones.
- **Perfil visible:** lo que se muestra sale de atributos del jugador que publica el servidor (`BaseVisits`, `BaseLikes`, `BestMineral`, `PedestalsUsed`, `PedestalCount`, `DecorCount`, `BaseEffect`, además de `Title`, `Rebirths` e `IndexCount`, que ya existían). No se envía el perfil de nadie a otros jugadores.
- **Clasificaciones:** pestaña "Top Bases" de la ventana Collection, con "🏆 Most Visited Bases" y "❤️ Most Liked Bases" (10 puestos cada una). Son globales, de todos los servidores.
- **Uso de DataStore:** dos `OrderedDataStore` (`BaseVisits_v1` y `BaseLikes_v1`). Cada servidor lee las dos clasificaciones cada 3 minutos (dos lecturas) y guarda la puntuación de cada jugador como mucho cada 5 minutos y al salir, y solo si ha cambiado desde el último guardado. Los nombres de los jugadores se guardan en memoria. El resultado se publica una vez en atributos de Workspace (texto JSON) y lo leen todos los clientes, sin remotes.
- **Textos en inglés**, como el resto del juego (`Strings.Inspect` y `Strings.Bases`).

## Objetivos secretos

- **No es un sistema aparte:** son logros con `secret = true` en `Config/Achievements.luau`. Reutilizan todo lo que ya había: se desbloquean solos cuando una estadística llega a su objetivo, se guardan en `achievements` del perfil para siempre, la recompensa se da una sola vez (se marca antes de dar las monedas) y pueden dar título.
- **22 objetivos secretos** (los 6 logros ocultos que ya había y 16 nuevos): primer Arcoíris, Star Heart, fusionar un Arcoíris, golpear a 25 jugadores, recibir 10 golpes, canjear un código, robar una carga de alto valor, llegar a la base tras un robo (3 veces), depositar una mochila llena solo de Raros o superior, ganar 3 competiciones seguidas, 25 rebirths, visitar 25 bases, recibir 25 likes, dar 10 likes, completar una fila del índice, 50 minerales de meteoritos especiales, 100 de gigantes, 100 minerales dobles, 25 Radiactivos, presenciar 5 sucesos raros del cielo, decorar los 6 huecos de la base y completar 10 intercambios. En total hay 45 logros (23 visibles y 22 secretos) y 22 títulos.
- **No aparecen en la interfaz:** un objetivo secreto sin conseguir no se lista de ninguna forma (antes salía como "???"). La pestaña de logros solo dice cuántos se han encontrado, sin el total. Al conseguirlo aparece en la lista con un candado y su descripción.
- **Al desbloquear:** aviso grande propio ("🔒 SECRET OBJECTIVE COMPLETE!") con el nombre, la descripción, la recompensa y el título si lo da, con su sonido, un destello morado y los destellos del aviso.
- **Estadísticas nuevas:** `valuableSteals`, `escapes`, `rareBackpacks`, `competitionStreaks`, `basesVisited`, `specialMined`, `giantMined`, `doubleMinerals`, `radioactiveMined` y `ambientSeen` las suma el servicio donde ocurre cada cosa; `likes`, `likesGiven`, `indexRows` y `decorSlots` se calculan del perfil en `PlayerStats.GetStat`. Las condiciones con umbral (qué es un robo de alto valor, cuántos segundos para "sobrevivir", cuántas victorias seguidas) están en `Config/Achievements.luau`.
- **Racha de competiciones:** se cuenta por sesión, en memoria; al salir del servidor se pierde la racha en curso (no el objetivo ya conseguido).
- **Ampliar:** un objetivo nuevo es una línea en la lista y su nombre en `Strings`; si mide algo nuevo, una llamada a `AchievementService.AddStat` donde ocurra o un caso en `PlayerStats.GetStat`.
- **Las recompensas siguen la regla de los logros** (una fracción del coste del siguiente rebirth); no se ha tocado la economía.

## Sistema de diseño de la interfaz

No cambia ninguna función: los menús hacen lo mismo que antes, con otro aspecto.

- **`UI/Theme.luau`:** único sitio con colores, tipografías, tamaños, radios de esquina, grosores de línea, sombra, degradados, iconos, animaciones y sonidos de interfaz. `UI/Components.luau` lo aplica y todas las pantallas se montan con esos componentes, así que el cambio llega a todas a la vez: Base, Upgrades, Shop, Collection (índice, logros, perfil, jugadores, bases), Daily, Quests (misiones y temporada), Rebirth (y Shard Tree), Trade, inspección de base, avisos y HUD.
- **Estilo:** fondo azul noche, superficies en dos niveles, líneas finas, un acento cian y un color propio por menú (botón de la barra lateral y línea de la cabecera de su ventana). Tipografía Gotham (negra para títulos, negrita para el resto) en lugar de Fredoka, también en los carteles del mundo, para que todo hable igual.
- **Ventanas:** cabecera con icono, título y línea de acento, sombra, entrada con rebote y salida rápida, y desenfoque del mundo detrás. En pantallas de menos de 1.000 píxeles de ancho ocupan casi toda la pantalla para que sea fácil tocar. La ventana tapa los clics, así que no se mina sin querer a través de ella.
- **Botones:** borde que se enciende al pasar el ratón o al seleccionarlo con el mando, encogimiento con rebote al pulsar y sonido. El texto se oscurece solo sobre fondos claros (dorado).
- **Estado desactivado:** cualquier botón cuyo color sea `Colors.Disabled` se ve apagado (texto gris, sin respuesta al pasar el ratón, sin sonido y fuera de la navegación con mando), sin tener que tocar cada menú.
- **Carga:** `Components.Spinner` (arco que gira; lo usan las clasificaciones de bases hasta que llegan) y `Components.SetBusy` (botón en espera unos segundos; lo usan los botones de compra de la tienda para que no se pulsen dos veces).
- **Confirmación:** `Components.Confirm`, un diálogo con texto y dos botones que tapa el contenido. Lo usa el rebirth en lugar de su panel propio. Con mando, la selección empieza en "cancelar".
- **Éxito y error:** los avisos de texto tienen tres tipos (información, éxito y error) con su color, su icono y su sonido. Como el servidor solo envía el texto, el tipo se deduce de palabras clave (`UI/Notifications.luau`); un texto que no encaja sale como información.
- **Entrada de texto:** `Components.Input` (la casilla de códigos), con la línea que se enciende al escribir.
- **Pestañas:** la página entra con un pequeño deslizamiento.
- **Mando:** todos los botones se pueden recorrer con la cruceta o el joystick (selección de interfaz de Roblox), con un marco cian de selección. Al abrir una ventana la selección pasa a su primer botón y B la cierra.
- **Iconos de los menús:** pasan de `Strings` a `Theme.Icons`.
- **Sin probar en Studio:** es el cambio de aspecto más amplio hasta ahora y no lo he visto. Lo más probable es que haya que retocar tamaños de texto en móvil y contrastes.

## Sistema visual de rareza y gran pasada visual

Solo presentación. No cambian rarezas, probabilidades, multiplicadores, golpes ni datos.

- **Capas (`Config/RarityFx.luau`, `RarityVisualController`):** el aspecto de un mineral es la suma de su capa de rareza, su capa de mutación, la identidad de ese mineral y el nivel de calidad. No hay código por mineral ni por combinación: las 32 combinaciones salen de 6 capas de rareza, 3 de mutación y 8 identidades.
- **Capa de rareza:** Común, casi nada; Poco común, un brillo que late; Raro, aura, puntos en órbita y fragmentos; Épico, además rayos pequeños y un haz corto; Legendario, anillo de energía, ondas periódicas y haz de presencia visible desde lejos; Mítico, dos anillos, más de todo, partículas que caen hacia el núcleo (gravedad) y otras que suben, y un haz de 60 studs.
- **Capa de mutación:** cambia el color del aura y multiplica la luz y las partículas de la rareza (Dorado x1,25, Radiactivo x1,45, Arcoíris x1,8), así que un Dorado Legendario brilla mucho más que un Dorado Raro. Dorado añade destellos y un fragmento; Radiactivo, pulso fuerte, ondas y rayos; Arcoíris, color animado en el mineral y su aura, prismas flotando, un anillo más y rayos.
- **Identidad:** roca con polvo; hierro con chispas cortas; cobre con pulsos cálidos; cristal con prismas; plasma con partículas rápidas y luz que parpadea; nebulosa con nubes de color; materia oscura con partículas oscuras que caen hacia dentro y una esfera de cristal que deforma lo de detrás; Star Heart con energía estelar que cae al núcleo y la misma esfera.
- **Estado:** en pedestal y en el suelo, todos los efectos; en la espalda de un jugador, solo luz y partículas reducidas (sin órbitas, anillos ni haz), porque son muchos y pequeños.
- **Niveles de calidad:** 3 (hasta 50 studs) todo; 2 (hasta 130) la mitad de partículas y de órbitas, sin fragmentos ni rayos; 1 (hasta 340, solo Legendario o superior) luz, aura mínima y haz; más lejos, nada. Como mucho 16 minerales en nivel 3 y 36 en nivel 2, y 24 luces encendidas; los que no caben bajan de nivel. En móvil y con gráficos medios no se pasa de 2; con gráficos bajos, de 1.
- **El servidor ya no crea ningún efecto en los minerales:** `MineralVisual` pone el modelo, el material y una etiqueta, y nada más. Antes cada mineral raro llevaba su luz y sus partículas siempre encendidas para todos.
- **Pedestales:** el aura propia de `DisplayController` se sustituye por este sistema, así que el mineral se ve igual en el pedestal, en el suelo y en la espalda.
- **Momento de descubrimiento (`UI/DiscoveryMoment.luau`):** al minar, según la rareza: Raro, sonido y ráfaga; Épico, además onda, rayos y destello leve; Legendario, todo más fuerte y con sacudida; Mítico, momento cinematográfico de 1,8 s (pantalla algo oscurecida, el mineral girando en 3D en el centro con su rareza, su nombre y su mutación, y destellos). No tapa los controles: el jugador puede seguir moviéndose.
- **Momentos legendarios (`MomentService`, `Config/Moments.luau`, `UI/LegendaryMoment.luau`):** el servidor anuncia a todos un Mítico, un Arcoíris de rareza Épica o superior (al minar o al fusionar), completar el índice y ganar tres competiciones seguidas. Aviso de tres líneas arriba, con sonido, destello leve y destellos. Mínimo 6 s entre dos anuncios y 20 s entre dos del mismo tipo de un jugador. Cuando hay momento legendario no se envía además el aviso de texto.
- **Meteoritos:** el modelo gana cráteres, zonas incandescentes y llamas, en cantidad según su nivel; el gigante lleva además púas de energía. Antes de que entre un meteorito de evento hay un sonido lejano, una luz en el cielo en el punto del que vendrá y temblores cada vez más fuertes. Mientras se mina, del interior se escapa cada vez más energía.
- **Audio:** sonidos nuevos para Épico, Legendario, momento legendario y temblor del gigante (provisionales, con archivos de Roblox a distinto tono). `AudioManager.Loop` admite sonido ambiental en bucle por rareza, pero las tres claves están vacías: hace falta un sonido pensado para bucle.
- **`MutationFxController`** queda solo para la secuencia de aparición de una mutación; su efecto continuo es ahora una capa del sistema de rareza.
- **Sin probar en Studio:** no he visto ninguno de estos efectos. Tamaños, brillos y cantidades están calculados.

## Composición de capas y pulido visual de rarezas

Amplía el sistema visual de rareza ya existente; no hay un segundo sistema. Solo presentación.

- **Composición (`RarityFx.Compose`):** las capas ya no se suman sin más. La función compone rareza + mutación + identidad con límites (`RarityFx.Limits`: como mucho 14 partículas por segundo de aura, 5 órbitas, 6 fragmentos, 3 anillos, y un intervalo mínimo entre rayos y entre ondas). Si la mutación cae sobre un Legendario o un Mítico, el aura de partículas baja al 70 % y el protagonismo pasa a anillos, rayos y color, para que no sea ruido.
- **Combinaciones con composición propia (`RarityFx.Combos`):** Star Heart Arcoíris (tres anillos de colores, estrellas, rayos y haz de 80 studs, con menos aura para que se lean el núcleo y las órbitas), Star Heart Dorado, Star Heart Radiactivo y Materia Oscura Arcoíris. Añadir otra es una línea.
- **Mítico como categoría propia:** no lleva muchas más partículas que un Legendario; lleva otra composición: núcleo de energía que respira, dos anillos, energía que cae hacia el núcleo, estrellitas que titilan alrededor, partículas que suben y un haz de 60 studs.
- **La identidad nunca se pierde:** las partículas propias de cada mineral y su forma de moverse se conservan con cualquier rareza y mutación.
- **Animación por mineral (`Identity.motion`):** giro, vaivén, velocidad de las órbitas y temblor. El cristal gira despacio, el plasma rápido y con temblor, la materia oscura muy lento y al revés, el cobre con un vaivén amplio. Se aplica en los pedestales (`DisplayController`) y a los minerales del suelo, que ahora giran y flotan (antes estaban quietos).
- **Mutaciones:** Dorado suma polvo brillante que cae despacio; Radiactivo, humo verde que sube y luz que parpadea de forma irregular; Arcoíris, color animado, prismas, anillo y rayos de colores.
- **Presencia a distancia:** el nivel bajo (luz, aura mínima y haz) llega ahora a Raro (170 studs), Épico (230), Legendario (340) y Mítico (520); antes solo a Legendario o superior.
- **Presencia de la base:** el servidor publica en cada parcela el rango de lo más raro que expone (`Prestige`) y cada cliente tiñe la baliza de las bases ajenas con ese color, más intensa cuanto más raro. No añade partículas ni luces. La propia base sigue en verde.
- **Recoger del suelo:** al recoger un mineral que soltó otro jugador hay feedback según su rareza; de Legendario para arriba, el momento de descubrimiento completo.
- **Interfaz (`UI/RarityStyle.luau`):** el nombre de un mineral lleva el icono de su rareza y, según el rango, tipografía de títulos, contorno luminoso y un brillo que recorre el texto (degradado de colores para Arcoíris). Se usa en la lista de la base, el índice, la inspección de bases, el texto flotante al minar y el momento de descubrimiento.
- **Audio:** sonido distinto al recoger y al colocar según la rareza (`RarityFx.Audio`), además de los de encontrar, mutación y momento legendario que ya había.
- **Meteoritos:** sombra que crece en el punto de impacto durante la caída y, en los de evento, ondas en el aire a su paso.

### Auditoría de rendimiento y limpieza

- **Bucles:** el sistema de rareza tiene un solo bucle por fotograma, que recorre únicamente los minerales con algo que mover (conjunto `moving`), y otro a 15 veces por segundo solo sobre los cercanos (`active`). Antes recorrían todos los minerales del mapa. No hay conexiones ni bucles por mineral.
- **Animaciones sin coste por fotograma:** el núcleo que respira, el brillo de los nombres y los anillos del aviso de meteorito usan `TweenService`, no código por fotograma.
- **Limpieza:** todo lo que crea el sistema para un mineral va a su lista de efectos y se destruye al cambiar de nivel, al alejarse y al desaparecer el mineral; el contador de luces se devuelve.
- **Fuga corregida:** un meteorito que desaparecía antes de registrarse en el cliente dejaba su estado guardado para siempre; ahora no se registra.
- **Reutilización:** rayos, ondas, ráfagas y fragmentos salen del pool de `Effects`, con su tope de 40 efectos a la vez.
- **Luces:** máximo 24 encendidas entre todos los minerales, sin sombras.
- **Sin probar en Studio:** no he podido ejecutar el juego, así que PC, móvil, mando y 8 jugadores quedan por comprobar.

## Centro de control de administración

- **Quién es administrador:** se decide solo en `src/server/Admin/AdminPermissions.luau`, por UserId (`ADMIN_USER_IDS`), y ese archivo no llega a ningún cliente. Además vale el creador de la experiencia (`AllowCreator`) y, en Studio, cualquier jugador de prueba (`AllowStudio`). No se mira el nombre, el DisplayName ni ningún atributo.
- **Flujo:** panel (`src/server/AdminClient`) → remote `AdminRequest` → `AdminService` comprueba el permiso y los valores → servicio del juego → remote `AdminResponse`. El panel nunca modifica nada por sí mismo.
- **El código del panel no se reparte:** vive en `ServerScriptService.Server.AdminClient` (no se envía a los clientes y no necesita ningún cambio en `default.project.json`) y el servidor solo lo copia al PlayerGui de los administradores. Tenerlo no da permisos: cada petición se vuelve a validar.
- **Validación:** tipos, rangos, ids existentes y topes (monedas 1e15, rebirths 500, 50 minerales por entrega, boosts 24 h, anuncio 120 caracteres). Quien no es administrador no recibe respuesta y queda en el registro de acciones sospechosas; el límite de peticiones es `Network.RateLimits.AdminRequest`.
- **Acciones destructivas:** el servidor exige `confirm = true`, que el panel solo envía tras el diálogo de confirmación; resetear monedas, resetear rebirths y cerrar el servidor piden además escribir una palabra.
- **Registro:** `Admin/AdminLogs` guarda las últimas 300 acciones del servidor (hora, administrador, acción, objetivo, valor) y las escribe en la consola con el prefijo `[Admin]`. No se guarda en DataStore.
- **Economía intacta:** las monedas se cambian con `DataService.Set`, sin contar como ganadas (no tocan `totalCoinsEarned`, la clasificación ni los logros). Los "multiplicadores temporales" son los boosts que ya existían (suerte, imán, escudo); no hay ningún multiplicador nuevo. Dar minerales no cambia las probabilidades y generar meteoritos no cambia sus tiempos de caída.
- **Rebirths:** el panel solo cambia el número; no reinicia mejoras ni reparte Meteor Shards.
- **Añadidos a servicios existentes:** `MeteorService.Spawn` acepta una posición y hay `GetAll` y `Remove`; `EventService.Stop` y `CompetitionService.Stop` (terminan sin repartir recompensas) y `CompetitionService.GetState`; `LiveOpsService.SetFeature`.
- **Sustituye al panel antiguo:** se han quitado `UI/AdminPanel`, el remote `SetFeature`, `LiveOps.Admins` y el atributo `Admin` del jugador. Los interruptores de contenido están en la página Settings.
- **Armas y picos:** se dan y se quitan con los proveedores `pickaxe` y `weapon` registrados con `AdminService.RegisterItemProvider` (ver "Equipamiento").
- **Sin ban permanente:** solo expulsar del servidor; no existe un sistema de bans.
- **Anuncios:** el texto pasa por el filtro de Roblox antes de enviarse a todos.
- **Pendiente:** "minar un meteorito al instante" no está hecho (repartiría recompensas saltándose `MiningService`). Nada de esto se ha ejecutado en Studio.

## Equipamiento: picos, armas y cajas

- **Objetos por tipo, no por unidad:** un pico o un arma se tiene o no se tiene (`equipment.owned`). Un duplicado se convierte en Forge Dust según su rareza. Así no existen dos copias de un objeto que se puedan duplicar, y el intercambio es mover una propiedad.
- **Forge Dust:** moneda solo del equipamiento (duplicados y la estadística `fragment` de algunos picos). Compra la caja Legendaria. No toca las monedas ni los Meteor Shards.
- **Rarezas propias:** `Config/Equipment.Rarities`, con los mismos seis nombres y colores que los minerales pero en una tabla aparte. Las rarezas y probabilidades de los minerales no se han tocado.
- **Topes centrales:** `Equipment.Limits` limita cada estadística, se escriba lo que se escriba en un objeto. Picos: velocidad ≤ 12 %, crítico ≤ 6 %, suerte ≤ +0,08, mutación ≤ +0,10, Forge Dust ≤ 10 %. Armas: alcance ≤ +3, tiempo entre golpes ≥ 1,6 s, soltar ≤ +10 %, empujón ≤ 60, aturdir ≤ 30 % y ≤ 0,8 s.
- **Cambio de economía (justificado):** el pico equipado sí cambia el minado, con esos topes. El pico inicial no da nada, así que quien no abre cajas juega exactamente igual que antes. El mejor pico (Mítico) equivale a ~12 % más de golpes, 6 % de minerales extra y algo más de suerte: deseable, no obligatorio. Las cajas de monedas son además un gasto nuevo (1 %, 5 % y 20 % del coste del siguiente rebirth).
- **Las armas no hacen daño.** Cambian alcance, ritmo, cuánto se suelta, empujón y aturdimiento. Tope absoluto de lo que suelta un golpe: 60 % de la mochila (`Steal.MaxDropFraction`).
- **Anti-frustración:** se mantienen zona segura, inmunidad de 5 s tras un golpe, enfriamiento del atacante, escudo y protección de novato. Nuevo: el aturdimiento máximo (0,8 s) dura menos que la inmunidad y no se repite en 20 s (`StunImmunity`); cada golpe recibido en 60 s reduce a la mitad lo que suelta el siguiente (mínimo x0,25).
- **Void Pulse:** única habilidad activa. 45 s de espera, radio 14, máximo 4 jugadores, cada uno suelta 1 mineral (cantidad fija, nunca fracción), empujón y 1,5 s de lentitud. Respeta las mismas protecciones que un golpe y no se puede usar desde la propia base.
- **Empujón:** lo aplica el cliente de la víctima (es quien mueve su personaje). Un tramposo podría ignorarlo; solo se libra del empujón, no de soltar la carga.
- **Cajas:** Basic, Rare y Epic con monedas; Legendary con Forge Dust; Mythic definida pero sin precio (eventos y administración). El servidor gasta la caja, tira y guarda en una sola modificación del perfil; el cliente solo presenta. SKIP salta la animación, no la lógica.
- **Seguro (pity):** activado en las cuatro cajas que se venden (15/20/25/12 aperturas → Raro/Épico/Legendario/Legendario). Se puede apagar por caja en `Config/Crates`.
- **Política de Roblox:** las cajas son objetos aleatorios de pago (las monedas se compran con Robux, y el Forge Dust sale de cajas). El servidor no vende ninguna caja, ni con monedas ni con Forge Dust, a quien tenga `ArePaidRandomItemsRestricted` (PolicyService), ni mientras no haya podido consultarlo; el menú solo activa la compra cuando el servidor confirma que está permitido. Antes de comprar se ven las probabilidades por rareza y, en "Drop rates", la de cada objeto con dos decimales, repartidas para sumar exactamente 100,00 % (`Crates.GetItemOdds`). Al arrancar se comprueba que los pesos de cada caja suman 100 (`Crates.Validate`). Lo que se enseña son las probabilidades base: el seguro solo puede mejorarlas y también está a la vista.
- **Cosméticos de caja:** tres nuevos (`trailPlasma`, `trailVoid`, `baseNebula`) marcados con `crate = true` en `Config/Shop`. Los cosméticos de Robux no salen en cajas.
- **Intercambio:** los picos y armas van en la misma oferta que los minerales, con el prefijo `gear:`. No se ofrece lo equipado ni lo inicial, y el otro jugador no puede tenerlo ya. Se revalida al ejecutar.
- **Migración:** el campo `equipment` es nuevo en la plantilla; los perfiles antiguos lo reciben con `Reconcile`. `EquipmentService` lo revisa al cargar sin borrar nada (los ids que no conoce se quedan).
- **Modelos y animaciones:** todo por código (`Util/EquipmentVisual`), sin assets ni animaciones subidas. "Animación" de cada pico = ritmo de picado según su velocidad, brillo y partículas según rareza, destello al equipar y efecto de crítico. No hay animaciones de esqueleto propias.
- **Sin monetización nueva:** ningún objeto ni caja se vende por Robux.
- **Sin probar en Studio:** nada de esto se ha ejecutado. Sonidos provisionales, como el resto.

## Presencia de los minerales especiales

- **Cartel apilado:** cada mineral expuesto lleva encima mutación (en su color), nombre, rareza e ingresos (`MineralVisual.AddSign`). Lo crea el servidor con colores fijos; el cliente anima los degradados (`DisplayController`): arcoíris en Rainbow, brillo en las demás mutaciones y en Legendario y Mítico.
- **Especial** = con mutación, o Legendario o superior. Su cartel se lee a 90 studs (45 los normales). El haz de luz vertical se quitó: molestaba a la vista.
- **Tamaño:** +10 % por rango de rareza y x1,1 / x1,2 / x1,35 por Golden / Radioactive / Rainbow (`MineralVisual.RankScale`, `MutationScale`). Solo visual: no cambia ingresos ni probabilidades.
- **En el suelo:** los minerales especiales que suelta un jugador también son más grandes y llevan cartel (sin ingresos).
- **No tocado:** la mochila a la espalda (su rejilla depende de un tamaño fijo) y el aura, las partículas y el ciclo de color del arcoíris, que ya los ponía `RarityVisualController`.
- **Referencia:** pedido a partir de un vídeo de Steal a Brainrot que no se pudo ver; hecho con identidad propia, sin copiar assets.

## Limpieza visual (menos luz, suelo de losas, llama de rareza)

- **Motivo:** en una captura del juego, las luces de los minerales y de la base teñían todo de verde y los haces y carteles se pisaban. Referencia del usuario: un juego de día, limpio, con suelo de bloques y una llama a los pies de cada personaje según su rareza.
- **Luz:** Bloom 0,7 → 0,25 con umbral 1,8; exposición 0,4 → 0,15; sin desenfoque lejano. Las luces de los minerales se multiplican por `RarityFx.LightScale` (0,3) y su alcance por 0,55; máximo 8 encendidas. Luces de pilares y baliza de la base, a menos de la mitad.
- **Haces fuera:** ni el haz de presencia de `RarityFx` ni el de los minerales especiales.
- **Llama de rareza (`RarityFx.Flame`):** un `Fire` a los pies del mineral, del color de su rareza o su mutación. Nada en Común y Poco común; crece de Raro a Mítico. Un mineral con mutación lleva como mínimo la de Raro. Solo de cerca (niveles de calidad 2 y 3).
- **Carteles:** más pequeños (5,5 studs de ancho) y con contorno negro sólido.
- **Suelo de losas:** 6x6 baldosas en dos tonos sobre un suelo oscuro que hace de junta (`Map.PlotTiles`). Los cosméticos de color de base tiñen las losas. Las losas llevan los tacos que trae Roblox (`SurfaceType.Studs` sobre plástico, `Map.PlotTileStuds`), sin ningún asset externo.

## Política de Roblox en el intercambio

- **`PolicyGateService`:** consulta la política de cada jugador una vez al entrar (con reintentos) y la guarda. `CrateService` y `TradeService` preguntan sin esperar; sin respuesta todavía, cuenta como "no permitido".
- **`IsPaidItemTradingAllowed`:** los picos y las armas son objetos de pago (salen de cajas compradas con monedas, y las monedas se compran con Robux). Nunca se intercambian si alguno de los dos jugadores no lo tiene permitido.
- **`Trade.PolicyBlocksAllTrading = true`:** a esos jugadores se les bloquea todo el intercambio, también el de minerales. Es la opción prudente (los minerales se venden por monedas y hay boosts de pago que ayudan a conseguirlos). En `false`, solo se bloquean picos y armas.
- **Dónde se comprueba:** al pedir el intercambio, al aceptarlo, al añadir un pico o un arma a la oferta y otra vez justo antes de ejecutarlo.

## Outpost: la plaza de los NPCs

- **Motivo:** los cuatro NPCs originales estaban repartidos por el mapa y no se veían. Ahora están todos en una plaza (`Map.Hub`), fuera del anillo de bases, en el hueco 4. El decorado del mapa deja libre ese sitio.
- **Ocho NPCs.** Siete abren un menú del juego al hablar con ellos (cajas, equipamiento, intercambio, colección, misiones, recompensa diaria y mejoras); el meteorólogo solo informa. No venden nada por sí mismos ni cambian reglas: son un acceso con cara a lo que ya existe.
- **Aspecto:** figuras por código con cara (ojos, cejas, boca), pelo, botas, cinturón, hombreras y, según el NPC, lo que lleva en la cabeza, puesto y en la mano (`Config/Npcs`). Cada uno tiene su puesto; el de cajas y la fragua exponen los modelos reales de `EquipmentVisual`.
- **Teletransporte:** botones Outpost y Home en el HUD (remote `Teleport`, `VisitService`). No se puede con minerales encima, para que no sirva para escapar de un robo ni para saltarse el camino a la base; 5 s de espera entre usos.
- **Abrir menús desde fuera del HUD:** `UI/MenuBus` (el HUD se registra) y `TabbedMenu.Select` para elegir pestaña.
- **Mando:** hablar con un NPC pasa a la cruceta arriba, porque Y es ahora la habilidad del arma.

## Idiomas: español e inglés

- **Sistema propio, no LocalizationTable:** los textos son casi todos dinámicos y el jugador elige idioma en partida, distinto del de su cuenta. Tablas en código (`Locale/en`, `Locale/es`), comprobables con `tools/check-locales.luau`. Detalle en `LOCALIZATION.md`.
- **`Strings` sigue siendo la puerta de entrada:** es la tabla del idioma activo y se reescribe en el sitio al cambiar, así que el código que ya leía `Strings.X.Y` no ha cambiado.
- **El servidor no formatea textos:** manda mensajes (clave + parámetros) y marca los textos del mundo con `Locale.Tag`; cada cliente los muestra en su idioma.
- **Detección:** idioma de la cuenta de Roblox, español → `es`, cualquier otro → `en`. No se guarda. Lo elegido en Ajustes se guarda en `settings.language` y siempre gana.
- **Sin traducción automática de Roblox** en nuestras interfaces (`AutoLocalize = false`): traduciría el inglés de quien lo ha elegido a mano.
- **Títulos:** atributo nuevo `TitleId` (id del logro) para traducirlos; `Title` sigue con el texto en inglés por compatibilidad.
- **Sin cambios de reglas:** el idioma no interviene en precios, recompensas ni probabilidades. `Lune` se fija en `rokit.toml` solo para ejecutar las pruebas.

## HUD de cristal y ofertas de Robux

- **HUD:** estilo ciencia ficción limpio. Paneles de cristal oscuro con borde y línea de luz del color de cada cosa (`Components.Glass`, `Theme.Glass`). Arriba a la izquierda, una columna con monedas (y un "+" que abre la tienda en Monedas), mochila con barra y boosts activos con icono. Píldora central para el próximo meteorito. Botones laterales de cristal con franja de color y un punto rojo cuando hay recompensa diaria o misión por cobrar.
- **Opciones nuevas:** 3 pases (Minado rápido −30 % por golpe, Súper suerte ×1,5, Mega mochila +20), boost nuevo Monedas x2 (30 min y 1 h), versiones de 1 h de suerte, imán y escudo, Mega Pack y Meteorito para el servidor. Todo concreto y visible antes de pagar: nada aleatorio con Robux.
- **Pack Inicial (99 R$):** una vez por cuenta (`offers.starterPack`). Si el recibo llega otra vez (Roblox ya ha cobrado), se entrega igual. Incluye monedas (15 % del siguiente rebirth), Suerte x2 1 h, Escudo 1 h y la Estela Starter, que solo existe en este pack.
- **Sin urgencia falsa:** ni cuentas atrás inventadas ni "precio anterior". "MEJOR VALOR" es verdad: el Mega Pack (499 R$) cuesta menos que sus partes sueltas (841 R$).
- **Ofertas en pantalla:** la de bienvenida sale grande al entrar mientras no se haya comprado y al cerrarla queda minimizada en el lateral derecho. Las de esquina salen en momentos concretos (mochila llena, meteorito grande, o de vez en cuando), cada una como mucho una vez por sesión y con 4 min mínimos entre dos (`Shop.CornerOffers`).
- **Ids pendientes:** los productos nuevos están con id 0 (sale "Próximamente") hasta crearlos con `tools/create-shop-items.ps1`. En Studio las ofertas se enseñan igual para poder probarlas (`Shop.ShowUnreleasedOffersInStudio`), y `DebugService.FakeReceipt` acepta la clave del producto aunque su id sea 0.
- **Monedas x2 y los ingresos:** el boost entra en `GetIncomeMultiplier`. No cuenta para los ingresos sin conexión ni para los carteles de los pedestales, que no se repintan cuando el boost se acaba.
