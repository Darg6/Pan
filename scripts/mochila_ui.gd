extends PanelContainer
## Ventana de la Mochila: cartas de criaturas (con nivel y progreso) y objetos.

signal cerrado

var _lista: VBoxContainer
var _resumen: Label


func _ready() -> void:
	visible = false
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	add_child(caja)

	var titulo := Label.new()
	titulo.text = "MOCHILA DE PAN"
	titulo.theme_type_variation = &"Titulo"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)

	_resumen = Label.new()
	_resumen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resumen.theme_type_variation = &"TextoChico"
	caja.add_child(_resumen)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 4)
	scroll.add_child(_lista)

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(0, 22)
	cerrar.pressed.connect(cerrar_mochila)
	caja.add_child(cerrar)


func abrir() -> void:
	for hijo in _lista.get_children():
		hijo.queue_free()
	var partes: Array = []
	for id in Juego.objetos:
		if Juego.objetos[id] > 0:
			partes.append("%s x%d" % [Juego.NOMBRES_OBJETOS.get(id, id), Juego.objetos[id]])
	partes.append("Monedas: %d" % Juego.monedas)
	if Juego.chatarra > 0:
		partes.append("Chatarra: %d" % Juego.chatarra)
	_resumen.text = "  ·  ".join(PackedStringArray(partes))
	if Juego.mochila.is_empty():
		var vacio := Label.new()
		vacio.text = "Todavía no tienes cartas de criaturas."
		vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lista.add_child(vacio)
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
	fila.add_theme_constant_override("separation", 8)

	var dibujo := TextureRect.new()
	dibujo.texture = Juego.textura_criatura(carta["id"])
	dibujo.custom_minimum_size = Vector2(32, 32)
	dibujo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dibujo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if rota:
		dibujo.modulate = Color(0.35, 0.35, 0.35)  # carta rota: gris
	fila.add_child(dibujo)

	var texto := Label.new()
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto.theme_type_variation = &"TextoChico"
	var siguiente := ""
	if nivel < Juego.NIVEL_MAXIMO:
		siguiente = "  Cartas %d/%d para Nvl %d" % [carta["cantidad"], Juego.cartas_para_nivel(nivel + 1), nivel + 1]
	var estado := "CARTA ROTA (duerme para repararla)" if rota else "HP %d/%d" % [carta["hp"], hp_max]
	var nombres: Array = []
	for mov in Juego.movimientos(carta["id"], nivel):
		nombres.append(mov["nombre"])
	texto.text = "%s  Nvl %d%s\n%s  ·  %s\n%s" % [
		datos["nombre"], nivel, siguiente,
		estado, "Equipo" if en_equipo else "Colección",
		", ".join(PackedStringArray(nombres)),
	]
	fila.add_child(texto)
	return fila
