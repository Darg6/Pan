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

## Dónde cambiar cada cosa

| Quiero cambiar...            | Archivo |
|------------------------------|---------|
| Los textos y diálogos        | `datos/dialogos.json` |
| Las imágenes de la intro     | `arte/cinematica/` (cada frase de la intro elige su imagen con `"imagen"` en `datos/dialogos.json`) |
| Qué pasa en cada evento      | `scripts/historia.gd` |
| Criaturas, ataques y stats   | `datos/criaturas.json` |
| Los mapas                    | `escenas/mapas/*.tscn` (ábrelos y pinta con el editor de TileMap) |
| El arte                      | `arte/` (reemplaza un PNG por el tuyo con el **mismo nombre y tamaño**) |
| Botones, paneles y letra     | `arte/tema.tres` y `arte/interfaz/` |
| Música y sonidos             | `audio/` (reemplaza un .ogg por el tuyo con el **mismo nombre**) |
| Música/clima de cada mapa    | `AMBIENTACION` al inicio de `scripts/mapa.gd` (música, viento, color de luz, ceniza) |

Para probar sin repetir la intro, pon `SALTAR_PROLOGO = true` en `scripts/juego.gd`.

## Carpetas

| Carpeta              | Qué contiene |
|----------------------|--------------|
| `escenas/`           | `intro.tscn`, `titulo.tscn`, `combate.tscn`, `pan.tscn` |
| `escenas/mapas/`     | `refugio_cero.tscn` y `superficie.tscn` |
| `escenas/ui/`        | HUD, caja de diálogo |
| `scripts/`           | Código. `juego.gd` = estado (mochila, cartas, flags); `historia.gd` = la historia |
| `datos/`             | `dialogos.json` y `criaturas.json` |
| `arte/tiles/`        | Texturas de los mapas (16x16 por tile) |
| `arte/criaturas/`    | Criaturas para el combate (64x64, mirando a la derecha, patas en la fila 60) |
| `arte/personajes/`   | Pan y los personajes en el mapa y en combate |
| `arte/retratos/`     | Caras que salen en los diálogos |
| `arte/cinematica/`   | Imágenes de la intro |
| `arte/fondos/`       | Fondos de combate |
| `arte/efectos/`      | Sombra, chispa de golpe y polvo del combate |
| `arte/shaders/`      | Shader de los luchadores (destello al recibir golpes y respiración) |
| `arte/interfaz/`     | Paneles, botones y joystick |
| `arte/objetos/`      | Mochila, cartas, collar, etc. |
| `arte/fuentes/`      | Letras pixel |
| `audio/musica/`      | Música (recuerdo = intro, paramo = exploración, combate) |
| `audio/ambiente/`    | Sonidos de fondo en bucle (viento, búnker) |
| `audio/sfx/`         | Efectos (golpes, captura, botones, voz de los diálogos...) |
| `herramientas/`      | Scripts que generaron el arte y los mapas (solo para regenerarlos desde cero) |

**Ojo:** si vuelves a correr las herramientas, sobrescriben el arte y los mapas. Si ya
editaste algo a mano en Godot, no las uses.

## Créditos

- Letras: **Pixelify Sans** y **Press Start 2P**, licencia SIL Open Font License
  (ver `arte/fuentes/`).
