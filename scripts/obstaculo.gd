@tool
extends StaticBody2D
## Bloque sólido (ruinas, muros, chatarra). Pan no lo puede atravesar.

@export var tamano := Vector2(120, 80):
	set(valor):
		tamano = valor
		queue_redraw()
@export var color := Color(0.36, 0.33, 0.31, 1.0):
	set(valor):
		color = valor
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = tamano
	forma.shape = rect
	forma.position = tamano / 2.0
	add_child(forma)


func _draw() -> void:
	draw_rect(Rect2(Vector2(6, 8), tamano), Color(0, 0, 0, 0.25))  # sombra
	draw_rect(Rect2(Vector2.ZERO, tamano), color)
	draw_rect(Rect2(Vector2.ZERO, Vector2(tamano.x, 8)), color.lightened(0.2))
	draw_rect(Rect2(Vector2.ZERO, tamano), color.darkened(0.45), false, 3.0)
	# Grietas
	var rng := RandomNumberGenerator.new()
	rng.seed = int(tamano.x * 7 + tamano.y * 13)
	for i in int(maxf(1.0, tamano.x * tamano.y / 6000.0)):
		var a := Vector2(rng.randf_range(10, tamano.x - 10), rng.randf_range(10, tamano.y - 10))
		var b := a + Vector2(rng.randf_range(-18, 18), rng.randf_range(8, 22))
		draw_line(a, b, color.darkened(0.5), 2.0)
