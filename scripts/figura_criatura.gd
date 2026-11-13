extends Node2D
## Dibujo provisional de una criatura (o de Pan) en el combate, hecho con formas de colores.
## Cuando tengas sprites, puedes reemplazar este nodo por un Sprite2D / AnimatedSprite2D.

@export_enum("humanoide", "gato", "bandada", "pan") var forma := "humanoide"
@export var color := Color.WHITE
## true = mira a la derecha (aliado), false = mira a la izquierda (enemigo)
@export var mira_derecha := true
@export var tamano := 1.0

var _tiempo := 0.0


func configurar(luchador: Dictionary) -> void:
	forma = luchador["forma"]
	color = Color(luchador["color"])
	scale = Vector2.ONE
	modulate = Color.WHITE
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	_tiempo += delta
	queue_redraw()


## Pequeño salto hacia el rival al atacar.
func embestir() -> void:
	var dir := 1.0 if mira_derecha else -1.0
	var inicio := position
	var t := create_tween()
	t.tween_property(self, "position", inicio + Vector2(40 * dir, -10), 0.1)
	t.tween_property(self, "position", inicio, 0.15)


## Parpadeo rojo al recibir daño.
func parpadear() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate", Color(1, 0.3, 0.3), 0.06)
	t.tween_property(self, "modulate", Color.WHITE, 0.12)


func _draw() -> void:
	var s := tamano
	var dir := 1.0 if mira_derecha else -1.0
	var respira := sin(_tiempo * 3.0) * 2.0
	var borde := Color(0.08, 0.08, 0.1)
	# Sombra en el suelo
	draw_set_transform(Vector2(0, 0), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 60 * s, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	match forma:
		"humanoide":
			# Piernas
			draw_rect(Rect2(Vector2(-18, -50) * s, Vector2(12, 50) * s), color.darkened(0.1))
			draw_rect(Rect2(Vector2(6, -50) * s, Vector2(12, 50) * s), color.darkened(0.1))
			# Torso
			var torso := Rect2(Vector2(-24, -110 + respira) * s, Vector2(48, 64) * s)
			draw_rect(torso, color)
			draw_rect(torso, borde, false, 3.0)
			# Brazos
			draw_line(Vector2(-24, -104 + respira) * s, Vector2(-40, -60) * s, color.darkened(0.05), 10 * s)
			draw_line(Vector2(24, -104 + respira) * s, Vector2(40, -60) * s, color.darkened(0.05), 10 * s)
			# Cabeza con pelo largo
			var cabeza := Vector2(0, -130 + respira) * s
			draw_circle(cabeza + Vector2(-6 * dir, 4) * s, 24 * s, color.darkened(0.12))
			draw_circle(cabeza, 20 * s, color)
			draw_arc(cabeza, 20 * s, 0, TAU, 32, borde, 2.0)
			# Ojos blancos brillantes con contorno
			draw_circle(cabeza + Vector2(9 * dir, -3) * s, 5 * s, Color("#b9e6ff"))
			draw_circle(cabeza + Vector2(9 * dir, -3) * s, 2 * s, borde)
		"gato":
			var cuerpo := Vector2(0, -38 + respira * 0.5) * s
			# Cola
			draw_line(cuerpo + Vector2(-40 * dir, 0) * s, cuerpo + Vector2(-70 * dir, -40 + respira * 2) * s, color.darkened(0.2), 9 * s)
			# Cuerpo
			draw_set_transform(cuerpo, 0, Vector2(1.5, 1))
			draw_circle(Vector2.ZERO, 30 * s, color)
			draw_arc(Vector2.ZERO, 30 * s, 0, TAU, 32, borde, 2.0)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			# Manchas tóxicas (mutación)
			draw_circle(cuerpo + Vector2(-10, -8) * s, 7 * s, Color("#7bd13b"))
			draw_circle(cuerpo + Vector2(12, 6) * s, 5 * s, Color("#7bd13b"))
			# Cabeza y orejas
			var cabeza := cuerpo + Vector2(42 * dir, -26) * s
			draw_colored_polygon(PackedVector2Array([cabeza + Vector2(-16, -10) * s, cabeza + Vector2(-10, -38) * s, cabeza + Vector2(0, -16) * s]), color.darkened(0.1))
			draw_colored_polygon(PackedVector2Array([cabeza + Vector2(16, -10) * s, cabeza + Vector2(10, -38) * s, cabeza + Vector2(0, -16) * s]), color.darkened(0.1))
			draw_circle(cabeza, 22 * s, color)
			draw_arc(cabeza, 22 * s, 0, TAU, 32, borde, 2.0)
			draw_circle(cabeza + Vector2(-7, -4) * s, 5 * s, Color("#c6ff3d"))
			draw_circle(cabeza + Vector2(7, -4) * s, 5 * s, Color("#c6ff3d"))
			draw_circle(cabeza + Vector2(-7, -4) * s, 2 * s, borde)
			draw_circle(cabeza + Vector2(7, -4) * s, 2 * s, borde)
		"bandada":
			# 5 aves que se mueven un poco cada una
			var puestos := [Vector2(0, -120), Vector2(-50, -90), Vector2(50, -95), Vector2(-25, -50), Vector2(30, -45)]
			for i in puestos.size():
				var p: Vector2 = puestos[i] * s + Vector2(0, sin(_tiempo * 5.0 + i * 1.3) * 6)
				var aleteo := sin(_tiempo * 12.0 + i) * 8.0
				var ala := PackedVector2Array([
					p + Vector2(-26, -6 + aleteo) * s, p + Vector2(0, 6) * s,
					p + Vector2(26, -6 + aleteo) * s, p + Vector2(0, -2) * s,
				])
				draw_colored_polygon(ala, color)
				draw_circle(p + Vector2(4 * dir, -2) * s, 6 * s, color.lightened(0.1))
				draw_circle(p + Vector2(7 * dir, -4) * s, 1.8 * s, Color("#ff3b3b"))
		"pan":
			# Pan de pie al fondo, de brazos cruzados (domador)
			draw_rect(Rect2(Vector2(-14, -48) * s, Vector2(10, 48) * s), Color("#3b3b4a"))
			draw_rect(Rect2(Vector2(4, -48) * s, Vector2(10, 48) * s), Color("#3b3b4a"))
			draw_rect(Rect2(Vector2(-30 * dir - 10, -100) * s, Vector2(20, 44) * s), Color("#6b4a2b"))  # mochila
			draw_rect(Rect2(Vector2(-20, -104) * s, Vector2(40, 58) * s), Color("#d9662b"))
			draw_rect(Rect2(Vector2(-22, -84) * s, Vector2(44, 12) * s), Color("#b8521f"))  # brazos cruzados
			draw_circle(Vector2(0, -120) * s, 16 * s, Color("#f1c27d"))
			draw_circle(Vector2(-3 * dir, -128) * s, 14 * s, Color("#3b2a1e"))
			draw_circle(Vector2(6 * dir, -120) * s, 2 * s, borde)
