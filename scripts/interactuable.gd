@tool
extends Node2D
## Algo con lo que Pan puede interactuar (objeto, persona, cartel, puerta...).
## Cuando Pan está cerca aparece un "!" y puede pulsar el botón A (o E / Espacio).
## Lo que pasa al interactuar se programa en scripts/historia.gd con el nombre de `evento`.

## Nombre del evento en historia.gd (ej. "mochila", "ciudadano", "saqueo")
@export var evento := ""
## Imagen opcional (un objeto en el suelo, un personaje...)
@export var textura: Texture2D:
	set(valor):
		textura = valor
		_actualizar_sprite()
## Distancia (en píxeles) desde la que se puede interactuar
@export var radio := 18.0
## Si esta bandera de la historia está activa, el objeto desaparece (ej. ya lo recogiste)
@export var ocultar_si := ""
## Si no está vacío, el objeto solo aparece cuando esta bandera está activa
@export var mostrar_si := ""
## Si es true, choca con Pan (personas, muebles)
@export var solido := false

var _sprite: Sprite2D


func _ready() -> void:
	_actualizar_sprite()
	if Engine.is_editor_hint():
		return
	add_to_group("interactuables")
	if solido:
		var cuerpo := StaticBody2D.new()
		var forma := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(12, 8)
		forma.shape = rect
		cuerpo.add_child(forma)
		add_child(cuerpo)
	actualizar()


func _actualizar_sprite() -> void:
	if not is_inside_tree():
		return
	if _sprite == null:
		_sprite = Sprite2D.new()
		add_child(_sprite)
	_sprite.texture = textura
	if textura != null:
		# Los personajes (24 px de alto) se apoyan en los pies; los objetos se centran.
		_sprite.offset = Vector2(0, -9) if textura.get_height() > 16 else Vector2.ZERO


## Muestra u oculta el objeto según las banderas de la historia.
func actualizar() -> void:
	var visible_ahora := true
	if ocultar_si != "" and Juego.flag(ocultar_si):
		visible_ahora = false
	if mostrar_si != "" and not Juego.flag(mostrar_si):
		visible_ahora = false
	visible = visible_ahora
	for hijo in get_children():
		if hijo is StaticBody2D:
			hijo.process_mode = Node.PROCESS_MODE_INHERIT if visible_ahora else Node.PROCESS_MODE_DISABLED
			for f in hijo.get_children():
				f.disabled = not visible_ahora


func activo() -> bool:
	return visible and evento != ""


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, radio, 0, TAU, 24, Color(1, 0.8, 0.2, 0.6), 1.0)
