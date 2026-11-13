extends Control
## MENÚ PRINCIPAL: lo primero que se ve al abrir el juego.
## - Continuar: aparece solo si hay una partida guardada (sigue donde la dejaste).
## - Nueva partida: empieza desde la intro (si ya había partida, pregunta antes de borrarla).
## El nombre del juego se cambia en scripts/juego.gd (NOMBRE_JUEGO y SUBTITULO_JUEGO).
## Todo se arma por código para que sea fácil de leer y cambiar.

const INTRO := "res://escenas/intro.tscn"
const IMAGEN := "res://arte/cinematica/04_acantilado.png"

var _imagen: TextureRect
var _titulo: Label
var _subtitulo: Label
var _botones: VBoxContainer
var _info: Label
var _confirmar: PanelContainer
var _transicion: ColorRect
var _eligiendo := false


func _ready() -> void:
	Juego.cambiando_escena = false
	Sonido.musica("recuerdo")
	Sonido.ambiente("viento")
	_armar_fondo()
	_armar_titulo()
	_armar_botones()
	_armar_confirmacion()
	_transicion = ColorRect.new()
	_transicion.color = Color.BLACK
	_transicion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transicion.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transicion.add_to_group("fundido")
	add_child(_transicion)
	_aparecer()


# ---------------------------------------------------------------------------
# Fondo: Pan en el acantilado, ceniza cayendo y un acercamiento muy lento
# ---------------------------------------------------------------------------
func _armar_fondo() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.1, 0.08, 0.12)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	_imagen = TextureRect.new()
	_imagen.texture = Juego.textura(IMAGEN)
	_imagen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_imagen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_imagen)
	# Sombra a la derecha para que los botones se lean bien
	var sombra := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.06, 0.04, 0.06, 0.0))
	grad.set_color(1, Color(0.06, 0.04, 0.06, 0.75))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.35, 0)
	tex.fill_to = Vector2(1, 0)
	sombra.texture = tex
	sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
	sombra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sombra.stretch_mode = TextureRect.STRETCH_SCALE
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sombra)
	var ceniza := Ambiente.ceniza(get_viewport_rect().size)
	ceniza.position = get_viewport_rect().size / 2.0
	add_child(ceniza)


func _armar_titulo() -> void:
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_TOP_WIDE)
	caja.offset_top = 14
	caja.add_theme_constant_override("separation", 0)
	add_child(caja)
	_titulo = Label.new()
	_titulo.text = Juego.NOMBRE_JUEGO
	_titulo.theme_type_variation = &"TituloGrande"
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(_titulo)
	_subtitulo = Label.new()
	_subtitulo.text = Juego.SUBTITULO_JUEGO
	_subtitulo.theme_type_variation = &"NombreDialogo"
	_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitulo.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.05))
	_subtitulo.add_theme_constant_override("outline_size", 4)
	caja.add_child(_subtitulo)


# ---------------------------------------------------------------------------
# Botones
# ---------------------------------------------------------------------------
func _armar_botones() -> void:
	var columna := VBoxContainer.new()
	columna.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	columna.offset_left = -172
	columna.offset_right = -18
	columna.offset_top = -132
	columna.offset_bottom = -16
	columna.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	columna.grow_vertical = Control.GROW_DIRECTION_BEGIN
	columna.alignment = BoxContainer.ALIGNMENT_END
	columna.add_theme_constant_override("separation", 6)
	add_child(columna)
	_botones = columna

	var resumen := Juego.resumen_partida()
	if not resumen.is_empty():
		_boton("Continuar", _continuar)
		_info = Label.new()
		_info.theme_type_variation = &"TextoChico"
		_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_info.text = "%s\n%d cartas · %d monedas · %s" % [resumen["lugar"], resumen["cartas"], resumen["monedas"], resumen["tiempo"]]
		_info.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72))
		_info.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.05))
		_info.add_theme_constant_override("outline_size", 3)
		_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		columna.add_child(_info)
	_boton("Nueva partida", _pedir_nueva_partida)
	# En computadora se puede cerrar el juego desde aquí (en el celular y la web no hace falta).
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		_boton("Salir", get_tree().quit)
	(columna.get_child(0) as Control).grab_focus.call_deferred()


func _boton(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, 26)
	var foco := StyleBoxFlat.new()   # marco dorado al elegir con teclado o control
	foco.draw_center = false
	foco.set_border_width_all(1)
	foco.border_color = Color(1, 0.82, 0.3)
	foco.set_corner_radius_all(2)
	b.add_theme_stylebox_override("focus", foco)
	b.pressed.connect(Sonido.efecto.bind("boton"))
	b.pressed.connect(accion)
	_botones.add_child(b)
	return b


func _armar_confirmacion() -> void:
	_confirmar = PanelContainer.new()
	_confirmar.visible = false
	_confirmar.set_anchors_preset(Control.PRESET_CENTER)
	_confirmar.offset_left = -150
	_confirmar.offset_right = 150
	_confirmar.offset_top = -48
	_confirmar.offset_bottom = 48
	_confirmar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirmar.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_confirmar)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	_confirmar.add_child(caja)
	var texto := Label.new()
	texto.text = "¿Empezar una partida nueva?\nSe borrará tu partida guardada."
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(texto)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	caja.add_child(fila)
	for d in [["Sí, empezar", _nueva_partida], ["No", _cancelar_nueva]]:
		var b := Button.new()
		b.text = d[0]
		b.custom_minimum_size = Vector2(0, 24)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(Sonido.efecto.bind("boton"))
		b.pressed.connect(d[1])
		fila.add_child(b)


# ---------------------------------------------------------------------------
# Animación de entrada: todo aparece suave (nada de golpes de golpe)
# ---------------------------------------------------------------------------
func _aparecer() -> void:
	_titulo.modulate.a = 0.0
	_subtitulo.modulate.a = 0.0
	_botones.modulate.a = 0.0
	_imagen.pivot_offset = get_viewport_rect().size / 2.0
	_imagen.scale = Vector2(1.08, 1.08)
	var t := create_tween().set_parallel()
	t.tween_property(_transicion, "color:a", 0.0, 1.6)
	t.tween_property(_imagen, "scale", Vector2.ONE, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_titulo, "modulate:a", 1.0, 1.4).set_delay(1.0)
	t.tween_property(_subtitulo, "modulate:a", 1.0, 1.2).set_delay(1.8)
	t.tween_property(_botones, "modulate:a", 1.0, 0.8).set_delay(2.4)
	# Respiración lenta del fondo mientras esperas
	await t.finished
	if not is_inside_tree():
		return
	var r := create_tween().set_loops()
	r.tween_property(_imagen, "scale", Vector2(1.04, 1.04), 9.0).set_trans(Tween.TRANS_SINE)
	r.tween_property(_imagen, "scale", Vector2.ONE, 9.0).set_trans(Tween.TRANS_SINE)


func _salir_a(accion: Callable) -> void:
	if _eligiendo:
		return
	_eligiendo = true
	var t := create_tween()
	t.tween_property(_transicion, "color:a", 1.0, 0.8)
	await t.finished
	accion.call()


# ---------------------------------------------------------------------------
# Acciones
# ---------------------------------------------------------------------------
func _continuar() -> void:
	_salir_a(_cargar_partida)


func _cargar_partida() -> void:
	if not Juego.cargar():
		_eligiendo = false
		_transicion.color.a = 0.0
		if _info:
			_info.text = "No se pudo leer la partida guardada."


func _pedir_nueva_partida() -> void:
	if Juego.hay_partida_guardada():
		_botones.visible = false
		_confirmar.visible = true
		(_confirmar.get_child(0).get_child(1).get_child(1) as Control).grab_focus()   # "No" por defecto
	else:
		_nueva_partida()


func _cancelar_nueva() -> void:
	_confirmar.visible = false
	_botones.visible = true
	(_botones.get_child(0) as Control).grab_focus()


func _nueva_partida() -> void:
	_confirmar.visible = false
	_salir_a(_empezar_de_cero)


func _empezar_de_cero() -> void:
	Juego.borrar_partida()
	Juego.nueva_partida()
	Juego.cambiar_escena(INTRO)
