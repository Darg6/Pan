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
  siempre en todas tus criaturas. También se abre la **salida este** (los vecinos quitan la
  barricada).

## Camino: la Autopista Quemada

Sales de Bastión por el este. Es un río de asfalto con autos calcinados y ceniza que cae.

- **Emboscada**: un Cazador Furtivo sale de detrás de un auto quemado y **ataca primero**
  (Lobo de Ceniza y Cazador Camuflado). Su botín es alto.
- **Piña silvestre**: cura un poco a tu carta del frente... pero viene contaminada (infección).
- Una viajera que escapó del Sumidero, un letrero para investigar y saqueos.
- Al este, la **boca del metro** baja al Sumidero.

## Ciudad 2: El Sumidero (Dra. Vesper, La Tóxica)

Una ciudad en los túneles del viejo metro: pasarelas de madera podrida sobre ríos de lodo,
hongos que brillan en verde y violeta, y en el centro el laboratorio limpio de Vesper.
Vesper envenena el agua y vende el "antídoto" a cambio de monstruos raros o de experimentos.

- **Una ciudad viva**: los vecinos caminan sus rutas, hacen fila en la ventanilla del
  antídoto, tosen y murmuran cuando pasas. Los niños corren, la patrulla vigila, las ratas
  cruzan las vías y **gotas de ácido** caen del techo (mira su sombra para esquivarlas).
- **Charcos tóxicos**: pisar los charcos verdes puede infectar a tu carta del frente. La
  infección ya no se va sola al terminar el combate: se cura con un **Antídoto** o durmiendo.
- **Escena del antídoto**: al llegar a la plaza ves la fila, un vecino rechazado y a Vesper,
  que se fija en tu collar ("especímenes", "selección natural").
- **Vagón de Sabina**: la primera tienda con **Antídotos** (curan infección, quemadura,
  parálisis y ceguera) y la **Máscara de Filtro**.
- **Vagón Dormitorio de Tula**: dormir (8 monedas, o gratis al liberar la ciudad).
- **Misiones secundarias**:
  - *Pan para los niños*: lleva 2 Piñas en lata a la madre del barrio. Te da una hoja del
    cuaderno de Vesper con pistas para la pelea.
  - *El filtro de Nilo*: consigue 3 Núcleos Tóxicos (los sueltan las Burbujas Tóxicas) y Nilo
    te arma la Máscara de Filtro para entrar al **Colector de Gas** (botín y criaturas fuertes).
  - *La entrega de Iris*: su papá necesita el antídoto. Dale uno de tus Antídotos o entrega
    una de tus cartas (Iris te la devuelve cuando el Sumidero sea libre).
  - Además, un anciano que pide comida limpia.
- **Cosas para investigar**: mapa del metro, jardín de hongos, tanque envenenado, ventanilla,
  altavoz, cristales del laboratorio, jaulas, vagón con grafitis, memorial y el cartel del
  Benefactor. Cambian después de liberar la ciudad.
- **Criaturas nuevas**: Lobo de Ceniza y Cazador Camuflado (autopista), Burbuja Tóxica y
  Sirena de Fango (jardín de hongos), Tejedor de Sombras y Humanoide sin Consciencia (túneles
  oscuros) y Guardián de Flora (colector de gas).
- **Guardias de la Organización**: dos en la puerta del laboratorio, con 3 bestias cada uno.
  Usan potenciadores y **Intervención Directa** (te lanzan un frasco de veneno o un molotov).
- **Jefa: la Dra. Vesper**. Llena la arena de gas (**Campo Radioactivo**: tu carta pierde un
  poco de vida cada turno). Burbuja Tóxica (si la golpeas con ataques físicos revienta y te
  paraliza), Sirena de Fango (su lodo deja tu Velocidad en cero) y Guardián de Flora (te drena
  la vida y se cura entero si debilita a tu carta). Rota tus cartas y usa ataques térmicos.
- **Al salvar la ciudad** Pan cierra la válvula del veneno, el agua sale limpia y todo el
  Sumidero lo aplaude: otro +10% de ataque para siempre. Se abre el **túnel del este**.

## Camino: el Paso del Smog

Al este del Sumidero. Un smog violeta y espeso... que se puede respirar.
- Los altavoces dicen que el aire de afuera es **gas letal**. La "nube verde" del camino es
  una película que lanza un **proyector**: es la mentira con la que Silas encierra a su gente.
- *La carta de Leo*: un pedalero que escapó te pide llevarle una carta a su hermana Mara.
- Un **patrullero** de Silas cuida la entrada de la ciudad.

## Ciudad 3: Ciudad Neón (Silas, El Ilusionista)

Un viejo distrito de casinos y salas de juego. Aquí **siempre es de noche**: letreros cian y
magenta, hologramas de la cara de Silas y altavoces que repiten su voz cada tanto.
- La gente **pedalea 16 horas al día** en generadores gigantes para encender las luces y las
  torres sónicas. Hablan rápido, sonríen a la fuerza y susurran por los micrófonos.
- **Neones de Coral** (tienda con **Granadas de Luz**) y el motel (10 monedas, gratis al liberar).
- **Misiones**: *El turno de Tobi* (pedalea por su mamá; minijuego de pedales),
  *Los micrófonos de Rina* (3 micrófonos escondidos = **Visor Polarizado**, que corta el Juego
  de Luces a la mitad) y la carta de Leo. Don Ciro y el cantinero dan pistas.
- **Criaturas nuevas**: Caballero de Neón (ciega) y Espectro Sónico (sus ataques nunca fallan).
- **Dos guardias** cuidan el escenario del Palacio Lumen.
- **Jefe: Silas**. Antes de pelear te muestra una **ilusión de tus padres** que te pide
  quedarte. En combate: **Juego de Luces** (tus ataques pierden 30% de precisión), Bestia
  Blanca que esquiva los primeros ataques, Bailarina Eléctrica que paraliza al que la golpea
  (represalia) y Caballero de Neón que ciega. Cada 3 turnos vuelve la ilusión y confunde a tu
  carta. Usa ataques **sónicos** (nunca fallan), de **tierra** contra la Bailarina y Granadas de Luz.
- **Al salvar la ciudad** se apagan los generadores, la gente respira el aire de afuera y se
  abre la puerta norte: otro +10% de ataque.

## Camino: el Bosque Calcinado

Ceniza que cae como nieve, troncos negros y **brasas escondidas** que queman a tu carta del
frente si las pisas. Brotes verdes para la misión de Lucía, una trampa desarmada a propósito,
y un **recaudador** de la Organización que va a cobrarle al valle.

## Ciudad 4: Valle Ceniza (Kael, El Escudo Roto)

Cabañas de madera, un invernadero, la olla común y un monumento a los caídos. Aquí la gente
**quiere a Kael**: caza para ellos y recibe los castigos de la Organización en silencio.
- Nadie te pide ayuda: **te piden que no le hagas daño a Kael**. La abuela Nita te da la cama gratis.
- La **olla común** te cura una vez. *Brotes para Lucía*: 3 brotes del bosque. La despensa de Hugo.
- **Jefe: Kael**. **Postura Defensiva** (sus bestias reciben 25% menos de daño). Dos
  Humanoides (bloquean tus curas), Bestia Blindada (**Reflejo**: te devuelve 30% del daño
  físico) y el Vigilante Ciego (nunca falla e ignora tu defensa). Música melancólica.
- **El evento de piedad**: al perder, la música se apaga, Kael cae de rodillas y llora. Primer
  plano del rostro de Pan y **tú decides**:
  - **Perdonarlo**: los ojos de Pan se suavizan. Kael cuenta la verdad sobre tus padres y te
    da los Códigos de la Capital, el Mapa de Debilidades del Líder y una **grabación de tus
    padres** (se puede volver a escuchar desde la mochila). El valle celebra.
  - **Ejecutarlo**: la sombra del pelo tapa sus ojos, la pantalla se va a negro (no se ve
    violencia), te llevas su botín por la fuerza y el valle se vuelve frío y callado. Tienes
    que encontrar solo lo que Kael escondía (3 pistas).
  - La decisión se guarda (`kael_perdonado` o `kael_ejecutado`) para los finales del juego.
- El camino del norte (la Fortaleza de Hierro) llegará en una próxima versión.

## Menú de prueba (oculto)

En el menú principal, **toca 5 veces el título "PAN"** (o pulsa la tecla **T**). Aparece el
MODO PRUEBA: elige Ciudad 1, 2, 3 o 4 y empiezas ahí con un equipo armado, como si hubieras
jugado lo anterior. **Tu partida guardada no se toca** (el modo prueba guarda aparte, en
`user://partida_prueba.json`). Para volver a tu partida, cierra el juego y pulsa Continuar.

## Dónde cambiar cada cosa

| Quiero cambiar...            | Archivo |
|------------------------------|---------|
| El nombre del juego          | `NOMBRE_JUEGO` y `SUBTITULO_JUEGO` en `scripts/juego.gd` |
| El menú principal            | `scripts/menu.gd` (fondo, botones y textos) |
| Los textos y diálogos        | `datos/dialogos.json` |
| Las imágenes de la intro     | `arte/cinematica/` (cada frase de la intro elige su imagen con `"imagen"` en `datos/dialogos.json`) |
| Qué pasa en cada evento      | `scripts/historia.gd` (Ciudad 3: `historia_neon.gd`, Ciudad 4: `historia_valle.gd`) |
| Criaturas, ataques y stats   | `datos/criaturas.json` |
| Los mapas                    | `escenas/mapas/*.tscn` (ábrelos y pinta con el editor de TileMap) |
| El arte                      | `arte/` (reemplaza un PNG por el tuyo con el **mismo nombre y tamaño**) |
| Botones, paneles y letra     | `arte/tema.tres` y `arte/interfaz/` |
| Música y sonidos             | `audio/` (reemplaza un .ogg por el tuyo con el **mismo nombre**) |
| Música/clima de cada mapa    | `AMBIENTACION` al inicio de `scripts/mapa.gd` (música, viento, color de luz, ceniza) |
| Duración de las tormentas    | `CLIMA_CALMA` y `CLIMA_TORMENTA` en `scripts/mapa.gd` (segundos) |
| Precios y límites de objetos | `OBJETOS` al inicio de `scripts/juego.gd` |
| Lo que vende cada tienda     | `SURTIDO` (Bastión), `SURTIDO_SUMIDERO`, `SURTIDO_NEON` y `SURTIDO_VALLE` en `scripts/tienda_ui.gd` |
| El equipo del menú de prueba | `PRUEBA_EQUIPOS` y `preparar_prueba()` al final de `scripts/juego.gd` |
| Los vecinos que caminan      | Nodos con `scripts/vecino.gd` (ruta, pausa, si tosen y lo que murmuran) |
| Las construcciones grandes   | Nodos con `scripts/decorado.gd` en `Entidades` (imagen, choque, humo, animación) |

Para probar sin repetir la intro, pon `SALTAR_PROLOGO = true` en `scripts/juego.gd`.

## Carpetas

| Carpeta              | Qué contiene |
|----------------------|--------------|
| `escenas/`           | `menu.tscn` (menú principal), `intro.tscn`, `titulo.tscn`, `combate.tscn`, `pan.tscn` |
| `escenas/mapas/`     | `refugio_cero.tscn`, `superficie.tscn`, `bastion_oxido.tscn`, `autopista.tscn`, `sumidero.tscn`, `paso_smog.tscn`, `ciudad_neon.tscn`, `bosque_calcinado.tscn` y `valle_ceniza.tscn` |
| `escenas/ui/`        | HUD, caja de diálogo |
| `scripts/`           | Código. `juego.gd` = estado (mochila, cartas, flags); `historia.gd` = la historia |
| `datos/`             | `dialogos.json` y `criaturas.json` |
| `arte/tiles/`        | Texturas de los mapas (16x16 por tile) |
| `arte/criaturas/`    | Criaturas para el combate (64x64, mirando a la derecha, patas en la fila 60) |
| `arte/personajes/`   | Pan y los personajes en el mapa y en combate |
| `arte/retratos/`     | Caras que salen en los diálogos (48x48, también las de los 6 comandantes) |
| `arte/conceptos/`    | Hojas de diseño de Pan, Diego y Danitza (no se usan en el juego, son de referencia) |
| `arte/cinematica/`   | Imágenes de la intro y los primeros planos de Pan (decisión de Kael) |
| `arte/fondos/`       | Fondos de combate por capas (cielo, nubes, montañas, ruinas, suelo). Cada zona de encuentro elige el suyo con `fondo` (paramo, pastizal, chatarra, dunas, bastion, autopista, sumidero, laboratorio, smog, neon, casino, bosque, valle) |
| `arte/efectos/`      | Sombra, chispa de golpe y polvo del combate |
| `arte/shaders/`      | Shader de los luchadores (destello al recibir golpes y respiración) |
| `arte/interfaz/`     | Paneles, botones y joystick |
| `arte/objetos/`      | Mochila, cartas, collar, iconos de la tienda, etc. |
| `arte/decorados/`    | Construcciones grandes (Bastión: trituradora, buque, grúa...; Sumidero: vagones, laboratorio, tanques, hongos...) |
| `arte/fuentes/`      | Letras pixel |
| `audio/musica/`      | Música (recuerdo = intro, paramo = exploración, combate, bastion = ciudad 1, sumidero = ciudad 2, neon = ciudad 3, valle = ciudad 4, jefe = comandantes, vesper / silas / kael = sus peleas) |
| `audio/ambiente/`    | Sonidos de fondo en bucle (viento, búnker, ciudad, tormenta, subterraneo, neon, bosque) |
| `audio/sfx/`         | Efectos (golpes, captura, botones, voz de los diálogos...) |
| `herramientas/`      | Scripts que generaron el arte y los mapas (solo para regenerarlos desde cero). El arte de Bastión está en `arte_bastion.py`, el del Sumidero en `arte_sumidero.py`, el de Neón en `arte_neon.py` y el del Valle en `arte_valle.py` |

**Ojo:** si vuelves a correr las herramientas, sobrescriben el arte y los mapas. Si ya
editaste algo a mano en Godot, no las uses.

## Créditos

- Letras: **Pixelify Sans** y **Press Start 2P**, licencia SIL Open Font License
  (ver `arte/fuentes/`).
