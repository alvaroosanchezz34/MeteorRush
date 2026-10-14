# Meteor Rush — Roadmap de producción

Resumen del documento "Roadmap de producción por fases" que entregó el desarrollador el 2026-10-03, con el estado de cada punto. Es la guía de trabajo a partir de ahora.

**Regla principal:** una fase cada vez. Cada fase termina con pruebas, correcciones y una versión jugable antes de empezar la siguiente. No se marca nada como terminado si no se ha podido probar.

**Orden:** fases 0–2 (sin publicar) → 3–5 (retención) → 6–7 (contenido) → 8 (monetización) → 9 (live ops) → 10 (QA y publicación).

**Leyenda:** `[x]` hecho en código · `[~]` hecho a medias · `[ ]` pendiente. "Hecho en código" no significa probado: las pruebas en Studio las hace el desarrollador, porque Claude Code no puede ejecutar Roblox Studio.

---

## Fase 0 — Auditoría y seguridad

- [x] Revisar la estructura del proyecto
- [x] Identificar todos los remotes y validar que las recompensas se ejecutan en servidor
- [x] Revisar DataStore: monedas, inventario, pedestales, mejoras, rebirth, misiones, códigos
- [x] Configuración central (`src/shared/Config`)
- [x] Eliminar lógica duplicada y scripts temporales (no se encontró nada que quitar)
- [x] Registro de errores de guardado y acciones sospechosas (`Util/Log.luau`)

Pruebas: reiniciar el servidor minando/transportando · intentar cambiar monedas desde el cliente · entrar y salir varias veces · dos jugadores a la vez · exploits de remotes.

## Fase 1 — Core gameplay

- [x] Aviso de meteorito 10 s antes
- [x] Feedback al golpear: sonido, partículas, texto del mineral y barra de progreso
- [x] Feedback visual al llenar la mochila (contador en rojo y flecha a la base parpadeando)
- [x] Efecto de transporte y penalización de velocidad (minerales en la espalda y porcentaje de freno en el HUD)
- [x] Indicador de distancia a la base (flecha y distancia al llevar minerales; baliza propia en verde)
- [x] Zona de seguridad en la base (aviso SAFE ZONE en el HUD)
- [x] Feedback al colocar minerales (aparece creciendo, con destello y sonido)
- [x] Panel de ingresos por segundo
- [x] Guardado de minerales colocados y producción offline
- [x] Tutorial de 3 pasos

Pruebas: 8 jugadores minando · dos jugadores llegan a una base a la vez · desconexión con mochila llena · meteorito que desaparece mientras se mina · producción offline.

## Fase 2 — Economía y progresión

- [x] 8 minerales con valor y frecuencia por rareza
- [x] Mutaciones: Dorado x2, Radiactivo x5, Arcoíris x15
- [x] 9 mejoras
- [x] Vender, fusionar 3 iguales y colocar los mejores
- [x] Sinks de monedas (mejoras, refinería hasta el nivel 40, coste de fusión y rebirth)
- [x] Panel de estadísticas económicas para pruebas (botón `$ stats`, solo en Studio)
- [x] Simulación de 1 h, 5 h, 10 h y 30 h de progreso (`DebugService.SimulateEconomy`)
- [x] Ajuste de equilibrio a partir de la simulación (rarezas altas, coste de rebirth)

Pruebas: simular 1 h, 5 h, 10 h y 30 h · ninguna mejora rompe el equilibrio · el mejor mineral no sale demasiado pronto · vender no invalida colocar · fusionar no crea duplicados.

## Fase 3 — Colección y retención

- [x] MeteorDex: 8 minerales x 4 variantes = 32 combinaciones
- [x] Recompensa por completar filas
- [x] Animación de NUEVO DESCUBRIMIENTO (aviso grande con el mineral girando)
- [x] Logros (29, con recompensa automática y única)
- [x] Títulos equipables (15; se ven sobre la cabeza y en el cartel de la base)
- [x] Racha diaria de 7 días
- [x] 5 misiones diarias
- [x] Misiones secretas y logros ocultos (6 logros que aparecen como "???")
- [x] Perfil con estadísticas (pestaña de la ventana Collection)

Pruebas: descubrir un mineral por primera vez · completar una fila · cobrar una recompensa y reconectar · completar las 5 misiones · romper la racha · desbloquear un logro y reconectar · equipar y quitar un título.

## Fase 4 — PvP y juego social

- [x] Robo con pérdida parcial configurable, cooldown, protección en la base y de novatos
- [x] Feedback visual del robo (chispas y "-N" sobre la víctima, destello rojo, sacudida, campo de fuerza y minerales en el suelo)
- [x] Intercambio con doble confirmación, atómico, que bloquea objetos no válidos
- [x] Eventos competitivos de servidor (4 competiciones de 3 minutos que se turnan)
- [x] Bonus por jugar con amigos (+10 % de ingresos por amigo, hasta +30 %)

Pruebas: robar con 2 jugadores · robar dentro de la base · robar a un novato · intercambiar · cancelar el intercambio en cada paso · desconectarse durante un intercambio · datos manipulados desde el cliente · competición con 2 jugadores · bonus de amigos con un amigo real.

## Fase 5 — Rebirth y meta-progresión

- [x] Rebirth con +50 % de ingresos permanente
- [x] Pantalla de confirmación en dos pasos: qué se pierde, qué se conserva y qué se gana
- [x] Moneda permanente: Meteor Shards (5 el primer rebirth y 2 más cada uno de los siguientes)
- [x] Árbol de mejoras permanentes (7 nodos, pestaña Shard Tree de la ventana Rebirth)
- [x] Desbloqueos ligados al número de rebirths (3 nodos del árbol y 3 cosméticos gratis)
- [x] Estadísticas de rebirth (rebirths, shards, duración del actual y el más rápido)

Pruebas: rebirth sin monedas suficientes · rebirth válido · reconectar después · comprar una mejora permanente · comprobar que el +50 % se aplica una sola vez.

## Fase 6 — Bases y personalización

- [x] Color de base
- [x] Decoraciones desbloqueables (9, en 6 huecos fijos por base)
- [x] Pedestales con mejor presentación
- [x] Área de exposición de colección (panel con las 32 combinaciones en el muro del fondo)
- [x] Nombre y título del propietario en el cartel
- [x] Efectos de partículas y luces desbloqueables (6 efectos de base)
- [x] Cosméticos de pico, estela y base
- [x] Vista de colección (índice propio y panel de la base, visible para todos)
- [x] Visitar o inspeccionar bases (pestaña Players: resumen de cada jugador y botón de visita)

Pruebas: equipar y quitar cosméticos · guardar la personalización · reiniciar el servidor y comprobar que sigue · 8 bases personalizadas a la vez.

## Fase 7 — Eventos y contenido

- [x] Framework de eventos (`EventService`: anuncio, cuenta atrás, inicio, duración, UI, recompensas y fin)
- [x] Meteoritos Dorado, Corrupto, Negro, Arcoíris y Alienígena (solo caen en eventos)
- [x] Evento Lluvia de Meteoritos
- [x] Evento Supernova
- [x] Anuncios globales con cuenta atrás (aviso, contador en el HUD y aviso grande al empezar)
- [x] Recompensas por participar, cooldowns por evento y calendario configurable (`Config/Events.luau`)

Pruebas: cada evento empieza y termina limpio · todos ven el mismo estado · desconexión durante un evento · 8 jugadores en un evento · las recompensas no se duplican.

## Fase 8 — Monetización

- [x] 5 game passes, 3 boosts, cosméticos y paquetes de monedas
- [x] Comprobación de passes en servidor
- [x] Entrega segura de consumibles (idempotente y confirmada solo cuando el perfil está guardado)
- [x] Sin compras aleatorias: todo lo que se paga con Robux es concreto y se ve antes de pagar
- [x] Ampliación: 3 pases, boosts de 1 h, Monedas x2, Pack Inicial (oferta de bienvenida), Mega Pack, Meteorito para el servidor y ofertas en pantalla (ver DECISIONS.md). Falta crear sus ids en Roblox

Pruebas: comprar cada pass y comprobar su efecto · comprar un consumible y reconectar · procesar una compra repetida · servidor caído durante una compra · comprobar que no hay compras de resultado incierto · comprobar que no se pueden duplicar monedas.

## Fase 9 — Live Ops

- [x] Temporadas de 30 días con temática, misiones, recompensas y cosméticos temporales (`Config/LiveOps.luau`)
- [x] Códigos canjeables con caducidad
- [x] Calendario de eventos (citas semanales a hora fija, iguales en todos los servidores)
- [x] Panel de configuración para activar y desactivar contenido en caliente (solo administradores)
- [x] Anuncios de actualización y registro de versión

Pruebas: activar y desactivar una temporada · caducidad de un código · canjear un código dos veces · cambio de temporada · jugador que vuelve después de varios días · el contenido temporal no rompe datos antiguos.

## Fase 10 — QA, optimización y lanzamiento

- [ ] Pruebas con 1, 2, 4 y 8 jugadores, móvil, reconexión, DataStore, robos, intercambios y compras
- [ ] Rendimiento y memoria; quitar prints de depuración
- [ ] Máximo de 8 jugadores, icono, miniatura, metadatos y cuestionario de contenido
- [ ] Publicar en privado, pruebas finales, hacerla pública; checklist de lanzamiento y plan de rollback

Preparado en código: lista de pruebas, pasos de publicación y plan de vuelta atrás en `LAUNCH.md`; los `print` que quedan son solo de Studio o del registro de administración. Las casillas se marcan cuando el desarrollador lo pruebe y publique.
