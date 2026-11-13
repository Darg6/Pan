extends Control
## Fondo provisional del combate: cielo polvoriento, ruinas en el horizonte y dos plataformas.

func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Cielo en franjas (atardecer tóxico)
	var franjas := [Color("#3a2f3f"), Color("#5a4048"), Color("#8a5a4a"), Color("#b77a52")]
	for i in franjas.size():
		draw_rect(Rect2(0, h * 0.12 * i, w, h * 0.12 + 1), franjas[i])
	# Ruinas en el horizonte
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var x := 0.0
	while x < w:
		var ancho := rng.randf_range(40, 110)
		var alto := rng.randf_range(40, 170)
		draw_rect(Rect2(x, h * 0.48 - alto, ancho, alto), Color("#2b2430"))
		x += ancho + rng.randf_range(5, 40)
	# Suelo
	draw_rect(Rect2(0, h * 0.48, w, h * 0.52), Color("#6e604a"))
	# Plataformas
	_elipse(Vector2(w * 0.74, h * 0.37), Vector2(150, 34), Color("#5a4e3b"))
	_elipse(Vector2(w * 0.28, h * 0.6), Vector2(170, 38), Color("#5a4e3b"))


func _elipse(centro: Vector2, radios: Vector2, c: Color) -> void:
	draw_set_transform(centro, 0, Vector2(1, radios.y / radios.x))
	draw_circle(Vector2.ZERO, radios.x, c)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
