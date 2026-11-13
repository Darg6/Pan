@tool
extends Node2D
## Refugio de la ciudad. Al entrar, Pan duerme y TODAS las cartas se reparan.
## Es la única forma de curar (el GDD no tiene objetos de revivir).

@export var tamano := Vector2(240, 200):
	set(valor):
		tamano = valor
		queue_redraw()


func contiene(punto_global: Vector2) -> bool:
	return Rect2(global_position, tamano).has_point(punto_global)


func centro() -> Vector2:
	return global_position + tamano / 2.0


func _draw() -> void:
	# Suelo de la ciudad
	draw_rect(Rect2(Vector2.ZERO, tamano), Color("#4d5a63"))
	draw_rect(Rect2(Vector2.ZERO, tamano), Color("#9fb3bf"), false, 4.0)
	# Tienda de campaña
	var c := Vector2(tamano.x / 2.0, tamano.y * 0.42)
	var tienda := PackedVector2Array([c + Vector2(-60, 40), c + Vector2(0, -45), c + Vector2(60, 40)])
	draw_colored_polygon(tienda, Color("#c9a227"))
	draw_polyline(PackedVector2Array([tienda[0], tienda[1], tienda[2], tienda[0]]), Color("#6e5512"), 3.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 40), c + Vector2(0, 5), c + Vector2(14, 40)]), Color("#3a2e0b"))
	# Fogata
	var f := c + Vector2(0, 70)
	draw_circle(f, 9, Color("#ff8c1a"))
	draw_circle(f + Vector2(0, -3), 5, Color("#ffd24d"))
	var fuente := ThemeDB.fallback_font
	draw_string(fuente, Vector2(0, 26), "REFUGIO", HORIZONTAL_ALIGNMENT_CENTER, tamano.x, 22, Color.WHITE)
