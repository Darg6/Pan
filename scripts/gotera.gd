extends Node2D
## Gotera de ácido (El Sumidero): cada tanto aparece una sombra en el suelo y cae una gota.
## Si Pan está debajo cuando cae, la carta que va al frente pierde un poco de vida (nunca se rompe).

@export var cada_min := 3.5
@export var cada_max := 7.5

var _t := 0.0
var _sombra: Sprite2D


func _ready() -> void:
	_t = randf_range(0.5, cada_max)
	_sombra = Sprite2D.new()
	_sombra.texture = preload("res://arte/efectos/sombra.png")
	_sombra.modulate = Color(0.3, 0.9, 0.3, 0.0)
	_sombra.scale = Vector2(0.35, 0.6)
	add_child(_sombra)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = randf_range(cada_min, cada_max)
	_caer()


func _caer() -> void:
	var t := create_tween()
	t.tween_property(_sombra, "modulate:a", 0.55, 0.7)   # aviso: la sombra crece
	t.parallel().tween_property(_sombra, "scale", Vector2(0.5, 0.8), 0.7)
	await t.finished
	var gota := Sprite2D.new()
	var img := Image.create(2, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.72, 1.0, 0.42))
	gota.texture = ImageTexture.create_from_image(img)
	gota.position = Vector2(0, -70)
	gota.z_index = 18
	add_child(gota)
	var c := create_tween()
	c.tween_property(gota, "position:y", 0.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await c.finished
	gota.queue_free()
	_salpicar()
	var s := create_tween()
	s.tween_property(_sombra, "modulate:a", 0.0, 0.3)
	s.parallel().tween_property(_sombra, "scale", Vector2(0.35, 0.6), 0.3)
	var mapa = Historia.mapa
	if mapa == null or not is_instance_valid(mapa) or mapa.ocupado or Juego.cambiando_escena:
		return
	if global_position.distance_to(mapa.pan.global_position) <= 10.0:
		Sonido.efecto("goteo", 0.8)
		mapa.gota_de_acido()
	elif global_position.distance_to(mapa.pan.global_position) < 90.0:
		Sonido.efecto("goteo", randf_range(0.9, 1.2), -10.0)


func _salpicar() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 6
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 70
	p.gravity = Vector2(0, 120)
	p.initial_velocity_min = 20
	p.initial_velocity_max = 40
	p.color = Color(0.72, 1.0, 0.42)
	p.z_index = 18
	add_child(p)
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)
