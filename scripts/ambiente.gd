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


## Una rayita horizontal (arena volando con el viento).
static func _raya() -> Texture2D:
	var img := Image.create(10, 2, false, Image.FORMAT_RGBA8)
	for x in 10:
		var a := float(x + 1) / 10.0   # la cola se desvanece
		img.set_pixel(x, 0, Color(1, 1, 1, a))
		img.set_pixel(x, 1, Color(1, 1, 1, a * 0.5))
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


## Humo oscuro que sale de una chimenea y se lo lleva el viento.
static func humo(pos: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 24
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.texture = _pixel(2)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(2, 1)
	p.direction = Vector2(0.3, -1)
	p.spread = 12
	p.gravity = Vector2(3, -2)
	p.initial_velocity_min = 4
	p.initial_velocity_max = 7
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.6))
	curva.add_point(Vector2(1, 3.0))
	p.scale_amount_curve = curva
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(0.3, 0.26, 0.28, 0.9), Color(0.5, 0.45, 0.47, 0.6), Color(0.62, 0.57, 0.58, 0.0)])
	p.color_ramp = g
	return p


## Polvo que el viento arrastra a ras del suelo (pastizales).
static func viento(area: Vector2) -> CPUParticles2D:
	var p := _base(34, 5.0, area)
	p.direction = Vector2(1, -0.05)
	p.spread = 6
	p.gravity = Vector2(0, 0)
	p.initial_velocity_min = 30
	p.initial_velocity_max = 55
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.6, 0.0))
	g.set_color(1, Color(1.0, 0.9, 0.6, 0.0))
	g.add_point(0.3, Color(1.0, 0.92, 0.65, 0.75))
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
	var coords := coords_de(capa, [nombre])
	if coords.is_empty():
		return lista
	for celda in capa.get_used_cells():
		if capa.get_cell_atlas_coords(celda) in coords:
			lista.append(celda)
	return lista


## Coordenadas (en el atlas del mapa) de los tiles con estos nombres.
## Busca primero en el grupo del atlas que usa el mapa (ej. "neon" si el tileset usa neon.png),
## porque hay nombres repetidos entre atlas ("ceniza_1", "pared", "barril"...).
static func coords_de(capa: TileMapLayer, nombres: Array) -> Array[Vector2i]:
	var lista: Array[Vector2i] = []
	if not FileAccess.file_exists(TILES_JSON):
		return lista
	var info = JSON.parse_string(FileAccess.get_file_as_string(TILES_JSON))
	if typeof(info) != TYPE_DICTIONARY:
		return lista
	var grupo = null
	var ts := capa.tile_set
	if ts != null and ts.get_source_count() > 0:
		var fuente := ts.get_source(ts.get_source_id(0)) as TileSetAtlasSource
		if fuente != null and fuente.texture != null:
			grupo = info.get(fuente.texture.resource_path.get_file().get_basename(), null)
	for nombre in nombres:
		var c = null
		if grupo is Dictionary and grupo.has(nombre):
			c = grupo[nombre]
		else:   # como antes: el último atlas que tenga ese nombre
			for g in info.values():
				if g is Dictionary and g.has(nombre):
					c = g[nombre]
		if c != null:
			lista.append(Vector2i(int(c[0]), int(c[1])))
	return lista


## Ceniza que cae despacio y en silencio, como nieve (Valle Ceniza y el Bosque Calcinado).
static func nieve_ceniza(area: Vector2) -> CPUParticles2D:
	var p := _base(90, 10.0, area)
	p.texture = _pixel(2)
	p.direction = Vector2(0.1, 1)
	p.spread = 25
	p.gravity = Vector2(1, 3)
	p.initial_velocity_min = 4
	p.initial_velocity_max = 9
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.85, 0.86, 0.0))
	g.set_color(1, Color(0.75, 0.74, 0.76, 0.0))
	g.add_point(0.12, Color(0.88, 0.87, 0.9, 0.75))
	g.add_point(0.85, Color(0.78, 0.77, 0.8, 0.55))
	p.color_ramp = g
	return p


## Tormenta de óxido: ráfagas de polvo naranja que cruzan la pantalla de izquierda a derecha.
static func tormenta(area: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 200
	p.lifetime = 1.6
	p.preprocess = 1.6
	p.local_coords = true
	p.texture = _raya()
	p.position = Vector2(-20, area.y / 2.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(10, area.y / 2.0)
	p.direction = Vector2(1, 0.12)
	p.spread = 6
	p.gravity = Vector2(0, 8)
	p.initial_velocity_min = 260
	p.initial_velocity_max = 380
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var g := Gradient.new()   # arena clara: se distingue sobre el suelo oxidado
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.88, 0.66, 0.0), Color(1.0, 0.88, 0.66, 0.9), Color(0.98, 0.72, 0.45, 0.75), Color(0.98, 0.72, 0.45, 0.0)])
	p.color_ramp = g
	return p


## Burbujas tóxicas que suben y revientan (lodo del Sumidero, gas de Vesper en combate).
static func burbujas(area: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 26
	p.lifetime = 2.2
	p.preprocess = 2.2
	p.texture = _pixel(2)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area / 2.0
	p.direction = Vector2(0, -1)
	p.spread = 10
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 4
	p.initial_velocity_max = 12
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.85, 1.0])
	g.colors = PackedColorArray([Color(0.7, 1.0, 0.4, 0.0), Color(0.7, 1.0, 0.4, 0.8), Color(0.85, 1.0, 0.6, 0.6), Color(1, 1, 1, 0.0)])
	p.color_ramp = g
	return p


## Esporas que brillan y flotan alrededor de los hongos bioluminiscentes (en el mundo, no en la pantalla).
static func esporas(pos: Vector2, color: Color, radio := 14.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 8
	p.lifetime = 3.5
	p.preprocess = 3.5
	p.texture = _pixel()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radio
	p.direction = Vector2(0, -1)
	p.spread = 60
	p.gravity = Vector2(0, -2)
	p.initial_velocity_min = 2
	p.initial_velocity_max = 6
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(color, 0.0), Color(color, 0.9), Color(color, 0.0)])
	p.color_ramp = g
	p.z_index = 15
	return p


## Niebla tóxica verde que se arrastra por la pantalla (subterráneo).
static func niebla(area: Vector2, color := Color(0.55, 0.9, 0.45)) -> CPUParticles2D:
	var p := _base(22, 10.0, area)
	p.texture = _pixel(6)
	p.direction = Vector2(1, 0)
	p.spread = 20
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 2
	p.initial_velocity_max = 6
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(color, 0.0), Color(color, 0.09), Color(color, 0.0)])
	p.color_ramp = g
	p.z_index = 19
	return p
