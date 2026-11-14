extends PanelContainer
## Ventana de la Mochila: cartas de criaturas (con nivel y progreso), suministros
## (curas y comida se pueden usar fuera de combate) y misiones.

signal cerrado

var _lista: VBoxContainer
var _resumen: Label
var _usando := ""          # id del objeto que se va a usar (esperando que elijas una carta)


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
	_resumen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_resumen)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 4)
	scroll.add_child(_lista)

	var abajo := HBoxContainer.new()
	abajo.add_theme_constant_override("separation", 4)
	caja.add_child(abajo)
	for b in [["Guardar", _guardar], ["Menú principal", _ir_al_menu], ["Cerrar", cerrar_mochila]]:
		var boton := Button.new()
		boton.text = b[0]
		boton.custom_minimum_size = Vector2(0, 22)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.focus_mode = Control.FOCUS_NONE
		boton.pressed.connect(b[1])
		boton.pressed.connect(Sonido.efecto.bind("boton"))
		abajo.add_child(boton)


func abrir() -> void:
	_usando = ""
	_refrescar()
	visible = true


func cerrar_mochila() -> void:
	visible = false
	cerrado.emit()


func _refrescar(aviso := "") -> void:
	for hijo in _lista.get_children():
		_lista.remove_child(hijo)
		hijo.queue_free()
	var partes: Array = ["Monedas: %d" % Juego.monedas]
	if Juego.chatarra > 0:
		partes.append("Reliquias: %d" % Juego.chatarra)
	var n_partes := 0
	for id in Juego.partes:
		n_partes += int(Juego.partes[id])
	if n_partes > 0:
		partes.append("Partes de criaturas: %d" % n_partes)
	_resumen.text = aviso if aviso != "" else "  ·  ".join(PackedStringArray(partes))

	if _usando != "":
		_seccion("¿En qué carta usas %s?" % Juego.nombre_objeto(_usando))
		for i in Juego.mochila.size():
			var carta: Dictionary = Juego.mochila[i]
			var nombre: String = Juego.criaturas[carta["id"]]["nombre"]
			var rota: bool = carta["hp"] <= 0
			var llena: bool = carta["hp"] >= Juego.hp_max_carta(carta)
			if Juego.tipo_objeto(_usando) == "antidoto":
				llena = not carta.get("infectada", false)   # el antídoto solo sirve si está infectada
			var estado := "rota" if rota else ("%d/%d HP" % [carta["hp"], Juego.hp_max_carta(carta)])
			if carta.get("infectada", false) and not rota:
				estado += ", infectada"
			_boton("%s  (%s)" % [nombre, estado], _usar_en.bind(i), rota or llena)
		_boton("Cancelar", _elegir_objeto.bind(""))
		return

	_seccion("Cartas")
	if Juego.mochila.is_empty():
		var vacio := Label.new()
		vacio.text = "Todavía no tienes cartas de criaturas."
		vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lista.add_child(vacio)
	for i in Juego.mochila.size():
		_lista.add_child(_crear_fila(Juego.mochila[i], i < Juego.MAX_EQUIPO))

	_seccion("Suministros")
	var alguno := false
	for id in Juego.OBJETOS:
		var cantidad: int = Juego.objetos.get(id, 0)
		if cantidad <= 0:
			continue
		alguno = true
		var fila := HBoxContainer.new()
		var etiqueta := Label.new()
		etiqueta.theme_type_variation = &"TextoChico"
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		etiqueta.text = "%s  x%d/%d" % [Juego.nombre_objeto(id), cantidad, Juego.max_objeto(id)]
		fila.add_child(etiqueta)
		if id == "grabacion_padres":   # Valle Ceniza: la grabación de mamá y papá se puede volver a escuchar
			var e := Button.new()
			e.text = "Escuchar"
			e.focus_mode = Control.FOCUS_NONE
			e.custom_minimum_size = Vector2(56, 18)
			e.pressed.connect(_escuchar_grabacion)
			e.pressed.connect(Sonido.efecto.bind("boton"))
			fila.add_child(e)
		if Juego.tipo_objeto(id) in ["cura", "comida", "antidoto"]:
			var b := Button.new()
			b.text = "Usar"
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(56, 18)
			b.pressed.connect(_elegir_objeto.bind(id))
			b.pressed.connect(Sonido.efecto.bind("boton"))
			fila.add_child(b)
		_lista.add_child(fila)
	if not alguno:
		_texto("No llevas suministros. Cómpralos en las tiendas de las ciudades.")

	if not Juego.misiones.is_empty() or Juego.mision != "":
		_seccion("Misiones")
		if Juego.mision != "":
			_texto("Principal: " + Juego.mision)
		for id in Juego.misiones:
			var m: Dictionary = Juego.misiones[id]
			_texto(("[Hecha] " if m["estado"] == "completa" else "[  ] ") + m["titulo"])


func _guardar() -> void:
	_usando = ""
	if Juego.guardar():
		Sonido.efecto("objeto")
		_refrescar("Partida guardada. Puedes seguir desde aquí con \"Continuar\" en el menú.")
	else:
		_refrescar("Ahora no se puede guardar. Termina lo que estás haciendo e inténtalo otra vez.")


## Guarda y vuelve al menú principal.
func _ir_al_menu() -> void:
	Juego.guardar()
	visible = false
	var fundido: ColorRect = get_parent().get_node_or_null("Transicion")
	if fundido:
		var t := create_tween()
		t.tween_property(fundido, "color:a", 1.0, 0.4)
		await t.finished
	Juego.cambiar_escena(Juego.MENU)


func _escuchar_grabacion() -> void:
	cerrar_mochila()
	var m = Historia.mapa
	if m != null and is_instance_valid(m) and m.is_inside_tree() and not m.ocupado:
		m.correr(Historia.ejecutar.bind("escuchar_grabacion"))


func _elegir_objeto(id: String) -> void:
	_usando = id
	_refrescar()


func _usar_en(i: int) -> void:
	var id := _usando
	_usando = ""
	var texto := Juego.usar_en_carta(id, i)
	Sonido.efecto("objeto")
	_refrescar(texto)


func _seccion(texto: String) -> void:
	var l := Label.new()
	l.text = texto
	l.theme_type_variation = &"NombreDialogo"
	_lista.add_child(l)


func _texto(texto: String) -> void:
	var l := Label.new()
	l.text = texto
	l.theme_type_variation = &"TextoChico"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lista.add_child(l)


func _boton(texto: String, accion: Callable, desactivado := false) -> void:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 20)
	b.disabled = desactivado
	b.pressed.connect(accion)
	_lista.add_child(b)


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
	if carta.get("infectada", false) and not rota:
		estado += "  INFECTADA"
	var nombres: Array = []
	for mov in Juego.movimientos(carta["id"], nivel):
		nombres.append(mov["nombre"])
	texto.text = "%s  Nvl %d%s\n%s  ·  %s  ·  tipo %s\n%s" % [
		datos["nombre"], nivel, siguiente,
		estado, "Equipo" if en_equipo else "Colección", _tipo_bonito(datos.get("tipo", "feral")),
		", ".join(PackedStringArray(nombres)),
	]
	fila.add_child(texto)
	return fila


func _tipo_bonito(t: String) -> String:
	return { "toxico": "Tóxico", "termico": "Térmico", "energia": "Energía", "sonico": "Sónico" }.get(t, t.capitalize())
