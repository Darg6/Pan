class_name Ambiente
extends RefCounted
## Piezas de ambiente reutilizables: partículas (ceniza, polvo, brasas), luces que titilan
## y la viñeta oscura de los bordes. Todo se crea por código, no hace falta arte extra.

const TILES_JSON := "res://arte/tiles/tiles.json"


## Un cuadradito de 1x1 píxel blanco: las partículas lo tiñen de su color.
static func _pixel(tam := 1) -> Texture2D:
	var img := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


static func _base(cantidad: int, vida: float, area: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = cantidad
	p.lifetime = vida
	p.preprocess = vida           # la pantalla ya empieza llena
	p.local_coords = false        # las partículas se quedan en el mundo aunque la cámara se mueva
	p.texture = _pixel()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area / 2.0 + Vector2(24, 24)
	p.z_index = 20
	return p


## Ceniza que cae en diagonal con el viento (para el páramo y el combate).
static func ceniza(area: Vector2) -> CPUParticles2D:
	var p := _base(70, 7.0, area)
	p.direction = Vector2(0.4, 1)
	p.spread = 15
	p.gravity = Vector2(4, 6)
	p.initial_velocity_min = 6
	p.initial_velocity_max = 14
	p.angular_velocity_min = 0
	p.scale_amount_min = 1
	p.scale_amount_max = 2
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.82, 0.78, 0.0))
	g.set_color(1, Color(0.85, 0.82, 0.78, 0.0))
	g.add_point(0.15, Color(0.85, 0.82, 0.78, 0.7))
	g.add_point(0.85, Color(0.7, 0.66, 0.62, 0.5))
	p.color_ramp = g
	return p


## Motas de polvo flotando lento (interiores).
static func polvo(area: Vector2) -> CPUParticles2D:
	var p := _base(28, 9.0, area)
	p.direction = Vector2(0, -1)
	p.spread = 180
	p.gravity = Vector2(0, -1)
	p.initial_velocity_min = 1
	p.initial_velocity_max = 4
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.92, 0.7, 0.0))
	g.set_color(1, Color(1.0, 0.92, 0.7, 0.0))
	g.add_point(0.5, Color(1.0, 0.92, 0.7, 0.45))
	p.color_ramp = g
	return p


## Brasas que suben de una fogata.
static func brasas(pos: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos + Vector2(0, -4)
	p.amount = 12
	p.lifetime = 1.6
	p.texture = _pixel()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(4, 1)
	p.direction = Vector2(0, -1)
	p.spread = 20
	p.gravity = Vector2(0, -10)
	p.initial_velocity_min = 8
	p.initial_velocity_max = 18
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	g.set_color(1, Color(0.8, 0.2, 0.05, 0.0))
	p.color_ramp = g
	p.z_index = 15
	return p


## Brillo de luz que titila (se suma a los colores de abajo).
static func luz(pos: Vector2, color: Color, fuego := false) -> Sprite2D:
	var s := Sprite2D.new()
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	var fuerza := 0.4 if fuego else 0.2
	g.set_color(0, Color(color, fuerza))
	g.set_color(1, Color(color, 0.0))
	g.add_point(0.35, Color(color, fuerza * 0.55))
	g.add_point(0.7, Color(color, fuerza * 0.2))
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT  # anillos: se ve pixel art
	tex.gradient = g
	s.texture = tex
	s.position = pos
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.z_index = 14
	s.scale = Vector2(1.5, 1.5) if fuego else Vector2.ONE
	# Titileo suave e irregular
	s.ready.connect(func():
		var t := s.create_tween().set_loops()
		var base_a := 1.0
		for i in 4:
			var a := base_a - randf_range(0.1, 0.35 if fuego else 0.15)
			t.tween_property(s, "modulate:a", a, randf_range(0.12, 0.3) if fuego else randf_range(0.6, 1.2))
			t.tween_property(s, "modulate:a", base_a, randf_range(0.12, 0.3) if fuego else randf_range(0.6, 1.2)))
	return s


## Viñeta: bordes oscuros y centro transparente.
static func textura_vineta() -> Texture2D:
	var tex := GradientTexture2D.new()
	tex.width = 160
	tex.height = 90
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.15, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.05, 0.02, 0.03, 0.55))
	g.add_point(0.55, Color(0, 0, 0, 0))
	tex.gradient = g
	return tex


## Celdas del mapa que usan cierto tile (por su nombre en arte/tiles/tiles.json).
static func celdas_con_tile(capa: TileMapLayer, nombre: String) -> Array[Vector2i]:
	var lista: Array[Vector2i] = []
	if not FileAccess.file_exists(TILES_JSON):
		return lista
	var info = JSON.parse_string(FileAccess.get_file_as_string(TILES_JSON))
	if typeof(info) != TYPE_DICTIONARY:
		return lista
	var coords = null
	for grupo in info.values():
		if grupo.has(nombre):
			coords = Vector2i(int(grupo[nombre][0]), int(grupo[nombre][1]))
	if coords == null:
		return lista
	for celda in capa.get_used_cells():
		if capa.get_cell_atlas_coords(celda) == coords:
			lista.append(celda)
	return lista
