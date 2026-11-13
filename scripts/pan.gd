extends CharacterBody2D
## Pan: el protagonista. Se mueve con el joystick táctil o con el teclado (WASD / flechas).

## Se emite cada vez que Pan camina un "paso" (DISTANCIA_PASO píxeles).
## El mundo lo usa para decidir si aparece una criatura.
signal paso_dado

const DISTANCIA_PASO := 40.0

@export var velocidad := 230.0

## El mundo le asigna el joystick en mundo.gd.
var joystick: Node = null
var puede_moverse := true

var _distancia := 0.0
var _mirando := Vector2.DOWN
var _tiempo := 0.0


func _physics_process(delta: float) -> void:
	var direccion := Vector2.ZERO
	if puede_moverse:
		direccion = Input.get_vector("mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo")
		if joystick != null and joystick.direccion != Vector2.ZERO:
			direccion = joystick.direccion

	velocity = direccion * velocidad
	var antes := global_position
	move_and_slide()

	if direccion != Vector2.ZERO:
		_mirando = direccion.normalized()
		_tiempo += delta
		_distancia += global_position.distance_to(antes)
		if _distancia >= DISTANCIA_PASO:
			_distancia -= DISTANCIA_PASO
			paso_dado.emit()
	queue_redraw()


## Dibujo provisional de Pan (formas de colores). Cámbialo por un Sprite2D cuando tengas arte.
func _draw() -> void:
	var rebote := absf(sin(_tiempo * 12.0)) * 2.0 if velocity != Vector2.ZERO else 0.0
	# Sombra
	draw_set_transform(Vector2(0, 14), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 17, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2(0, -rebote), 0, Vector2.ONE)
	# Mochila (siempre detrás, del lado contrario a donde mira)
	var atras := -_mirando * 11.0
	draw_rect(Rect2(atras - Vector2(10, 10), Vector2(20, 20)), Color("#6b4a2b"))
	draw_rect(Rect2(atras - Vector2(10, 10), Vector2(20, 20)), Color("#3d2a18"), false, 2.0)
	# Cuerpo (chaqueta naranja)
	draw_circle(Vector2.ZERO, 15, Color("#d9662b"))
	draw_arc(Vector2.ZERO, 15, 0, TAU, 24, Color("#7a3311"), 2.0)
	# Cabeza
	var cabeza := _mirando * 4.0
	draw_circle(cabeza, 9, Color("#f1c27d"))
	# Pelo
	draw_circle(cabeza - _mirando * 3.0, 8, Color("#3b2a1e"))
	# Ojos
	var lado := _mirando.orthogonal() * 3.5
	var ojos := cabeza + _mirando * 5.0
	draw_circle(ojos + lado, 1.8, Color.BLACK)
	draw_circle(ojos - lado, 1.8, Color.BLACK)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
