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
	# Autopista Quemada (camino al Sumidero)
	"%": ["ceniza_1"], "&": ["ceniza_2"], "_": ["baranda"], "~": ["asfalto_roto"],
}
## El Sumidero (atlas "subterraneo"): ver la leyenda en herramientas/componer_mapas.py
const SUBTERRANEO := {
	"#": ["roca"], "W": ["pared"], "w": ["pared_tubo"], "A": ["azulejo"], "M": ["azulejo_letrero"], "G": ["azulejo_grafiti"],
	".": ["anden_1", "anden_1", "anden_1", "anden_2"], ",": ["anden_2"], "_": ["anden_borde"], "=": ["via"],
	"~": ["lodo_1", "lodo_2"], "o": ["orilla"], "|": ["pasarela_v"], "-": ["pasarela_h"], "x": ["pasarela_rota"],
	"h": ["hongos_1", "hongos_2"], "m": ["musgo"], "r": ["rejilla"], "c": ["charco"], "t": ["tubo_h"], "T": ["tubo_v"],
	"l": ["lab_piso"], "L": ["lab_linea"], "P": ["lab_pared"], "K": ["cristal"], "g": ["gas_1"], "q": ["gas_2"],
	"n": ["oscuro_1"], "N": ["oscuro_2"], "E": ["escalera"], "k": ["cajas"], "b": ["barril_verde"], "z": ["colchon"],
	"f": ["fogon"], "H": ["hongo_grande"], "v": ["valla_lab"],
}
## Ciudad Neón y el Paso del Smog (atlas "neon"): ver la leyenda en herramientas/componer_mapas.py
const NEON := {
	".": ["asfalto_1", "asfalto_2", "asfalto_1"], "-": ["asfalto_linea"], ",": ["calle_1", "calle_1", "calle_2"], "=": ["calle_linea"],
	":": ["acera_1"], ";": ["acera_2"], "s": ["smog_1"], "S": ["smog_2"], "a": ["alfombra_1"], "A": ["alfombra_2"],
	"#": ["techo"], "W": ["pared"], "w": ["pared_ventana"], "C": ["pared_cian"], "M": ["pared_magenta"],
	"c": ["linea_cian"], "m": ["linea_magenta"], "t": ["tarima"], "V": ["vacio"], "r": ["rejilla"], "l": ["charco_luz"],
	"g": ["guardarrail"], "o": ["barril"], "k": ["cajas"], "b": ["basura"], "n": ["cono"], "u": ["auto_smog"],
	"x": ["arcade"], "X": ["mesa_casino"],
}
## Valle Ceniza y el Bosque Calcinado (atlas "ceniza")
const CENIZA := {
	".": ["ceniza_1", "ceniza_1", "ceniza_2"], ",": ["ceniza_brote"], "_": ["sendero_1", "sendero_1", "sendero_2"],
	"h": ["hierba_1"], "H": ["hierba_2"], "b": ["brasa_1"], "B": ["brasa_2"], "u": ["huerto"], "p": ["pasto_verde"],
	"m": ["madera"], "~": ["agua_1", "agua_2"], "=": ["puente"], "#": ["bosque"], "T": ["tronco"], "t": ["tocon"],
	"r": ["roca"], "y": ["arbusto"], "l": ["lena"], "f": ["cerca"], "F": ["cerca_v"], "w": ["barril_agua"], "k": ["canasto"],
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
	var ts_ext := _crear_tileset("exterior", ["pasto_1", "pasto_2", "duna_1", "duna_2", "chatarral_1", "chatarral_2", "ceniza_1", "ceniza_2"])
	var ts_int := _crear_tileset("interior", [])
	var ts_sub := _crear_tileset("subterraneo", ["hongos_1", "hongos_2", "gas_1", "gas_2", "oscuro_1", "oscuro_2"], ["charco"])
	_crear_tema()
	_crear_refugio(ts_int)
	_crear_superficie(ts_ext)
	_crear_bastion(ts_ext)
	_crear_autopista(ts_ext)
	_crear_sumidero(ts_sub)
	var ts_neon := _crear_tileset("neon", ["smog_1", "smog_2", "alfombra_1", "alfombra_2"])
	var ts_ceniza := _crear_tileset("ceniza", ["hierba_1", "hierba_2"])
	_crear_paso_smog(ts_neon)
	_crear_ciudad_neon(ts_neon)
	_crear_bosque(ts_ceniza)
	_crear_valle(ts_ceniza)
	print("Proyecto construido.")
	get_tree().quit()


# ---------------------------------------------------------------------------
## pastos: tiles donde salen criaturas. toxicos: charcos que pueden infectar a tu carta al pisarlos.
func _crear_tileset(nombre: String, pastos: Array, toxicos: Array = []) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "pasto")
	ts.set_custom_data_layer_type(0, TYPE_BOOL)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(1, "toxico")
	ts.set_custom_data_layer_type(1, TYPE_BOOL)
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
		datos.set_custom_data("toxico", nombre_tile in toxicos)
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
	var humo := Array([], TYPE_VECTOR2, &"", null)
	for p in props.get("humo", []):
		humo.append(p)
	n.set("humo", humo)
	for k in props:
		if k != "humo":
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
	_entrada(b, "Este", _px(57.5, 30.5))
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
	# Salida este (hacia la Autopista y el Sumidero): contenedores caídos hasta que Bruno los mueve con su grúa
	_decorado(b, "Barricada", Vector2(59 * T16 + 8, 32 * T16), "barricada", Vector2(16, 36), { "ocultar_si": "salida_este_abierta" })
	_interactuable(b, "BarricadaInv", _px(58, 30.5), "barricada", { "ocultar_si": "salida_este_abierta", "radio": 22.0 })
	_disparador(b, "SalidaEste", 59, 30, 1, 2, "salida_este")
	# Ciudad viva: vecinos que van y vienen por la plaza y el barrio
	_vecino(b, "Paseante1", "paseo_bastion", "ciudadano_mapa", [_px(21, 29), _px(28, 29), _px(28, 33), _px(21, 33)],
		{ "murmullos": ["Ojalá llueva...", "¿Viste al niño del collar?", "Escóndete las monedas."] })
	_vecino(b, "Paseante2", "paseo_bastion", "vecina_mapa", [_px(9, 15), _px(9, 30), _px(16, 32), _px(9, 32)],
		{ "murmullos": ["Otra cuota más...", "Mi hijo tose por el polvo.", "Shh, los guardias."] })
	_disparador(b, "PasoGuardia1", 30, 18, 3, 1, "guardia_1")
	_disparador(b, "PasoGuardia2", 30, 12, 3, 1, "guardia_2")
	# --- Criaturas: vertedero (chatarra) y dunas (tierra y electricidad)
	var tormenta_chatarra: Array[String] = ["enjambre_mecanico", "enjambre_mecanico", "oso_de_escoria"]
	_zona(b, "Vertedero", 1, 2, 9, 9, ["enjambre_mecanico", "oso_de_escoria", "gato_mutado"], 1, 3, "chatarra", tormenta_chatarra)
	var tormenta_dunas: Array[String] = ["enjambre_mecanico", "gusano_devorador"]
	_zona(b, "DunasTorres", 48, 2, 11, 14, ["bailarina_electrica", "bailarina_electrica", "gusano_devorador"], 1, 3, "dunas", tormenta_dunas)
	_zona(b, "DunasSur", 48, 16, 11, 28, ["gusano_devorador", "aves_negras", "bailarina_electrica"], 1, 3, "dunas", tormenta_dunas)
	_terminar_mapa(b, _px(29.5, 42), "res://escenas/mapas/bastion_oxido.tscn")


# ---------------------------------------------------------------------------
# Ciudad 2: la Autopista Quemada y El Sumidero
# ---------------------------------------------------------------------------

## Vecino que camina por su ruta (scripts/vecino.gd). Sin ruta (o con un solo punto) se queda quieto.
func _vecino(raiz: Node, nombre: String, evento: String, imagen: String, ruta: Array, props := {}) -> void:
	var n := Node2D.new()
	n.name = nombre
	n.set_script(load("res://scripts/vecino.gd"))
	n.position = ruta[0]
	n.set("evento", evento)
	n.set("textura", load("res://arte/personajes/%s.png" % imagen))
	n.set("radio", 22.0)
	var r := Array([], TYPE_VECTOR2, &"", null)
	for p in ruta:
		r.append(p)
	n.set("ruta", r)
	if r.size() < 2:
		n.set("solido", true)
	var m := Array([], TYPE_STRING, &"", null)
	for t in props.get("murmullos", []):
		m.append(str(t))
	n.set("murmullos", m)
	for k in props:
		if k != "murmullos":
			n.set(k, props[k])
	raiz.get_node("Entidades").add_child(n)
	n.owner = raiz


func _gotera(raiz: Node, pos: Vector2) -> void:
	var n := Node2D.new()
	n.name = "Gotera%d" % raiz.get_node("Entidades").get_child_count()
	n.position = pos
	n.set_script(load("res://scripts/gotera.gd"))
	raiz.get_node("Entidades").add_child(n)
	n.owner = raiz


func _rata(raiz: Node, pos: Vector2, hasta: Vector2) -> void:
	var n := Node2D.new()
	n.name = "Rata%d" % raiz.get_node("Entidades").get_child_count()
	n.position = pos
	n.set_script(load("res://scripts/rata.gd"))
	n.set("hasta", hasta)
	raiz.get_node("Entidades").add_child(n)
	n.owner = raiz


func _hongo(raiz: Node, nombre: String, pos: Vector2, morado: bool) -> void:
	_decorado(raiz, nombre, pos, "hongo_morado" if morado else "hongo_cian", Vector2(10, 6))
	var n: Node = raiz.get_node("Entidades/" + nombre)
	n.set_meta("luz", Color(0.75, 0.5, 1.0) if morado else Color(0.35, 1.0, 0.9))
	n.set_meta("luz_pos", Vector2(0, -40))
	n.set_meta("esporas", true)


func _crear_autopista(ts: TileSet) -> void:
	var a := _nuevo_mapa("Autopista", "autopista", ts, "exterior", EXTERIOR)
	var T16 := float(T)
	_entrada(a, "Oeste", _px(1.5, 12))
	_entrada(a, "Metro", _px(59, 9.5))
	_decorado(a, "BocaMetro", Vector2(59 * T16 + 8, 8 * T16), "boca_metro", Vector2.ZERO)
	_decorado(a, "Letrero", Vector2(53 * T16 + 8, 8 * T16), "letrero_autopista", Vector2(60, 4))
	_decorado(a, "Pilar1", Vector2(14 * T16 + 8, 8 * T16), "pilar", Vector2(20, 8))
	_decorado(a, "Pilar2", Vector2(40 * T16 + 8, 8 * T16), "pilar", Vector2(20, 8))
	_decorado(a, "Camion", Vector2(33 * T16 + 8, 15 * T16 + 8), "camion", Vector2(96, 12))
	_decorado(a, "Auto1", Vector2(8 * T16, 14 * T16), "auto_quemado_1", Vector2(36, 8))
	_decorado(a, "Auto2", Vector2(48 * T16, 11 * T16), "auto_quemado_2", Vector2(36, 8))
	_decorado(a, "Auto3", Vector2(39 * T16, 21 * T16), "auto_quemado_1", Vector2(36, 8))
	_decorado(a, "Auto4", Vector2(24 * T16, 21 * T16), "auto_quemado_2", Vector2(36, 8))
	# Cazador furtivo escondido detrás del auto quemado (sale en la emboscada)
	_interactuable(a, "Cazador", _px(39, 19.6), "cazador", { "textura": load("res://arte/personajes/cazador_mapa.png"), "solido": true,
		"mostrar_si": "cazador_visible", "ocultar_si": "cazador_derrotado", "radio": 22.0 })
	_disparador(a, "Emboscada", 36, 17, 2, 7, "emboscada")
	_vecino(a, "Viajera", "viajera", "vendada_mapa", [_px(6, 13.5), _px(27, 13.5)],
		{ "rapidez": 14.0, "pausa": 4.0, "tose": true, "murmullos": ["No bajes al metro...", "*cof* El agua de allá abajo..."] })
	_interactuable(a, "Fruta", _px(30, 5), "fruta_silvestre", { "textura": load("res://arte/objetos/pina_silvestre.png"), "ocultar_si": "fruta_Fruta" })
	var saqueo := load("res://arte/objetos/saqueo.png")
	for p in [["SaqueoA1", Vector2(5, 5)], ["SaqueoA2", Vector2(27, 6)], ["SaqueoA3", Vector2(50, 22)], ["SaqueoA4", Vector2(12, 22)]]:
		_interactuable(a, p[0], _px(p[1].x, p[1].y), "saqueo", { "textura": saqueo, "ocultar_si": "saqueo_" + p[0] })
	_interactuable(a, "InvLetrero", _px(53, 8.6), "inv_letrero", { "radio": 22.0 })
	_disparador(a, "VolverBastion", 0, 9, 1, 7, "salida_autopista_oeste")
	_disparador(a, "BajarMetro", 58, 5, 3, 2, "bajar_metro")
	var lobos: Array[String] = ["lobo_de_ceniza", "lobo_de_ceniza", "aves_negras", "bestia_blanca", "cazador_camuflado"]
	_zona(a, "PastoCeniza", 1, 17, 62, 7, lobos, 2, 3, "autopista")
	_zona(a, "CenizaNorte", 26, 4, 9, 3, ["lobo_de_ceniza", "bestia_blanca"], 2, 3, "autopista")
	_terminar_mapa(a, _px(1.5, 12), "res://escenas/mapas/autopista.tscn")


func _crear_sumidero(ts: TileSet) -> void:
	var s := _nuevo_mapa("Sumidero", "sumidero", ts, "subterraneo", SUBTERRANEO)
	var T16 := float(T)
	var tex := func(n: String) -> Texture2D: return load("res://arte/personajes/%s.png" % n)
	_entrada(s, "Escalera", _px(3.5, 4.6))
	_entrada(s, "Posada", _px(19.5, 7))
	_entrada(s, "Plaza", _px(31, 31))
	# --- Andén del Mercado: vagones convertidos en tienda y dormitorio
	_decorado(s, "VagonTienda", Vector2(9 * T16, 12 * T16), "vagon_tienda", Vector2(108, 40))
	_decorado(s, "VagonPosada", Vector2(20 * T16, 12 * T16), "vagon_posada", Vector2(108, 40))
	_decorado(s, "MapaMetro", Vector2(14 * T16 + 8, 5 * T16 + 4), "mapa_metro", Vector2(40, 6))
	_interactuable(s, "Sabina", _px(8.5, 8.0), "tienda_sumidero", { "textura": tex.call("sabina_mapa"), "solido": true, "radio": 24.0 })
	_interactuable(s, "Tula", _px(21.5, 8.0), "tula", { "textura": tex.call("tula_mapa"), "solido": true, "radio": 24.0 })
	_interactuable(s, "CamaVagon", _px(19.5, 8.4), "cama_sumidero", { "radio": 18.0 })
	_interactuable(s, "InvMapaMetro", _px(14, 5.7), "inv_mapa_metro", { "radio": 20.0 })
	_disparador(s, "Subir", 3, 2, 2, 1, "subir_metro")
	_vecino(s, "Mendigo", "mendigo", "anciano_mapa", [_px(12, 7.6)], { "tose": true,
		"murmullos": ["¿Comida limpia? ¿Un poquito?", "*cof* Por favor, niño...", "Tengo hambre..."] })
	_vecino(s, "PaseanteAnden", "paseante_anden", "vendado_mapa", [_px(5, 6), _px(26, 6), _px(26, 8), _px(16, 8)],
		{ "tose": true, "murmullos": ["Siete días más hasta el antídoto...", "El agua sabe a metal.", "No mires a los guardias."] })
	_rata(s, _px(1.5, 10.5), Vector2(28 * T16, 0))
	_rata(s, _px(33, 11), Vector2(20 * T16, 0))
	# --- Jardín de hongos (criaturas)
	_hongo(s, "Hongo1", Vector2(38 * T16, 8 * T16), false)
	_hongo(s, "Hongo2", Vector2(50 * T16, 6 * T16), true)
	_hongo(s, "Hongo3", Vector2(57 * T16, 10 * T16), false)
	_hongo(s, "Hongo4", Vector2(44 * T16, 11 * T16), true)
	_interactuable(s, "InvHongos", _px(38, 8.4), "inv_hongos", { "radio": 22.0 })
	_interactuable(s, "FrutaS", _px(52, 9), "fruta_silvestre", { "textura": load("res://arte/objetos/pina_silvestre.png"), "ocultar_si": "fruta_FrutaS" })
	_zona(s, "JardinHongos", 32, 4, 31, 8, ["burbuja_toxica", "sirena_de_fango", "burbuja_toxica", "sirena_de_fango", "gato_mutado"], 2, 4, "sumidero")
	# --- Plaza del Antídoto y el laboratorio de Vesper
	_decorado(s, "Laboratorio", Vector2(31 * T16, 27 * T16), "laboratorio", Vector2(208, 16))
	s.get_node("Entidades/Laboratorio").set_meta("luz", Color(0.6, 1.0, 0.75))
	s.get_node("Entidades/Laboratorio").set_meta("luz_pos", Vector2(0, -40))
	_decorado(s, "Ventanilla", Vector2(46 * T16, 31 * T16), "ventanilla", Vector2(50, 12))
	_decorado(s, "TanqueVeneno", Vector2(19.5 * T16, 27 * T16), "tanque_veneno", Vector2(40, 10), { "ocultar_si": "valvula_cerrada" })
	_decorado(s, "TanqueLimpio", Vector2(19.5 * T16, 27 * T16), "tanque_limpio", Vector2(40, 10), { "mostrar_si": "valvula_cerrada" })
	_decorado(s, "Valvula", Vector2(41 * T16, 26 * T16), "valvula", Vector2(36, 8), { "ocultar_si": "valvula_cerrada" })
	_decorado(s, "ValvulaCerrada", Vector2(41 * T16, 26 * T16), "valvula_cerrada", Vector2(36, 8), { "mostrar_si": "valvula_cerrada" })
	_decorado(s, "Altavoz1", Vector2(17 * T16, 24 * T16), "altavoz", Vector2(6, 4))
	_decorado(s, "Altavoz2", Vector2(45 * T16, 24 * T16), "altavoz", Vector2(6, 4))
	_decorado(s, "Jaulas", Vector2(20.5 * T16, 31 * T16), "jaulas", Vector2(52, 8))
	_decorado(s, "VagonGrafiti", Vector2(54 * T16, 22 * T16), "vagon_grafiti", Vector2(108, 40))
	_hongo(s, "Hongo5", Vector2(16 * T16, 32 * T16), true)
	_hongo(s, "Hongo6", Vector2(60 * T16, 33 * T16), false)
	_interactuable(s, "InvTanque", _px(19, 27.2), "inv_tanque_veneno", { "radio": 22.0 })
	_interactuable(s, "InvVentanilla", _px(45.5, 31.3), "inv_ventanilla", { "radio": 20.0 })
	_interactuable(s, "InvAltavoz", _px(16.5, 24.2), "inv_altavoz", { "radio": 18.0 })
	_interactuable(s, "InvCristal", _px(27, 27.2), "inv_cristal", { "radio": 22.0 })
	_interactuable(s, "InvJaulas", _px(20.5, 31.3), "inv_jaulas", { "radio": 22.0 })
	_interactuable(s, "InvGrafiti", _px(54, 22.3), "inv_vagon_grafiti", { "radio": 26.0 })
	_interactuable(s, "Valvula", _px(41, 26.4), "valvula", { "radio": 22.0 })
	var guardia: Texture2D = tex.call("guardia_org_mapa")
	_interactuable(s, "GuardiaLab1", _px(29.2, 27.4), "guardia_lab_1", { "textura": guardia, "solido": true, "ocultar_si": "guardia_lab_1_derrotado", "radio": 22.0 })
	_interactuable(s, "GuardiaLab2", _px(31.8, 27.4), "guardia_lab_2", { "textura": guardia, "solido": true, "ocultar_si": "guardia_lab_2_derrotado", "radio": 22.0 })
	_interactuable(s, "Vesper", _px(30.5, 27.3), "vesper", { "textura": tex.call("vesper_mapa"), "solido": true,
		"mostrar_si": "vesper_espera", "ocultar_si": "vesper_derrotada", "radio": 24.0 })
	_interactuable(s, "VesperEscena", _px(30.5, 27.3), "", { "textura": tex.call("vesper_mapa"), "mostrar_si": "vesper_en_escena" })
	_interactuable(s, "Rechazado", _px(44.4, 30.6), "", { "textura": tex.call("vendado_mapa"), "mostrar_si": "rechazado_en_escena" })
	_disparador(s, "PasoLaboratorio", 28, 28, 6, 1, "paso_laboratorio")
	_disparador(s, "LlegadaPlaza", 1, 18, 62, 1, "escena_antidoto")
	# La fila del antídoto: avanza, cada uno llega a la ventanilla y vuelve al final
	var fila: Array = [_px(37.5, 30.2), _px(39, 30.2), _px(40.5, 30.2), _px(42, 30.2), _px(43.6, 30.4), _px(44.6, 32.6),
		_px(41, 32.8), _px(37, 32.8), _px(36.5, 31.4)]
	var gente_fila := ["vendado_mapa", "vendada_mapa", "anciano_mapa", "nina_tos_mapa"]
	for i in 4:
		_vecino(s, "Fila%d" % (i + 1), "fila_%d" % (i + 1), gente_fila[i], fila, { "inicio": 3 - i, "pausa": 3.0, "rapidez": 14.0,
			"tose": true, "ocultar_si": "valvula_cerrada" })
	# Patrulla de la Organización (hasta que la ciudad es libre)
	_vecino(s, "Patrulla", "patrulla", "guardia_org_mapa", [_px(47, 19), _px(60, 19), _px(60, 29), _px(48, 29)],
		{ "rapidez": 18.0, "murmullos": ["¡Circulen!", "Sin monstruo no hay antídoto.", "¿Qué miras, rata?"], "ocultar_si": "sumidero_liberado" })
	# --- Barrio de los vagones (oeste): las familias, los niños que tosen, el memorial
	_decorado(s, "Memorial", Vector2(4 * T16, 20 * T16), "memorial", Vector2(52, 6))
	_decorado(s, "CartelBenefactor", Vector2(11.5 * T16 + 8, 19 * T16), "cartel_benefactor", Vector2(8, 4))
	_interactuable(s, "InvMemorial", _px(3.5, 20.2), "inv_memorial", { "radio": 22.0 })
	_interactuable(s, "InvCartel", _px(11.5, 19.2), "inv_cartel_benefactor", { "radio": 18.0 })
	_vecino(s, "Madre", "madre_ninos", "vendada_mapa", [_px(5.5, 25)], { "tose": true })
	_vecino(s, "Nino", "nino_tos", "nino_tos_mapa", [_px(7, 23.6)], { "tose": true })
	_vecino(s, "Nina", "nina_tos", "nina_tos_mapa", [_px(3, 22), _px(11, 22), _px(11, 30), _px(3, 30)], { "rapidez": 40.0, "pausa": 1.0, "tose": true })
	_vecino(s, "PaseantePlaza", "paseante_plaza", "vendado_mapa", [_px(15, 19), _px(15, 33), _px(5, 33), _px(5, 27)],
		{ "rapidez": 16.0, "tose": true, "murmullos": ["Mi hermano entró al laboratorio y no salió.", "Hongos otra vez para cenar...", "*cof* ¿Tienes comida limpia?"] })
	_rata(s, _px(47, 18), Vector2(0, 9 * T16))
	# --- Sur-oeste: el taller de Nilo y la familia de Iris
	_decorado(s, "TallerNilo", Vector2(6 * T16, 41 * T16), "taller_nilo", Vector2(60, 10))
	_vecino(s, "Nilo", "nilo", "nilo_mapa", [_px(6.5, 41.4)])
	_vecino(s, "Iris", "iris", "iris_mapa", [_px(14, 42)])
	_vecino(s, "PadreIris", "padre_iris", "padre_iris_mapa", [_px(16, 41.6)], { "tose": true, "ocultar_si": "padre_iris_sano" })
	_vecino(s, "PadreIrisSano", "padre_iris", "padre_iris_mapa", [_px(16, 41.6)], { "mostrar_si": "padre_iris_sano" })
	# --- Túneles oscuros y el Colector de Gas
	_zona(s, "TunelesOscuros", 25, 38, 22, 9, ["tejedor_de_sombras", "humanoide_sin_consciencia", "tejedor_de_sombras", "aves_negras"], 2, 4, "sumidero")
	_zona(s, "ColectorGas", 48, 38, 15, 9, ["guardian_de_flora", "burbuja_toxica", "humanoide_sin_consciencia", "burbuja_toxica"], 3, 4, "sumidero")
	_disparador(s, "PuertaGas", 47, 41, 1, 2, "puerta_gas")
	_interactuable(s, "BotinGas", _px(59, 42), "botin_gas", { "textura": load("res://arte/objetos/saqueo.png"), "ocultar_si": "botin_gas" })
	var saqueo := load("res://arte/objetos/saqueo.png")
	for p in [["SaqueoS1", Vector2(30, 6)], ["SaqueoS2", Vector2(61, 5)], ["SaqueoS3", Vector2(3, 45)], ["SaqueoS4", Vector2(44, 45)]]:
		_interactuable(s, p[0], _px(p[1].x, p[1].y), "saqueo", { "textura": saqueo, "ocultar_si": "saqueo_" + p[0] })
	# --- Goteras de ácido (la sombra avisa dónde va a caer la gota)
	for p in [Vector2(7, 6), Vector2(17, 7), Vector2(24, 5), Vector2(12, 21), Vector2(35, 29), Vector2(50, 25),
			Vector2(40, 7), Vector2(30, 42), Vector2(40, 44), Vector2(20, 40), Vector2(56, 41), Vector2(9, 31)]:
		_gotera(s, _px(p.x, p.y))
	# --- Túnel este (cerrado por la Organización hasta que el Sumidero es libre): lleva al Paso del Smog
	_entrada(s, "Este", _px(61.5, 24.5))
	_decorado(s, "RejaTunel", Vector2(62 * T16 + 8, 26 * T16), "reja_tunel", Vector2(40, 64), { "ocultar_si": "sumidero_liberado" })
	_interactuable(s, "InvReja", _px(61, 24.5), "inv_reja_tunel", { "radio": 22.0, "ocultar_si": "sumidero_liberado" })
	_disparador(s, "TunelEste", 63, 24, 1, 2, "salida_sumidero_este")
	_terminar_mapa(s, _px(3.5, 4.6), "res://escenas/mapas/sumidero.tscn")


# ---------------------------------------------------------------------------
# CIUDAD 3: el Paso del Smog y Ciudad Neón (Comandante Silas)
# ---------------------------------------------------------------------------
func _farola(raiz: Node, nombre: String, pos: Vector2, cian: bool) -> void:
	_decorado(raiz, nombre, pos, "farola_cian" if cian else "farola_magenta", Vector2(6, 4))
	var n: Node = raiz.get_node("Entidades/" + nombre)
	n.set_meta("luz", Color(0.35, 0.95, 1.0) if cian else Color(1.0, 0.35, 0.85))
	n.set_meta("luz_pos", Vector2(0, -42))


func _crear_paso_smog(ts: TileSet) -> void:
	var p := _nuevo_mapa("PasoSmog", "paso_smog", ts, "neon", NEON)
	var T16 := float(T)
	var tex := func(n: String) -> Texture2D: return load("res://arte/personajes/%s.png" % n)
	_entrada(p, "Oeste", _px(1.5, 12))
	_entrada(p, "Este", _px(57.5, 12))
	_decorado(p, "LetreroAire1", Vector2(6 * T16 + 8, 9 * T16), "letrero_aire", Vector2(40, 4))
	_decorado(p, "LetreroAire2", Vector2(43 * T16, 9 * T16), "letrero_aire", Vector2(40, 4))
	_decorado(p, "Proyector", Vector2(25 * T16, 17 * T16), "proyector_gas", Vector2(20, 6), { "ocultar_si": "neon_liberado" })
	p.get_node("Entidades/Proyector").set_meta("luz", Color(0.35, 1.0, 0.5))
	p.get_node("Entidades/Proyector").set_meta("luz_pos", Vector2(0, -26))
	p.get_node("Entidades/Proyector").set_meta("esporas", true)
	_decorado(p, "ProyectorRoto", Vector2(25 * T16, 17 * T16), "proyector_roto", Vector2(20, 6), { "mostrar_si": "neon_liberado" })
	_interactuable(p, "InvProyector", _px(24.5, 16.2), "inv_proyector", { "radio": 22.0 })
	_interactuable(p, "InvLetrero", _px(6.5, 9.6), "inv_letrero_aire", { "radio": 22.0 })
	_disparador(p, "GasFalso", 20, 10, 1, 5, "gas_falso")
	# Leo, el pedalero que escapó, se esconde entre las ruinas (cree que el aire lo va a matar)
	_vecino(p, "Leo", "leo", "leo_mapa", [_px(41, 5.4)], { "ocultar_si": "leo_en_neon", "tose": true })
	# Un patrullero de Silas cuida que nadie salga ni entre
	_interactuable(p, "Patrullero", _px(54, 11.4), "patrullero", { "textura": tex.call("guardia_org_mapa"), "solido": true,
		"ocultar_si": "patrullero_derrotado", "radio": 22.0 })
	_disparador(p, "PasoPatrullero", 51, 10, 1, 5, "paso_patrullero")
	var saqueo := load("res://arte/objetos/saqueo.png")
	for q in [["SaqueoP1", Vector2(12, 22)], ["SaqueoP2", Vector2(55, 3)], ["SaqueoP3", Vector2(31, 23)]]:
		_interactuable(p, q[0], _px(q[1].x, q[1].y), "saqueo", { "textura": saqueo, "ocultar_si": "saqueo_" + q[0] })
	_disparador(p, "VolverSumidero", 0, 10, 1, 5, "salida_smog_oeste")
	_disparador(p, "IrNeon", 59, 10, 1, 5, "entrar_neon")
	_zona(p, "SmogSur", 1, 16, 58, 7, ["espectro_sonico", "espectro_sonico", "bestia_blanca", "lobo_de_ceniza", "caballero_de_neon"], 3, 4, "smog")
	_zona(p, "SmogNorte", 10, 4, 45, 4, ["espectro_sonico", "aves_negras", "bestia_blanca"], 3, 4, "smog")
	_terminar_mapa(p, _px(1.5, 12), "res://escenas/mapas/paso_smog.tscn")


func _crear_ciudad_neon(ts: TileSet) -> void:
	var n := _nuevo_mapa("CiudadNeon", "ciudad_neon", ts, "neon", NEON)
	var T16 := float(T)
	var tex := func(nombre: String) -> Texture2D: return load("res://arte/personajes/%s.png" % nombre)
	_entrada(n, "Sur", _px(27.5, 37.5))
	_entrada(n, "Norte", _px(27.5, 2.5))
	_entrada(n, "Motel", _px(7, 17.4))
	_entrada(n, "Plaza", _px(27.5, 19.5))
	# --- Puertas de la ciudad (la del norte sigue cerrada por la barrera sónica hasta vencer a Silas)
	_decorado(n, "PuertaSur", Vector2(28 * T16, 40 * T16), "puerta_neon_abierta", Vector2.ZERO)
	_decorado(n, "PuertaNorte", Vector2(28 * T16, 3 * T16), "puerta_neon", Vector2(64, 8), { "ocultar_si": "neon_liberado" })
	_decorado(n, "PuertaNorteAbierta", Vector2(28 * T16, 3 * T16), "puerta_neon_abierta", Vector2.ZERO, { "mostrar_si": "neon_liberado" })
	_disparador(n, "SalidaSur", 26, 39, 4, 1, "salida_neon_sur")
	_disparador(n, "SalidaNorte", 26, 1, 4, 1, "salida_neon_norte")
	# --- Plaza de los Generadores (noroeste): la gente pedalea 16 horas al día para encender las luces
	_decorado(n, "Generador1", Vector2(9 * T16, 8 * T16), "generador", Vector2(104, 14), { "cuadros": 3, "cuadros_por_segundo": 5.0, "detener_si": "neon_liberado" })
	_decorado(n, "Generador2", Vector2(19 * T16, 8 * T16), "generador", Vector2(104, 14), { "cuadros": 3, "cuadros_por_segundo": 5.0, "detener_si": "neon_liberado" })
	_decorado(n, "Motel", Vector2(7 * T16, 16 * T16), "motel", Vector2(100, 16))
	_decorado(n, "TiendaCoral", Vector2(18 * T16, 16 * T16), "tienda_neon", Vector2(88, 16))
	_decorado(n, "Holograma1", Vector2(23.5 * T16, 14 * T16), "holograma_silas", Vector2(12, 6), { "cuadros": 4, "cuadros_por_segundo": 4.0, "ocultar_si": "neon_liberado" })
	_interactuable(n, "Coral", _px(18, 16.8), "tienda_neon", { "textura": tex.call("coral_mapa"), "solido": true, "radio": 24.0 })
	_interactuable(n, "CamaMotel", _px(7, 16.6), "cama_neon", { "radio": 18.0 })
	_interactuable(n, "InvGenerador", _px(9, 8.6), "inv_generador", { "radio": 22.0 })
	_interactuable(n, "InvHolograma", _px(23.5, 14.4), "inv_holograma", { "radio": 20.0 })
	_vecino(n, "Tobi", "tobi", "tobi_mapa", [_px(13.5, 9.4)])
	_vecino(n, "MamaTobi", "mama_tobi", "pedalera_mapa", [_px(11.5, 9.6)], { "mostrar_si": "turno_tobi" })
	_vecino(n, "Pedalero1", "pedalero", "pedalero_mapa", [_px(13, 10.4), _px(23, 10.4), _px(23, 17.2), _px(4, 17.2)],
		{ "rapidez": 34.0, "pausa": 1.0, "murmullos": ["¡Sonrío-sonrío! ¡Todo bien!", "Turno-de-día-turno-de-noche...", "Shh... los micrófonos."] })
	_vecino(n, "Pedalera1", "pedalera", "pedalera_mapa", [_px(31, 16.4), _px(53, 16.4), _px(53, 22.6), _px(31, 22.6)],
		{ "rapidez": 36.0, "pausa": 0.8, "murmullos": ["¡Qué-lindas-luces! ¡Gracias, Silas!", "*sonrisa* *sonrisa*", "No-puedo-parar..."] })
	# --- El Palacio Lumen (noreste): el escenario de Silas y sus dos guardias
	_decorado(n, "PalacioLumen", Vector2(42 * T16, 9 * T16 + 8), "casino", Vector2(184, 20))
	n.get_node("Entidades/PalacioLumen").set_meta("luz", Color(1.0, 0.45, 0.9))
	n.get_node("Entidades/PalacioLumen").set_meta("luz_pos", Vector2(0, -60))
	_decorado(n, "Torre1", Vector2(33 * T16, 9 * T16), "torre_sonica", Vector2(14, 6), { "cuadros": 2, "cuadros_por_segundo": 3.0 })
	_decorado(n, "Torre2", Vector2(51 * T16, 9 * T16), "torre_sonica", Vector2(14, 6), { "cuadros": 2, "cuadros_por_segundo": 3.0 })
	_interactuable(n, "InvTorre", _px(33, 9.2), "inv_torre", { "radio": 20.0 })
	_interactuable(n, "InvCasino", _px(37, 10.2), "inv_casino", { "radio": 20.0 })
	var guardia: Texture2D = tex.call("guardia_org_mapa")
	_interactuable(n, "GuardiaNeon1", _px(39, 14.4), "guardia_neon_1", { "textura": guardia, "solido": true, "ocultar_si": "guardia_neon_1_derrotado", "radio": 22.0 })
	_interactuable(n, "GuardiaNeon2", _px(45, 14.4), "guardia_neon_2", { "textura": guardia, "solido": true, "ocultar_si": "guardia_neon_2_derrotado", "radio": 22.0 })
	_disparador(n, "PasoEscenario", 35, 15, 15, 1, "paso_escenario")
	_interactuable(n, "Silas", _px(42, 11.2), "silas", { "textura": tex.call("silas_mapa"), "solido": true,
		"mostrar_si": "silas_espera", "ocultar_si": "silas_derrotado", "radio": 24.0 })
	_interactuable(n, "HoloPapa", _px(40.5, 12), "", { "textura": tex.call("holo_papa_mapa"), "mostrar_si": "ilusion_padres" })
	_interactuable(n, "HoloMama", _px(43.5, 12), "", { "textura": tex.call("holo_mama_mapa"), "mostrar_si": "ilusion_padres" })
	_vecino(n, "Vigia", "vigia_neon", "guardia_org_mapa", [_px(31, 19), _px(52, 19), _px(52, 21), _px(31, 21)],
		{ "rapidez": 22.0, "murmullos": ["¡Sonríe, ciudadano!", "El aire de afuera mata. Eso dice Silas.", "¿Por qué no estás pedaleando?"], "ocultar_si": "neon_liberado" })
	# --- La sala de juegos sin techo (suroeste): aquí se esconden las bestias de luz
	_decorado(n, "Arcade", Vector2(18.5 * T16, 30 * T16), "arcade", Vector2(100, 16))
	_interactuable(n, "InvArcade", _px(18.5, 30.4), "inv_arcade", { "radio": 22.0 })
	_zona(n, "SalaJuegos", 2, 25, 21, 12, ["caballero_de_neon", "bailarina_electrica", "espectro_sonico", "tejedor_de_sombras"], 3, 5, "neon")
	_decorado(n, "Holograma3", Vector2(24 * T16, 36 * T16), "holograma_silas", Vector2(12, 6), { "cuadros": 4, "cuadros_por_segundo": 4.0, "ocultar_si": "neon_liberado" })
	# --- Sureste: el bar El Comodín, Rina la técnica, Mara y Don Ciro
	_decorado(n, "BarComodin", Vector2(37 * T16, 28 * T16), "bar_comodin", Vector2(88, 14))
	_interactuable(n, "Cantinero", _px(37, 28.4), "bar_comodin", { "radio": 22.0 })
	_decorado(n, "Holograma2", Vector2(44 * T16, 25 * T16), "holograma_silas", Vector2(12, 6), { "cuadros": 4, "cuadros_por_segundo": 4.0, "ocultar_si": "neon_liberado" })
	_decorado(n, "Torre3", Vector2(49 * T16, 31 * T16), "torre_sonica", Vector2(14, 6), { "cuadros": 2, "cuadros_por_segundo": 3.0 })
	_vecino(n, "Rina", "rina", "rina_mapa", [_px(47.5, 31.6)])
	_vecino(n, "Mara", "mara", "mara_mapa", [_px(36, 33)])
	_vecino(n, "LeoNeon", "leo_neon", "leo_mapa", [_px(37.4, 33.2)], { "mostrar_si": "leo_en_neon" })
	_vecino(n, "DonCiro", "ciro", "ciro_mapa", [_px(44, 35.4)])
	_decorado(n, "LetreroAire3", Vector2(32 * T16, 37 * T16), "letrero_aire", Vector2(40, 4), { "ocultar_si": "neon_liberado" })
	_interactuable(n, "InvLetreroNeon", _px(32, 37.3), "inv_letrero_neon", { "radio": 20.0, "ocultar_si": "neon_liberado" })
	# --- Los micrófonos escondidos de Silas (misión de Rina)
	var mic := load("res://arte/objetos/microfono.png")
	for q in [["Microfono1", Vector2(24.4, 5.8)], ["Microfono2", Vector2(13, 34)], ["Microfono3", Vector2(53, 24)]]:
		_interactuable(n, q[0], _px(q[1].x, q[1].y), "microfono", { "textura": mic, "ocultar_si": "mic_" + q[0] })
	# --- Farolas de la avenida
	var i := 0
	for y in [6, 12, 25, 31, 36]:
		_farola(n, "FarolaO%d" % y, Vector2(25 * T16 + 8, y * T16), i % 2 == 0)
		_farola(n, "FarolaE%d" % y, Vector2(30 * T16 + 8, y * T16), i % 2 == 1)
		i += 1
	var saqueo := load("res://arte/objetos/saqueo.png")
	for q in [["SaqueoN1", Vector2(3, 30)], ["SaqueoN2", Vector2(53, 3)], ["SaqueoN3", Vector2(52, 37)]]:
		_interactuable(n, q[0], _px(q[1].x, q[1].y), "saqueo", { "textura": saqueo, "ocultar_si": "saqueo_" + q[0] })
	_terminar_mapa(n, _px(27.5, 37.5), "res://escenas/mapas/ciudad_neon.tscn")


# ---------------------------------------------------------------------------
# CIUDAD 4: el Bosque Calcinado y Valle Ceniza (Comandante Kael)
# ---------------------------------------------------------------------------
func _crear_bosque(ts: TileSet) -> void:
	var b := _nuevo_mapa("BosqueCalcinado", "bosque_calcinado", ts, "ceniza", CENIZA)
	var T16 := float(T)
	_entrada(b, "Oeste", _px(1.5, 13.5))
	_entrada(b, "Este", _px(57.5, 13.5))
	_disparador(b, "VolverNeon", 0, 13, 1, 2, "salida_bosque_oeste")
	_disparador(b, "IrValle", 59, 13, 1, 2, "entrar_valle")
	var k := 0
	for q in [Vector2(5, 9), Vector2(11, 4), Vector2(18, 3), Vector2(26, 5), Vector2(4, 18), Vector2(12, 11), Vector2(23, 14),
			Vector2(27, 24), Vector2(34, 4), Vector2(45, 7), Vector2(54, 6), Vector2(41, 18), Vector2(47, 17), Vector2(56, 10),
			Vector2(9, 27), Vector2(34, 26), Vector2(52, 27), Vector2(20, 6)]:
		_decorado(b, "Arbol%d" % k, Vector2(q.x * T16 + 8, q.y * T16 + 12), "arbol_quemado", Vector2(8, 6))
		k += 1
	for q in [Vector2(7, 23), Vector2(43, 2), Vector2(57, 23), Vector2(21, 27)]:
		_decorado(b, "ArbolBrote%d" % k, Vector2(q.x * T16 + 8, q.y * T16 + 12), "arbol_brote", Vector2(8, 6))
		k += 1
	var brote := load("res://arte/objetos/brote.png")
	for q in [["Brote1", Vector2(6, 25)], ["Brote2", Vector2(41, 3)], ["Brote3", Vector2(56, 25)]]:
		_interactuable(b, q[0], _px(q[1].x, q[1].y), "brote", { "textura": brote, "ocultar_si": "brote_" + q[0] })
	_interactuable(b, "InvTrampa", _px(20, 12), "inv_trampa", { "radio": 20.0 })
	# El recaudador de la Organización va camino al valle a cobrar
	_decorado(b, "CarretaOrg", Vector2(44 * T16, 8 * T16), "carreta_org", Vector2(40, 8), { "ocultar_si": "recaudador_derrotado" })
	_interactuable(b, "Recaudador", _px(46, 9.6), "recaudador", { "textura": load("res://arte/personajes/recaudador_mapa.png"),
		"solido": true, "ocultar_si": "recaudador_derrotado", "radio": 22.0 })
	_disparador(b, "PasoRecaudador", 42, 9, 1, 2, "paso_recaudador")
	var saqueo := load("res://arte/objetos/saqueo.png")
	for q in [["SaqueoB1", Vector2(3, 3)], ["SaqueoB2", Vector2(57, 3)], ["SaqueoB3", Vector2(28, 27)]]:
		_interactuable(b, q[0], _px(q[1].x, q[1].y), "saqueo", { "textura": saqueo, "ocultar_si": "saqueo_" + q[0] })
	_zona(b, "Bosque", 1, 2, 58, 26, ["bestia_blindada", "lobo_de_ceniza", "gusano_devorador", "humanoide_sin_consciencia",
		"bestia_blindada", "lobo_de_ceniza", "vigilante_ciego"], 4, 5, "bosque")
	_terminar_mapa(b, _px(1.5, 13.5), "res://escenas/mapas/bosque_calcinado.tscn")


func _crear_valle(ts: TileSet) -> void:
	var v := _nuevo_mapa("ValleCeniza", "valle_ceniza", ts, "ceniza", CENIZA)
	var T16 := float(T)
	var tex := func(nombre: String) -> Texture2D: return load("res://arte/personajes/%s.png" % nombre)
	_entrada(v, "Sur", _px(26.5, 37.5))
	_entrada(v, "Cama", _px(10, 33.2))
	_entrada(v, "Plaza", _px(26.5, 22.5))
	_entrada(v, "Monumento", _px(40.5, 15.5))
	_decorado(v, "ArcoValle", Vector2(27 * T16, 39 * T16), "arco_valle", Vector2.ZERO)
	_disparador(v, "SalidaSur", 26, 39, 2, 1, "salida_valle_sur")
	_disparador(v, "SalidaNorte", 26, 0, 2, 1, "salida_valle_norte")
	# --- El invernadero de Lucía y su huerto
	_decorado(v, "Invernadero", Vector2(12 * T16, 10 * T16), "invernadero", Vector2(76, 12))
	_decorado(v, "Espantapajaros", Vector2(11 * T16, 14 * T16 + 8), "espantapajaros", Vector2(6, 4))
	_interactuable(v, "InvInvernadero", _px(10, 10.4), "inv_invernadero", { "radio": 20.0 })
	_vecino(v, "Lucia", "lucia", "lucia_mapa", [_px(16, 10.4)])
	# --- La plaza de la olla común (todos comen de la misma olla)
	_decorado(v, "Olla", Vector2(24 * T16, 20 * T16), "olla_comun", Vector2(24, 8), { "cuadros": 3, "cuadros_por_segundo": 5.0 })
	v.get_node("Entidades/Olla").set_meta("luz", Color(1.0, 0.6, 0.25))
	v.get_node("Entidades/Olla").set_meta("luz_pos", Vector2(0, -8))
	_interactuable(v, "InvOlla", _px(24, 20.4), "olla_comun", { "radio": 20.0 })
	_decorado(v, "Pozo", Vector2(20 * T16, 23 * T16), "pozo", Vector2(24, 8))
	_vecino(v, "Cocinera", "cocinera", "aldeana_mapa", [_px(25.4, 20.9)])
	_vecino(v, "NinaValle", "nina_valle", "nina_valle_mapa", [_px(20.5, 17.4), _px(31, 17.4), _px(31, 22.6), _px(20.5, 22.6)],
		{ "rapidez": 34.0, "pausa": 1.2, "murmullos": ["¡Kael trajo carne hoy!", "¡Mira, una hojita verde!"] })
	_vecino(v, "Aldeano", "aldeano_valle", "aldeano_mapa", [_px(26.5, 30), _px(26.5, 12), _px(33, 10.5)],
		{ "rapidez": 18.0, "pausa": 3.0, "murmullos": ["Que no le pase nada a Kael...", "Hoy hay guiso en la olla.", "Cuidado con las brasas del bosque."] })
	# --- El monumento a los caídos (aquí espera Kael)
	_decorado(v, "Monumento", Vector2(40 * T16 + 8, 12 * T16), "monumento", Vector2(36, 10))
	_interactuable(v, "InvMonumento", _px(38.4, 12.6), "inv_monumento", { "radio": 16.0 })
	_interactuable(v, "Kael", _px(40.5, 13.4), "kael", { "textura": tex.call("kael_mapa"), "solido": true,
		"mostrar_si": "kael_en_monumento", "ocultar_si": "kael_derrotado", "radio": 24.0 })
	_interactuable(v, "KaelEscena", _px(26.5, 4), "", { "textura": tex.call("kael_mapa"), "mostrar_si": "kael_en_escena" })
	_interactuable(v, "KaelRodillas", _px(40.5, 13.4), "", { "textura": tex.call("kael_rodillas_mapa"), "mostrar_si": "kael_rodillas" })
	_vecino(v, "KaelPerdonado", "kael_perdonado", "kael_mapa", [_px(22, 18.6), _px(29.6, 18.6)], { "mostrar_si": "kael_perdonado", "rapidez": 14.0, "pausa": 5.0 })
	# --- La cabaña de Kael y su puesto de caza (noreste)
	_decorado(v, "CabanaKael", Vector2(47 * T16 + 8, 7 * T16), "cabana_kael", Vector2(68, 14), { "humo": [Vector2(22.5, -54)] })
	_decorado(v, "PuestoCaza", Vector2(52 * T16, 10 * T16), "puesto_caza", Vector2(44, 8))
	_interactuable(v, "InvPuesto", _px(52, 10.4), "inv_puesto_caza", { "radio": 20.0 })
	_vecino(v, "Ana", "ana", "ana_mapa", [_px(45, 8.8)])
	_vecino(v, "Teo", "teo", "teo_mapa", [_px(44, 9.8), _px(49, 9.8), _px(49, 12)], { "rapidez": 30.0, "pausa": 1.5 })
	# --- Las cabañas del sur: la abuela Nita (cama gratis), la despensa de Hugo y la leña de Ramiro
	_decorado(v, "CabanaNita", Vector2(10 * T16, 32 * T16), "cabana_3", Vector2(52, 14), { "humo": [Vector2(14.5, -46)] })
	_interactuable(v, "CamaValle", _px(10, 32.4), "cama_valle", { "radio": 18.0 })
	_vecino(v, "Nita", "nita", "nita_mapa", [_px(12.4, 32.8)])
	_decorado(v, "Despensa", Vector2(18 * T16, 32 * T16), "cabana_2", Vector2(60, 14), { "humo": [Vector2(18.5, -50)] })
	_interactuable(v, "Hugo", _px(18, 32.8), "tienda_valle", { "textura": tex.call("hugo_mapa"), "solido": true, "radio": 24.0 })
	_decorado(v, "Cabana1", Vector2(39 * T16, 33 * T16), "cabana_1", Vector2(60, 14), { "humo": [Vector2(18.5, -50)] })
	_decorado(v, "Cabana2", Vector2(47 * T16, 33 * T16), "cabana_2", Vector2(60, 14), { "humo": [Vector2(18.5, -50)] })
	_decorado(v, "Lenera", Vector2(36 * T16 + 8, 31 * T16), "lenera", Vector2(36, 8))
	_vecino(v, "Ramiro", "ramiro", "ramiro_mapa", [_px(34.5, 32.6), _px(38, 32.6)], { "rapidez": 16.0, "pausa": 3.0 })
	_decorado(v, "Tendedero", Vector2(31 * T16, 36 * T16), "tendedero", Vector2(40, 4))
	_vecino(v, "Aldeana", "aldeana_valle", "aldeana_mapa", [_px(29.5, 36.6), _px(33, 36.6)], { "rapidez": 12.0, "pausa": 4.0,
		"murmullos": ["La ropa no se seca con tanta ceniza...", "Kael nos salvó del hambre."] })
	var k := 0
	for q in [Vector2(6, 6), Vector2(20, 5), Vector2(36, 3), Vector2(51, 4), Vector2(5, 22), Vector2(45, 22),
			Vector2(8, 37), Vector2(50, 37), Vector2(22, 9), Vector2(32, 13)]:
		_decorado(v, "Arbol%d" % k, Vector2(q.x * T16 + 8, q.y * T16 + 12), "arbol_brote", Vector2(8, 6))
		k += 1
	# --- Pistas (solo si Pan ejecutó a Kael: tiene que encontrar la verdad solo)
	var pista := load("res://arte/objetos/saqueo.png")
	_interactuable(v, "PistaCabana", _px(47.5, 8.4), "pista_cabana", { "textura": pista, "mostrar_si": "kael_ejecutado", "ocultar_si": "pista_cabana" })
	_interactuable(v, "PistaMonumento", _px(42.2, 12.8), "pista_monumento", { "textura": pista, "mostrar_si": "kael_ejecutado", "ocultar_si": "pista_monumento" })
	_interactuable(v, "PistaPuesto", _px(53.6, 10.6), "pista_puesto", { "textura": pista, "mostrar_si": "kael_ejecutado", "ocultar_si": "pista_puesto" })
	_zona(v, "LindeBosque", 46, 12, 8, 11, ["bestia_blindada", "lobo_de_ceniza", "gusano_devorador"], 4, 5, "bosque")
	_terminar_mapa(v, _px(26.5, 37.5), "res://escenas/mapas/valle_ceniza.tscn")
