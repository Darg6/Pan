extends Node
## Estado global del juego. Está registrado como Autoload con el nombre "Juego",
## así que desde cualquier script puedes escribir Juego.mochila, Juego.agregar_carta(...), etc.

const RUTA_CRIATURAS := "res://datos/criaturas.json"
const NIVEL_MAXIMO := 10
const MAX_EQUIPO := 6
const AUMENTO_STATS_POR_NIVEL := 0.15  # +15% de stats por nivel (GDD)

## Datos de todas las criaturas, leídos de datos/criaturas.json. Clave = id ("gato_mutado").
var criaturas: Dictionary = {}

## La mochila de Pan: una lista de cartas. Cada carta es un diccionario:
## { "id": "gato_mutado", "cantidad": 1, "hp": 90 }
## Las primeras MAX_EQUIPO cartas son el "Equipo activo".
var mochila: Array = []

# --- Estado del mundo (se guarda aquí porque la escena del mundo se destruye al ir al combate) ---
var posicion_pan = null          # Vector2 o null si es la primera vez
var posicion_refugio := Vector2(260, 260)
var pasos_sin_encuentro := 0     # pasos de gracia tras un combate
var encuentro := {}              # { "id": "aves_negras", "nivel": 1 } para la escena de combate
var mensajes_pendientes: Array = []  # textos a mostrar al volver al mapa


func _ready() -> void:
	randomize()
	_cargar_datos()


func _cargar_datos() -> void:
	var archivo := FileAccess.open(RUTA_CRIATURAS, FileAccess.READ)
	if archivo == null:
		push_error("No se pudo abrir " + RUTA_CRIATURAS)
		return
	var datos = JSON.parse_string(archivo.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY:
		push_error("criaturas.json tiene un error de formato")
		return
	criaturas = datos["criaturas"]
	# Pan empieza con una carta de compañero.
	if mochila.is_empty():
		agregar_carta(datos.get("carta_inicial", "gato_mutado"))


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


## Devuelve los movimientos que la criatura conoce a ese nivel
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
		"forma": c.get("forma", "humanoide"),
		"color": c.get("color", "#ffffff"),
		"infectado": false,
	}


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


## Agrega una carta a la mochila. Si ya la tenías, suma un duplicado (y quizá sube de nivel).
## Devuelve información para mostrar mensajes.
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
	# Al subir de nivel aumenta la vida máxima; la carta gana esa vida extra
	# (pero una carta rota sigue rota hasta dormir en un refugio).
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


## Dormir en un refugio: la ÚNICA forma de curar y reparar cartas (no hay objetos de revivir).
func dormir() -> void:
	for carta in mochila:
		carta["hp"] = hp_max_carta(carta)


func hay_cartas_heridas() -> bool:
	for carta in mochila:
		if carta["hp"] < hp_max_carta(carta):
			return true
	return false
