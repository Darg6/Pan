extends "res://scripts/interactuable.gd"
## Un vecino que hace su vida: camina por su ruta, se detiene a esperar, tose, murmura...
## Se detiene cuando Pan está cerca (para que puedas hablarle) y cuando corre un evento.
## Lo usan las ciudades "vivas" (El Sumidero, Bastión de Óxido).

## Puntos por los que camina, en coordenadas del mapa (vacío = se queda quieto)
@export var ruta: Array = []
@export var rapidez := 20.0
## Segundos que espera en cada punto de la ruta
@export var pausa := 2.5
## Tose de vez en cuando (los vecinos del Sumidero están envenenados)
@export var tose := false
## Lo que murmura cuando Pan pasa cerca (una frase al azar, en una burbuja)
@export var murmullos: Array = []
## Empieza en este punto de la ruta (para que una fila de vecinos no esté amontonada)
@export var inicio := 0

var _i := 0
var _espera := 0.0
var _t_burbuja := 0.0
var _t := 0.0


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	_i = inicio % maxi(1, ruta.size())
	if ruta.size() > 0:
		position = ruta[_i]
	_t_burbuja = randf_range(2.0, 8.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not visible:
		return
	var mapa = Historia.mapa
	if mapa == null or not is_instance_valid(mapa) or not mapa.is_inside_tree():
		return
	var cerca := global_position.distance_to(mapa.pan.global_position) < 30.0
	_t_burbuja -= delta
	if _t_burbuja <= 0.0 and not mapa.ocupado:
		_t_burbuja = randf_range(6.0, 12.0)
		if cerca and not murmullos.is_empty():
			burbuja(self, murmullos.pick_random())
		elif tose and randf() < 0.7:
			burbuja(self, ["*cof, cof*", "*cof*", "*cof cof cof*"].pick_random(), Color(0.75, 0.95, 0.6))
			if cerca:
				Sonido.efecto("tos", randf_range(0.9, 1.15), -6.0)
	if mapa.ocupado or cerca or ruta.size() < 2:
		_quieto()
		return
	if _espera > 0.0:
		_espera -= delta
		_quieto()
		return
	var destino: Vector2 = ruta[_i]
	var dir := destino - position
	if dir.length() < 0.5:
		_i = (_i + 1) % ruta.size()
		_espera = pausa
		return
	position += dir.normalized() * minf(rapidez * delta, dir.length())
	_t += delta
	if _sprite:
		if absf(dir.x) > 0.1:
			_sprite.flip_h = dir.x < 0.0
		_sprite.position.y = -1.0 if int(_t * 7.0) % 2 == 0 else 0.0   # pasitos


func _quieto() -> void:
	if _sprite:
		_sprite.position.y = 0.0


## Una burbuja de texto que sube y se desvanece sobre la cabeza de alguien.
static func burbuja(nodo: Node2D, texto: String, color := Color(1, 0.95, 0.85)) -> void:
	var l := Label.new()
	l.text = texto
	l.theme_type_variation = &"TextoChico"
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.08))
	l.add_theme_constant_override("outline_size", 3)
	l.z_index = 30
	l.position = Vector2(-l.get_minimum_size().x / 2.0, -36)
	nodo.add_child(l)
	l.position.x = -l.size.x / 2.0
	var t := l.create_tween()
	t.tween_property(l, "position:y", -44.0, 1.8)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(1.4)
	t.tween_callback(l.queue_free)
