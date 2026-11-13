extends CanvasLayer
## Interfaz del mapa: misión, joystick, botón de acción (A), mochila, avisos y diálogos.

signal accion_pulsada

@onready var mision: Label = $Mision/Texto
@onready var panel_mision: PanelContainer = $Mision
@onready var joystick: Control = $Joystick
@onready var boton_accion: Button = $BotonAccion
@onready var boton_mochila: Button = $BotonMochila
@onready var aviso: PanelContainer = $Aviso
@onready var texto_aviso: Label = $Aviso/Texto
@onready var dialogo: PanelContainer = $CajaDialogo
@onready var panel_mochila: PanelContainer = $PanelMochila
@onready var transicion: ColorRect = $Transicion

var _avisos: Array = []
var _mostrando_aviso := false


func _ready() -> void:
	boton_accion.pressed.connect(func(): accion_pulsada.emit())
	boton_mochila.pressed.connect(abrir_mochila)
	panel_mochila.cerrado.connect(func(): set_controles(true))
	aviso.visible = false
	actualizar()


func actualizar() -> void:
	mision.text = Juego.mision
	panel_mision.visible = Juego.mision != ""
	boton_mochila.visible = Juego.flag("tiene_mochila")


## Muestra u oculta los controles (durante diálogos y menús se ocultan).
func set_controles(activos: bool) -> void:
	joystick.visible = activos
	boton_accion.visible = activos
	boton_mochila.visible = activos and Juego.flag("tiene_mochila")


func abrir_mochila() -> void:
	set_controles(false)
	panel_mochila.abrir()


func decir(id_o_lineas) -> void:
	set_controles(false)
	await dialogo.mostrar(id_o_lineas)
	set_controles(true)


func fundido(a_negro: bool, duracion := 0.5) -> void:
	var t := create_tween()
	t.tween_property(transicion, "color:a", 1.0 if a_negro else 0.0, duracion)
	await t.finished


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
	t.tween_interval(2.4)
	t.tween_property(aviso, "modulate:a", 0.0, 0.3)
	t.finished.connect(_siguiente_aviso)
