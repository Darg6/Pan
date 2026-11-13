@tool
extends Node2D
## Zona invisible: cuando Pan entra, se ejecuta un evento de la historia (scripts/historia.gd).
## Solo se ve en el editor (rectángulo celeste).

@export var evento := ""
@export var tamano := Vector2(32, 32):
	set(valor):
		tamano = valor
		queue_redraw()


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("disparadores")


func contiene(punto_global: Vector2) -> bool:
	return Rect2(global_position, tamano).has_point(punto_global)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, tamano), Color(0.3, 0.8, 1.0, 0.25))
		draw_rect(Rect2(Vector2.ZERO, tamano), Color(0.3, 0.8, 1.0, 0.8), false, 1.0)
