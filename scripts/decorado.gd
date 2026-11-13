@tool
extends Node2D
## Construcción grande del mapa (trituradora, buque encallado, grúa, tienda...).
## Es una imagen que se apoya en su base (los "pies" están en la posición del nodo) y
## choca con Pan en un rectángulo de esa base. Puede tener varios cuadros de animación
## y humo saliendo de sus chimeneas.

@export var textura: Texture2D:
	set(valor):
		textura = valor
		_actualizar()
## Tamaño del rectángulo que choca con Pan, centrado en la base de la imagen
@export var colision := Vector2(32, 12)
## Cuadros de animación (la imagen tiene los cuadros uno al lado del otro)
@export var cuadros := 1
@export var cuadros_por_segundo := 6.0
## Puntos (relativos al nodo) de donde sale humo
@export var humo: Array[Vector2] = []
## Si esta bandera de la historia está activa, la animación se detiene (ej. la trituradora apagada)
@export var detener_si := ""

var _sprite: Sprite2D
var _t := 0.0


func _ready() -> void:
	_actualizar()
	if Engine.is_editor_hint():
		return
	if colision.x > 0 and colision.y > 0:
		var cuerpo := StaticBody2D.new()
		var forma := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = colision
		forma.shape = rect
		forma.position = Vector2(0, -colision.y / 2.0)
		cuerpo.add_child(forma)
		add_child(cuerpo)
	for p in humo:
		var h := Ambiente.humo(p)
		h.z_index = 1
		add_child(h)


func _actualizar() -> void:
	if not is_inside_tree():
		return
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.texture = textura   # antes de add_child: así se usa el PNG al día (Juego._al_agregar_nodo)
		add_child(_sprite)
	else:
		_sprite.texture = textura
	_sprite.hframes = maxi(1, cuadros)
	if textura != null:
		_sprite.offset = Vector2(0, -textura.get_height() / 2.0)
		_sprite.centered = true


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or cuadros <= 1 or _sprite == null:
		return
	if detener_si != "" and Juego.flag(detener_si):
		_sprite.frame = 0
		return
	_t += delta * cuadros_por_segundo
	_sprite.frame = int(_t) % cuadros


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2(-colision.x / 2.0, -colision.y), colision), Color(1, 0.4, 0.2, 0.5), false, 1.0)
