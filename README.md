# Pan

RPG 2D top-down de captura de criaturas por turnos (Godot 4.3, renderer Compatibility).

## Cómo probarlo

1. Abre Godot 4.3, pulsa **Importar** y elige el archivo `project.godot` de esta carpeta.
2. Pulsa **F5** (o el botón ▶ arriba a la derecha).

**Controles**
- PC: **WASD** o **flechas** para mover a Pan. También puedes arrastrar con el mouse en la
  mitad izquierda de la pantalla (simula el joystick táctil).
- Celular: toca y arrastra en la mitad izquierda de la pantalla.
- Camina por el **pasto seco** para que aparezcan criaturas. El **Refugio** (arriba a la
  izquierda) repara todas tus cartas.

## Qué hay en el prototipo

- Pan empieza con 1 carta de **Gato Mutado**.
- Combate por turnos: Luchar, Mochila (cambiar carta), Capturar (el % sube cuanto menos vida
  tiene la criatura) y Huir.
- Daño según el GDD: `Poder × (Ataque/Defensa) × (1 + Nivel×0.2) × Debilidad × (0.85–1.0)`.
- "Infectar" quita 1/8 de la vida máxima al final de cada turno.
- Niveles por cartas duplicadas: 2 cartas = Nvl 2, 4 = Nvl 3, 8 = Nvl 4...
- Pan no muere: si caen todas sus cartas, huye y despierta en el refugio.
- 3 criaturas: Bestia Blanca (muy rápida y evasiva, débil a tóxico/térmico), Gato Mutado
  (su Arañazo infecta, débil a térmico/fluido) y Aves Negras (5 golpes por turno, débil a térmico).

## Carpetas

| Carpeta     | Qué contiene |
|-------------|--------------|
| `escenas/`  | Escenas de Godot: `mundo.tscn` (mapa), `combate.tscn`, `pan.tscn` |
| `scripts/`  | Código GDScript. `juego.gd` guarda el estado global (mochila, cartas) |
| `datos/`    | `criaturas.json`: estadísticas y ataques de cada criatura |
| `criaturas/`| Arte y escenas de criaturas (por ahora vacío) |
| `arte/`     | Arte general y `tema.tres` (estilo de botones y paneles) |
| `audio/`    | Música y sonidos (por ahora vacío) |

El arte actual son figuras de colores provisionales dibujadas por código; se pueden
reemplazar por sprites más adelante.
