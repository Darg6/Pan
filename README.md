# Pan

RPG 2D top-down de captura de criaturas por turnos, en pixel art (Godot 4.3, renderer Compatibility).

## Cómo probarlo

1. Abre Godot 4.3, pulsa **Importar** y elige el archivo `project.godot` de esta carpeta.
2. Pulsa **F5** (o el botón ▶ arriba a la derecha).
3. La intro se puede saltar con el botón **Saltar**.

**Controles**
- PC: **WASD** o **flechas** para mover a Pan. **E**, **Espacio** o **Enter** para hablar,
  tocar objetos y avanzar los diálogos.
- Celular: toca y arrastra en la mitad izquierda para mover. El botón **A** interactúa y el
  botón de la mochila abre tu inventario. Toca la pantalla para avanzar los diálogos.
- En combate, tocar la pantalla adelanta los mensajes.

## Si algo no carga (pantalla negra o mensaje de error)

Cierra Godot, borra la carpeta `.godot` dentro del proyecto (es solo caché; en Windows activa
*Vista > Elementos ocultos* si no la ves), abre Godot de nuevo, espera a que termine la barra de
importación y pulsa F5. Al iniciar, el juego hace un **autodiagnóstico** y te dice en pantalla qué falla.

## Exportar para celular y navegador

El juego está pensado para **celular (Android)** y **navegador (Web)**: todo se controla tocando.
Ya están configurados los dos en *Proyecto > Exportar*.

1. La primera vez: *Editor > Administrar plantillas de exportación > Descargar e instalar*.
2. **Web**: en *Proyecto > Exportar* elige "Web" y pulsa *Exportar proyecto*. Se crea `exportar/web/`.
   Sube esa carpeta a itch.io (como juego HTML) o pruébala con el botón ▶ de Web arriba a la derecha
   del editor ("Ejecutar en el navegador").
3. **Android**: necesitas el SDK de Android y Java (Godot te dice qué falta en *Editor > Configuración
   del editor > Exportar > Android*). Luego elige "Android" y exporta el `.apk`.

La exportación Web no usa hilos (*thread support* apagado), así funciona en itch.io y en celulares
sin configuración especial del servidor.

## Menú principal y partida guardada

Al abrir el juego aparece el **menú principal**:

- **Continuar**: solo aparece si hay una partida guardada. Muestra dónde estabas, tus cartas,
  monedas y tiempo jugado, y te lleva justo a ese lugar.
- **Nueva partida**: empieza desde la intro. Si ya tenías una partida, pregunta antes de borrarla.

La partida se guarda **sola** al entrar a cada lugar, al dormir y al minimizar o cerrar el juego.
También puedes guardar cuando quieras con el botón **Guardar** de la Mochila, y volver al menú con
**Menú principal** (guarda antes de salir). En el celular y en el navegador funciona igual: se
guarda en la memoria del juego (`user://partida.json`).

El nombre que se ve en el menú y en la pantalla de título está en `scripts/juego.gd`:
`NOMBRE_JUEGO` y `SUBTITULO_JUEGO`.

## La historia que ya se puede jugar (prólogo)

1. **El Recuerdo**: la intro con Diego, Danitza y Pan, la Organización, la rejilla y la promesa.
2. **El Despertar** en el Refugio Cero: tomar la mochila, revisar la mesa de papá (cartas y
   granada) y ponerse el collar. Después, salir por la escalera.
3. **El Encuentro**: el Gato Mutado atrapado bajo la viga (tutorial: granada y captura).
4. **La Prueba de Fuego**: el Recluta de Chatarra y su Oso de Escoria.
5. **Consecuencias**: volver a dormir al refugio, que después se sella para siempre.
6. **Título**: el acantilado, la pantalla "PAN" y la misión de llegar a Bastión de Óxido.

Después puedes explorar el páramo, saquear chatarra, capturar criaturas en el pasto seco y
llegar a las afueras de Bastión (campamento, cartel, ciudadano y portón).

## Ciudad 1: Bastión de Óxido (Comandante Rictus)

Entra por el portón de contenedores (al noreste de la Superficie).

- **Llegada**: Rictus patea el balde de agua de Odila y te reta a subir al puerto.
- **Tienda de Mila**: compra (precios fijos), vende Reliquias y partes de criaturas, y vende
  cartas repetidas en el Mercado de Bestias. La mochila tiene límites (10 curas de cada tipo,
  5 comidas, 3 potenciadores de cada tipo).
- **Posada de Odila**: duerme para reparar tus cartas (5 monedas, o gratis si ayudas a Lía).
- **Misiones secundarias**: *El agua de Lía* (lleva 3 Reliquias a Odila) y *Herramientas de
  Bruno* (espanta a las Aves Negras de la grúa, en las dunas del este).
- **Cosas para investigar**: trituradora, tanque de agua, tablón, estatua, mural, radio, cinta
  transportadora y el buque "Esperanza". Cambian después de liberar la ciudad.
- **Tormentas de óxido**: cada tanto el cielo se pone naranja. Caminas más lento, salen más
  criaturas (el Enjambre Mecánico solo en tormenta) y en combate las bestias que no son de
  chatarra pierden vida y fallan más.
- **Criaturas nuevas**: Enjambre Mecánico (vertedero), Bailarina Eléctrica y Gusano Devorador
  (dunas) y el Titán de Chatarra de Rictus.
- **Jefe**: dos reclutas en la Avenida del Impuesto y Rictus en su trono. Su Grito de Guerra
  cura a sus bestias cada 3 turnos.
- **Al salvar la ciudad** la gente te aplaude en la plaza y te da fuerzas: +10% de ataque para
  siempre en todas tus criaturas.

## Dónde cambiar cada cosa

| Quiero cambiar...            | Archivo |
|------------------------------|---------|
| El nombre del juego          | `NOMBRE_JUEGO` y `SUBTITULO_JUEGO` en `scripts/juego.gd` |
| El menú principal            | `scripts/menu.gd` (fondo, botones y textos) |
| Los textos y diálogos        | `datos/dialogos.json` |
| Las imágenes de la intro     | `arte/cinematica/` (cada frase de la intro elige su imagen con `"imagen"` en `datos/dialogos.json`) |
| Qué pasa en cada evento      | `scripts/historia.gd` |
| Criaturas, ataques y stats   | `datos/criaturas.json` |
| Los mapas                    | `escenas/mapas/*.tscn` (ábrelos y pinta con el editor de TileMap) |
| El arte                      | `arte/` (reemplaza un PNG por el tuyo con el **mismo nombre y tamaño**) |
| Botones, paneles y letra     | `arte/tema.tres` y `arte/interfaz/` |
| Música y sonidos             | `audio/` (reemplaza un .ogg por el tuyo con el **mismo nombre**) |
| Música/clima de cada mapa    | `AMBIENTACION` al inicio de `scripts/mapa.gd` (música, viento, color de luz, ceniza) |
| Duración de las tormentas    | `CLIMA_CALMA` y `CLIMA_TORMENTA` en `scripts/mapa.gd` (segundos) |
| Precios y límites de objetos | `OBJETOS` al inicio de `scripts/juego.gd` |
| Lo que vende cada tienda     | `SURTIDO` en `scripts/tienda_ui.gd` |
| Las construcciones grandes   | Nodos con `scripts/decorado.gd` en `Entidades` (imagen, choque, humo, animación) |

Para probar sin repetir la intro, pon `SALTAR_PROLOGO = true` en `scripts/juego.gd`.

## Carpetas

| Carpeta              | Qué contiene |
|----------------------|--------------|
| `escenas/`           | `menu.tscn` (menú principal), `intro.tscn`, `titulo.tscn`, `combate.tscn`, `pan.tscn` |
| `escenas/mapas/`     | `refugio_cero.tscn`, `superficie.tscn` y `bastion_oxido.tscn` |
| `escenas/ui/`        | HUD, caja de diálogo |
| `scripts/`           | Código. `juego.gd` = estado (mochila, cartas, flags); `historia.gd` = la historia |
| `datos/`             | `dialogos.json` y `criaturas.json` |
| `arte/tiles/`        | Texturas de los mapas (16x16 por tile) |
| `arte/criaturas/`    | Criaturas para el combate (64x64, mirando a la derecha, patas en la fila 60) |
| `arte/personajes/`   | Pan y los personajes en el mapa y en combate |
| `arte/retratos/`     | Caras que salen en los diálogos (48x48, también las de los 6 comandantes) |
| `arte/conceptos/`    | Hojas de diseño de Pan, Diego y Danitza (no se usan en el juego, son de referencia) |
| `arte/cinematica/`   | Imágenes de la intro |
| `arte/fondos/`       | Fondos de combate por capas (cielo, nubes, montañas, ruinas, suelo). Cada zona de encuentro elige el suyo con `fondo` (paramo, pastizal, chatarra, dunas, bastion) |
| `arte/efectos/`      | Sombra, chispa de golpe y polvo del combate |
| `arte/shaders/`      | Shader de los luchadores (destello al recibir golpes y respiración) |
| `arte/interfaz/`     | Paneles, botones y joystick |
| `arte/objetos/`      | Mochila, cartas, collar, iconos de la tienda, etc. |
| `arte/decorados/`    | Construcciones grandes de Bastión (trituradora, buque, grúa, tienda, posada, trono...) |
| `arte/fuentes/`      | Letras pixel |
| `audio/musica/`      | Música (recuerdo = intro, paramo = exploración, combate, bastion = ciudad 1, jefe = comandantes) |
| `audio/ambiente/`    | Sonidos de fondo en bucle (viento, búnker, ciudad, tormenta) |
| `audio/sfx/`         | Efectos (golpes, captura, botones, voz de los diálogos...) |
| `herramientas/`      | Scripts que generaron el arte y los mapas (solo para regenerarlos desde cero). El arte de Bastión está en `arte_bastion.py` |

**Ojo:** si vuelves a correr las herramientas, sobrescriben el arte y los mapas. Si ya
editaste algo a mano en Godot, no las uses.

## Créditos

- Letras: **Pixelify Sans** y **Press Start 2P**, licencia SIL Open Font License
  (ver `arte/fuentes/`).
