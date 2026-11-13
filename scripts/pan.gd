extends CharacterBody2D
## Pan en el mapa. Se mueve con el joystick táctil o con el teclado (WASD / flechas).
## El sprite (arte/personajes/pan_mapa.png) tiene 3 cuadros por fila y 4 filas:
## abajo, izquierda, derecha, arriba.

## Se emite cada vez que Pan camina un "paso" (el mapa lo usa para los encuentros).
signal paso_dado

const DISTANCIA_PASO := 16.0
const FILA := { "abajo": 0, "izquierda": 1, "derecha": 2, "arriba": 3 }

@export var velocidad := 70.0
@export var aceleracion := 700.0   # qué tan rápido arranca (más alto = más brusco)
@export var frenado := 900.0       # qué tan rápido se detiene

var joystick: Node = null      # el mapa se lo asigna
var puede_moverse := true
var mirando := Vector2.DOWN

var _distancia := 0.0
var _tiempo_anim := 0.0
var _dir_guion := Vector2.ZERO   # mientras camina solo en una escena de la historia

@onready var sprite: Sprite2D = $Sprite


## Se mueve en _process (cada cuadro de la pantalla) para que se vea fluido
## en cualquier monitor, también en los de 120 o 144 Hz.
func _process(delta: float) -> void:
	if _dir_guion != Vector2.ZERO:
		_tiempo_anim += delta
		_animar(true)
		return
	var direccion := Vector2.ZERO
	if puede_moverse:
		direccion = Input.get_vector("mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo")
		if joystick != null and joystick.direccion != Vector2.ZERO:
			direccion = joystick.direccion

	var objetivo := direccion * velocidad
	velocity = velocity.move_toward(objetivo, (aceleracion if direccion != Vector2.ZERO else frenado) * delta)
	var antes := global_position
	move_and_slide()

	if direccion != Vector2.ZERO:
		mirando = direccion
		_tiempo_anim += delta * clampf(velocity.length() / velocidad, 0.3, 1.0)
		_distancia += global_position.distance_to(antes)
		if _distancia >= DISTANCIA_PASO:
			_distancia -= DISTANCIA_PASO
			paso_dado.emit()
	else:
		_tiempo_anim = 0.0
	_animar(direccion != Vector2.ZERO)


func _animar(caminando: bool) -> void:
	var fila: int
	if absf(mirando.x) > absf(mirando.y):
		fila = FILA["derecha"] if mirando.x > 0 else FILA["izquierda"]
	else:
		fila = FILA["abajo"] if mirando.y > 0 else FILA["arriba"]
	var cuadro := 0
	if caminando:
		cuadro = [1, 0, 2, 0][int(_tiempo_anim * 8.0) % 4]
	sprite.frame = fila * 3 + cuadro


## Hacia dónde mira Pan, como dirección limpia (arriba/abajo/izquierda/derecha).
func direccion_mirada() -> Vector2:
	if absf(mirando.x) > absf(mirando.y):
		return Vector2(signf(mirando.x), 0)
	return Vector2(0, signf(mirando.y) if mirando.y != 0 else 1.0)


## Camina solo hasta `destino` (para las escenas de la historia). Atraviesa obstáculos.
func caminar_a(destino: Vector2, rapidez := 55.0) -> void:
	var distancia := global_position.distance_to(destino)
	if distancia < 1.0:
		return
	_dir_guion = (destino - global_position).normalized()
	mirando = _dir_guion
	velocity = Vector2.ZERO
	var t := create_tween()
	t.tween_property(self, "global_position", destino, distancia / rapidez)
	await t.finished
	_dir_guion = Vector2.ZERO
	_tiempo_anim = 0.0
	_animar(false)


## Mira hacia un punto (sin moverse).
func mirar_a(punto: Vector2) -> void:
	mirando = (punto - global_position).normalized()
	_animar(false)
