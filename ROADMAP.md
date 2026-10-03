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
- [~] Sinks de monedas (mejoras y rebirth; nada más)
- [ ] Panel de estadísticas económicas para pruebas
- [ ] Simulación de 1 h, 5 h, 10 h y 30 h de progreso

## Fase 3 — Colección y retención

- [x] MeteorDex: 8 minerales x 4 variantes = 32 combinaciones
- [x] Recompensa por completar filas
- [ ] Animación de NUEVO DESCUBRIMIENTO (ahora es un aviso de texto)
- [ ] Logros
- [ ] Títulos equipables
- [x] Racha diaria de 7 días
- [x] 5 misiones diarias
- [ ] Misiones secretas y logros ocultos
- [ ] Perfil con estadísticas

## Fase 4 — PvP y juego social

- [x] Robo con pérdida parcial configurable, cooldown, protección en la base y de novatos
- [~] Feedback visual del robo (campo de fuerza y minerales en el suelo)
- [x] Intercambio con doble confirmación, atómico, que bloquea objetos no válidos
- [ ] Eventos competitivos de servidor
- [ ] Bonus por jugar con amigos

## Fase 5 — Rebirth y meta-progresión

- [x] Rebirth con +50 % de ingresos permanente
- [~] Pantalla de confirmación de qué se pierde y qué se conserva (hay texto, no confirmación en dos pasos)
- [ ] Moneda permanente: Meteor Shards
- [ ] Árbol de mejoras permanentes
- [ ] Desbloqueos ligados al número de rebirths
- [ ] Estadísticas de rebirth

## Fase 6 — Bases y personalización

- [x] Color de base
- [ ] Decoraciones desbloqueables
- [x] Pedestales con mejor presentación
- [ ] Área de exposición de colección
- [~] Nombre del propietario (falta el título)
- [ ] Efectos de partículas y luces desbloqueables
- [x] Cosméticos de pico, estela y base
- [~] Vista de colección (el índice)
- [ ] Visitar o inspeccionar bases

## Fase 7 — Eventos y contenido

- [ ] Framework de eventos (inicio, duración, estado, UI, recompensas, fin)
- [ ] Meteoritos Dorado, Corrupto, Negro, Arcoíris y Alienígena
- [ ] Evento Lluvia de Meteoritos
- [ ] Evento Supernova
- [~] Anuncios globales con cuenta atrás (existen para el meteorito gigante)
- [ ] Recompensas especiales, cooldowns y calendario configurable

## Fase 8 — Monetización

- [x] 5 game passes, 3 boosts, cosméticos y paquetes de monedas
- [x] Comprobación de passes en servidor
- [~] Entrega segura de consumibles (idempotente, pero confirma la compra antes de que se guarde el perfil)

## Fase 9 — Live Ops

- [ ] Temporadas de 30 días con temática, misiones y cosméticos temporales
- [~] Códigos canjeables (existen; falta la caducidad)
- [ ] Calendario de eventos
- [ ] Panel de configuración para activar y desactivar contenido
- [ ] Anuncios de actualización y registro de versión

## Fase 10 — QA, optimización y lanzamiento

- [ ] Pruebas con 1, 2, 4 y 8 jugadores, móvil, reconexión, DataStore, robos, intercambios y compras
- [ ] Rendimiento y memoria; quitar prints de depuración
- [ ] Máximo de 8 jugadores, icono, miniatura, metadatos y cuestionario de contenido
- [ ] Publicar en privado, pruebas finales, hacerla pública; checklist de lanzamiento y plan de rollback
