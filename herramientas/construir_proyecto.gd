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
	# Bastión de Óxido
	"a": ["arena_oxido"], "p": ["placa_1"], "q": ["placa_2"], "d": ["duna_1"], "S": ["duna_2"],
	"j": ["chatarral_1"], "J": ["chatarral_2"], "D": ["puerta_roja"], "E": ["puerta_azul"],
	"w": ["ventana_roja"], "e": ["ventana_azul"], "L": ["farol"], "b": ["cinta_1"], "B": ["cinta_2"],
	"l": ["aceite"], "g": ["lecho_1"], "G": ["lecho_2"], "x": ["reja"],
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
	if "solo_tema" in OS.get_cmdline_user_args():
		_crear_tema()  # godot --headless --path . res://herramientas/construir_proyecto.tscn -- solo_tema
		print("Tema construido.")
		get_tree().quit()
		return
	var ts_ext := _crear_tileset("exterior", ["pasto_1", "pasto_2", "duna_1", "duna_2", "chatarral_1", "chatarral_2"])
	var ts_int := _crear_tileset("interior", [])
	_crear_tema()
	_crear_refugio(ts_int)
	_crear_superficie(ts_ext)
	_crear_bastion(ts_ext)
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
	# Letra con un poco más de aire: 1 píxel entre letras y 3 entre palabras (si no, se ven pegadas)
	var letra := FontVariation.new()
	letra.base_font = pixelify
	letra.spacing_glyph = 1
	letra.spacing_space = 3
	tema.default_font = letra
	tema.default_font_size = 11
	tema.set_constant("line_spacing", "Label", 4)
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


func _zona(raiz: Node, nombre: String, tx: int, ty: int, tw: int, th: int, criaturas: Array[String], nmin: int, nmax: int,
		fondo := "pastizal", en_tormenta: Array[String] = []) -> void:
	var n := Node2D.new()
	n.name = nombre
	n.position = Vector2(tx * T, ty * T)
	n.set_script(load("res://scripts/zona_encuentro.gd"))
	n.set("tamano", Vector2(tw * T, th * T))
	n.set("criaturas", criaturas)
	n.set("nivel_minimo", nmin)
	n.set("nivel_maximo", nmax)
	n.set("fondo", fondo)
	n.set("criaturas_tormenta", en_tormenta)
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
	_entrada(s, "Porton", _px(61.5, 7))
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
	_zona(s, "PastizalSur", 27, 34, 15, 5, ["aves_negras", "bestia_blanca", "oso_de_escoria"], 1, 3, "paramo")
	_zona(s, "PastizalBastion", 51, 12, 9, 9, ["aves_negras", "oso_de_escoria", "gato_mutado"], 2, 3, "chatarra")
	_terminar_mapa(s, _px(6, 31), "res://escenas/mapas/superficie.tscn")


# ---------------------------------------------------------------------------
# Construcción grande (scripts/decorado.gd): la posición es la BASE de la imagen.
func _decorado(raiz: Node, nombre: String, pos: Vector2, imagen: String, colision: Vector2, props := {}) -> void:
	var n := Node2D.new()
	n.name = nombre
	n.position = pos
	n.set_script(load("res://scripts/decorado.gd"))
	n.set("textura", load("res://arte/decorados/%s.png" % imagen))
	n.set("colision", colision)
	for k in props:
		n.set(k, props[k])
	raiz.get_node("Entidades").add_child(n)
	n.owner = raiz


func _crear_bastion(ts: TileSet) -> void:
	var b := _nuevo_mapa("BastionOxido", "bastion_oxido", ts, "exterior", EXTERIOR)
	var T16 := float(T)
	_entrada(b, "Puerta", _px(29.5, 42))
	_entrada(b, "Posada", _px(16, 39.5))
	_entrada(b, "Plaza", _px(30.5, 30.5))
	_entrada(b, "Trono", _px(33, 10))
	# --- Construcciones grandes
	var humo_tritu: Array[Vector2] = [Vector2(26, -80)]
	_decorado(b, "Trituradora", Vector2(15 * T16, 30 * T16), "trituradora", Vector2(88, 18),
		{ "cuadros": 2, "cuadros_por_segundo": 5.0, "humo": humo_tritu, "detener_si": "trituradora_apagada" })
	_decorado(b, "Buque", Vector2(20 * T16, 10 * T16 + 8), "buque", Vector2(220, 26))
	_decorado(b, "Trono", Vector2(33 * T16 + 8, 8 * T16), "trono", Vector2(48, 10))
	_decorado(b, "Estatua", Vector2(30 * T16 + 8, 28 * T16), "estatua", Vector2(28, 8))
	_decorado(b, "Tanque", Vector2(23 * T16, 27 * T16), "tanque", Vector2(40, 8))
	_decorado(b, "Tablon", Vector2(36 * T16, 26 * T16), "tablon", Vector2(26, 6))
	_decorado(b, "Tienda", Vector2(38 * T16 + 8, 32 * T16), "tienda", Vector2(72, 14))
	_decorado(b, "Posada", Vector2(16 * T16, 38 * T16), "posada", Vector2(88, 4))
	_decorado(b, "Mural", Vector2(4 * T16 + 8, 34 * T16), "mural", Vector2.ZERO)
	_decorado(b, "Torre1", Vector2(51 * T16, 13 * T16), "torre", Vector2(30, 8))
	_decorado(b, "Torre2", Vector2(56 * T16, 26 * T16), "torre", Vector2(30, 8))
	_decorado(b, "Torre3", Vector2(50 * T16, 37 * T16), "torre", Vector2(30, 8))
	_decorado(b, "Grua", Vector2(54 * T16, 10 * T16), "grua", Vector2(30, 10))
	# --- Vecinos (sus diálogos y misiones están en historia.gd)
	var tex := func(n: String) -> Texture2D: return load("res://arte/personajes/%s.png" % n)
	_interactuable(b, "GuardiaPuerta", _px(26.6, 41), "guardia_puerta", { "textura": load("res://arte/personajes/recluta_mapa.png"), "solido": true, "ocultar_si": "bastion_liberado", "radio": 22.0 })
	_interactuable(b, "OdilaTanque", _px(24.4, 28.4), "odila", { "textura": tex.call("odila_mapa"), "solido": true, "ocultar_si": "escena_rictus_vista", "radio": 22.0 })
	_interactuable(b, "Balde", _px(23.6, 28.6), "", { "textura": load("res://arte/objetos/balde.png"), "ocultar_si": "escena_rictus_vista" })
	_interactuable(b, "Odila", _px(19.6, 38.2), "odila", { "textura": tex.call("odila_mapa"), "solido": true, "mostrar_si": "escena_rictus_vista", "radio": 22.0 })
	_interactuable(b, "LiaEnferma", _px(13.2, 39.6), "lia", { "textura": tex.call("lia_mapa"), "ocultar_si": "lia_sana", "radio": 20.0 })
	_interactuable(b, "Lia", _px(21, 39), "lia", { "textura": tex.call("lia_mapa"), "solido": true, "mostrar_si": "lia_sana", "radio": 20.0 })
	_interactuable(b, "Mila", _px(38.5, 32.6), "tienda", { "textura": tex.call("mila_mapa"), "solido": true, "radio": 24.0 })
	_interactuable(b, "Bruno", _px(45, 24.4), "bruno", { "textura": tex.call("bruno_mapa"), "solido": true, "radio": 22.0 })
	_interactuable(b, "Rosa", _px(6.5, 35.2), "rosa", { "textura": tex.call("rosa_mapa"), "solido": true, "radio": 22.0 })
	_interactuable(b, "Tavo", _px(10, 13.5), "tavo", { "textura": tex.call("tavo_mapa"), "solido": true, "radio": 22.0 })
	_interactuable(b, "VecinoCola1", _px(19.4, 26.6), "vecino_cola", { "textura": load("res://arte/personajes/ciudadano_mapa.png"), "solido": true, "radio": 20.0 })
	_interactuable(b, "VecinaCola2", _px(20.2, 28.4), "vecina_cola", { "textura": tex.call("vecina_mapa"), "solido": true, "radio": 20.0 })
	_interactuable(b, "Guardia1", _px(29, 19.2), "guardia_1", { "textura": load("res://arte/personajes/recluta_mapa.png"), "solido": true, "ocultar_si": "guardia_1_derrotado", "radio": 22.0 })
	_interactuable(b, "Guardia2", _px(33, 13.2), "guardia_2", { "textura": load("res://arte/personajes/recluta_mapa.png"), "solido": true, "ocultar_si": "guardia_2_derrotado", "radio": 22.0 })
	_interactuable(b, "Rictus", _px(33, 8.7), "rictus", { "textura": tex.call("rictus_mapa"), "solido": true, "ocultar_si": "rictus_derrotado", "radio": 24.0 })
	_interactuable(b, "RictusEscena", _px(31, 22), "", { "textura": tex.call("rictus_mapa"), "mostrar_si": "rictus_en_plaza" })
	# --- Cosas para investigar
	_interactuable(b, "InvTrituradora", _px(16.5, 30.6), "inv_trituradora", { "radio": 22.0 })
	_interactuable(b, "InvTanque", _px(22, 27.6), "inv_tanque", { "radio": 20.0 })
	_interactuable(b, "InvTablon", _px(36, 26.6), "inv_tablon", { "radio": 20.0 })
	_interactuable(b, "InvEstatua", _px(30.5, 28.6), "inv_estatua", { "radio": 20.0 })
	_interactuable(b, "InvMural", _px(4.5, 34.2), "inv_mural", { "radio": 20.0 })
	_interactuable(b, "InvRadio", _px(25.4, 42), "inv_radio", { "textura": load("res://arte/objetos/radio.png"), "radio": 18.0 })
	_interactuable(b, "InvCinta", _px(13, 18), "inv_cinta", { "radio": 20.0 })
	_interactuable(b, "InvBuque", _px(20, 11.2), "inv_buque", { "radio": 26.0 })
	_interactuable(b, "Nido", _px(54, 10.6), "nido", { "radio": 24.0 })
	_interactuable(b, "CajaBruno", _px(55.5, 10.4), "caja_bruno", { "textura": load("res://arte/objetos/caja_herramientas.png"), "mostrar_si": "nido_libre", "ocultar_si": "caja_recogida" })
	_interactuable(b, "CamaPosada", _px(16, 37.4), "cama_posada", { "radio": 26.0 })
	var saqueo := load("res://arte/objetos/saqueo.png")
	for p in [["SaqueoB1", Vector2(3, 5)], ["SaqueoB2", Vector2(57, 40)], ["SaqueoB3", Vector2(41, 6)], ["SaqueoB4", Vector2(9, 42)]]:
		_interactuable(b, p[0], _px(p[1].x, p[1].y), "saqueo", { "textura": saqueo, "ocultar_si": "saqueo_" + p[0] })
	# --- Eventos al pisar
	_disparador(b, "Salida", 28, 45, 4, 1, "salida_bastion")
	_disparador(b, "PasoGuardia1", 30, 18, 3, 1, "guardia_1")
	_disparador(b, "PasoGuardia2", 30, 12, 3, 1, "guardia_2")
	# --- Criaturas: vertedero (chatarra) y dunas (tierra y electricidad)
	var tormenta_chatarra: Array[String] = ["enjambre_mecanico", "enjambre_mecanico", "oso_de_escoria"]
	_zona(b, "Vertedero", 1, 2, 9, 9, ["enjambre_mecanico", "oso_de_escoria", "gato_mutado"], 1, 3, "chatarra", tormenta_chatarra)
	var tormenta_dunas: Array[String] = ["enjambre_mecanico", "gusano_devorador"]
	_zona(b, "DunasTorres", 48, 2, 11, 14, ["bailarina_electrica", "bailarina_electrica", "gusano_devorador"], 1, 3, "dunas", tormenta_dunas)
	_zona(b, "DunasSur", 48, 16, 11, 28, ["gusano_devorador", "aves_negras", "bailarina_electrica"], 1, 3, "dunas", tormenta_dunas)
	_terminar_mapa(b, _px(29.5, 42), "res://escenas/mapas/bastion_oxido.tscn")
