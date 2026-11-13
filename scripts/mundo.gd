extends Node2D
## Escena del mapa top-down: Pan explora, entra en zonas de criaturas y duerme en el refugio.

const ESCENA_COMBATE := "res://escenas/combate.tscn"

@onready var pan: CharacterBody2D = $Pan
@onready var camara: Camera2D = $Pan/Camara
@onready var suelo: Node2D = $Suelo
@onready var refugio: Node2D = $Refugio
@onready var joystick: Control = $Interfaz/Joystick
@onready var boton_mochila: Button = $Interfaz/BotonMochila
@onready var panel_mochila: PanelContainer = $Interfaz/PanelMochila
@onready var aviso: PanelContainer = $Interfaz/Aviso
@onready var texto_aviso: Label = $Interfaz/Aviso/Texto
@onready var transicion: ColorRect = $Interfaz/Transicion

var _cambiando_escena := false
var _en_refugio := false
var _avisos: Array = []
var _mostrando_aviso := false
var _aviso_sin_cartas_dado := false


func _ready() -> void:
	pan.joystick = joystick
	pan.paso_dado.connect(_on_paso_dado)
	boton_mochila.pressed.connect(_abrir_mochila)
	panel_mochila.cerrado.connect(_on_mochila_cerrada)

	if Juego.posicion_pan != null:
		pan.global_position = Juego.posicion_pan
	Juego.posicion_refugio = refugio.centro()

	camara.limit_left = 0
	camara.limit_top = 0
	camara.limit_right = int(suelo.tamano.x)
	camara.limit_bottom = int(suelo.tamano.y)
	camara.reset_smoothing()

	aviso.visible = false
	# Aparecer desde negro
	transicion.color.a = 1.0
	create_tween().tween_property(transicion, "color:a", 0.0, 0.4)

	if Juego.mensajes_pendientes.is_empty() and Juego.posicion_pan == null:
		Juego.mensajes_pendientes.append("Muévete con el joystick (o WASD / flechas). Camina por el pasto seco para encontrar criaturas.")
	for m in Juego.mensajes_pendientes:
		mostrar_aviso(m)
	Juego.mensajes_pendientes.clear()


func _process(_delta: float) -> void:
	var dentro: bool = refugio.contiene(pan.global_position)
	if dentro and not _en_refugio:
		if Juego.hay_cartas_heridas():
			Juego.dormir()
			mostrar_aviso("Pan durmió en el refugio. ¡Todas sus cartas se repararon!")
		else:
			mostrar_aviso("Refugio: aquí Pan duerme y repara sus cartas.")
		_aviso_sin_cartas_dado = false
	_en_refugio = dentro


func _on_paso_dado() -> void:
	if _cambiando_escena or panel_mochila.visible:
		return
	if Juego.pasos_sin_encuentro > 0:
		Juego.pasos_sin_encuentro -= 1
		return
	for zona in get_tree().get_nodes_in_group("zonas_encuentro"):
		if zona.contiene(pan.global_position):
			if not Juego.hay_cartas_vivas():
				if not _aviso_sin_cartas_dado:
					_aviso_sin_cartas_dado = true
					mostrar_aviso("Todas tus cartas están rotas. Pan no puede pelear: vuelve al refugio a dormir.")
				return
			if randf() < zona.probabilidad:
				_iniciar_encuentro(zona.elegir_encuentro())
			return


func _iniciar_encuentro(datos: Dictionary) -> void:
	_cambiando_escena = true
	pan.puede_moverse = false
	Juego.posicion_pan = pan.global_position
	Juego.encuentro = datos
	# Destello y fundido a negro
	var t := create_tween()
	for i in 2:
		t.tween_property(transicion, "color", Color(1, 1, 1, 0.8), 0.08)
		t.tween_property(transicion, "color", Color(1, 1, 1, 0.0), 0.08)
	t.tween_property(transicion, "color", Color(0, 0, 0, 1), 0.35)
	await t.finished
	get_tree().change_scene_to_file(ESCENA_COMBATE)


func _abrir_mochila() -> void:
	if _cambiando_escena:
		return
	pan.puede_moverse = false
	joystick.visible = false  # así el joystick no "roba" los toques sobre la mochila
	panel_mochila.abrir()


func _on_mochila_cerrada() -> void:
	pan.puede_moverse = true
	joystick.visible = true


func mostrar_aviso(texto: String) -> void:
	_avisos.append(texto)
	if not _mostrando_aviso:
		_siguiente_aviso()


func _siguiente_aviso() -> void:
	if _avisos.is_empty():
		_mostrando_aviso = false
		aviso.visible = false
		return
	_mostrando_aviso = true
	texto_aviso.text = _avisos.pop_front()
	aviso.visible = true
	aviso.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(aviso, "modulate:a", 1.0, 0.2)
	t.tween_interval(2.6)
	t.tween_property(aviso, "modulate:a", 0.0, 0.3)
	t.finished.connect(_siguiente_aviso)
