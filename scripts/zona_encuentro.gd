@tool
extends Node2D
## Zona de pasto alto / escombros donde pueden aparecer criaturas salvajes.
## Puedes moverla y cambiar su tamaño, criaturas y probabilidad desde el Inspector.

@export var tamano := Vector2(400, 300):
	set(valor):
		tamano = valor
		queue_redraw()
## ids de criaturas (las mismas claves que en datos/criaturas.json)
@export var criaturas: Array[String] = ["gato_mutado"]
@export var nivel_minimo := 1
@export var nivel_maximo := 2
## Probabilidad de encuentro en cada paso dentro de la zona (0.15 = 15%)
@export_range(0.0, 1.0) var probabilidad := 0.15
@export var color := Color(0.33, 0.42, 0.2, 1.0):
	set(valor):
		color = valor
		queue_redraw()


func _ready() -> void:
	add_to_group("zonas_encuentro")


func contiene(punto_global: Vector2) -> bool:
	return Rect2(global_position, tamano).has_point(punto_global)


func elegir_encuentro() -> Dictionary:
	return {
		"id": criaturas.pick_random(),
		"nivel": randi_range(nivel_minimo, nivel_maximo),
	}


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, tamano), color)
	# Matas de pasto seco (siempre en el mismo lugar gracias a la semilla)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(tamano.x * 31 + tamano.y)
	var oscuro := color.darkened(0.35)
	var claro := color.lightened(0.25)
	for i in int(tamano.x * tamano.y / 900.0):
		var p := Vector2(rng.randf_range(6, tamano.x - 6), rng.randf_range(10, tamano.y - 2))
		draw_line(p, p + Vector2(-4, -9), oscuro, 2.0)
		draw_line(p, p + Vector2(0, -12), claro, 2.0)
		draw_line(p, p + Vector2(4, -9), oscuro, 2.0)
	draw_rect(Rect2(Vector2.ZERO, tamano), oscuro, false, 3.0)
