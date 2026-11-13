extends Control
## Joystick táctil flotante: toca en cualquier parte de la zona izquierda de la pantalla
## y arrastra el dedo. En PC funciona igual arrastrando con el mouse.
## Otros scripts leen la variable `direccion` (un Vector2 de largo 0 a 1).

@export var radio := 90.0
@export var radio_palanca := 38.0
@export var zona_muerta := 0.15

var direccion := Vector2.ZERO

var _dedo := -1
var _base := Vector2.ZERO       # centro del joystick (coordenadas locales)
var _palanca := Vector2.ZERO    # desplazamiento de la palanca desde la base


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_volver_a_reposo)
	_volver_a_reposo()


func _volver_a_reposo() -> void:
	_base = Vector2(radio + 50, size.y - radio - 50)
	_palanca = Vector2.ZERO
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _dedo == -1 and get_global_rect().has_point(event.position):
			_dedo = event.index
			_base = event.position - global_position
			_mover_palanca(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _dedo:
			_soltar()
	elif event is InputEventScreenDrag and event.index == _dedo:
		_mover_palanca(event.position)
		get_viewport().set_input_as_handled()


func _soltar() -> void:
	_dedo = -1
	direccion = Vector2.ZERO
	_volver_a_reposo()


func _mover_palanca(posicion_pantalla: Vector2) -> void:
	_palanca = (posicion_pantalla - global_position - _base).limit_length(radio)
	direccion = _palanca / radio
	if direccion.length() < zona_muerta:
		direccion = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var activo := _dedo != -1
	draw_circle(_base, radio, Color(1, 1, 1, 0.18 if activo else 0.1))
	draw_arc(_base, radio, 0, TAU, 48, Color(1, 1, 1, 0.5 if activo else 0.3), 3.0)
	draw_circle(_base + _palanca, radio_palanca, Color(1, 1, 1, 0.55 if activo else 0.35))
