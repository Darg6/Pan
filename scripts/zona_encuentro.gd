@tool
extends Node2D
## Zona donde pueden aparecer criaturas salvajes (solo al caminar sobre pasto seco).
## En el juego es invisible; en el editor se ve como un rectángulo verde.
## Puedes moverla y cambiar su tamaño, criaturas y probabilidad desde el Inspector.

@export var tamano := Vector2(160, 96):
	set(valor):
		tamano = valor
		queue_redraw()
## ids de criaturas (las mismas claves que en datos/criaturas.json)
@export var criaturas: Array[String] = ["gato_mutado"]
@export var nivel_minimo := 1
@export var nivel_maximo := 2
## Probabilidad de encuentro en cada paso sobre pasto (0.12 = 12%)
@export_range(0.0, 1.0) var probabilidad := 0.12


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("zonas_encuentro")


func contiene(punto_global: Vector2) -> bool:
	return Rect2(global_position, tamano).has_point(punto_global)


func elegir_encuentro() -> Dictionary:
	return {
		"tipo": "salvaje",
		"equipo": [{ "id": criaturas.pick_random(), "nivel": randi_range(nivel_minimo, nivel_maximo) }],
	}


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, tamano), Color(0.4, 1.0, 0.3, 0.15))
		draw_rect(Rect2(Vector2.ZERO, tamano), Color(0.4, 1.0, 0.3, 0.8), false, 1.0)
