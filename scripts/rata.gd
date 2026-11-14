extends Node2D
## Una rata del subterráneo que cruza corriendo de un punto a otro cada tanto (ambiente).

@export var hasta := Vector2(64, 0)   # relativo a la posición del nodo
@export var cada := 9.0

var _s: Sprite2D
var _t := 0.0


func _ready() -> void:
	_s = Sprite2D.new()
	_s.texture = load("res://arte/personajes/rata_mapa.png")
	_s.hframes = 2
	_s.visible = false
	add_child(_s)
	_t = randf_range(1.0, cada)


func _process(delta: float) -> void:
	_t -= delta
	if _s.visible:
		_s.frame = int(Time.get_ticks_msec() / 90) % 2
	if _t > 0.0:
		return
	_t = cada + randf_range(-2.0, 4.0)
	var ida := randf() < 0.5
	var a := Vector2.ZERO if ida else hasta
	var b := hasta if ida else Vector2.ZERO
	_s.position = a
	_s.flip_h = b.x < a.x
	_s.visible = true
	var t := create_tween()
	t.tween_property(_s, "position", b, a.distance_to(b) / 90.0)
	t.tween_callback(func(): _s.visible = false)
