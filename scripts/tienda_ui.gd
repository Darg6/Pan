extends PanelContainer
## Tienda de una ciudad: comprar suministros (precios fijos del GDD), vender reliquias y
## partes de criaturas, y el Mercado de Bestias (vender cartas repetidas).
## Uso desde historia.gd:  await mapa.hud.abrir_tienda("Tienda de Mila")

signal cerrado

## Lo que se vende en esta tienda (en este orden).
const SURTIDO := ["cura_40", "cura_50", "cura_80", "potenciador_20", "potenciador_70", "racion", "carta_vinculo"]
const ICONOS := {
	"cura_40": "res://arte/objetos/cura_40.png", "cura_50": "res://arte/objetos/cura_50.png",
	"cura_80": "res://arte/objetos/cura_80.png", "potenciador_20": "res://arte/objetos/potenciador_20.png",
	"potenciador_70": "res://arte/objetos/potenciador_70.png", "racion": "res://arte/objetos/racion.png",
	"carta_vinculo": "res://arte/objetos/cartas.png",
}

var _titulo: Label
var _monedas: Label
var _lista: VBoxContainer
var _scroll: ScrollContainer
var _mensaje: Label
var _pestana := "comprar"
var _botones_pestana := {}


func _ready() -> void:
	visible = false
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -222
	offset_top = -128
	offset_right = 222
	offset_bottom = 128
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 3)
	add_child(caja)

	var arriba := HBoxContainer.new()
	caja.add_child(arriba)
	_titulo = Label.new()
	_titulo.theme_type_variation = &"Titulo"
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arriba.add_child(_titulo)
	_monedas = Label.new()
	_monedas.add_theme_color_override("font_color", Color("#ffd24d"))
	arriba.add_child(_monedas)

	var pestanas := HBoxContainer.new()
	pestanas.add_theme_constant_override("separation", 4)
	caja.add_child(pestanas)
	for p in [["comprar", "Comprar"], ["vender", "Vender botín"], ["bestias", "Mercado de Bestias"]]:
		var b := Button.new()
		b.text = p[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.pressed.connect(_cambiar_pestana.bind(p[0]))
		b.pressed.connect(Sonido.efecto.bind("boton"))
		pestanas.add_child(b)
		_botones_pestana[p[0]] = b

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(_scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 3)
	_scroll.add_child(_lista)

	var abajo := HBoxContainer.new()
	caja.add_child(abajo)
	_mensaje = Label.new()
	_mensaje.theme_type_variation = &"TextoChico"
	_mensaje.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	abajo.add_child(_mensaje)
	var salir := Button.new()
	salir.text = "Salir"
	salir.focus_mode = Control.FOCUS_NONE
	salir.custom_minimum_size = Vector2(70, 22)
	salir.pressed.connect(cerrar)
	salir.pressed.connect(Sonido.efecto.bind("boton"))
	abajo.add_child(salir)


func abrir(nombre: String) -> void:
	_titulo.text = nombre.to_upper()
	_mensaje.text = "Precios fijos. La mochila tiene bolsillos limitados."
	visible = true
	_cambiar_pestana("comprar")


func cerrar() -> void:
	visible = false
	cerrado.emit()


func _cambiar_pestana(p: String) -> void:
	_pestana = p
	for k in _botones_pestana:
		_botones_pestana[k].button_pressed = k == p
	_refrescar()
	_scroll.scroll_vertical = 0


func _refrescar() -> void:
	_monedas.text = "%d monedas" % Juego.monedas
	for hijo in _lista.get_children():
		_lista.remove_child(hijo)
		hijo.queue_free()
	match _pestana:
		"comprar":
			for id in SURTIDO:
				_fila_compra(id)
		"vender":
			_filas_venta()
		"bestias":
			_filas_bestias()


func _fila(icono: Texture2D, texto: String, boton: String, accion: Callable, activo := true) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	var dibujo := TextureRect.new()
	dibujo.texture = icono
	dibujo.custom_minimum_size = Vector2(20, 20)
	dibujo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dibujo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fila.add_child(dibujo)
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.theme_type_variation = &"TextoChico"
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fila.add_child(etiqueta)
	if boton != "":
		var b := Button.new()
		b.text = boton
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(78, 20)
		b.disabled = not activo
		b.pressed.connect(accion)
		fila.add_child(b)
	_lista.add_child(fila)


func _fila_compra(id: String) -> void:
	var info: Dictionary = Juego.OBJETOS[id]
	var tengo: int = Juego.objetos.get(id, 0)
	var texto := "%s  ·  %d monedas  (tienes %d/%d)\n%s" % [info["nombre"], info["precio"], tengo, info["max"], info["desc"]]
	var puede: bool = tengo < int(info["max"]) and Juego.monedas >= int(info["precio"])
	_fila(Juego.textura(ICONOS.get(id, "")), texto, "Comprar", _comprar.bind(id), puede)


func _comprar(id: String) -> void:
	var error := Juego.comprar(id)
	if error == "":
		Sonido.efecto("objeto")
		_mensaje.text = "Compraste %s." % Juego.nombre_objeto(id)
	else:
		Sonido.efecto("fallo")
		_mensaje.text = error
	_refrescar()


func _filas_venta() -> void:
	var saqueo := Juego.textura("res://arte/objetos/saqueo.png")
	var hay := false
	if Juego.chatarra > 0:
		hay = true
		_fila(saqueo, "Reliquias del Viejo Mundo x%d  ·  %d c/u" % [Juego.chatarra, Juego.PRECIO_RELIQUIA], "", Callable())
	for id_parte in Juego.partes:
		if Juego.partes[id_parte] > 0:
			hay = true
			var p := Juego.info_parte(id_parte)
			_fila(saqueo, "%s x%d  ·  %d c/u" % [p["nombre"], Juego.partes[id_parte], p["precio"]], "", Callable())
	if not hay:
		_fila(null, "No tienes nada para vender. Las reliquias se encuentran saqueando el páramo y las partes las sueltan las criaturas salvajes al derrotarlas.", "", Callable())
		return
	var total := Juego.chatarra * Juego.PRECIO_RELIQUIA + Juego.valor_partes()
	_fila(null, "Total: %d monedas" % total, "Vender todo", _vender_botin)


func _vender_botin() -> void:
	var ganado := Juego.vender_botin()
	Sonido.efecto("objeto")
	_mensaje.text = "Vendiste tu botín por %d monedas." % ganado
	_refrescar()


func _filas_bestias() -> void:
	_fila(null, "Aquí compran cartas de criaturas. Si vendes una carta repetida, puede bajar el nivel de esa criatura.", "", Callable())
	for i in Juego.mochila.size():
		var carta: Dictionary = Juego.mochila[i]
		var datos: Dictionary = Juego.criaturas[carta["id"]]
		var nivel := Juego.nivel_carta(carta)
		var aviso := ""
		if carta["cantidad"] > 1:
			var nivel_despues := Juego.nivel_por_cartas(carta["cantidad"] - 1)
			if nivel_despues < nivel:
				aviso = "  (bajará a Nvl %d)" % nivel_despues
		elif Juego.mochila.size() > 1:
			aviso = "  (es tu única carta: se irá)"
		else:
			aviso = "  (no puedes quedarte sin criaturas)"
		var texto := "%s  Nvl %d  ·  %d cartas  ·  paga %d%s" % [datos["nombre"], nivel, carta["cantidad"], Juego.precio_carta(carta["id"]), aviso]
		_fila(Juego.textura_criatura(carta["id"]), texto, "Vender 1", _vender_carta.bind(i), Juego.puede_vender_carta(i) and Juego.precio_carta(carta["id"]) > 0)


func _vender_carta(i: int) -> void:
	var nombre: String = Juego.criaturas[Juego.mochila[i]["id"]]["nombre"]
	var ganado := Juego.vender_carta(i)
	Sonido.efecto("objeto")
	_mensaje.text = "Vendiste una carta de %s por %d monedas." % [nombre, ganado]
	_refrescar()
