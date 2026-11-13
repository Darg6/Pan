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
var panel_tienda: PanelContainer   # se crea por código (scripts/tienda_ui.gd)
var _tormenta: Node = null


func _ready() -> void:
	boton_accion.pressed.connect(func(): accion_pulsada.emit())
	boton_mochila.pressed.connect(abrir_mochila)
	boton_mochila.pressed.connect(Sonido.efecto.bind("boton"))
	panel_mochila.cerrado.connect(func(): set_controles(true))
	aviso.visible = false
	panel_tienda = PanelContainer.new()
	panel_tienda.name = "PanelTienda"
	panel_tienda.set_script(load("res://scripts/tienda_ui.gd"))
	add_child(panel_tienda)
	move_child(panel_tienda, transicion.get_index())   # debajo del fundido
	actualizar()


func actualizar() -> void:
	mision.text = Juego.mision
	panel_mision.visible = Juego.mision != ""
	boton_mochila.visible = Juego.flag("tiene_mochila")


## Bordes de la pantalla un poco más oscuros: da ambiente y centra la mirada.
func agregar_vineta() -> void:
	if has_node("Vineta"):
		return
	var v := TextureRect.new()
	v.name = "Vineta"
	v.texture = Ambiente.textura_vineta()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	move_child(v, 0)


## Muestra u oculta los controles (durante diálogos y menús se ocultan).
func set_controles(activos: bool) -> void:
	joystick.visible = activos
	boton_accion.visible = activos
	boton_mochila.visible = activos and Juego.flag("tiene_mochila")


func abrir_mochila() -> void:
	set_controles(false)
	panel_mochila.abrir()


## true si hay una ventana abierta (Pan no se mueve).
func menu_abierto() -> bool:
	return panel_mochila.visible or (panel_tienda != null and panel_tienda.visible)


func abrir_tienda(nombre: String) -> void:
	set_controles(false)
	panel_tienda.abrir(nombre)
	await panel_tienda.cerrado


## Tormenta de óxido en pantalla: luz naranja que tapa un poco la vista.
func set_tormenta(activa: bool) -> void:
	if _tormenta == null:
		var r := ColorRect.new()
		r.name = "Tormenta"
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.color = Color(0.82, 0.4, 0.16, 0.0)
		add_child(r)
		move_child(r, 0)
		_tormenta = r
	create_tween().tween_property(_tormenta, "color:a", 0.3 if activa else 0.0, 1.2)


func decir(id_o_lineas) -> void:
	set_controles(false)
	await dialogo.mostrar(id_o_lineas)
	set_controles(true)


func fundido(a_negro: bool, duracion := 0.5) -> void:
	var t := create_tween()
	t.tween_property(transicion, "color:a", 1.0 if a_negro else 0.0, duracion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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
