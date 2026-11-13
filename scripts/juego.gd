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

const NOMBRES_OBJETOS := {
	"carta_vinculo": "Carta de Vínculo",
	"granada_aturdidora": "Granada Aturdidora",
}

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
var chatarra := 0

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
	etiqueta.text = "Algo falló (el juego no se colgó):\n\n" + texto \
		+ "\n\nVersión de Godot: %s. Este proyecto necesita Godot 4.3 o más nuevo." % Engine.get_version_info()["string"] \
		+ "\nCopia este mensaje y la pestaña Salida (Output) de Godot y mándamelo."
	_capa_error.add_child(etiqueta)
	add_child(_capa_error)


func _version_suficiente() -> bool:
	var v := Engine.get_version_info()
	return v["major"] > VERSION_MINIMA[0] or (v["major"] == VERSION_MINIMA[0] and v["minor"] >= VERSION_MINIMA[1])


func _ready() -> void:
	randomize()
	if not _version_suficiente():
		_mostrar_error.call_deferred("Tu Godot es muy viejo para este proyecto: los mapas usan TileMapLayer, que existe desde Godot 4.3.\nDescarga Godot 4.3 o más nuevo desde godotengine.org.")
	criaturas = _leer_json(RUTA_CRIATURAS).get("criaturas", {})
	dialogos = _leer_json(RUTA_DIALOGOS)
	var inicial: String = _leer_json(RUTA_CRIATURAS).get("carta_inicial", "")
	if inicial != "":
		agregar_carta(inicial)


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
		"debil_a": c.get("debil_a", []),
		"resiste": c.get("resiste", []),
		"ia": c.get("ia", "agresivo"),
		"facilidad_captura": float(c.get("facilidad_captura", 0.7)),
		"movimientos": movimientos(id, nivel),
		"infectado": false,
	}


func textura_criatura(id: String) -> Texture2D:
	var ruta := "res://arte/criaturas/%s.png" % id
	if ResourceLoader.exists(ruta):
		return load(ruta)
	return load("res://icon.svg")


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
func dormir() -> void:
	for carta in mochila:
		carta["hp"] = hp_max_carta(carta)


func hay_cartas_heridas() -> bool:
	for carta in mochila:
		if carta["hp"] < hp_max_carta(carta):
			return true
	return false


func dar_objeto(id: String, cantidad: int = 1) -> void:
	objetos[id] = objetos.get(id, 0) + cantidad


func tiene_objeto(id: String) -> bool:
	return objetos.get(id, 0) > 0


func usar_objeto(id: String) -> void:
	objetos[id] = maxi(0, objetos.get(id, 0) - 1)
