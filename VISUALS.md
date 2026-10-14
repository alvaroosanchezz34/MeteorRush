# Pasada visual y de animaciones

Mejoras sobre lo que ya existía; no cambian economía, reglas ni datos guardados. No hay IDs de
animación nuevos ni recursos subidos: todo son partes, partículas y tweens creados por código.

## 1. Qué ha cambiado

| Zona | Cambio | Archivo |
| --- | --- | --- |
| Calidad | Módulo nuevo que decide el nivel de detalle (bajo/medio/alto) por dispositivo y gráficos elegidos. Reduce partículas, piezas y efectos simultáneos (18/30/40). | `src/client/UI/Quality.luau`, `Effects.luau` |
| Caída | Humo oscuro detrás de la bola de fuego (no en gráficos bajos); ascuas escaladas por calidad. | `MeteorController.luau` |
| Impacto | Nube de polvo que se queda flotando y se disipa (`Effects.Dust`). | `MeteorController.luau`, `Effects.luau` |
| Salud del meteorito | La barra baja con tween, deja un rastro blanco del daño reciente, cambia de naranja a amarillo claro según se gasta, da un salto con cada golpe y su borde se ilumina del color del meteorito. | `MeteorController.luau` |
| Minado | Chispas en rayo al golpear (`Effects.Sparks`); la barra de progreso tiene esquinas redondeadas y destella en blanco al empezar cada golpe. | `MeteorController.luau`, `Effects.luau` |
| Rotura | Polvo al desaparecer el meteorito (minado entero o por tiempo). | `MeteorController.luau` |
| Monedas | Vuelan más monedas cuanto mayor es el ingreso (4–12), con borde y brillo; el panel de estadísticas da un pequeño salto al llegar. | `Hud.luau`, `Components.Punch` |
| Depósito | Anillo verde a los pies y destellos que suben al guardar minerales. | `UIController.luau` |
| Rebirth | Además del destello: dos ondas doradas, ráfaga y rayos alrededor del personaje. | `UIController.luau` |
| Botones | Crecen un 4 % al pasar el ratón o seleccionarlos con mando (fuera de listas); vuelven a su tamaño al desactivarse; el texto largo parte en dos líneas en vez de encogerse; “en espera” muestra puntos animados. | `Components.luau`, `Theme.luau` |
| Ventanas | Entran subiendo un poco desde abajo y salen bajando, además de la escala. | `Components.luau`, `Theme.luau` |

Las rarezas y mutaciones ya tenían su propia secuencia (`DiscoveryMoment`, `MutationFxController`,
`RarityVisualController`); no se han tocado. Las cajas (`CrateOpening`) tampoco: ya tienen la
secuencia completa por rareza.

## 2. Auditoría de iluminación y rendimiento

- **Iluminación**: `Future` se mantiene. Roblox baja solo de técnica con gráficos bajos, así que no
  hace falta cambiarla. Bloom, Atmosphere y ColorCorrection se usan (AmbienceController los anima).
- **DepthOfField** estaba activo con intensidad 0: no se veía, pero costaba una pasada de
  postprocesado en cada fotograma. Ahora tiene `Enabled = false` en `default.project.json`.
- **Luces**: todas las `PointLight` de efectos tienen `Shadows = false` y viven menos de 1 s,
  salvo la de la bola de fuego, que dura lo que tarda en caer.
- **Bucles por fotograma**: NpcController, DisplayController y RarityVisualController ya cortan por
  distancia a la cámara. El HUD hace lo pesado cada 0,25 s. Ningún bucle nuevo por fotograma en
  esta pasada.
- **Partículas**: `Effects.Burst`, `Fragments`, `Sparks`, `Dust` y la ráfaga local de
  MeteorController pasan por `Quality.Count`. El humo y el polvo flotante no salen en gráficos
  bajos.
- **Pendiente si en móvil va justo**: medir con el MicroProfiler (Ctrl+F6) durante un meteorito
  gigante con 8 jugadores minando. El candidato siguiente es `RarityVisualController`, que ya tiene
  su propio límite (`RarityFx.Quality`).

## 3. Pruebas en Studio

Abrir `juego1` con `rojo serve` y probar en Play (y en Play con 2 jugadores para lo que ven los demás).

1. **Caída normal**: se ve el humo detrás de la bola de fuego; al caer queda una nube de polvo
   que se disipa en unos 2 s.
2. **Meteorito grande/gigante**: el humo y el polvo escalan con el tamaño; no hay tirones.
3. **Barra de salud**: al golpear, la barra naranja baja enseguida, el rastro blanco la sigue
   un poco después, la barra da un salto y se vuelve más amarilla. El borde brilla más cuanto
   menos le queda. Con otro jugador golpeando, también se ve.
4. **Entrar con un meteorito ya gastado**: la barra aparece directamente a su valor, sin
   animación ni rastro raro.
5. **Golpe de pico**: salen chispas en rayo hacia ti; la barra de progreso de encima destella en
   blanco y vuelve al dorado.
6. **Rotura**: al minar el último golpe hay polvo además de la ráfaga; si se agota el tiempo,
   solo polvo.
7. **Depósito**: al dejar minerales en la base, anillo verde a los pies y destellos.
8. **Monedas**: un ingreso pequeño hace volar 4 monedas; uno grande (vender mucho), hasta 12. El
   panel de arriba a la izquierda da un salto pequeño y no se descoloca.
9. **Rebirth**: destello dorado, dos ondas y columna de destellos alrededor del personaje.
10. **Botones**: al pasar el ratón crecen un poco; un botón desactivado no crece; en la tienda,
    al comprar, el botón muestra `.`, `..`, `...` y vuelve a su texto.
11. **Textos largos en español**: con el idioma en español, revisar que los botones de Rebirth,
    Tienda, Cajas, Ajustes y Misiones parten en dos líneas en vez de quedar diminutos. Cambiar a
    inglés y comprobar que siguen bien.
12. **Ventanas**: abren subiendo desde un poco más abajo y cierran bajando; abrir y cerrar
    rápido varias veces no las deja descolocadas.
13. **Mando**: seleccionar botones con el mando los agranda igual que el ratón.
14. **Gráficos bajos**: en Ajustes de Roblox, gráficos a 1–3. Al caer un meteorito no hay humo ni
    polvo flotante, y hay menos partículas, pero todo se entiende igual.
15. **Profundidad de campo**: el aspecto general es el mismo que antes (estaba a intensidad 0).
