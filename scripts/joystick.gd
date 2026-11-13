extends Control
## Joystick táctil flotante: toca en cualquier parte de la zona izquierda de la pantalla
## y arrastra el dedo. En PC funciona igual arrastrando con el mouse.
## Otros scripts leen la variable `direccion` (un Vector2 de largo 0 a 1).

const BASE := preload("res://arte/interfaz/joystick_base.png")
const PALANCA := preload("res://arte/interfaz/joystick_palanca.png")

@export var radio := 22.0
@export var zona_muerta := 0.2

var direccion := Vector2.ZERO

var _dedo := -1
var _base := Vector2.ZERO
var _palanca := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_volver_a_reposo)
	visibility_changed.connect(func(): if not visible: _soltar())
	_volver_a_reposo()


func _volver_a_reposo() -> void:
	_base = Vector2(40, size.y - 40)
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
	var alfa := 1.0 if _dedo != -1 else 0.6
	draw_texture(BASE, (_base - BASE.get_size() / 2.0).round(), Color(1, 1, 1, alfa))
	draw_texture(PALANCA, (_base + _palanca - PALANCA.get_size() / 2.0).round(), Color(1, 1, 1, alfa))
