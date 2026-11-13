extends Control
## Combate por turnos (GDD: Iniciativa -> Selección -> Ejecución -> Estados -> Victoria/Derrota).
## La criatura salvaje viene de Juego.encuentro. Tus criaturas vienen de Juego.mochila.

const ESCENA_MUNDO := "res://escenas/mundo.tscn"
const PAUSA_MENSAJE := 1.0
const COLOR_DEBILIDAD := Color("#ff4040")

@onready var figura_pan: Node2D = $FiguraPan
@onready var figura_aliada: Node2D = $FiguraAliada
@onready var figura_enemiga: Node2D = $FiguraEnemiga
@onready var nombre_aliado: Label = $HUDAliado/VBox/Nombre
@onready var barra_aliado: ProgressBar = $HUDAliado/VBox/Barra
@onready var vida_aliado: Label = $HUDAliado/VBox/Vida
@onready var estado_aliado: Label = $HUDAliado/VBox/Estado
@onready var nombre_enemigo: Label = $HUDEnemigo/VBox/Nombre
@onready var barra_enemigo: ProgressBar = $HUDEnemigo/VBox/Barra
@onready var estado_enemigo: Label = $HUDEnemigo/VBox/Estado
@onready var mensaje: Label = $PanelInferior/Margen/HBox/Mensaje
@onready var opciones: GridContainer = $PanelInferior/Margen/HBox/Opciones
@onready var transicion: ColorRect = $Transicion

var aliado: Dictionary = {}      # luchador de Pan que está en el campo
var indice_aliado := -1          # su posición en Juego.mochila
var enemigo: Dictionary = {}     # criatura salvaje
var terminado := false


func _ready() -> void:
	resized.connect(_colocar_figuras)
	_colocar_figuras()
	_preparar_barra(barra_aliado)
	_preparar_barra(barra_enemigo)

	var datos: Dictionary = Juego.encuentro
	if datos.is_empty():  # por si abres esta escena sola con F6 para probar
		datos = { "id": "aves_negras", "nivel": 1 }
	enemigo = Juego.crear_luchador(datos["id"], datos["nivel"])
	var nombre_especie: String = enemigo["nombre"]
	enemigo["nombre"] = nombre_especie + " salvaje"  # para no confundirlo con tus cartas
	figura_enemiga.configurar(enemigo)

	transicion.color.a = 1.0
	create_tween().tween_property(transicion, "color:a", 0.0, 0.35)

	_limpiar_opciones()
	figura_aliada.visible = false
	_actualizar_hud()
	await _decir("¡Una criatura salvaje apareció: %s (Nvl %d)!" % [nombre_especie, enemigo["nivel"]])

	var primera := _primera_carta_viva()
	if primera == -1:
		await _decir("Pan no tiene compañeros en pie... ¡Pan huye!")
		_terminar("huida")
		return
	await _sacar_carta(primera)
	_menu_principal()


func _colocar_figuras() -> void:
	figura_pan.position = Vector2(size.x * 0.09, size.y * 0.5)
	figura_aliada.position = Vector2(size.x * 0.28, size.y * 0.6)
	figura_enemiga.position = Vector2(size.x * 0.74, size.y * 0.37)


# ---------------------------------------------------------------------------
# Menús (botones grandes para pantalla táctil)
# ---------------------------------------------------------------------------

func _menu_principal() -> void:
	_limpiar_opciones()
	mensaje.text = "¿Qué hará %s?" % aliado["nombre"]
	_agregar_boton("Luchar", _menu_luchar)
	_agregar_boton("Mochila", _menu_cartas.bind(false))
	_agregar_boton("Capturar (%d%%)" % roundi(_probabilidad_captura() * 100), func(): _turno({ "tipo": "capturar" }))
	_agregar_boton("Huir", func(): _turno({ "tipo": "huir" }))


func _menu_luchar() -> void:
	_limpiar_opciones()
	for mov in aliado["movimientos"]:
		var texto: String = mov["nombre"]
		if int(mov.get("golpes", 1)) > 1:
			texto += " x%d" % mov["golpes"]
		_agregar_boton(texto, func(): _turno({ "tipo": "ataque", "movimiento": mov }))
	_agregar_boton("Volver", _menu_principal)


## Lista de cartas para cambiar de criatura. Si `obligatorio` es true (tu criatura cayó),
## no hay botón de Volver y el cambio no le da turno gratis al enemigo.
func _menu_cartas(obligatorio: bool) -> void:
	_limpiar_opciones()
	mensaje.text = "Elige una carta:" if obligatorio else "Mochila: cambiar de carta"
	var equipo := Juego.equipo()
	for i in equipo.size():
		var carta: Dictionary = equipo[i]
		if i == indice_aliado or carta["hp"] <= 0:
			continue
		var nombre: String = Juego.criaturas[carta["id"]]["nombre"]
		var texto := "%s Nvl %d (%d HP)" % [nombre, Juego.nivel_carta(carta), carta["hp"]]
		if obligatorio:
			_agregar_boton(texto, _cambio_obligatorio.bind(i))
		else:
			_agregar_boton(texto, func(): _turno({ "tipo": "cambio", "indice": i }))
	if not obligatorio:
		if opciones.get_child_count() == 0:
			mensaje.text = "No tienes otras cartas sanas en el equipo."
		_agregar_boton("Volver", _menu_principal)


func _cambio_obligatorio(i: int) -> void:
	_limpiar_opciones()
	await _sacar_carta(i)
	_menu_principal()


func _agregar_boton(texto: String, accion: Callable) -> void:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(250, 72)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(accion)
	opciones.add_child(b)


func _limpiar_opciones() -> void:
	for hijo in opciones.get_children():
		opciones.remove_child(hijo)
		hijo.queue_free()


# ---------------------------------------------------------------------------
# Un turno completo
# ---------------------------------------------------------------------------

func _turno(accion: Dictionary) -> void:
	_limpiar_opciones()
	var accion_enemigo := _ia_enemigo()

	# Huir siempre funciona contra criaturas salvajes.
	if accion["tipo"] == "huir":
		await _decir("¡Pan y %s escapan del combate!" % aliado["nombre"])
		_terminar("huida")
		return

	# Fase de iniciativa: cambiar de carta y capturar tienen Prioridad +1.
	# Si no, ataca primero el más rápido (empate = moneda al aire).
	var jugador_primero := true
	if accion["tipo"] == "ataque":
		if aliado["velocidad"] == enemigo["velocidad"]:
			jugador_primero = randf() < 0.5
		else:
			jugador_primero = aliado["velocidad"] > enemigo["velocidad"]

	var orden := ["jugador", "enemigo"] if jugador_primero else ["enemigo", "jugador"]
	for actor in orden:
		if terminado or aliado["hp"] <= 0 or enemigo["hp"] <= 0:
			break  # si alguien cayó, el otro pierde su turno
		if actor == "jugador":
			await _accion_jugador(accion)
		else:
			await _accion_enemigo(accion_enemigo)
	if terminado:
		return

	# Fase de estados: la infección hace 1/8 de la vida máxima.
	if aliado["hp"] > 0 and enemigo["hp"] > 0:
		await _fase_estados()

	# Fase de condición: victoria / derrota.
	if await _revisar_caidos():
		return
	_menu_principal()


func _accion_jugador(accion: Dictionary) -> void:
	match accion["tipo"]:
		"ataque":
			await _usar_movimiento(aliado, enemigo, accion["movimiento"], figura_aliada, figura_enemiga)
		"cambio":
			await _decir("¡Vuelve, %s!" % aliado["nombre"])
			await _sacar_carta(accion["indice"])
		"capturar":
			await _intentar_captura()


func _accion_enemigo(accion: Dictionary) -> void:
	if accion["tipo"] == "huir":
		await _decir("¡%s intenta escapar!" % enemigo["nombre"])
		if randf() < 0.5:
			await _decir("¡%s huyó del combate!" % enemigo["nombre"])
			_terminar("enemigo_huyo")
		else:
			await _decir("¡Pero Pan le cierra el paso!")
		return
	await _usar_movimiento(enemigo, aliado, accion["movimiento"], figura_enemiga, figura_aliada)


# ---------------------------------------------------------------------------
# Daño: (Poder * (Ataque / Defensa)) * (1 + Nivel*0.2) * Debilidad * RNG(0.85-1.0)
# ---------------------------------------------------------------------------

func _modificador_tipo(tipo: String, defensor: Dictionary) -> float:
	if tipo in defensor["debil_a"]:
		return 2.0
	if tipo in defensor["resiste"]:
		return 0.5
	return 1.0


func _calcular_danio(atacante: Dictionary, defensor: Dictionary, mov: Dictionary) -> int:
	var poder := float(mov["poder"])
	var ratio: float = atacante["ataque"] / defensor["defensa"]
	var mult_nivel: float = 1.0 + atacante["nivel"] * 0.2
	var debilidad := _modificador_tipo(mov["tipo"], defensor)
	var rng := randf_range(0.85, 1.0)
	return maxi(1, roundi(poder * ratio * mult_nivel * debilidad * rng))


func _usar_movimiento(atacante: Dictionary, defensor: Dictionary, mov: Dictionary, fig_atacante: Node2D, fig_defensor: Node2D) -> void:
	await _decir("%s usa %s." % [atacante["nombre"], mov["nombre"]])
	fig_atacante.embestir()

	if mov.get("efecto", "") == "evasion_arriba":
		atacante["evasion"] = minf(atacante["evasion"] + 0.15, 0.7)
		_texto_flotante(fig_atacante, "Evasión +", Color("#9fe8ff"))
		await _decir("¡La evasión de %s subió!" % atacante["nombre"])
		return

	var golpes := int(mov.get("golpes", 1))
	var debilidad := _modificador_tipo(mov["tipo"], defensor)
	var aciertos := 0
	for g in golpes:
		if defensor["hp"] <= 0:
			break
		if g > 0:
			await get_tree().create_timer(0.22).timeout
		if randf() < defensor["evasion"]:
			_texto_flotante(fig_defensor, "Fallo", Color(1, 1, 1, 0.6))
			continue
		var danio := _calcular_danio(atacante, defensor, mov)
		defensor["hp"] = maxi(0, defensor["hp"] - danio)
		aciertos += 1
		_texto_flotante(fig_defensor, str(danio), COLOR_DEBILIDAD if debilidad > 1.0 else Color.WHITE)
		fig_defensor.parpadear()
		if debilidad > 1.0:
			_sacudir_pantalla()
		_actualizar_hud()

	if golpes > 1:
		await _decir("¡%d de %d golpes acertaron!" % [aciertos, golpes])
	elif aciertos == 0:
		await _decir("¡%s esquivó el ataque!" % defensor["nombre"])
	if aciertos == 0:
		return
	if debilidad > 1.0:
		await _decir("¡Es súper efectivo!")
	elif debilidad < 1.0:
		await _decir("No es muy efectivo...")
	if mov.get("efecto", "") == "infectar" and defensor["hp"] > 0 and not defensor["infectado"]:
		defensor["infectado"] = true
		_actualizar_hud()
		await _decir("¡%s quedó Infectado!" % defensor["nombre"])


func _fase_estados() -> void:
	for pareja in [[aliado, figura_aliada], [enemigo, figura_enemiga]]:
		var luchador: Dictionary = pareja[0]
		if luchador["infectado"] and luchador["hp"] > 0:
			var danio := maxi(1, luchador["hp_max"] / 8)
			luchador["hp"] = maxi(0, luchador["hp"] - danio)
			_texto_flotante(pareja[1], str(danio), Color("#7bd13b"))
			_actualizar_hud()
			await _decir("%s sufre por la infección." % luchador["nombre"])


## Devuelve true si el combate terminó o si se abrió el menú de cambio obligatorio.
func _revisar_caidos() -> bool:
	if enemigo["hp"] <= 0:
		figura_enemiga.visible = false
		await _decir("¡%s fue derrotado!" % enemigo["nombre"])
		await _decir("(Para capturarlo, debilítalo sin derrotarlo.)")
		_terminar("victoria")
		return true
	if aliado["hp"] <= 0:
		_guardar_aliado()
		figura_aliada.visible = false
		await _decir("¡%s cayó! Su carta se rompió." % aliado["nombre"])
		if _primera_carta_viva() == -1:
			await _decir("Todos los compañeros de Pan cayeron... ¡Pan huye!")
			_terminar("derrota")
		else:
			_menu_cartas(true)
		return true
	return false


# ---------------------------------------------------------------------------
# Cartas de Pan
# ---------------------------------------------------------------------------

func _primera_carta_viva() -> int:
	var equipo := Juego.equipo()
	for i in equipo.size():
		if equipo[i]["hp"] > 0:
			return i
	return -1


## Guarda la vida actual del aliado en su carta de la mochila.
func _guardar_aliado() -> void:
	if indice_aliado >= 0 and not aliado.is_empty():
		Juego.mochila[indice_aliado]["hp"] = aliado["hp"]


func _sacar_carta(i: int) -> void:
	_guardar_aliado()
	var carta: Dictionary = Juego.mochila[i]
	indice_aliado = i
	aliado = Juego.crear_luchador(carta["id"], Juego.nivel_carta(carta), carta["hp"])
	figura_aliada.configurar(aliado)
	_actualizar_hud()
	await _decir("¡Adelante, %s!" % aliado["nombre"])


# ---------------------------------------------------------------------------
# Captura: más fácil cuanto menos vida le queda a la criatura.
# ---------------------------------------------------------------------------

func _probabilidad_captura() -> float:
	var vida := float(enemigo["hp"]) / float(enemigo["hp_max"])
	return clampf((1.0 - vida) * 0.85 + 0.1, 0.05, 0.95) * enemigo["facilidad_captura"]


func _intentar_captura() -> void:
	var probabilidad := _probabilidad_captura()
	await _decir("¡Pan lanza una carta en blanco!")

	# La carta vuela de Pan hacia la criatura
	var carta := ColorRect.new()
	carta.size = Vector2(36, 50)
	carta.color = Color("#f4e9c8")
	carta.position = figura_pan.position + Vector2(0, -120)
	add_child(carta)
	var destino := figura_enemiga.position + Vector2(-18, -110)
	var t := create_tween()
	t.tween_property(carta, "position", destino, 0.35)
	await t.finished
	var t2 := create_tween()
	t2.tween_property(figura_enemiga, "scale", Vector2(0.05, 0.05), 0.25)
	await t2.finished

	for i in 3:  # la carta tiembla
		var t3 := create_tween()
		t3.tween_property(carta, "rotation", 0.3, 0.12)
		t3.tween_property(carta, "rotation", -0.3, 0.12)
		t3.tween_property(carta, "rotation", 0.0, 0.12)
		await t3.finished
		await get_tree().create_timer(0.25).timeout

	if randf() < probabilidad:
		carta.color = Color("#ffd24d")
		_guardar_aliado()  # antes de agregar la carta (por si es un duplicado del aliado)
		var r := Juego.agregar_carta(enemigo["id"])
		var especie: String = Juego.criaturas[enemigo["id"]]["nombre"]
		await _decir("¡Captura exitosa! %s ahora es una carta en tu mochila." % especie)
		var aviso := "¡Carta conseguida: %s!" % especie
		if r["nueva"]:
			if Juego.mochila.size() > Juego.MAX_EQUIPO:
				await _decir("Tu equipo está lleno: la carta se guardó en la Colección.")
		elif r["nivel_despues"] > r["nivel_antes"]:
			var texto := "¡Vínculo fortalecido! %s alcanzó el Nivel %d." % [especie, r["nivel_despues"]]
			await _decir(texto)
			aviso += " " + texto
		else:
			var faltan: int = Juego.cartas_para_nivel(r["nivel_despues"] + 1) - r["cantidad"]
			await _decir("Carta duplicada (%d en total). Te falta%s %d para subir de nivel." % [r["cantidad"], "" if faltan == 1 else "n", faltan])
		Juego.mensajes_pendientes.append(aviso)
		indice_aliado = -1  # ya guardamos su vida; no volver a sobrescribirla
		_terminar("captura")
	else:
		carta.queue_free()
		var t4 := create_tween()
		t4.tween_property(figura_enemiga, "scale", Vector2.ONE, 0.2)
		await _decir("¡%s rompió la carta y se liberó!" % enemigo["nombre"])


# ---------------------------------------------------------------------------
# IA enemiga por pesos (GDD): cada acción recibe una puntuación y gana la más alta.
# ---------------------------------------------------------------------------

func _ia_enemigo() -> Dictionary:
	var vida := float(enemigo["hp"]) / float(enemigo["hp_max"])
	var vida_rival := float(aliado["hp"]) / float(aliado["hp_max"]) if not aliado.is_empty() else 1.0
	var mas_fuerte := 0
	for mov in enemigo["movimientos"]:
		mas_fuerte = maxi(mas_fuerte, int(mov["poder"]) * int(mov.get("golpes", 1)))

	var opciones_ia: Array = []  # [puntuación, acción]
	for mov in enemigo["movimientos"]:
		var peso := 60.0
		var efecto: String = mov.get("efecto", "")
		var poder_total := int(mov["poder"]) * int(mov.get("golpes", 1))
		if efecto == "infectar":
			peso = 40.0 + (50.0 if not aliado.get("infectado", false) else 0.0)
		elif efecto == "evasion_arriba":
			peso = 20.0
			if enemigo["ia"] == "evasivo" and vida < 0.5 and enemigo["evasion"] < 0.6:
				peso = 85.0
		elif poder_total == mas_fuerte and vida_rival < 0.3:
			peso = 100.0  # modo "rematar"
		opciones_ia.append([peso + randf() * 5.0, { "tipo": "ataque", "movimiento": mov }])

	# Arquetipo evasivo (Bestia Blanca): si está en la zona roja, intenta huir.
	if enemigo["ia"] == "evasivo" and vida < 0.25:
		opciones_ia.append([95.0 + randf() * 5.0, { "tipo": "huir" }])

	opciones_ia.sort_custom(func(a, b): return a[0] > b[0])
	return opciones_ia[0][1]


# ---------------------------------------------------------------------------
# Interfaz y "juice"
# ---------------------------------------------------------------------------

func _decir(texto: String) -> void:
	mensaje.text = texto
	await get_tree().create_timer(PAUSA_MENSAJE).timeout


func _actualizar_hud() -> void:
	if not aliado.is_empty():
		nombre_aliado.text = "%s  Nvl %d" % [aliado["nombre"], aliado["nivel"]]
		_poner_barra(barra_aliado, aliado)
		vida_aliado.text = "HP %d / %d" % [aliado["hp"], aliado["hp_max"]]
		estado_aliado.text = "INFECTADO" if aliado["infectado"] else ""
	nombre_enemigo.text = "%s  Nvl %d" % [enemigo["nombre"], enemigo["nivel"]]
	_poner_barra(barra_enemigo, enemigo)  # el enemigo no muestra número, solo la barra
	estado_enemigo.text = "INFECTADO" if enemigo["infectado"] else ""


func _preparar_barra(barra: ProgressBar) -> void:
	var relleno := StyleBoxFlat.new()
	relleno.set_corner_radius_all(4)
	barra.add_theme_stylebox_override("fill", relleno)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0, 0, 0, 0.5)
	fondo.set_corner_radius_all(4)
	barra.add_theme_stylebox_override("background", fondo)


func _poner_barra(barra: ProgressBar, luchador: Dictionary) -> void:
	barra.max_value = luchador["hp_max"]
	var t := create_tween()
	t.tween_property(barra, "value", float(luchador["hp"]), 0.25)
	var pct := float(luchador["hp"]) / float(luchador["hp_max"])
	var relleno: StyleBoxFlat = barra.get_theme_stylebox("fill")
	if pct > 0.5:
		relleno.bg_color = Color("#4caf50")  # verde
	elif pct > 0.2:
		relleno.bg_color = Color("#e6c229")  # amarillo
	else:
		relleno.bg_color = Color("#e53935")  # rojo


func _texto_flotante(figura: Node2D, texto: String, color: Color) -> void:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", 34)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta.add_theme_constant_override("outline_size", 6)
	etiqueta.position = figura.position + Vector2(randf_range(-30, 20), -170)
	add_child(etiqueta)
	var t := create_tween().set_parallel()
	t.tween_property(etiqueta, "position:y", etiqueta.position.y - 60, 0.8)
	t.tween_property(etiqueta, "modulate:a", 0.0, 0.8).set_delay(0.3)
	t.chain().tween_callback(etiqueta.queue_free)


func _sacudir_pantalla() -> void:
	var t := create_tween()
	for i in 6:
		t.tween_property(self, "position", Vector2(randf_range(-10, 10), randf_range(-8, 8)), 0.04)
	t.tween_property(self, "position", Vector2.ZERO, 0.04)


func _terminar(resultado: String) -> void:
	terminado = true
	_limpiar_opciones()
	_guardar_aliado()
	Juego.pasos_sin_encuentro = 4  # unos pasos de calma al volver al mapa
	if resultado == "derrota":
		# Pan no muere: despierta en el último refugio (allí duerme y repara sus cartas).
		Juego.posicion_pan = Juego.posicion_refugio
		Juego.mensajes_pendientes.append("Pan escapó con sus cartas rotas y llegó al refugio.")
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(transicion, "color:a", 1.0, 0.4)
	await t.finished
	get_tree().change_scene_to_file(ESCENA_MUNDO)
