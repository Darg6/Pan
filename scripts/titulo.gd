extends Control
## "La Salida al Mundo Abierto": la cámara se aleja del acantilado, aparece el título
## con letras metálicas y la nueva misión. Después vuelve al mapa de la superficie.

const SUPERFICIE := "res://escenas/mapas/superficie.tscn"

@onready var imagen: TextureRect = $Imagen
@onready var titulo: Label = $Titulo
@onready var subtitulo: Label = $Subtitulo
@onready var transicion: ColorRect = $Transicion


func _ready() -> void:
	Juego.cambiando_escena = false
	Sonido.musica("recuerdo")
	Sonido.ambiente("viento" if true else "")
	titulo.text = Juego.NOMBRE_JUEGO
	titulo.modulate.a = 0.0
	subtitulo.modulate.a = 0.0
	imagen.pivot_offset = Vector2(150, 200)
	imagen.scale = Vector2(2.2, 2.2)  # empieza cerca de Pan...
	var t := create_tween().set_parallel()
	t.tween_property(transicion, "color:a", 0.0, 1.0)
	t.tween_property(imagen, "scale", Vector2.ONE, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished
	# Golpe de título
	titulo.scale = Vector2(1.6, 1.6)
	titulo.pivot_offset = titulo.size / 2.0
	var g := create_tween().set_parallel()
	g.tween_property(titulo, "modulate:a", 1.0, 0.15)
	g.tween_property(titulo, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await g.finished
	_sacudir()
	await get_tree().create_timer(1.0).timeout
	create_tween().tween_property(subtitulo, "modulate:a", 1.0, 0.8)
	await get_tree().create_timer(3.5).timeout
	var f := create_tween()
	f.tween_property(transicion, "color:a", 1.0, 0.8)
	await f.finished
	Juego.ir_a_mapa(SUPERFICIE, "Mirador")


func _sacudir() -> void:
	var t := create_tween()
	for i in 6:
		t.tween_property(self, "position", Vector2(randf_range(-3, 3), randf_range(-2, 2)), 0.03)
	t.tween_property(self, "position", Vector2.ZERO, 0.03)
