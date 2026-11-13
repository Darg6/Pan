extends PanelContainer
## Caja de diálogo con retrato, nombre y texto que aparece letra por letra.
## Uso:  await caja.mostrar("collar")   (un id de datos/dialogos.json)
##   o:  await caja.mostrar([{ "quien": "Pan", "texto": "Hola" }])
## Para avanzar: toca la pantalla, haz clic, o pulsa Espacio / Enter / E.

signal termino
signal _avanzar

const LETRAS_POR_SEGUNDO := 45.0

@onready var retrato: TextureRect = $Fila/Retrato
@onready var nombre: Label = $Fila/Columna/Nombre
@onready var texto: Label = $Fila/Columna/Texto
@onready var flecha: Label = $Flecha

var _escribiendo := false
var _activa := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func mostrar(dialogo) -> void:
	var lineas: Array = dialogo if dialogo is Array else Juego.dialogos.get(dialogo, [])
	if lineas.is_empty():
		push_warning("No existe el diálogo: " + str(dialogo))
		return
	_activa = true
	visible = true
	for linea in lineas:
		await _mostrar_linea(linea)
	visible = false
	_activa = false
	termino.emit()


func esta_activa() -> bool:
	return _activa


func _mostrar_linea(linea: Dictionary) -> void:
	var quien: String = linea.get("quien", "")
	nombre.text = quien
	nombre.visible = quien != ""
	var ruta_retrato := "res://arte/retratos/%s.png" % linea.get("retrato", "")
	if linea.has("retrato") and ResourceLoader.exists(ruta_retrato):
		retrato.texture = load(ruta_retrato)
		retrato.visible = true
	else:
		retrato.visible = false
	texto.text = linea.get("texto", "")
	texto.visible_characters = 0
	flecha.visible = false
	_escribiendo = true
	var total := texto.get_total_character_count()
	var t := 0.0
	while _escribiendo and texto.visible_characters < total:
		await get_tree().process_frame
		t += get_process_delta_time()
		texto.visible_characters = int(t * LETRAS_POR_SEGUNDO)
	texto.visible_characters = -1
	_escribiendo = false
	flecha.visible = true
	await _avanzar


func _input(event: InputEvent) -> void:
	if not _activa or not is_visible_in_tree():
		return
	var pulso := false
	if event is InputEventScreenTouch and event.pressed:
		pulso = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interactuar"):
		pulso = true
	if pulso:
		get_viewport().set_input_as_handled()
		if _escribiendo:
			_escribiendo = false  # mostrar todo el texto de golpe
		else:
			_avanzar.emit()

