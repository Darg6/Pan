extends PanelContainer
## Ventana de la Mochila: muestra las cartas de Pan, su nivel y cuántas faltan para subir.

signal cerrado

var _lista: VBoxContainer


func _ready() -> void:
	visible = false
	var fondo := StyleBoxFlat.new()  # fondo opaco para que no se vea el mapa detrás
	fondo.bg_color = Color(0.12, 0.11, 0.1)
	fondo.border_color = Color(0.55, 0.42, 0.25)
	fondo.set_border_width_all(3)
	fondo.set_corner_radius_all(6)
	fondo.set_content_margin_all(16)
	add_theme_stylebox_override("panel", fondo)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	add_child(caja)

	var titulo := Label.new()
	titulo.text = "Mochila de Pan"
	titulo.add_theme_font_size_override("font_size", 30)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 8)
	scroll.add_child(_lista)

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(0, 64)
	cerrar.pressed.connect(cerrar_mochila)
	caja.add_child(cerrar)


func abrir() -> void:
	for hijo in _lista.get_children():
		hijo.queue_free()
	for i in Juego.mochila.size():
		_lista.add_child(_crear_fila(Juego.mochila[i], i < Juego.MAX_EQUIPO))
	visible = true


func cerrar_mochila() -> void:
	visible = false
	cerrado.emit()


func _crear_fila(carta: Dictionary, en_equipo: bool) -> Control:
	var datos: Dictionary = Juego.criaturas[carta["id"]]
	var nivel := Juego.nivel_carta(carta)
	var hp_max := Juego.hp_max_carta(carta)
	var rota: bool = carta["hp"] <= 0

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)

	# "Carta" de color (arte provisional)
	var dibujo := ColorRect.new()
	dibujo.custom_minimum_size = Vector2(56, 76)
	dibujo.color = Color(datos.get("color", "#ffffff"))
	if rota:
		dibujo.color = dibujo.color.darkened(0.6)
	fila.add_child(dibujo)

	var texto := Label.new()
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var siguiente := ""
	if nivel < Juego.NIVEL_MAXIMO:
		siguiente = "   Cartas: %d / %d para Nvl %d" % [carta["cantidad"], Juego.cartas_para_nivel(nivel + 1), nivel + 1]
	var estado := "CARTA ROTA (duerme en el refugio)" if rota else "HP %d / %d" % [carta["hp"], hp_max]
	var nombres_ataques: Array = []
	for mov in Juego.movimientos(carta["id"], nivel):
		nombres_ataques.append(mov["nombre"])
	texto.text = "%s  Nvl %d%s\n%s   %s\nAtaques: %s" % [
		datos["nombre"], nivel, siguiente,
		estado, "Equipo" if en_equipo else "Colección",
		", ".join(PackedStringArray(nombres_ataques)),
	]
	texto.add_theme_font_size_override("font_size", 20)
	if rota:
		texto.modulate = Color(0.7, 0.7, 0.7)
	fila.add_child(texto)
	return fila
