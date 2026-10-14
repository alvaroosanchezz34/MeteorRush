# Meteor Rush — Lanzamiento (Fase 10)

Lista de pruebas, pasos de publicación y plan de vuelta atrás. Marca cada casilla cuando lo
hayas comprobado tú en Studio o en el juego publicado.

## 1. Antes de publicar: cambios en el código

- [x] **Tu UserId** en `src/server/Admin/AdminPermissions.luau` (`ADMIN_USER_IDS`). Si la
      experiencia es de tu cuenta ya te reconoce como creador; si es de un grupo, es obligatorio.
- [ ] **Fecha de la Temporada 1** en `src/shared/Config/LiveOps.luau` (`startsAt`). Ahora empieza
      el 1 de octubre de 2026 y dura 30 días: ponla en el día real de lanzamiento.
- [ ] **Código `SEASON1`** en `src/shared/Config/Codes.luau`: caduca el 1 de noviembre de 2026;
      muévelo con la temporada.
- [ ] **Versión y notas** en `LiveOps.Releases` (lo que ve el jugador al entrar).
- [ ] **Sonidos:** casi todos son provisionales (los que trae Roblox). La música de evento y los
      bucles ambientales están vacíos en `src/shared/Config/Sounds.luau`.
- [ ] `stylua --check src`, `selene src` y `rojo build -o MeteorRush.rbxlx` sin errores.

## 2. Pruebas

Con 1, 2, 4 y 8 jugadores (Studio → Test → Clients and Servers) y, al final, en el juego
publicado en privado. El panel de administración (F2) acelera casi todo.

### Datos
- [ ] Entrar por primera vez: perfil nuevo, pico y arma iniciales, sin errores en Output.
- [ ] Ganar monedas, colocar minerales, salir y volver a entrar: todo sigue igual.
- [ ] Reconexión rápida (salir y entrar en segundos): no se pierde ni se duplica nada.
- [ ] Entrar desde dos dispositivos a la vez: el primero es expulsado con el aviso de sesión.
- [ ] Cerrar el servidor desde el panel (Settings → Cerrar servidor): expulsa a todos y, al
      volver, los datos están. Lo que se llevaba encima se pierde, igual que al salir.

### Bucle principal
- [ ] Minar los tres tamaños de meteorito y los cinco especiales (panel → Meteorites).
- [ ] Mochila llena: aviso, y depositar en la base.
- [ ] Pedestales: colocar, quitar, "Place Best", vender y fusionar.
- [ ] Rebirth: reinicia lo que debe y da Meteor Shards; el árbol permanente se conserva.
- [ ] Misiones diarias, recompensa diaria, códigos (uno válido, uno caducado, uno repetido).

### Robo y equipamiento
- [ ] Golpear a quien lleva carga: suelta parte, queda inmune 5 s, el atacante espera su tiempo.
- [ ] No se puede golpear a un novato (10 min), ni dentro de su base, ni con escudo.
- [ ] Dos golpes seguidos a la misma víctima: el segundo suelta menos.
- [ ] Dos atacantes a la vez sobre la misma víctima: solo cuenta un golpe.
- [ ] Aturdimiento (Shock Stick): dura menos de 1 s y no se repite enseguida.
- [ ] Void Pulse: 45 s de espera, 1 mineral por jugador alcanzado, no funciona desde la base propia.
- [ ] Comprar y abrir cada caja; SKIP; duplicado → Forge Dust; el seguro salta al llegar a su número.
- [ ] Dos aperturas a la vez (doble clic rápido): solo se abre una caja.
- [ ] Equipar y quitar pico y arma; se ven en el personaje tras reaparecer.

### Social
- [ ] Intercambio completo con minerales y con un pico; cancelar a mitad; cambiar la oferta tras
      confirmar; salir del juego a mitad.
- [ ] Visitar una base, dar like (una sola vez), clasificación de bases.
- [ ] Competición y evento de principio a fin (panel → Events / Competitions).

### Política de Roblox
- [ ] Jugador con objetos aleatorios restringidos: las cajas salen como UNAVAILABLE y el servidor
      rechaza la compra aunque se dispare el remote a mano.
- [ ] Jugador sin intercambio de objetos de pago: no puede pedir ni aceptar intercambios.
- [ ] "DROP RATES" de cada caja: la lista de objetos suma 100.00%.

### Compras
- [ ] Cada game pass y cada producto en el juego publicado en privado (en Studio son de prueba).
- [ ] Comprar y salir al instante: al volver, la compra está y no se ha dado dos veces.

### Dispositivos
- [ ] Móvil (emulador de Studio y un teléfono real): botones táctiles Mine, Hit y Pulse; menús,
      apertura de cajas e intercambio legibles.
- [ ] Mando: recorrer menús, B cierra, minar con R2, golpear con X, habilidad con Y.

### Seguridad
- [ ] Con una segunda cuenta que no sea administradora: no aparece el botón ADMIN ni existe
      `AdminClient` en su PlayerGui.
- [ ] Desde la barra de comandos de ese cliente, disparar `AdminRequest`, `OpenCrate` sin cajas y
      `EquipGear` con un objeto que no tiene: no pasa nada y Output muestra el aviso `[Suspicious]`
      cuando toca.

### Rendimiento
- [ ] 8 jugadores con bases llenas de minerales raros: sin caídas de FPS en PC ni en móvil.
- [ ] Consola (F9) → Memory tras 30 minutos: la memoria del servidor no sube sin parar.
- [ ] Panel → Dashboard: FPS del servidor cerca de 60.

## 3. Publicar

1. **Ajustes de la experiencia** (Creator Dashboard):
   - [ ] Máximo de jugadores por servidor: **8**.
   - [ ] Icono, miniaturas, nombre, descripción y género.
   - [ ] Cuestionario de contenido (Maturity & Compliance). Marca **objetos aleatorios de pago**:
         las cajas se compran con monedas y las monedas se compran con Robux. El juego ya enseña
         las probabilidades y no vende esas cajas donde están restringidas.
   - [ ] Game passes y productos creados y con sus ids en `src/shared/Config/Shop.luau`.
   - [ ] Para probar el guardado en Studio: "Enable Studio Access to API Services" (Security).
         El juego publicado no lo necesita.
2. **Publicar en privado**, repetir las pruebas de Datos, Compras y Seguridad en el juego real.
3. **Hacerla pública.**
4. Guardar la versión en git: `git tag v1.0.0`.

## 4. Vuelta atrás

Si algo va mal después de publicar, de menos a más drástico:

1. **Apagar el sistema que falla, sin publicar nada.** Panel de administración → Settings →
   interruptores: `events`, `competitions`, `seasons`, `codes`, `trading`, `stealing`, `ambient`.
   Llega a todos los servidores en menos de un minuto.
2. **Volver a la versión anterior del lugar.** Creator Dashboard → la experiencia → Places →
   Version History → restaurar la versión anterior y publicarla. Después, "Restart servers for
   updates" para que los servidores abiertos pasen a esa versión.
3. **En el código:** `git checkout <etiqueta anterior>`, `rojo build` y publicar ese archivo.

Los datos de los jugadores aguantan una vuelta atrás: los campos nuevos del perfil se añaden
sin tocar los antiguos, y una versión anterior del juego simplemente no los lee.
**No cambies `Data.StoreName`**: equivale a empezar todos los jugadores de cero.

Qué mirar las primeras horas: errores `[DataStore]` y avisos `[Suspicious]` en la consola del
servidor, y las compras en el panel de ingresos de Roblox.
