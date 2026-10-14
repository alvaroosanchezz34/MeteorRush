# Meteor Rush — Idiomas (español e inglés)

El juego se publicó en inglés. Ahora se ve entero en **español** o en **inglés**, se puede cambiar en partida desde **Ajustes (⚙)** y la elección se guarda. El idioma **solo cambia lo que se ve**: ninguna regla, precio, recompensa o probabilidad depende de él.

---

## 1. Arquitectura

```
src/shared/Locale/init.luau   módulo Locale (todo lo de idiomas)
src/shared/Locale/en.luau     textos en inglés (original y respaldo)
src/shared/Locale/es.luau     textos en español (mismas claves)
src/shared/Strings.luau       textos del idioma activo (= Locale.Active)
src/server/Services/LanguageService.luau      idioma de cada jugador y su guardado
src/client/Controllers/LanguageController.luau   idioma en el cliente y textos del mundo
src/client/UI/SettingsMenu.luau               ventana de Ajustes con el selector
tools/check-locales.luau                      comprobación y pruebas (Lune)
```

### Por qué un sistema propio y no LocalizationTable

Se evaluó la localización nativa de Roblox (`LocalizationService`, `LocalizationTable`, `Translator`). No se usa porque:

- Casi todos los textos son dinámicos (`string.format` con números, nombres, minerales). La traducción automática de Roblox solo encaja textos fijos; con parámetros habría que usar `Translator:FormatByKey` en cada sitio igualmente.
- El jugador elige idioma en partida y debe cambiar al momento, aunque su cuenta de Roblox esté en otro idioma. La traducción nativa sigue el idioma de la cuenta.
- Las tablas viven en el código (Rojo, Git, revisables y comprobables con `tools/check-locales.luau`), no en la nube ni en un archivo binario de Studio.

Para que Roblox no traduzca encima de nuestros textos (por ejemplo, el inglés de alguien que tiene la cuenta en español pero ha elegido inglés), todas nuestras `ScreenGui`, `BillboardGui` y `SurfaceGui` llevan `AutoLocalize = false`, y también los textos del mundo localizados.

> **Recomendación en el Creator Dashboard:** si la experiencia tiene activada la *traducción automática*, no hace falta desactivarla (nuestras interfaces ya la ignoran), pero las traducciones automáticas que ya existan para español no se usarán.

### Cómo funciona

| Dónde | Qué hace |
|---|---|
| **Tablas** (`Locale/en`, `Locale/es`) | Mismas claves. Lo que falte en español sale en inglés. |
| **`Strings`** | Es `Locale.Active`: en el cliente, los textos del idioma elegido; en el servidor, siempre inglés. Al cambiar de idioma se reescribe **en el sitio**, así que todo el código que lee `Strings.X.Y` al pintar ya sale traducido sin cambios. |
| **Textos que se pintan una vez** | Se pasan como función a `Components` (`text = function() return Strings.X end`), que los enlaza con `Locale.Bind` y los repinta al cambiar de idioma. |
| **Ventanas** | Una ventana abierta se repinta (vuelve a llamar a sus `OnOpened`) al cambiar de idioma. Las cerradas se pintan al abrirse. |
| **Avisos del servidor** | El servidor ya no manda texto en inglés: manda un mensaje `Locale.Msg("Clave", parámetros...)`. Cada cliente lo traduce a su idioma (`NotificationController`). Un aviso a todo el servidor sale a cada jugador en el suyo. |
| **Textos del mundo** (carteles de parcela, NPC, pedestales, clasificaciones, títulos, ProximityPrompt) | El servidor los marca con `Locale.Tag(instancia, "Text", mensaje)`: guarda el mensaje en un atributo `L10n_Text` y deja el inglés como texto. `LanguageController` los pinta en el idioma de cada jugador y los repinta al cambiar. |
| **Expulsiones** (`Kick`) | En el idioma del jugador (`Locale.GetText(clave, Locale.GetCurrentLanguage(player))`). |

### Interfaz del módulo `Locale`

| Función | Para qué |
|---|---|
| `GetText(key, language?, params?)` | Texto de una clave (`"Upgrades.Bought"`) con sus parámetros. Clave inexistente → devuelve la clave; parámetros que faltan o de otro tipo → hueco vacío, nunca un error. |
| `GetCurrentLanguage(player?)` | Cliente: idioma que se ve. Servidor: idioma de ese jugador. |
| `SetCurrent(language)` | (Cliente) cambia el idioma mostrado. Para el jugador, `LanguageController.SetLanguage(language)`, que además lo guarda. |
| `FormatNumber(value, language?)` | `1.2K` / `1,2K`. `Format.Number` lo usa, así que todos los contadores siguen el idioma. |
| `FormatCurrency(value, language?)` | `$1.2K` / `$1,2K`. |
| `FormatDecimal(value, decimals, language?)` | `1.25` / `1,25`. |
| `MineralName(mineral, mutation, language?)` | `Golden Plasma Core` / `Núcleo de Plasma Dorado` (con concordancia: `Roca Espacial Dorada`). |
| `Upper(text)` | Mayúsculas que respetan tildes y ñ (`string.upper` deja `COLECCIóN`). También `Strings.Upper`. |
| `Msg`, `Ref`, `Num`, `Dur`, `Mineral`, `Join`, `UpperMsg` | Construyen mensajes para enviar desde el servidor. |
| `Resolve(message, language?)` | Texto de un mensaje. |
| `Tag(instance, property, message)` | Marca un texto del mundo como localizado (servidor). |
| `OnChanged(callback)` / `Bind(instance, property, getter)` | Repintar al cambiar de idioma. `Bind` se desconecta solo al destruir la instancia. |

### Detección y guardado

- **Primera vez:** el idioma de la cuenta de Roblox (`Player.LocaleId`, y si no `LocalizationService.RobloxLocaleId` / `SystemLocaleId`). `es-*` → español; **cualquier otro idioma → inglés**. No se guarda: si el jugador cambia el idioma de su cuenta, el juego lo sigue.
- **Elección en Ajustes:** se guarda en el perfil (`settings.language = "es"` o `"en"`) y gana siempre a lo detectado. La última elección es la que vale.
- **Servidor:** `LanguageService` valida el idioma (solo `es` / `en`), limita las peticiones (`Network.RateLimits.SetLanguage`), registra valores raros como sospechosos y publica el idioma efectivo en el atributo `Language` del jugador.
- **Datos existentes:** el campo `settings` es nuevo y lo añade `Reconcile` al cargar (`settings.language = ""` = automático). No se ha cambiado el nombre del almacén, ninguna clave existente ni ningún remote existente. Remote nuevo: `SetLanguage`.

### Qué no se traduce (a propósito)

- El nombre del juego, "VIP", "R$", "studs" y los ids internos (atributos, remotes, claves de guardado, nombres de instancias).
- Nombres de jugador y anuncios de administración (texto libre filtrado).
- El panel de administración y el panel de economía de Studio: son herramientas internas y ya estaban en español.

---

## 2. Textos traducidos

Todo lo que estaba en `Strings.luau` (unos 900 textos) más los que había sueltos en `Config/LiveOps` (nombre y misiones de la temporada, notas de versión), ahora en `Strings.Seasons` y `Strings.Releases`:

menús y pestañas · botones · HUD · tutorial · misiones diarias y de temporada · avisos de éxito y error · inventario, pedestales, venta y fusión · equipamiento, rasgos y estadísticas · minerales, rarezas y mutaciones · mejoras y árbol de fragmentos · rebirth (renacer) y su confirmación · cajas, probabilidades y garantía · robos, golpes y habilidades · intercambio · tienda, pases, boosts y cosméticos · logros, títulos y perfil · clasificación y mejores bases · visitas y "me gusta" · eventos, competiciones y fenómenos del cielo · NPC (nombres, carteles, frases) · códigos · expulsiones y errores de datos · ajustes.

Términos elegidos: Rebirth → **Renacer**, Meteor Shards → **Fragmentos de Meteorito**, Forge Dust → **Polvo de Forja**, Outpost → **Campamento**, Index → **Índice**, SP → **PT** (puntos de temporada), Boosts → **Potenciadores**.

---

## 3. Añadir un idioma (p. ej. portugués)

1. Copia `src/shared/Locale/es.luau` como `pt.luau` y traduce los textos. **No cambies las claves** y deja los `%s` / `%d` en el mismo orden (si una frase necesita otro orden, reescríbela para que encaje).
2. En `src/shared/Locale/init.luau`: añade `pt = require(script.pt)` a `tables`, `"pt"` a `Locale.Languages`, su nombre a `Locale.LanguageNames` (`"Português 🇧🇷"`) y su separador decimal a `DECIMAL`.
3. Si el orden de "mutación + mineral" cambia, ajusta `MineralNameFormat`; si hay género, `MineralGenders` y `MutationsFeminine` (mira `es.luau`).
4. En `tools/check-locales.luau`, carga el idioma nuevo y añade su comparación (igual que `es`).
5. Ejecuta `lune run tools/check-locales.luau`. Detecta claves mal escritas, parámetros cambiados y textos sin traducir.

La detección ya funciona sola: `Locale.FromLocaleId("pt-br")` devuelve `pt` en cuanto el idioma está en `tables`. El selector de Ajustes muestra un botón por idioma de `Locale.Languages` (con más de dos, ajusta el ancho de los botones en `SettingsMenu`).

### Añadir un texto nuevo

1. Añádelo a `en.luau` y `es.luau` con la misma clave.
2. En el cliente, léelo de `Strings` al pintar. Si se pinta una sola vez, pásalo como función a `Components`.
3. En el servidor, nunca lo mandes formateado: `Remotes.Notify:FireClient(player, Locale.Msg("Clave", ...))`. Para números `Locale.Num(n)`, tiempos `Locale.Dur(s)`, minerales `Locale.Mineral(id, mutacion)`, otros textos `Locale.Ref("Clave")`.
4. Texto en el mundo creado por el servidor: `Locale.Tag(label, "Text", Locale.Msg("Clave", ...))`.
5. Temporada o versión nuevas en `Config/LiveOps`: añade sus textos a `Seasons` / `Releases` en los dos idiomas.

---

## 4. Pruebas

### Ejecutadas (sin Studio)

| Prueba | Resultado |
|---|---|
| `lune run tools/check-locales.luau`: todas las claves de `es` existen en `en`, mismos parámetros, nada sin traducir | Correcto |
| Detección: `es-es`, `es-mx` → es; `en-us` → en; `pt-br`, vacío → en; idioma no soportado → en | Correcto |
| Clave inexistente, parámetros que faltan o de otro tipo, idioma inexistente | Correcto (no rompe) |
| Números `1,2K`, `-2,5M`, `$1,5K`, NaN; mayúsculas con tildes | Correcto |
| Nombres de mineral con concordancia; mensajes anidados del servidor | Correcto |
| Cambio en caliente: referencias guardadas, listas de frases, claves solo-español, dejar de escuchar | Correcto |
| `rojo build` | Correcto |
| `selene src` (0 errores, 0 avisos) y `stylua --check` | Correcto |

### Pendientes en Studio (no se han ejecutado)

Abre el lugar con Rojo (`rojo serve`, plugin conectado) en un **lugar de pruebas**, no en la experiencia publicada.

1. **Primer inicio en español:** *Test → Player Emulator*, idioma `es-es`. Play. HUD, tutorial y carteles en español. (Si el emulador no cambia el idioma que detecta el juego, comprueba en la consola del cliente `game.Players.LocalPlayer.LocaleId` y `game:GetService("LocalizationService").RobloxLocaleId`; la detección lee esos valores en ese orden.)
2. **Inglés y otro idioma:** emulador en `en-us` y en `pt-br` → inglés.
3. **Cambio manual:** ⚙ → *English 🇬🇧*: todo cambia sin reiniciar (HUD, botones laterales, ventana abierta, carteles de NPC, parcelas, pedestales, clasificación, botones táctiles en modo móvil). Volver a español.
4. **Persistencia:** elegir inglés con el emulador en `es-es`, salir y volver a entrar → sigue en inglés. (En Studio con *Enable Studio Access to API Services* activado; si no, los datos no se guardan.)
5. **Reabrir menús** tras cambiar: cada pestaña de Base, Colección, Misiones y Renacer.
6. **Avisos dinámicos:** minar (mochila llena), depositar, vender, fusionar, comprar mejora, reclamar diario, canjear código inválido, golpear a otro jugador.
7. **Dos jugadores** (*Test → Clients and Servers*, 2 jugadores) con idiomas distintos: un aviso global (meteorito, evento, competición) llega a cada uno en el suyo; los carteles del mundo se ven distintos en cada cliente.
8. **Textos largos:** móvil (emulador de teléfono): botones laterales, pestañas, confirmación de renacer y descripciones de la tienda se leen sin cortarse.
9. **Sin mezclas:** recorrer todos los menús en español buscando textos en inglés.
10. **Reglas intactas:** mismos precios, recompensas y probabilidades en los dos idiomas.

---

## 5. Limitaciones conocidas

- Un aviso que ya está en pantalla al cambiar de idioma termina en el idioma anterior (dura 3 s).
- El diálogo de confirmación de renacer se cierra al cambiar de idioma, en vez de traducirse con él abierto.
- Los nombres de los tableros de la clasificación global son nombres de usuario (no se traducen).
- Las abreviaturas K/M/B se mantienen en español, como es habitual en los juegos de Roblox.
- Las temporadas o versiones nuevas de `Config/LiveOps` sin textos en `Seasons` / `Releases` muestran la clave (misiones) o el texto de la configuración (notas).
