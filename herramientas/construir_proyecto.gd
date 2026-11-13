extends Node
## Construye los recursos de Godot a partir del arte y de los mapas de texto:
##   - arte/tiles/exterior.tres y interior.tres (TileSets con colisiones)
##   - arte/tema.tres (tema pixel art: fuentes, paneles y botones)
##   - escenas/mapas/refugio_cero.tscn y superficie.tscn
##
## NO necesitas correrlo para jugar. Solo sirve para regenerar todo desde cero.
## Uso (desde la carpeta del proyecto):
##   godot --headless --editor --quit           (importa las imágenes)
##   godot --headless --path . res://herramientas/construir_proyecto.tscn
## OJO: sobrescribe los mapas; si ya los editaste a mano en Godot, perderás esos cambios.

const T := 16

const EXTERIOR := {
	".": ["tierra_1", "tierra_2", "tierra_3"], ":": ["tierra_oscura"],
	"=": ["asfalto_1", "asfalto_2", "asfalto_1", "asfalto_2", "asfalto_grieta"], "-": ["asfalto_linea"],
	"c": ["concreto"], "\"": ["pasto_1", "pasto_2"], "s": ["arena_1", "arena_2"], "T": ["charco_toxico"],
	"V": ["vacio"], "N": ["borde_norte"], "#": ["muro_top"], "W": ["muro"],
	"o": ["barril"], "O": ["barril_toxico"], "k": ["chatarra"], "n": ["neumaticos"], "Y": ["arbol_muerto"],
	"P": ["cartel"], "F": ["fogata"], "z": ["cama_carton"], "v": ["viga"], "|": ["valla"],
	"[": ["auto_izq"], "]": ["auto_der"], "R": ["contenedor_rojo_top"], "r": ["contenedor_rojo"],
	"U": ["contenedor_azul_top"], "u": ["contenedor_azul"], "{": ["porton_izq"], "}": ["porton_der"],
	"H": ["escotilla"],
}
const INTERIOR := {
	"#": ["pared_top"], "W": ["pared"], ".": ["piso_1", "piso_1", "piso_1", "piso_2"], ",": ["piso_2"],
	"b": ["cama_top"], "B": ["cama_bot"], "m": ["mesa_izq"], "M": ["mesa_der"], "L": ["casillero"],
	"G": ["generador"], "E": ["estante"], "H": ["escalera"], "x": ["caja"], "a": ["alfombra"],
}

var tiles_info: Dictionary
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 99
	tiles_info = JSON.parse_string(FileAccess.get_file_as_string("res://arte/tiles/tiles.json"))
	var ts_ext := _crear_tileset("exterior", ["pasto_1", "pasto_2"])
	var ts_int := _crear_tileset("interior", [])
	_crear_tema()
	_crear_refugio(ts_int)
	_crear_superficie(ts_ext)
	print("Proyecto construido.")
	get_tree().quit()


# ---------------------------------------------------------------------------
func _crear_tileset(nombre: String, pastos: Array) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "pasto")
	ts.set_custom_data_layer_type(0, TYPE_BOOL)
	var fuente := TileSetAtlasSource.new()
	fuente.texture = load("res://arte/tiles/%s.png" % nombre)
	fuente.texture_region_size = Vector2i(T, T)
	ts.add_source(fuente, 0)
	var info: Dictionary = tiles_info[nombre]
	for nombre_tile in info:
		var d: Array = info[nombre_tile]
		var coords := Vector2i(int(d[0]), int(d[1]))
		fuente.create_tile(coords)
		var datos := fuente.get_tile_data(coords, 0)
		if d[2]:
			datos.add_collision_polygon(0)
			datos.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
		datos.set_custom_data("pasto", nombre_tile in pastos)
	var ruta := "res://arte/tiles/%s.tres" % nombre
	ResourceSaver.save(ts, ruta)
	return load(ruta)


func _coords(nombre_atlas: String, nombre_tile: String) -> Vector2i:
	var d: Array = tiles_info[nombre_atlas][nombre_tile]
	return Vector2i(int(d[0]), int(d[1]))


# ---------------------------------------------------------------------------
func _textura_9(ruta: String, margen: int, contenido: Vector4) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(ruta)
	s.texture_margin_left = margen
	s.texture_margin_top = margen
	s.texture_margin_right = margen
	s.texture_margin_bottom = margen
	s.content_margin_left = contenido.x
	s.content_margin_top = contenido.y
	s.content_margin_right = contenido.z
	s.content_margin_bottom = contenido.w
	return s


func _crear_tema() -> void:
	var tema := Theme.new()
	var pixelify: FontFile = load("res://arte/fuentes/PixelifySans.ttf")
	var press: FontFile = load("res://arte/fuentes/PressStart2P-Regular.ttf")
	tema.default_font = pixelify
	tema.default_font_size = 11
	var claro := Color("#f0e6d2")

	tema.set_stylebox("panel", "PanelContainer", _textura_9("res://arte/interfaz/panel.png", 6, Vector4(8, 6, 8, 6)))
	tema.set_stylebox("panel", "Panel", _textura_9("res://arte/interfaz/panel.png", 6, Vector4(8, 6, 8, 6)))
	var btn := Vector4(6, 3, 6, 4)
	tema.set_stylebox("normal", "Button", _textura_9("res://arte/interfaz/boton.png", 4, btn))
	tema.set_stylebox("hover", "Button", _textura_9("res://arte/interfaz/boton_encima.png", 4, btn))
	tema.set_stylebox("pressed", "Button", _textura_9("res://arte/interfaz/boton_pulsado.png", 4, btn))
	tema.set_stylebox("disabled", "Button", _textura_9("res://arte/interfaz/boton_desactivado.png", 4, btn))
	tema.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	tema.set_color("font_color", "Button", claro)
	tema.set_color("font_hover_color", "Button", Color("#ffe0a0"))
	tema.set_color("font_pressed_color", "Button", Color("#fff4d0"))
	tema.set_color("font_disabled_color", "Button", Color("#6e6258"))
	tema.set_color("font_color", "Label", claro)
	tema.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	tema.set_constant("shadow_offset_x", "Label", 1)
	tema.set_constant("shadow_offset_y", "Label", 1)

	tema.set_type_variation("TextoChico", "Label")
	tema.set_font_size("font_size", "TextoChico", 10)

	tema.set_type_variation("NombreDialogo", "Label")
	tema.set_color("font_color", "NombreDialogo", Color("#ffd24d"))

	tema.set_type_variation("Titulo", "Label")
	tema.set_font("font", "Titulo", press)
	tema.set_font_size("font_size", "Titulo", 8)
	tema.set_color("font_color", "Titulo", Color("#ffd24d"))

	tema.set_type_variation("TituloGrande", "Label")
	tema.set_font("font", "TituloGrande", press)
	tema.set_font_size("font_size", "TituloGrande", 40)
	tema.set_color("font_color", "TituloGrande", Color("#d9dde2"))
	tema.set_color("font_outline_color", "TituloGrande", Color("#3a2a22"))
	tema.set_constant("outline_size", "TituloGrande", 8)
	tema.set_color("font_shadow_color", "TituloGrande", Color("#c06a36"))
	tema.set_constant("shadow_offset_x", "TituloGrande", 3)
	tema.set_constant("shadow_offset_y", "TituloGrande", 3)

	tema.set_type_variation("NumeroDanio", "Label")
	tema.set_font("font", "NumeroDanio", press)
	tema.set_font_size("font_size", "NumeroDanio", 8)
	tema.set_color("font_outline_color", "NumeroDanio", Color.BLACK)
	tema.set_constant("outline_size", "NumeroDanio", 4)

	tema.set_type_variation("BotonRedondo", "Button")
	var redondo := StyleBoxFlat.new()
	redondo.bg_color = Color(0.75, 0.42, 0.21, 0.75)
	redondo.set_corner_radius_all(18)
	redondo.set_border_width_all(2)
	redondo.border_color = Color(0.1, 0.08, 0.1, 0.9)
	redondo.anti_aliasing = false
	var redondo_pulsado := redondo.duplicate()
	redondo_pulsado.bg_color = Color(1.0, 0.7, 0.35, 0.9)
	tema.set_stylebox("normal", "BotonRedondo", redondo)
	tema.set_stylebox("hover", "BotonRedondo", redondo)
	tema.set_stylebox("pressed", "BotonRedondo", redondo_pulsado)
	tema.set_font("font", "BotonRedondo", press)
	tema.set_font_size("font_size", "BotonRedondo", 16)
	ResourceSaver.save(tema, "res://arte/tema.tres")


# ---------------------------------------------------------------------------
func _leer_mapa(nombre: String) -> PackedStringArray:
	var texto := FileAccess.get_file_as_string("res://herramientas/mapas/%s.txt" % nombre)
	return texto.strip_edges(false, true).split("\n")


func _nuevo_mapa(nombre: String, nombre_mapa: String, tileset: TileSet, atlas: String, leyenda: Dictionary) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = nombre
	raiz.set_script(load("res://scripts/mapa.gd"))
	raiz.set("nombre_mapa", nombre_mapa)
	var suelo := TileMapLayer.new()
	suelo.name = "Suelo"
	suelo.tile_set = tileset
	raiz.add_child(suelo)
	suelo.owner = raiz
	var filas := _leer_mapa(nombre_mapa)
	for y in filas.size():
		for x in filas[y].length():
			var ch := filas[y][x]
			if not leyenda.has(ch):
				continue
			var opciones: Array = leyenda[ch]
			var tile: String = opciones[rng.randi() % opciones.size()]
			suelo.set_cell(Vector2i(x, y), 0, _coords(atlas, tile))
	for grupo in ["Zonas", "Disparadores", "Entradas", "Entidades"]:
		var n := Node2D.new()
		n.name = grupo
		if grupo == "Entidades":
			n.y_sort_enabled = true
		raiz.add_child(n)
		n.owner = raiz
	return raiz


func _px(tx: float, ty: float) -> Vector2:
	return Vector2(tx * T + T / 2.0, ty * T + T / 2.0)


func _entrada(raiz: Node, nombre: String, pos: Vector2) -> void:
	var m := Marker2D.new()
	m.name = nombre
	m.position = pos
	raiz.get_node("Entradas").add_child(m)
	m.owner = raiz


func _interactuable(raiz: Node, nombre: String, pos: Vector2, evento: String, props := {}) -> void:
	var n := Node2D.new()
	n.name = nombre
	n.position = pos
	n.set_script(load("res://scripts/interactuable.gd"))
	n.set("evento", evento)
	for k in props:
		n.set(k, props[k])
	raiz.get_node("Entidades").add_child(n)
	n.owner = raiz


func _disparador(raiz: Node, nombre: String, tx: int, ty: int, tw: int, th: int, evento: String) -> void:
	var n := Node2D.new()
	n.name = nombre
	n.position = Vector2(tx * T, ty * T)
	n.set_script(load("res://scripts/disparador.gd"))
	n.set("evento", evento)
	n.set("tamano", Vector2(tw * T, th * T))
	raiz.get_node("Disparadores").add_child(n)
	n.owner = raiz


func _zona(raiz: Node, nombre: String, tx: int, ty: int, tw: int, th: int, criaturas: Array[String], nmin: int, nmax: int) -> void:
	var n := Node2D.new()
	n.name = nombre
	n.position = Vector2(tx * T, ty * T)
	n.set_script(load("res://scripts/zona_encuentro.gd"))
	n.set("tamano", Vector2(tw * T, th * T))
	n.set("criaturas", criaturas)
	n.set("nivel_minimo", nmin)
	n.set("nivel_maximo", nmax)
	raiz.get_node("Zonas").add_child(n)
	n.owner = raiz


func _terminar_mapa(raiz: Node2D, pos_pan: Vector2, ruta: String) -> void:
	var pan: Node2D = load("res://escenas/pan.tscn").instantiate()
	pan.position = pos_pan
	raiz.get_node("Entidades").add_child(pan)
	pan.owner = raiz
	var hud: Node = load("res://escenas/ui/hud.tscn").instantiate()
	raiz.add_child(hud)
	hud.owner = raiz
	var escena := PackedScene.new()
	escena.pack(raiz)
	ResourceSaver.save(escena, ruta)


# ---------------------------------------------------------------------------
func _crear_refugio(ts: TileSet) -> void:
	var r := _nuevo_mapa("RefugioCero", "refugio_cero", ts, "interior", INTERIOR)
	r.set("zoom_camara", 1.6)
	_entrada(r, "Cama", _px(2, 5))
	_entrada(r, "Escalera", _px(5, 3))
	_interactuable(r, "Mochila", _px(3, 7), "mochila", { "textura": load("res://arte/objetos/mochila.png"), "ocultar_si": "tiene_mochila" })
	_interactuable(r, "Mesa", _px(6.5, 7) + Vector2(0, -3), "mesa", { "textura": load("res://arte/objetos/cartas.png"), "radio": 22.0 })
	_interactuable(r, "Collar", _px(14, 4) + Vector2(0, -3), "collar", { "textura": load("res://arte/objetos/collar.png"), "ocultar_si": "tiene_collar", "radio": 22.0 })
	_interactuable(r, "Cama", _px(1, 4.5), "cama", { "radio": 22.0 })
	_interactuable(r, "Escalera", _px(5, 2), "escalera", { "radio": 22.0 })
	_terminar_mapa(r, _px(2, 5), "res://escenas/mapas/refugio_cero.tscn")


func _crear_superficie(ts: TileSet) -> void:
	var s := _nuevo_mapa("Superficie", "superficie", ts, "exterior", EXTERIOR)
	_entrada(s, "Escotilla", _px(6, 31))
	_entrada(s, "Mirador", _px(30, 4))
	_entrada(s, "Fogata", _px(56, 12))
	# Prólogo
	_interactuable(s, "Escotilla", _px(6, 30), "escotilla", { "radio": 22.0 })
	_interactuable(s, "Recluta", _px(20, 31), "recluta", {
		"textura": load("res://arte/personajes/recluta_mapa.png"), "solido": true,
		"mostrar_si": "recluta_visible", "ocultar_si": "recluta_derrotado", "radio": 22.0 })
	_disparador(s, "GatoAtrapado", 14, 26, 6, 8, "gato_atrapado")
	_disparador(s, "Camino", 22, 29, 2, 5, "camino")
	_disparador(s, "Acantilado", 25, 3, 1, 36, "acantilado")
	# Saqueo (cartas de vínculo, monedas y reliquias)
	var saqueo := load("res://arte/objetos/saqueo.png")
	var puntos := [Vector2(10, 12), Vector2(30, 22), Vector2(45, 12), Vector2(48, 36), Vector2(66, 22)]
	for i in puntos.size():
		var nombre := "Saqueo%d" % (i + 1)
		_interactuable(s, nombre, _px(puntos[i].x, puntos[i].y), "saqueo", { "textura": saqueo, "ocultar_si": "saqueo_" + nombre })
	# Afueras de Bastión de Óxido
	_interactuable(s, "Cartel", _px(64, 8), "cartel_bastion", { "radio": 22.0 })
	_interactuable(s, "Ciudadano", _px(59, 9), "ciudadano", { "textura": load("res://arte/personajes/ciudadano_mapa.png"), "solido": true, "radio": 22.0 })
	_interactuable(s, "CamaCarton", _px(55, 11), "cama_carton", { "radio": 14.0 })
	_interactuable(s, "Porton", _px(61.5, 6), "porton", { "radio": 26.0 })
	# Zonas de criaturas (solo aparecen al pisar pasto seco)
	_zona(s, "PastizalNorte", 25, 5, 13, 9, ["bestia_blanca", "gato_mutado"], 1, 2)
	_zona(s, "PastizalCentro", 38, 18, 13, 9, ["gato_mutado", "aves_negras"], 1, 2)
	_zona(s, "PastizalSur", 27, 34, 15, 5, ["aves_negras", "bestia_blanca", "oso_de_escoria"], 1, 3)
	_zona(s, "PastizalBastion", 51, 12, 9, 9, ["aves_negras", "oso_de_escoria", "gato_mutado"], 2, 3)
	_terminar_mapa(s, _px(6, 31), "res://escenas/mapas/superficie.tscn")
