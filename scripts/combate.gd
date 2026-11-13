extends Control
## Combate por turnos (GDD: Iniciativa -> Selección -> Ejecución -> Estados -> Victoria/Derrota).
## Juego.encuentro dice qué tipo de combate es:
##   "salvaje"          -> criatura salvaje: se puede capturar y huir
##   "entrenador"       -> bandido de la Organización: no se captura ni se huye, puede tener varias bestias
##   "tutorial_captura" -> prólogo: Pan aún no tiene criaturas y usa la Granada + Carta de Vínculo

const PAUSA_MENSAJE := 1.1
const COLOR_DEBILIDAD := Color("#ff4a4a")
const TEX_CARTA := preload("res://arte/interfaz/carta.png")
const TEX_GRANADA := preload("res://arte/objetos/granada.png")

# Posiciones dentro del escenario de 480x270 (coinciden con las plataformas del fondo)
const POS_ENEMIGO := Vector2(352, 136)
const POS_ALIADO := Vector2(132, 196)
const POS_PAN := Vector2(46, 190)
const POS_ENTRENADOR := Vector2(440, 128)

@onready var escenario: Control = $Escenario
@onready var sprite_pan: Sprite2D = $Escenario/Pan
@onready var sprite_aliado: Sprite2D = $Escenario/Aliado
@onready var sprite_enemigo: Sprite2D = $Escenario/Enemigo
@onready var sprite_entrenador: Sprite2D = $Escenario/Entrenador
@onready var hud_aliado: PanelContainer = $HUDAliado
@onready var nombre_aliado: Label = $HUDAliado/VBox/Nombre
@onready var barra_aliado: ProgressBar = $HUDAliado/VBox/Barra
@onready var vida_aliado: Label = $HUDAliado/VBox/Vida
@onready var nombre_enemigo: Label = $HUDEnemigo/VBox/Nombre
@onready var barra_enemigo: ProgressBar = $HUDEnemigo/VBox/Barra
@onready var estado_enemigo: Label = $HUDEnemigo/VBox/Estado
@onready var mensaje: Label = $PanelInferior/HBox/Mensaje
@onready var opciones: GridContainer = $PanelInferior/HBox/Opciones
@onready var transicion: ColorRect = $Transicion

var tipo := "salvaje"
var datos: Dictionary = {}
var aliado: Dictionary = {}      # criatura de Pan en el campo (vacío en el tutorial)
var indice_aliado := -1          # su posición en Juego.mochila
var enemigo: Dictionary = {}
var equipo_enemigo: Array = []   # bestias que le quedan al entrenador
var terminado := false
var _paso_tutorial := 0


func _ready() -> void:
	Juego.cambiando_escena = false
	datos = Juego.encuentro
	if datos.is_empty():  # por si abres esta escena sola con F6 para probar
		datos = { "tipo": "salvaje", "equipo": [{ "id": "aves_negras", "nivel": 1 }] }
		if Juego.mochila.is_empty():
			Juego.agregar_carta("gato_mutado")
			Juego.dar_objeto("carta_vinculo", 3)
	tipo = datos.get("tipo", "salvaje")
	equipo_enemigo = datos.get("equipo", []).duplicate()

	_preparar_barra(barra_aliado)
	_preparar_barra(barra_enemigo)
	sprite_pan.position = POS_PAN
	sprite_aliado.position = POS_ALIADO
	sprite_enemigo.position = POS_ENEMIGO
	sprite_entrenador.position = POS_ENTRENADOR
	sprite_aliado.visible = false
	hud_aliado.visible = false
	_limpiar_opciones()

	if tipo == "entrenador":
		var e: Dictionary = datos.get("entrenador", {})
		sprite_entrenador.texture = load(e.get("sprite", "res://arte/personajes/recluta_combate.png"))
		sprite_entrenador.visible = true
	else:
		sprite_entrenador.visible = false
	if tipo == "tutorial_captura":
		sprite_pan.position = POS_ALIADO + Vector2(-10, 0)  # Pan está en la posición del luchador

	_sacar_enemigo(equipo_enemigo.pop_front())
	var f := create_tween()
	f.tween_property(transicion, "color:a", 0.0, 0.4)
	await f.finished

	match tipo:
		"tutorial_captura":
			await _decir("¡Un %s salvaje se lanza sobre Pan!" % enemigo["nombre_especie"])
			await _decir("Pan todavía no tiene criaturas. Los humanos son débiles ante los monstruos...")
			await _decir("...pero pueden usar herramientas. Abre la Mochila y usa la Granada Aturdidora.")
			_menu_principal()
			return
		"entrenador":
			var nombre_e: String = datos.get("entrenador", {}).get("nombre", "Bandido")
			await _decir("¡%s quiere pelear!" % nombre_e)
			await _decir("%s saca a %s (Nvl %d)." % [nombre_e, enemigo["nombre_especie"], enemigo["nivel"]])
		_:
			await _decir("¡Una criatura salvaje apareció: %s (Nvl %d)!" % [enemigo["nombre_especie"], enemigo["nivel"]])

	var primera := _primera_carta_viva()
	if primera == -1:
		await _decir("Pan no tiene compañeros en pie... ¡Pan huye!")
		_terminar("huida")
		return
	await _sacar_carta(primera)
	if datos.get("tutorial", false):
		await _decir("Tu %s (Velocidad %d) es más rápido que el %s (Velocidad %d): atacarás primero." % [
			aliado["nombre"], aliado["velocidad"], enemigo["nombre_especie"], enemigo["velocidad"]])
		await _decir("Consejo: Arañazo Infeccioso deja 'Infectado'. La infección quita vida al final de cada turno.")
	_menu_principal()


func _sacar_enemigo(info: Dictionary) -> void:
	enemigo = Juego.crear_luchador(info["id"], info["nivel"])
	enemigo["nombre_especie"] = enemigo["nombre"]
	enemigo["nombre"] += " rival" if tipo == "entrenador" else " salvaje"
	sprite_enemigo.texture = Juego.textura_criatura(info["id"])
	sprite_enemigo.flip_h = true  # las criaturas miran a la derecha; el enemigo mira a la izquierda
	sprite_enemigo.scale = Vector2.ONE
	sprite_enemigo.modulate = Color.WHITE
	sprite_enemigo.visible = true
	_actualizar_hud()


# ---------------------------------------------------------------------------
# Menús (botones grandes para pantalla táctil)
# ---------------------------------------------------------------------------

func _menu_principal() -> void:
	_limpiar_opciones()
	if tipo == "tutorial_captura":
		mensaje.text = "¿Qué hará Pan?"
		_agregar_boton("Luchar", Callable(), true)
		_agregar_boton("Mochila", _menu_mochila, _paso_tutorial != 0)
		_agregar_boton("Capturar", func(): _turno({ "tipo": "capturar" }), _paso_tutorial != 1)
		_agregar_boton("Huir", Callable(), true)
		return
	mensaje.text = "¿Qué hará %s?" % aliado["nombre"]
	_agregar_boton("Luchar", _menu_luchar)
	_agregar_boton("Mochila", _menu_mochila)
	if tipo == "salvaje":
		_agregar_boton("Capturar %d%%" % roundi(_probabilidad_captura() * 100), func(): _turno({ "tipo": "capturar" }))
	else:
		_agregar_boton("Capturar", func(): _turno({ "tipo": "capturar" }))
	_agregar_boton("Huir", func(): _turno({ "tipo": "huir" }))


func _menu_luchar() -> void:
	_limpiar_opciones()
	for mov in aliado["movimientos"]:
		var texto: String = mov["nombre"]
		if int(mov.get("golpes", 1)) > 1:
			texto += " x%d" % mov["golpes"]
		_agregar_boton(texto, func(): _turno({ "tipo": "ataque", "movimiento": mov }))
	_agregar_boton("Volver", _menu_principal)


## Mochila: objetos y cartas para cambiar de criatura.
func _menu_mochila() -> void:
	_limpiar_opciones()
	mensaje.text = "Mochila"
	if Juego.tiene_objeto("granada_aturdidora"):
		_agregar_boton("Granada x%d" % Juego.objetos["granada_aturdidora"], func(): _turno({ "tipo": "granada" }))
	if tipo != "tutorial_captura":
		var equipo := Juego.equipo()
		for i in equipo.size():
			var carta: Dictionary = equipo[i]
			if i == indice_aliado or carta["hp"] <= 0:
				continue
			var nombre: String = Juego.criaturas[carta["id"]]["nombre"]
			_agregar_boton("%s %dHP" % [nombre, carta["hp"]], func(): _turno({ "tipo": "cambio", "indice": i }))
	if opciones.get_child_count() == 0:
		mensaje.text = "No tienes objetos ni otras cartas sanas."
	_agregar_boton("Volver", _menu_principal)


## Cuando tu criatura cae: elegir otra (no hay Volver, y el enemigo no gana un turno gratis).
func _menu_cambio_obligatorio() -> void:
	_limpiar_opciones()
	mensaje.text = "Elige otra carta:"
	var equipo := Juego.equipo()
	for i in equipo.size():
		var carta: Dictionary = equipo[i]
		if carta["hp"] > 0:
			var nombre: String = Juego.criaturas[carta["id"]]["nombre"]
			_agregar_boton("%s %dHP" % [nombre, carta["hp"]], _cambio_obligatorio.bind(i))


func _cambio_obligatorio(i: int) -> void:
	_limpiar_opciones()
	await _sacar_carta(i)
	_menu_principal()


func _agregar_boton(texto: String, accion: Callable, desactivado := false) -> void:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(104, 24)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	if texto.length() > 14:
		b.add_theme_font_size_override("font_size", 10)  # textos largos en letra más chica
	b.disabled = desactivado
	if accion.is_valid():
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

	# Acciones que no gastan el turno
	if accion["tipo"] == "huir" and tipo == "entrenador":
		await _decir("¡No puedes huir de un combate contra un bandido!")
		_menu_principal()
		return
	if accion["tipo"] == "capturar" and tipo == "entrenador":
		await _decir("Pan: \"Su dispositivo de control bloquea mi carta. Tengo que derrotarlos.\"")
		_menu_principal()
		return
	if accion["tipo"] == "capturar" and not Juego.tiene_objeto("carta_vinculo"):
		await _decir("No te quedan Cartas de Vínculo. Busca más saqueando el páramo.")
		_menu_principal()
		return

	if accion["tipo"] == "huir":
		await _decir("¡Pan y %s escapan del combate!" % aliado["nombre"])
		_terminar("huida")
		return

	# Tutorial: el tiempo se detiene, el gato no ataca.
	if tipo == "tutorial_captura":
		await _accion_jugador(accion)
		if not terminado:
			if accion["tipo"] == "granada":
				_paso_tutorial = 1
				await _decir("Las Cartas de Vínculo ofrecen refugio a las bestias heridas. ¡Captúralo antes de que te ataque!")
			_menu_principal()
		return

	var accion_enemigo := _ia_enemigo()

	# Iniciativa: objetos, cambio y captura tienen Prioridad +1. Si no, ataca el más rápido.
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

	# Fase de estados: la infección quita 1/8 de la vida máxima.
	if aliado["hp"] > 0 and enemigo["hp"] > 0:
		await _fase_estados()

	if await _revisar_caidos():
		return
	_menu_principal()


func _accion_jugador(accion: Dictionary) -> void:
	match accion["tipo"]:
		"ataque":
			await _usar_movimiento(aliado, enemigo, accion["movimiento"], sprite_aliado, sprite_enemigo)
		"cambio":
			await _decir("¡Vuelve, %s!" % aliado["nombre"])
			await _sacar_carta(accion["indice"])
		"capturar":
			await _intentar_captura()
		"granada":
			await _usar_granada()


func _accion_enemigo(accion: Dictionary) -> void:
	if accion["tipo"] == "huir":
		await _decir("¡%s intenta escapar!" % enemigo["nombre"])
		if randf() < 0.5:
			await _decir("¡%s huyó del combate!" % enemigo["nombre"])
			_terminar("enemigo_huyo")
		else:
			await _decir("¡Pero Pan le cierra el paso!")
		return
	await _usar_movimiento(enemigo, aliado, accion["movimiento"], sprite_enemigo, sprite_aliado)


# ---------------------------------------------------------------------------
# Daño: (Poder * (Ataque / Defensa)) * (1 + Nivel*0.2) * Debilidad * RNG(0.85-1.0)
# ---------------------------------------------------------------------------

func _modificador_tipo(tipo_ataque: String, defensor: Dictionary) -> float:
	if tipo_ataque in defensor["debil_a"]:
		return 2.0
	if tipo_ataque in defensor["resiste"]:
		return 0.5
	return 1.0


func _calcular_danio(atacante: Dictionary, defensor: Dictionary, mov: Dictionary) -> int:
	var poder := float(mov["poder"])
	var ratio: float = atacante["ataque"] / defensor["defensa"]
	var mult_nivel: float = 1.0 + atacante["nivel"] * 0.2
	var debilidad := _modificador_tipo(mov["tipo"], defensor)
	return maxi(1, roundi(poder * ratio * mult_nivel * debilidad * randf_range(0.85, 1.0)))


func _usar_movimiento(atacante: Dictionary, defensor: Dictionary, mov: Dictionary, spr_atacante: Sprite2D, spr_defensor: Sprite2D) -> void:
	await _decir("%s usa %s." % [atacante["nombre"], mov["nombre"]])
	_embestir(spr_atacante)

	if mov.get("efecto", "") == "evasion_arriba":
		atacante["evasion"] = minf(atacante["evasion"] + 0.15, 0.7)
		_texto_flotante(spr_atacante, "EVA+", Color("#9fe8ff"))
		await _decir("¡La evasión de %s subió!" % atacante["nombre"])
		return

	var golpes := int(mov.get("golpes", 1))
	var precision := float(mov.get("precision", 1.0))
	var debilidad := _modificador_tipo(mov["tipo"], defensor)
	var aciertos := 0
	for g in golpes:
		if defensor["hp"] <= 0:
			break
		if g > 0:
			await get_tree().create_timer(0.2).timeout
		if randf() < defensor["evasion"] or randf() > precision:
			_texto_flotante(spr_defensor, "Fallo", Color(1, 1, 1, 0.6))
			continue
		var danio := _calcular_danio(atacante, defensor, mov)
		defensor["hp"] = maxi(0, defensor["hp"] - danio)
		aciertos += 1
		_texto_flotante(spr_defensor, str(danio), COLOR_DEBILIDAD if debilidad > 1.0 else Color.WHITE)
		_parpadear(spr_defensor)
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
		await _decir("¡%s quedó infectado!" % defensor["nombre"])


func _fase_estados() -> void:
	for pareja in [[aliado, sprite_aliado], [enemigo, sprite_enemigo]]:
		var luchador: Dictionary = pareja[0]
		if luchador["infectado"] and luchador["hp"] > 0:
			var danio := maxi(1, luchador["hp_max"] / 8)
			luchador["hp"] = maxi(0, luchador["hp"] - danio)
			_texto_flotante(pareja[1], str(danio), Color("#7bd13b"))
			_actualizar_hud()
			await _decir("%s sufre por la infección." % luchador["nombre"])


## Devuelve true si el combate terminó o si hay que elegir otra carta.
func _revisar_caidos() -> bool:
	if enemigo["hp"] <= 0:
		var t := create_tween()
		t.tween_property(sprite_enemigo, "modulate:a", 0.0, 0.4)
		await _decir("¡%s fue derrotado!" % enemigo["nombre"])
		if tipo == "entrenador" and not equipo_enemigo.is_empty():
			var nombre_e: String = datos.get("entrenador", {}).get("nombre", "El bandido")
			_sacar_enemigo(equipo_enemigo.pop_front())
			await _decir("%s saca a %s (Nvl %d)." % [nombre_e, enemigo["nombre_especie"], enemigo["nivel"]])
			return false
		if tipo == "entrenador":
			await _decir("¡%s se quedó sin bestias!" % datos.get("entrenador", {}).get("nombre", "El bandido"))
		else:
			await _decir("(Para capturar una criatura, debilítala sin derrotarla.)")
		_terminar("victoria")
		return true
	if aliado["hp"] <= 0:
		_guardar_aliado()
		var t := create_tween()
		t.tween_property(sprite_aliado, "modulate:a", 0.0, 0.4)
		await _decir("¡%s cayó! Pan atrapa su carta rota en el aire." % aliado["nombre"])
		if _primera_carta_viva() == -1:
			await _decir("Todos los compañeros de Pan cayeron... ¡Pan huye!")
			_terminar("derrota")
		else:
			_menu_cambio_obligatorio()
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


func _guardar_aliado() -> void:
	if indice_aliado >= 0 and not aliado.is_empty():
		Juego.mochila[indice_aliado]["hp"] = aliado["hp"]


## Pan lanza la carta al aire y la criatura se materializa.
func _sacar_carta(i: int) -> void:
	_guardar_aliado()
	var carta: Dictionary = Juego.mochila[i]
	indice_aliado = i
	aliado = Juego.crear_luchador(carta["id"], Juego.nivel_carta(carta), carta["hp"])
	sprite_aliado.texture = Juego.textura_criatura(carta["id"])
	sprite_aliado.flip_h = false
	sprite_aliado.visible = true
	sprite_aliado.modulate = Color(0.4, 1.0, 1.0, 0.0)
	sprite_aliado.scale = Vector2(0.2, 0.2)
	var t := create_tween().set_parallel()
	t.tween_property(sprite_aliado, "modulate", Color.WHITE, 0.35)
	t.tween_property(sprite_aliado, "scale", Vector2(1.2, 1.2), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hud_aliado.visible = true
	_actualizar_hud()
	await _decir("¡Adelante, %s!" % aliado["nombre"])


# ---------------------------------------------------------------------------
# Objetos
# ---------------------------------------------------------------------------

func _lanzar(textura: Texture2D, destino: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = textura
	s.position = sprite_pan.position + Vector2(8, -36)
	escenario.add_child(s)
	var inicio := s.position
	var medio := (inicio + destino) / 2.0 + Vector2(0, -50)
	var t := create_tween()
	# Curva en arco (Bézier cuadrática) desde Pan hasta el objetivo
	t.tween_method(func(k: float): s.position = inicio.lerp(medio, k).lerp(medio.lerp(destino, k), k), 0.0, 1.0, 0.45)
	t.parallel().tween_property(s, "rotation", TAU * 2, 0.45)
	await t.finished
	return s


func _usar_granada() -> void:
	Juego.usar_objeto("granada_aturdidora")
	await _decir("¡Pan lanza la Granada Aturdidora!")
	var g := await _lanzar(TEX_GRANADA, sprite_enemigo.position + Vector2(0, -30))
	g.queue_free()
	transicion.color = Color(1, 1, 1, 0.9)
	create_tween().tween_property(transicion, "color:a", 0.0, 0.4)
	_sacudir_pantalla()
	var objetivo := maxi(1, roundi(enemigo["hp_max"] * 0.15))
	var danio: int = enemigo["hp"] - objetivo if enemigo["hp"] > objetivo else mini(5, enemigo["hp"] - 1)
	enemigo["hp"] -= maxi(0, danio)
	_texto_flotante(sprite_enemigo, str(maxi(0, danio)), COLOR_DEBILIDAD)
	_parpadear(sprite_enemigo)
	_actualizar_hud()
	await _decir("¡%s quedó aturdido! Su vida bajó a la zona roja." % enemigo["nombre"])


func _probabilidad_captura() -> float:
	var vida := float(enemigo["hp"]) / float(enemigo["hp_max"])
	return clampf((1.0 - vida) * 0.85 + 0.1, 0.05, 0.95) * enemigo["facilidad_captura"]


func _intentar_captura() -> void:
	var probabilidad := 1.0 if tipo == "tutorial_captura" else _probabilidad_captura()
	Juego.usar_objeto("carta_vinculo")
	await _decir("¡Pan lanza una Carta de Vínculo como un shuriken!")
	var carta := await _lanzar(TEX_CARTA, sprite_enemigo.position + Vector2(0, -30))
	var t := create_tween().set_parallel()
	t.tween_property(sprite_enemigo, "scale", Vector2(0.05, 0.05), 0.3)
	t.tween_property(sprite_enemigo, "modulate", Color(0.4, 1.0, 0.5), 0.3)
	await t.finished

	for i in 3:  # la carta tiembla
		var t3 := create_tween()
		t3.tween_property(carta, "rotation", 0.4, 0.1)
		t3.tween_property(carta, "rotation", -0.4, 0.1)
		t3.tween_property(carta, "rotation", 0.0, 0.1)
		await t3.finished
		await get_tree().create_timer(0.3).timeout

	if randf() < probabilidad:
		carta.modulate = Color(0.6, 1.0, 0.6)
		_guardar_aliado()  # antes de agregar la carta (por si es un duplicado del aliado)
		var r := Juego.agregar_carta(enemigo["id"])
		var especie: String = enemigo["nombre_especie"]
		await _decir("¡%s atrapado! Ahora es una carta en tu mochila." % especie)
		var aviso := "¡%s atrapado!" % especie
		if r["nueva"]:
			if Juego.mochila.size() > Juego.MAX_EQUIPO:
				await _decir("Tu equipo está lleno: la carta se guardó en la Colección.")
		elif r["nivel_despues"] > r["nivel_antes"]:
			var texto := "¡Vínculo fortalecido! %s alcanzó el Nivel %d." % [especie, r["nivel_despues"]]
			await _decir(texto)
			aviso = texto
		else:
			var faltan: int = Juego.cartas_para_nivel(r["nivel_despues"] + 1) - r["cantidad"]
			await _decir("Carta duplicada (%d). Te falta%s %d para subir de nivel." % [r["cantidad"], "" if faltan == 1 else "n", faltan])
		Juego.mensajes_pendientes.append(aviso)
		indice_aliado = -1  # ya guardamos su vida; no volver a sobrescribirla
		_terminar("captura")
	else:
		carta.queue_free()
		var t4 := create_tween().set_parallel()
		t4.tween_property(sprite_enemigo, "scale", Vector2.ONE, 0.2)
		t4.tween_property(sprite_enemigo, "modulate", Color.WHITE, 0.2)
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

	# Arquetipo evasivo (Bestia Blanca): en la zona roja intenta huir (solo si es salvaje).
	if enemigo["ia"] == "evasivo" and vida < 0.25 and tipo == "salvaje":
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
		nombre_aliado.text = "%s Nv%d%s" % [aliado["nombre"], aliado["nivel"], "  INF" if aliado["infectado"] else ""]
		_poner_barra(barra_aliado, aliado)
		vida_aliado.text = "HP %d/%d" % [aliado["hp"], aliado["hp_max"]]
	if not enemigo.is_empty():
		nombre_enemigo.text = "%s Nv%d" % [enemigo["nombre_especie"], enemigo["nivel"]]
		_poner_barra(barra_enemigo, enemigo)  # el enemigo no muestra número, solo la barra
		estado_enemigo.text = "INFECTADO" if enemigo["infectado"] else ""


func _preparar_barra(barra: ProgressBar) -> void:
	var relleno := StyleBoxFlat.new()
	relleno.anti_aliasing = false
	barra.add_theme_stylebox_override("fill", relleno)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.05, 0.04, 0.05)
	fondo.anti_aliasing = false
	fondo.set_border_width_all(1)
	fondo.border_color = Color(0.42, 0.29, 0.18)
	barra.add_theme_stylebox_override("background", fondo)


func _poner_barra(barra: ProgressBar, luchador: Dictionary) -> void:
	barra.max_value = luchador["hp_max"]
	create_tween().tween_property(barra, "value", float(luchador["hp"]), 0.25)
	var pct := float(luchador["hp"]) / float(luchador["hp_max"])
	var relleno: StyleBoxFlat = barra.get_theme_stylebox("fill")
	if pct > 0.5:
		relleno.bg_color = Color("#5cb85c")  # verde
	elif pct > 0.2:
		relleno.bg_color = Color("#e6c229")  # amarillo
	else:
		relleno.bg_color = Color("#e04040")  # rojo


func _embestir(s: Sprite2D) -> void:
	var dir := -1.0 if s.flip_h else 1.0
	var inicio := s.position
	var t := create_tween()
	t.tween_property(s, "position", inicio + Vector2(14 * dir, -4), 0.08)
	t.tween_property(s, "position", inicio, 0.12)


func _parpadear(s: Sprite2D) -> void:
	var t := create_tween()
	for i in 2:
		t.tween_property(s, "modulate:a", 0.2, 0.05)
		t.tween_property(s, "modulate:a", 1.0, 0.05)


func _texto_flotante(s: Sprite2D, texto: String, color: Color) -> void:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.theme_type_variation = &"NumeroDanio"
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.position = s.position + Vector2(randf_range(-14, 6), -70)
	escenario.add_child(etiqueta)
	var t := create_tween().set_parallel()
	t.tween_property(etiqueta, "position:y", etiqueta.position.y - 18, 0.7)
	t.tween_property(etiqueta, "modulate:a", 0.0, 0.7).set_delay(0.3)
	t.chain().tween_callback(etiqueta.queue_free)


func _sacudir_pantalla() -> void:
	var inicio := escenario.position
	var t := create_tween()
	for i in 6:
		t.tween_property(escenario, "position", inicio + Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.035)
	t.tween_property(escenario, "position", inicio, 0.035)


func _terminar(resultado: String) -> void:
	terminado = true
	_limpiar_opciones()
	_guardar_aliado()
	Juego.pasos_sin_encuentro = 4  # unos pasos de calma al volver al mapa
	Juego.resultado_combate = { "evento": datos.get("evento", ""), "resultado": resultado }
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(transicion, "color:a", 1.0, 0.4)
	await t.finished
	if resultado == "derrota":
		# Pan no muere: huye y despierta en el último lugar donde durmió, con las cartas reparadas.
		Juego.dormir()
		Juego.ir_a_mapa(Juego.lugar_descanso["mapa"], Juego.lugar_descanso["entrada"])
	else:
		Juego.cambiar_escena(Juego.mapa_actual)
