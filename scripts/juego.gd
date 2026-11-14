extends Node
## Estado global del juego. Está registrado como Autoload con el nombre "Juego",
## así que desde cualquier script puedes escribir Juego.mochila, Juego.flags, etc.

const RUTA_CRIATURAS := "res://datos/criaturas.json"
const RUTA_DIALOGOS := "res://datos/dialogos.json"
const NIVEL_MAXIMO := 10
const MAX_EQUIPO := 6
const AUMENTO_STATS_POR_NIVEL := 0.15  # +15% de stats por nivel (GDD)

## Pon esto en true para saltarte el prólogo mientras pruebas (empiezas en la superficie con un Gato).
const SALTAR_PROLOGO := false

## EL NOMBRE DEL JUEGO: cámbialo aquí y se actualiza en el menú principal y en la pantalla de título.
const NOMBRE_JUEGO := "PAN"
const SUBTITULO_JUEGO := "Las Seis Ciudades"   # provisional

## Partida guardada (en Android y en el navegador también funciona: user:// es la memoria del juego)
const RUTA_GUARDADO := "user://partida.json"
const RUTA_RESPALDO := "user://partida_respaldo.json"
const VERSION_GUARDADO := 1
const MENU := "res://escenas/menu.tscn"

## Objetos de la mochila. "precio" es lo que cuesta en las tiendas de las ciudades (0 = no se vende)
## y "max" es cuánto cabe en los bolsillos de la mochila (Regla B del GDD: la mochila tiene límite).
const OBJETOS := {
	"cura_40": { "nombre": "Cura 40%", "tipo": "cura", "valor": 0.4, "precio": 15, "max": 10,
		"desc": "Jeringa purificada. Devuelve el 40% de la vida a una carta." },
	"cura_50": { "nombre": "Cura 50%", "tipo": "cura", "valor": 0.5, "precio": 20, "max": 10,
		"desc": "Suero de la ciudad. Devuelve el 50% de la vida." },
	"cura_80": { "nombre": "Cura 80%", "tipo": "cura", "valor": 0.8, "precio": 100, "max": 10,
		"desc": "Medicina de antes del colapso. Devuelve el 80% de la vida." },
	"potenciador_20": { "nombre": "Potenciador 20%", "tipo": "potenciador", "valor": 0.2, "precio": 30, "max": 3,
		"desc": "Sube el ataque de tu criatura un 20% durante el combate." },
	"potenciador_70": { "nombre": "Potenciador 70%", "tipo": "potenciador", "valor": 0.7, "precio": 80, "max": 3,
		"desc": "Sube el ataque de tu criatura un 70% durante el combate." },
	"racion": { "nombre": "Piña en lata", "tipo": "comida", "valor": 0.6, "precio": 50, "max": 5,
		"desc": "Comida purificada. Devuelve el 60% de la vida." },
	"carta_vinculo": { "nombre": "Carta de Vínculo", "tipo": "captura", "precio": 10, "max": 20,
		"desc": "Carta vacía para capturar criaturas debilitadas." },
	"granada_aturdidora": { "nombre": "Granada Aturdidora", "tipo": "granada", "precio": 0, "max": 5,
		"desc": "Aturde a una criatura y baja su vida a la zona roja." },
	# El Sumidero (Ciudad 2): los primeros objetos para curar estados alterados
	"antidoto": { "nombre": "Antídoto", "tipo": "antidoto", "precio": 25, "max": 5,
		"desc": "Cura la infección, la quemadura, la parálisis y la ceguera de una carta." },
	"mascara_filtro": { "nombre": "Máscara de Filtro", "tipo": "clave", "precio": 150, "max": 1,
		"desc": "Filtra el gas tóxico. Con ella puedes entrar al Colector de Gas del Sumidero." },
}
## Lo que pagan los mercaderes por cada Reliquia del Viejo Mundo (cables, placas, relojes...).
const PRECIO_RELIQUIA := 10

## Datos de todas las criaturas (datos/criaturas.json). Clave = id ("gato_mutado").
var criaturas: Dictionary = {}
## Todos los diálogos (datos/dialogos.json). Clave = id del diálogo.
var dialogos: Dictionary = {}

## Cartas de criaturas: { "id": "gato_mutado", "cantidad": 1, "hp": 90 }.
## Las primeras MAX_EQUIPO cartas son el "Equipo activo".
var mochila: Array = []
## Objetos consumibles: id -> cantidad
var objetos := { "carta_vinculo": 0, "granada_aturdidora": 0 }
var monedas := 0
var chatarra := 0                 # Reliquias del Viejo Mundo (solo sirven para venderlas)
## Partes de criaturas salvajes derrotadas (id -> cantidad). Se venden en las tiendas.
var partes: Dictionary = {}
## "Fuerzas" que te dan las ciudades liberadas: tus criaturas pegan más fuerte (0.1 = +10%).
var bonus_ataque := 0.0
## Misiones secundarias: id -> { "titulo": ..., "estado": "activa" | "completa" }
var misiones: Dictionary = {}
## true mientras sopla una tormenta de óxido en el mapa actual (Bastión de Óxido)
var tormenta := false
var tiempo_clima := 0.0           # segundos desde el último cambio de clima

## Banderas de la historia: qué ya pasó. Ej: flags["tiene_mochila"] = true
var flags: Dictionary = {}
var mision := ""

# --- Viaje entre escenas ---
var entrada := ""                # nombre del Marker2D donde aparece Pan al cargar un mapa
var posicion_pan = null          # al volver de un combate, Pan aparece donde estaba
var mapa_actual := ""            # ruta de la escena del mapa actual
var lugar_descanso := { "mapa": "res://escenas/mapas/refugio_cero.tscn", "entrada": "Cama" }
var pasos_sin_encuentro := 0
var encuentro := {}              # lo que la escena de combate debe preparar
var resultado_combate := {}      # lo que pasó en el último combate (para la historia)
var mensajes_pendientes: Array = []
var cambiando_escena := false     # true mientras se carga otra escena
var tiempo_jugado := 0.0          # segundos de juego (se guarda con la partida)
var guardar_pronto := false       # la historia pide guardar apenas termine el evento (ej. al dormir)


## Cambia de escena. Si algo falla, muestra el error en pantalla (nunca deja la pantalla en negro).
func cambiar_escena(ruta: String) -> void:
	cambiando_escena = true
	if not ResourceLoader.exists(ruta):
		_mostrar_error("No encuentro la escena:\n%s" % ruta)
		return
	var err := get_tree().change_scene_to_file(ruta)
	if err != OK:
		_mostrar_error("No se pudo abrir la escena:\n%s\n(código de error %d)" % [ruta, err])
		return
	_escena_pedida = ruta
	_tiempo_cambio = 0.0


# ---------------------------------------------------------------------------
# Protección contra la pantalla negra
#  1) Si un cambio de escena no termina en 4 segundos, se muestra el motivo en pantalla.
#  2) Si un fundido negro (grupo "fundido") se queda tapando la pantalla más de 4 segundos
#     sin ningún diálogo a la vista, se aclara solo.
# ---------------------------------------------------------------------------
const VERSION_MINIMA := [4, 3]
const ESPERA_MAXIMA := 4.0
var _escena_pedida := ""
var _tiempo_cambio := 0.0
var _tiempo_negro := {}          # fundido -> segundos que lleva tapando la pantalla
var _capa_error: CanvasLayer = null


func _process(delta: float) -> void:
	var escena_actual := get_tree().current_scene
	if escena_actual != null and escena_actual.scene_file_path != MENU:
		tiempo_jugado += delta
	# 1) ¿El cambio de escena terminó?
	if _escena_pedida != "":
		var actual := get_tree().current_scene
		if actual != null and actual.scene_file_path == _escena_pedida:
			_escena_pedida = ""
		else:
			_tiempo_cambio += delta
			if _tiempo_cambio > ESPERA_MAXIMA:
				_mostrar_error("La escena %s no terminó de cargar." % _escena_pedida)
				_escena_pedida = ""

	# 2) ¿Algún fundido negro se quedó pegado?
	var hay_dialogo := false
	for caja in get_tree().get_nodes_in_group("caja_dialogo"):
		if caja.is_visible_in_tree():
			hay_dialogo = true
	for f in get_tree().get_nodes_in_group("fundido"):
		var r := f as ColorRect
		if r == null or not r.is_visible_in_tree() or r.color.a < 0.9 or hay_dialogo or cambiando_escena:
			_tiempo_negro.erase(f)
			continue
		_tiempo_negro[f] = _tiempo_negro.get(f, 0.0) + delta
		if _tiempo_negro[f] > ESPERA_MAXIMA:
			push_warning("Un fundido negro se quedó pegado en %s: se aclara solo." % r.get_path())
			_tiempo_negro.erase(f)
			r.create_tween().tween_property(r, "color:a", 0.0, 0.4)


## Pantalla de error visible (en vez de un negro sin explicación).
func _mostrar_error(texto: String) -> void:
	push_error(texto)
	cambiando_escena = false
	if _capa_error != null:
		_capa_error.get_node("Texto").text += "\n\n" + texto
		return
	_capa_error = CanvasLayer.new()
	_capa_error.layer = 128
	var fondo := ColorRect.new()
	fondo.color = Color(0.12, 0.05, 0.05, 0.92)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capa_error.add_child(fondo)
	var etiqueta := Label.new()
	etiqueta.name = "Texto"
	etiqueta.set_anchors_preset(Control.PRESET_FULL_RECT)
	etiqueta.offset_left = 16
	etiqueta.offset_right = -16
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.add_theme_font_size_override("font_size", 8)  # chica: aunque el tema falle, cabe todo
	etiqueta.text = "Algo falló (el juego no se colgó):\n\n" + texto \
		+ "\n\nVersión de Godot: %s. Este proyecto necesita Godot 4.3 o más nuevo." % Engine.get_version_info()["string"] \
		+ "\nCopia este mensaje y la pestaña Salida (Output) de Godot y mándamelo."
	_capa_error.add_child(etiqueta)
	add_child(_capa_error)


# ---------------------------------------------------------------------------
# Autodiagnóstico al iniciar: revisa que el tema, los tilesets y los mapas carguen bien.
# Si algo falla, lo muestra en pantalla (y en la pestaña Salida) en vez de dejar todo negro.
# ---------------------------------------------------------------------------
const MAPAS := ["res://escenas/mapas/refugio_cero.tscn", "res://escenas/mapas/superficie.tscn", "res://escenas/mapas/bastion_oxido.tscn",
	"res://escenas/mapas/autopista.tscn", "res://escenas/mapas/sumidero.tscn"]

func _autodiagnostico() -> void:
	var problemas: Array[String] = []
	# ¿Godot importó las imágenes y letras? (si no, nada de lo demás puede cargar)
	var sin_importar: Array[String] = []
	for ruta in ["res://arte/interfaz/boton.png", "res://arte/interfaz/panel.png", "res://arte/tiles/interior.png",
			"res://arte/tiles/exterior.png", "res://arte/tiles/subterraneo.png", "res://arte/interfaz/exclamacion.png", "res://arte/fuentes/PixelifySans.ttf"]:
		if load(ruta) == null:
			sin_importar.append(ruta.trim_prefix("res://"))
	var tema := load("res://arte/tema.tres") as Theme
	if tema == null:
		problemas.append("No carga arte/tema.tres (botones y letra pixel).")
	elif not tema.is_type_variation(&"BotonRedondo", &"Button") or tema.default_font == null:
		problemas.append("arte/tema.tres es una versión vieja o está incompleto.")
	for ruta in ["res://arte/tiles/interior.tres", "res://arte/tiles/exterior.tres", "res://arte/tiles/subterraneo.tres"]:
		var ts := load(ruta) as TileSet
		if ts == null or ts.get_source_count() == 0:
			problemas.append("No carga el tileset " + ruta)
		else:
			var fuente := ts.get_source(ts.get_source_id(0)) as TileSetAtlasSource
			if fuente == null or fuente.texture == null:
				problemas.append("El tileset %s no encuentra su imagen PNG." % ruta)
	for ruta in ["res://scripts/mapa.gd", "res://scripts/historia.gd", "res://scripts/hud.gd", "res://scripts/pan.gd",
			"res://scripts/combate.gd", "res://scripts/intro.gd", "res://scripts/caja_dialogo.gd", "res://scripts/interactuable.gd"]:
		var sc := load(ruta) as GDScript
		if sc == null or not sc.can_instantiate():
			problemas.append("El script %s tiene un error." % ruta)
	for ruta in MAPAS:
		var escena := load(ruta) as PackedScene
		if escena == null:
			problemas.append("No carga el mapa " + ruta)
			continue
		var mapa := escena.instantiate()
		var suelo := mapa.get_node_or_null("Suelo") as TileMapLayer
		if suelo == null or suelo.tile_set == null or suelo.get_used_cells().is_empty():
			problemas.append("El mapa %s no tiene su suelo (TileMapLayer) bien cargado." % ruta)
		for nodo in ["HUD", "Entidades/Pan", "Entradas"]:
			if not mapa.has_node(nodo):
				problemas.append("Al mapa %s le falta el nodo %s." % [ruta, nodo])
		mapa.free()
	if problemas.is_empty() and sin_importar.is_empty():
		print("Autodiagnóstico: todo bien.")
		return
	var distintos := _archivos_distintos()
	var texto := "\n".join(problemas)
	if not sin_importar.is_empty():
		texto = "Godot no importó estas imágenes/letras: " + ", ".join(sin_importar) \
			+ "\nPor eso no cargan el tema, los tilesets ni los mapas.\n\n" \
			+ "ARREGLO: cierra Godot. Abre la carpeta del proyecto en el Explorador de Windows y borra la carpeta \".godot\" " \
			+ "(es solo caché; si no la ves, activa Vista > Elementos ocultos). Abre Godot otra vez, espera a que termine " \
			+ "la barra de importación y pulsa F5.\n\n" + texto
	if not distintos.is_empty():
		texto += "\n\nEstos archivos son distintos a los de GitHub (quizás Godot guardó encima una versión vieja):\n" \
			+ "\n".join(distintos.slice(0, 8)) + ("\n..." if distintos.size() > 8 else "")
		texto += "\n\nArreglo: cierra Godot. En GitHub Desktop, en la pestaña Changes, clic derecho > Discard all changes. Abre Godot otra vez."
	_mostrar_error(texto)


## Compara los archivos con datos/huellas.json (md5 de cada archivo tal como está en GitHub).
func _archivos_distintos() -> Array[String]:
	var lista: Array[String] = []
	var huellas := _leer_json("res://datos/huellas.json")
	for ruta in huellas:
		if not FileAccess.file_exists(ruta):
			lista.append(ruta.trim_prefix("res://") + " (falta)")
		elif FileAccess.get_md5(ruta) != huellas[ruta]:
			lista.append(ruta.trim_prefix("res://"))
	return lista


func _version_suficiente() -> bool:
	var v := Engine.get_version_info()
	return v["major"] > VERSION_MINIMA[0] or (v["major"] == VERSION_MINIMA[0] and v["minor"] >= VERSION_MINIMA[1])


func _ready() -> void:
	randomize()
	if OS.has_feature("editor"):
		get_tree().node_added.connect(_al_agregar_nodo)
	if not _version_suficiente():
		_mostrar_error.call_deferred("Tu Godot es muy viejo para este proyecto: los mapas usan TileMapLayer, que existe desde Godot 4.3.\nDescarga Godot 4.3 o más nuevo desde godotengine.org.")
	else:
		_autodiagnostico.call_deferred()
	criaturas = _leer_json(RUTA_CRIATURAS).get("criaturas", {})
	dialogos = _leer_json(RUTA_DIALOGOS)
	nueva_partida()


func _leer_json(ruta: String) -> Dictionary:
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		push_error("No se pudo abrir " + ruta)
		return {}
	var datos = JSON.parse_string(archivo.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY:
		push_error(ruta + " tiene un error de formato")
		return {}
	return datos


func flag(nombre: String) -> bool:
	return flags.get(nombre, false)


func ir_a_mapa(ruta: String, nombre_entrada: String) -> void:
	entrada = nombre_entrada
	posicion_pan = null
	cambiar_escena(ruta)


# ---------------------------------------------------------------------------
# Niveles por cartas duplicadas: 1 carta = Nvl 1, 2 = Nvl 2, 4 = Nvl 3, 8 = Nvl 4...
# ---------------------------------------------------------------------------

func nivel_por_cartas(cantidad: int) -> int:
	var nivel := 1
	var necesarias := 2
	while cantidad >= necesarias and nivel < NIVEL_MAXIMO:
		nivel += 1
		necesarias *= 2
	return nivel


## Cuántas cartas en total se necesitan para tener ese nivel.
func cartas_para_nivel(nivel: int) -> int:
	return 1 << (nivel - 1)


func stats(id: String, nivel: int) -> Dictionary:
	var c: Dictionary = criaturas[id]
	var mult := 1.0 + AUMENTO_STATS_POR_NIVEL * (nivel - 1)
	return {
		"hp": int(round(c["hp"] * mult)),
		"ataque": c["ataque"] * mult,
		"defensa": c["defensa"] * mult,
		"velocidad": c["velocidad"] * mult,
		"evasion": float(c.get("evasion", 0.0)),
	}


## Los movimientos que la criatura conoce a ese nivel
## (cada movimiento cambia de nombre y poder al subir de nivel).
func movimientos(id: String, nivel: int) -> Array:
	var lista: Array = []
	for mov in criaturas[id]["movimientos"]:
		var elegido = null
		for version in mov["versiones"]:
			if nivel >= int(version["desde_nivel"]):
				elegido = version
		if elegido != null:
			lista.append(elegido)
	return lista


## Crea un "luchador": todo lo que el combate necesita saber de una criatura.
func crear_luchador(id: String, nivel: int, hp_actual: int = -1) -> Dictionary:
	var c: Dictionary = criaturas[id]
	var s := stats(id, nivel)
	return {
		"id": id,
		"nombre": c["nombre"],
		"nivel": nivel,
		"hp_max": s["hp"],
		"hp": s["hp"] if hp_actual < 0 else hp_actual,
		"ataque": s["ataque"],
		"defensa": s["defensa"],
		"velocidad": s["velocidad"],
		"evasion": s["evasion"],
		"evasion_base": s["evasion"],
		"velocidad_base": s["velocidad"],
		"tipo": c.get("tipo", "feral"),
		"debil_a": c.get("debil_a", []),
		"resiste": c.get("resiste", []),
		"inmune": c.get("inmune", []),
		"pasiva": c.get("pasiva", ""),
		"ataque_base": s["ataque"],
		"defensa_base": s["defensa"],
		"ia": c.get("ia", "agresivo"),
		"facilidad_captura": float(c.get("facilidad_captura", 0.7)),
		"movimientos": movimientos(id, nivel),
		"infectado": false,
		"paralizado": 0,
		"bajo_tierra": false,
		"quemado": false,       # quemadura (molotov, colmillos ígneos): quita vida cada turno
		"cegado": 0,            # turnos con la precisión baja (humo)
		"enlodado": false,      # Velocidad en 0 hasta que sale del campo (lodo de la Sirena)
		"camuflado": 0,         # turnos en que es invisible (Cazador Camuflado)
		"aturdido": false,      # pierde su próxima acción (salpicadura de la Burbuja Tóxica)
	}


func textura_criatura(id: String) -> Texture2D:
	var t := textura("res://arte/criaturas/%s.png" % id)
	return t if t != null else load("res://icon.svg")


# ---------------------------------------------------------------------------
# Imágenes siempre al día
# ---------------------------------------------------------------------------
# Si actualizas el proyecto (Pull) y Godot no volvió a importar un PNG, el juego mostraría la
# imagen vieja (o nada, si el PNG es nuevo). Al jugar desde el editor (F5), aquí se compara cada
# PNG con lo que Godot importó y, si no coincide, se usa el PNG directo del disco.
var _texturas_frescas := {}   # ruta -> Texture2D cargada del disco (o null si la importada está al día)
var pngs_sin_importar: Array[String] = []


## Úsalo en vez de load() para cualquier PNG que se cargue desde código.
func textura(ruta: String) -> Texture2D:
	var fresca := _textura_fresca(ruta)
	if fresca != null:
		return fresca
	if ResourceLoader.exists(ruta):
		return load(ruta) as Texture2D
	return null


func _textura_fresca(ruta: String) -> Texture2D:
	if not OS.has_feature("editor") or not ruta.ends_with(".png"):
		return null  # en el juego exportado (celular / navegador) todo viene importado
	if _texturas_frescas.has(ruta):
		return _texturas_frescas[ruta]
	var tex: Texture2D = null
	if FileAccess.file_exists(ruta) and _importacion_vieja(ruta):
		var img := Image.load_from_file(ProjectSettings.globalize_path(ruta))
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
			pngs_sin_importar.append(ruta.trim_prefix("res://"))
	_texturas_frescas[ruta] = tex
	return tex


## true si Godot todavía no importó este PNG o lo importó cuando era otra versión.
func _importacion_vieja(ruta: String) -> bool:
	var info := ConfigFile.new()
	if info.load(ruta + ".import") != OK:
		return true
	var destino: String = info.get_value("remap", "path", "")
	if destino == "" or not FileAccess.file_exists(destino):
		return true
	var md5 := ConfigFile.new()
	if md5.load(destino.get_basename() + ".md5") != OK:
		return true
	return str(md5.get_value("", "source_md5", "")) != FileAccess.get_md5(ruta)


## Cada Sprite2D / TextureRect / mapa de tiles que aparece en pantalla usa la versión al día de su PNG.
func _al_agregar_nodo(nodo: Node) -> void:
	if nodo is Sprite2D or nodo is TextureRect:
		var t: Texture2D = nodo.texture
		if t != null and t.resource_path.ends_with(".png"):
			var fresca := _textura_fresca(t.resource_path)
			if fresca != null:
				nodo.texture = fresca
	elif nodo is TileMapLayer and nodo.tile_set != null:
		var ts: TileSet = nodo.tile_set
		for k in ts.get_source_count():
			var fuente := ts.get_source(ts.get_source_id(k)) as TileSetAtlasSource
			if fuente != null and fuente.texture != null and fuente.texture.resource_path.ends_with(".png"):
				var fresca := _textura_fresca(fuente.texture.resource_path)
				if fresca != null:
					fuente.texture = fresca


# ---------------------------------------------------------------------------
# Mochila / cartas
# ---------------------------------------------------------------------------

func indice_carta(id: String) -> int:
	for i in mochila.size():
		if mochila[i]["id"] == id:
			return i
	return -1


func nivel_carta(carta: Dictionary) -> int:
	return nivel_por_cartas(carta["cantidad"])


func hp_max_carta(carta: Dictionary) -> int:
	return stats(carta["id"], nivel_carta(carta))["hp"]


## Agrega una carta. Si ya la tenías, suma un duplicado (y quizá sube de nivel).
func agregar_carta(id: String) -> Dictionary:
	var i := indice_carta(id)
	if i == -1:
		var carta := { "id": id, "cantidad": 1, "hp": 0 }
		carta["hp"] = hp_max_carta(carta)
		mochila.append(carta)
		return { "nueva": true, "nivel_antes": 1, "nivel_despues": 1, "cantidad": 1 }
	var carta: Dictionary = mochila[i]
	var nivel_antes := nivel_carta(carta)
	var hp_max_antes := hp_max_carta(carta)
	carta["cantidad"] += 1
	var nivel_despues := nivel_carta(carta)
	# Al subir de nivel aumenta la vida máxima (una carta rota sigue rota hasta dormir).
	if carta["hp"] > 0:
		carta["hp"] += hp_max_carta(carta) - hp_max_antes
	return { "nueva": false, "nivel_antes": nivel_antes, "nivel_despues": nivel_despues, "cantidad": carta["cantidad"] }


func equipo() -> Array:
	return mochila.slice(0, MAX_EQUIPO)


func hay_cartas_vivas() -> bool:
	for carta in equipo():
		if carta["hp"] > 0:
			return true
	return false


## Dormir: la ÚNICA forma gratuita de curar y reparar cartas (no hay objetos de revivir).
## También quita la infección que las cartas arrastran después de un combate.
func dormir() -> void:
	for carta in mochila:
		carta["hp"] = hp_max_carta(carta)
		carta["infectada"] = false


## La infección no se va al terminar el combate (GDD: atrición). Fuera del combate, cada
## varios pasos quita un poquito de vida a las cartas infectadas, pero nunca las rompe.
## Devuelve los nombres de las cartas que perdieron vida.
func infeccion_al_caminar() -> Array:
	var nombres: Array = []
	for carta in equipo():
		if carta.get("infectada", false) and carta["hp"] > 1:
			carta["hp"] = maxi(1, carta["hp"] - maxi(1, hp_max_carta(carta) / 40))
			nombres.append(criaturas[carta["id"]]["nombre"])
	return nombres


func hay_cartas_infectadas() -> bool:
	for carta in equipo():
		if carta.get("infectada", false):
			return true
	return false


## Primera carta del equipo que no está rota (la que va al frente al caminar), o -1.
func carta_al_frente() -> int:
	var eq := equipo()
	for i in eq.size():
		if eq[i]["hp"] > 0:
			return i
	return -1


func hay_cartas_heridas() -> bool:
	for carta in mochila:
		if carta["hp"] < hp_max_carta(carta):
			return true
	return false


## Guarda objetos en la mochila sin pasarse del límite. Devuelve cuántos cupieron.
func dar_objeto(id: String, cantidad: int = 1) -> int:
	var tope := max_objeto(id)
	var antes: int = objetos.get(id, 0)
	objetos[id] = mini(antes + cantidad, tope)
	return objetos[id] - antes


func nombre_objeto(id: String) -> String:
	return OBJETOS.get(id, {}).get("nombre", id)


func max_objeto(id: String) -> int:
	return int(OBJETOS.get(id, {}).get("max", 99))


func tipo_objeto(id: String) -> String:
	return OBJETOS.get(id, {}).get("tipo", "")


func tiene_objeto(id: String) -> bool:
	return objetos.get(id, 0) > 0


func usar_objeto(id: String) -> void:
	objetos[id] = maxi(0, objetos.get(id, 0) - 1)


# ---------------------------------------------------------------------------
# Economía (GDD): comprar en la tienda, vender reliquias, partes y cartas
# ---------------------------------------------------------------------------

## Compra un objeto. Devuelve "" si salió bien, o el motivo si no se pudo.
func comprar(id: String) -> String:
	var precio := int(OBJETOS[id]["precio"])
	if objetos.get(id, 0) >= max_objeto(id):
		return "Tu mochila no tiene espacio para más (máx. %d)." % max_objeto(id)
	if monedas < precio:
		return "No te alcanza: cuesta %d monedas y tienes %d." % [precio, monedas]
	monedas -= precio
	dar_objeto(id, 1)
	return ""


## Datos de una parte de criatura ({ "nombre", "precio" }), buscándola en criaturas.json.
func info_parte(id_parte: String) -> Dictionary:
	for id in criaturas:
		var p: Dictionary = criaturas[id].get("parte", {})
		if p.get("id", "") == id_parte:
			return p
	return { "nombre": id_parte, "precio": 5 }


func valor_partes() -> int:
	var total := 0
	for id in partes:
		total += int(info_parte(id)["precio"]) * int(partes[id])
	return total


## Vende todas las reliquias y partes. Devuelve las monedas ganadas.
func vender_botin() -> int:
	var total := chatarra * PRECIO_RELIQUIA + valor_partes()
	monedas += total
	chatarra = 0
	partes.clear()
	return total


func precio_carta(id: String) -> int:
	return int(criaturas[id].get("valor", 20))


## ¿Se puede vender una carta de esta fila de la mochila? (siempre te queda al menos una criatura)
func puede_vender_carta(i: int) -> bool:
	return i < mochila.size() and (mochila[i]["cantidad"] > 1 or mochila.size() > 1)


## Vende UNA carta (un duplicado). Si era la última de esa criatura, la criatura se va.
func vender_carta(i: int) -> int:
	if not puede_vender_carta(i):
		return 0
	var carta: Dictionary = mochila[i]
	var precio := precio_carta(carta["id"])
	monedas += precio
	if carta["cantidad"] > 1:
		carta["cantidad"] -= 1
		carta["hp"] = mini(carta["hp"], hp_max_carta(carta))
	else:
		mochila.remove_at(i)
	return precio


## Usa una cura o comida fuera de combate en una carta. Devuelve un texto con lo que pasó.
func usar_en_carta(id: String, i: int) -> String:
	var carta: Dictionary = mochila[i]
	var nombre: String = criaturas[carta["id"]]["nombre"]
	var hp_max := hp_max_carta(carta)
	if carta["hp"] <= 0:
		return "La carta de %s está rota. Solo se repara durmiendo en una ciudad." % nombre
	if tipo_objeto(id) == "antidoto":
		if not carta.get("infectada", false):
			return "%s no está infectado." % nombre
		if not tiene_objeto(id):
			return "No te queda %s." % nombre_objeto(id)
		carta["infectada"] = false
		usar_objeto(id)
		return "El Antídoto limpia la infección de %s." % nombre
	if carta["hp"] >= hp_max:
		return "%s ya tiene toda su vida." % nombre
	if not tiene_objeto(id):
		return "No te queda %s." % nombre_objeto(id)
	var cura := maxi(1, roundi(hp_max * float(OBJETOS[id]["valor"])))
	var antes: int = carta["hp"]
	carta["hp"] = mini(hp_max, carta["hp"] + cura)
	usar_objeto(id)
	return "%s recupera %d de vida." % [nombre, carta["hp"] - antes]


func mision_activa(id: String) -> bool:
	return misiones.get(id, {}).get("estado", "") == "activa"


func mision_completa(id: String) -> bool:
	return misiones.get(id, {}).get("estado", "") == "completa"


func empezar_mision(id: String, titulo: String) -> void:
	if not misiones.has(id):
		misiones[id] = { "titulo": titulo, "estado": "activa" }


func completar_mision(id: String) -> void:
	if misiones.has(id):
		misiones[id]["estado"] = "completa"



# ---------------------------------------------------------------------------
# Partida: empezar de cero, guardar y cargar
# ---------------------------------------------------------------------------

## Deja todo como al principio del juego (mochila vacía, sin banderas...).
func nueva_partida() -> void:
	mochila = []
	objetos = { "carta_vinculo": 0, "granada_aturdidora": 0 }
	monedas = 0
	chatarra = 0
	partes = {}
	bonus_ataque = 0.0
	misiones = {}
	tormenta = false
	tiempo_clima = 0.0
	flags = {}
	mision = ""
	entrada = ""
	posicion_pan = null
	mapa_actual = ""
	lugar_descanso = { "mapa": "res://escenas/mapas/refugio_cero.tscn", "entrada": "Cama" }
	pasos_sin_encuentro = 0
	encuentro = {}
	resultado_combate = {}
	mensajes_pendientes = []
	tiempo_jugado = 0.0
	guardar_pronto = false
	var inicial: String = _leer_json(RUTA_CRIATURAS).get("carta_inicial", "")
	if inicial != "":
		agregar_carta(inicial)


func hay_partida_guardada() -> bool:
	return not _leer_guardado(RUTA_GUARDADO).is_empty() or not _leer_guardado(RUTA_RESPALDO).is_empty()


func borrar_partida() -> void:
	for ruta in [RUTA_GUARDADO, RUTA_RESPALDO]:
		if FileAccess.file_exists(ruta):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))


## Guarda la partida. Solo funciona en un mapa y cuando no está pasando ningún evento.
## Devuelve true si se guardó.
func guardar() -> bool:
	var escena := get_tree().current_scene
	if cambiando_escena or escena == null or not escena.has_method("puede_guardar") or not escena.puede_guardar():
		return false
	var pos: Vector2 = escena.pan.global_position
	var datos := {
		"version": VERSION_GUARDADO,
		"fecha": Time.get_datetime_string_from_system(false, true),
		"tiempo_jugado": tiempo_jugado,
		"mapa": escena.scene_file_path,
		"nombre_mapa": escena.nombre_mapa,
		"posicion": [pos.x, pos.y],
		"mochila": mochila,
		"objetos": objetos,
		"monedas": monedas,
		"chatarra": chatarra,
		"partes": partes,
		"bonus_ataque": bonus_ataque,
		"misiones": misiones,
		"flags": flags,
		"mision": mision,
		"lugar_descanso": lugar_descanso,
		"tormenta": tormenta,
		"tiempo_clima": tiempo_clima,
		"pasos_sin_encuentro": pasos_sin_encuentro,
	}
	# La partida anterior queda de respaldo, por si el guardado nuevo se corta a la mitad.
	var anterior := FileAccess.get_file_as_string(RUTA_GUARDADO) if FileAccess.file_exists(RUTA_GUARDADO) else ""
	if anterior != "":
		_escribir(RUTA_RESPALDO, anterior)
	return _escribir(RUTA_GUARDADO, JSON.stringify(datos, "\t"))


func _escribir(ruta: String, texto: String) -> bool:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_warning("No se pudo guardar en %s (error %d)" % [ruta, FileAccess.get_open_error()])
		return false
	archivo.store_string(texto)
	archivo.close()
	return true


func _leer_guardado(ruta: String) -> Dictionary:
	if not FileAccess.file_exists(ruta):
		return {}
	var datos = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	if typeof(datos) != TYPE_DICTIONARY or not datos.has("mapa") or not datos.has("mochila"):
		return {}
	return datos


## Lo que muestra el menú en "Continuar": lugar, cartas, monedas y tiempo jugado.
func resumen_partida() -> Dictionary:
	var datos := _leer_guardado(RUTA_GUARDADO)
	if datos.is_empty():
		datos = _leer_guardado(RUTA_RESPALDO)
	if datos.is_empty():
		return {}
	var lugares := { "refugio_cero": "Refugio Cero", "superficie": "La Superficie", "bastion_oxido": "Bastión de Óxido",
		"autopista": "La Autopista Quemada", "sumidero": "El Sumidero" }
	var nombre: String = datos.get("nombre_mapa", "")
	var minutos := int(float(datos.get("tiempo_jugado", 0.0)) / 60.0)
	return {
		"lugar": lugares.get(nombre, nombre.capitalize()),
		"cartas": (datos["mochila"] as Array).size(),
		"monedas": int(datos.get("monedas", 0)),
		"tiempo": "%d h %02d min" % [minutos / 60, minutos % 60] if minutos >= 60 else "%d min" % minutos,
	}


## Carga la partida guardada y lleva a Pan al lugar donde guardó.
func cargar() -> bool:
	var datos := _leer_guardado(RUTA_GUARDADO)
	if datos.is_empty():
		datos = _leer_guardado(RUTA_RESPALDO)
	if datos.is_empty():
		return false
	nueva_partida()
	mochila = []
	for c in datos["mochila"]:
		if c is Dictionary and criaturas.has(c.get("id", "")):
			var carta := { "id": c["id"], "cantidad": maxi(1, int(c.get("cantidad", 1))), "hp": int(c.get("hp", 0)) }
			if c.has("infectada"):
				carta["infectada"] = bool(c["infectada"])   # la infección sigue al cargar (Ciudad 2)
			mochila.append(carta)
	objetos = { "carta_vinculo": 0, "granada_aturdidora": 0 }
	var guardados: Dictionary = datos.get("objetos", {})
	for id in guardados:
		objetos[id] = int(guardados[id])
	monedas = int(datos.get("monedas", 0))
	chatarra = int(datos.get("chatarra", 0))
	partes = {}
	var p: Dictionary = datos.get("partes", {})
	for id in p:
		partes[id] = int(p[id])
	bonus_ataque = float(datos.get("bonus_ataque", 0.0))
	misiones = datos.get("misiones", {})
	flags = datos.get("flags", {})
	mision = str(datos.get("mision", ""))
	var descanso = datos.get("lugar_descanso", {})
	if descanso is Dictionary and ResourceLoader.exists(str(descanso.get("mapa", ""))):
		lugar_descanso = descanso
	tormenta = bool(datos.get("tormenta", false))
	tiempo_clima = float(datos.get("tiempo_clima", 0.0))
	pasos_sin_encuentro = int(datos.get("pasos_sin_encuentro", 0))
	tiempo_jugado = float(datos.get("tiempo_jugado", 0.0))
	var ruta: String = datos.get("mapa", "")
	var pos = datos.get("posicion", null)
	if ResourceLoader.exists(ruta) and pos is Array and pos.size() == 2:
		entrada = ""
		posicion_pan = Vector2(float(pos[0]), float(pos[1]))
		cambiar_escena(ruta)
	else:   # el mapa ya no existe: aparece donde descansó por última vez
		ir_a_mapa(lugar_descanso["mapa"], lugar_descanso["entrada"])
	return true


## Si cierras o minimizas el juego en medio de la exploración, se guarda solo.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		if is_inside_tree():
			guardar()
