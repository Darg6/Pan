@tool
extends Node2D
## Suelo del páramo. Define también el tamaño del mapa (la cámara no sale de aquí).

@export var tamano := Vector2(2400, 1600):
	set(valor):
		tamano = valor
		queue_redraw()
@export var color := Color("#8a7a5c"):
	set(valor):
		color = valor
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, tamano), color)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in int(tamano.x * tamano.y / 5000.0):
		var p := Vector2(rng.randf_range(0, tamano.x), rng.randf_range(0, tamano.y))
		var tono := color.darkened(rng.randf_range(0.05, 0.25))
		draw_circle(p, rng.randf_range(2, 6), tono)
