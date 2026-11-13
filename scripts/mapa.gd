extends Node2D
## Controla cualquier mapa top-down (Refugio Cero, Superficie, ...).
## Estructura que espera la escena:
##   Suelo (TileMapLayer)          -> los tiles del mapa
##   Entidades (Node2D, y-sort)    -> Pan, personajes e interactuables
##   Zonas (Node2D)                -> zonas de encuentro con criaturas
##   Disparadores (Node2D)         -> eventos al pisar una zona
##   Entradas (Node2D)             -> Marker2D donde aparece Pan al llegar
##   HUD (escenas/ui/hud.tscn)
## Lo que pasa en cada evento está en scripts/historia.gd.

const ESCENA_COMBATE := "res://escenas/combate.tscn"

## Nombre corto del mapa, lo usa historia.gd ("refugio_cero", "superficie")
@export var nombre_mapa := ""
## Acercamiento de la cámara (los interiores pequeños se ven mejor más cerca)
@export var zoom_camara := 1.0

@onready var pan: CharacterBody2D = $Entidades/Pan
@onready var suelo: TileMapLayer = $Suelo
@onready var hud: CanvasLayer = $HUD

var ocupado := false            # true mientras corre un evento o diálogo
var _dentro_de: Dictionary = {}  # disparadores que Pan está pisando
var _exclamacion: Sprite2D
var _aviso_sin_cartas := false


func _ready() -> void:
	Juego.cambiando_escena = false
	Juego.mapa_actual = scene_file_path
	pan.joystick = hud.joystick
	pan.paso_dado.connect(_on_paso_dado)
	hud.accion_pulsada.connect(interactuar)

	# ¿Dónde aparece Pan?
	if Juego.posicion_pan != null:
		pan.global_position = Juego.posicion_pan
		Juego.posicion_pan = null
	elif Juego.entrada != "" and has_node("Entradas/" + Juego.entrada):
		pan.global_position = get_node("Entradas/" + Juego.entrada).global_position

	# La cámara no sale del mapa (si el mapa es más chico que la pantalla, queda centrado)
	var camara: Camera2D = pan.get_node("Camara")
	camara.zoom = Vector2(zoom_camara, zoom_camara)
	var usado := suelo.get_used_rect()
	var rect := Rect2(Vector2(usado.position) * 16, Vector2(usado.size) * 16)
	var vista := get_viewport_rect().size / zoom_camara
	if rect.size.x < vista.x:
		rect = rect.grow_individual((vista.x - rect.size.x) / 2.0, 0, (vista.x - rect.size.x) / 2.0, 0)
	if rect.size.y < vista.y:
		rect = rect.grow_individual(0, (vista.y - rect.size.y) / 2.0, 0, (vista.y - rect.size.y) / 2.0)
	camara.limit_left = floori(rect.position.x)
	camara.limit_top = floori(rect.position.y)
	camara.limit_right = ceili(rect.end.x)
	camara.limit_bottom = ceili(rect.end.y)
	camara.reset_smoothing()

	_exclamacion = Sprite2D.new()
	_exclamacion.texture = preload("res://arte/interfaz/exclamacion.png")
	_exclamacion.z_index = 10
	_exclamacion.visible = false
	add_child(_exclamacion)

	# No disparar eventos de zonas en las que Pan ya aparece parado
	for d in get_tree().get_nodes_in_group("disparadores"):
		_dentro_de[d] = d.contiene(pan.global_position)

	refrescar()
	hud.transicion.color.a = 1.0
	await hud.fundido(false, 0.5)
	await correr(Historia.al_entrar_mapa.bind(self))
	for m in Juego.mensajes_pendientes:
		hud.mostrar_aviso(m)
	Juego.mensajes_pendientes.clear()


## Ejecuta un evento de la historia bloqueando el movimiento mientras dura.
func correr(evento: Callable) -> void:
	ocupado = true
	pan.puede_moverse = false
	hud.set_controles(false)
	_exclamacion.visible = false
	await evento.call()
	if Juego.cambiando_escena or not is_inside_tree():
		return  # el evento cambió de escena
	ocupado = false
	pan.puede_moverse = true
	hud.set_controles(true)
	refrescar()


func refrescar() -> void:
	for nodo in get_tree().get_nodes_in_group("interactuables"):
		nodo.actualizar()
	hud.actualizar()


func _process(_delta: float) -> void:
	if ocupado or hud.panel_mochila.visible:
		_exclamacion.visible = false
		pan.puede_moverse = not ocupado and not hud.panel_mochila.visible
		return
	pan.puede_moverse = true
	var cercano = _interactuable_cercano()
	_exclamacion.visible = cercano != null
	if cercano != null:
		_exclamacion.global_position = cercano.global_position + Vector2(0, -24 if cercano.solido else -14)

	for d in get_tree().get_nodes_in_group("disparadores"):
		var dentro: bool = d.contiene(pan.global_position)
		if dentro and not _dentro_de.get(d, false):
			_dentro_de[d] = true
			correr(Historia.ejecutar.bind(d.evento, d))
			return
		_dentro_de[d] = dentro


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interactuar") and not ocupado:
		get_viewport().set_input_as_handled()
		interactuar()


func _interactuable_cercano():
	var punto: Vector2 = pan.global_position + pan.direccion_mirada() * 8.0
	var mejor = null
	var mejor_dist := INF
	for nodo in get_tree().get_nodes_in_group("interactuables"):
		if not nodo.activo():
			continue
		var dist := punto.distance_to(nodo.global_position)
		if dist <= nodo.radio and dist < mejor_dist:
			mejor = nodo
			mejor_dist = dist
	return mejor


func interactuar() -> void:
	if ocupado or hud.panel_mochila.visible:
		return
	var nodo = _interactuable_cercano()
	if nodo != null:
		correr(Historia.ejecutar.bind(nodo.evento, nodo))


# ---------------------------------------------------------------------------
# Encuentros con criaturas salvajes (solo en tiles de pasto)
# ---------------------------------------------------------------------------

func pisando_pasto() -> bool:
	var datos := suelo.get_cell_tile_data(suelo.local_to_map(suelo.to_local(pan.global_position)))
	return datos != null and datos.get_custom_data("pasto")


func _on_paso_dado() -> void:
	if ocupado or not pisando_pasto():
		return
	if Juego.pasos_sin_encuentro > 0:
		Juego.pasos_sin_encuentro -= 1
		return
	for zona in get_tree().get_nodes_in_group("zonas_encuentro"):
		if not zona.contiene(pan.global_position):
			continue
		if not Juego.hay_cartas_vivas():
			if not _aviso_sin_cartas:
				_aviso_sin_cartas = true
				correr(hud.decir.bind("sin_cartas_vivas"))
			return
		if randf() < zona.probabilidad:
			correr(iniciar_combate.bind(zona.elegir_encuentro()))
		return


func iniciar_combate(datos: Dictionary) -> void:
	ocupado = true
	pan.puede_moverse = false
	Juego.posicion_pan = pan.global_position
	Juego.encuentro = datos
	var t := create_tween()
	for i in 2:
		t.tween_property(hud.transicion, "color", Color(1, 1, 1, 0.8), 0.07)
		t.tween_property(hud.transicion, "color", Color(1, 1, 1, 0.0), 0.07)
	t.tween_property(hud.transicion, "color", Color(0, 0, 0, 1), 0.3)
	await t.finished
	Juego.cambiar_escena(ESCENA_COMBATE)


## Empuja a Pan un poco hacia atrás (para caminos bloqueados).
func retroceder_pan(direccion: Vector2, distancia := 12.0) -> void:
	var t := create_tween()
	t.tween_property(pan, "global_position", pan.global_position + direccion * distancia, 0.2)
	await t.finished
