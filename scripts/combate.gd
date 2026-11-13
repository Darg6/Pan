extends Control
## Combate por turnos (GDD: Iniciativa -> Selección -> Ejecución -> Estados -> Victoria/Derrota).
## Juego.encuentro dice qué tipo de combate es:
##   "salvaje"          -> criatura salvaje: se puede capturar y huir
##   "entrenador"       -> bandido de la Organización: no se captura ni se huye, puede tener varias bestias
##   "tutorial_captura" -> prólogo: Pan aún no tiene criaturas y usa la Granada + Carta de Vínculo

const PAUSA_MENSAJE := 0.6        # segundos que se queda un mensaje (tocar la pantalla lo salta)
const LETRAS_POR_SEGUNDO := 90.0
const COLOR_DEBILIDAD := Color("#ff4a4a")
const TEX_CARTA := preload("res://arte/interfaz/carta.png")
const TEX_GRANADA := preload("res://arte/objetos/granada.png")
const TEX_SOMBRA := preload("res://arte/efectos/sombra.png")
const TEX_IMPACTO := preload("res://arte/efectos/impacto.png")
const TEX_POLVO := preload("res://arte/efectos/polvo.png")
const SHADER_LUCHADOR := preload("res://arte/shaders/luchador.gdshader")
const COLOR_TIPO := { "toxico": Color("#9cf05a"), "termico": Color("#ff9a3a"), "fluido": Color("#6ac8ff"), "feral": Color("#fff2c0"),
	"chatarra": Color("#d98a4a"), "energia": Color("#9ff0ff"), "terrestre": Color("#d8b070"), "sombra": Color("#a080d0"), "sonico": Color("#f0d0ff") }
## Tipos "físicos" (golpes de cuerpo): activan las defensas de los tanques y la estática de la Bailarina.
const TIPOS_FISICOS := ["feral", "chatarra", "terrestre"]

# Posiciones de los PIES dentro del escenario de 480x270 (centro de las plataformas del fondo)
const POS_ENEMIGO := Vector2(340, 127)
const POS_ALIADO := Vector2(138, 185)
const POS_PAN := Vector2(56, 186)
const POS_ENTRENADOR := Vector2(432, 121)

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
var _sombras := {}               # sprite -> su sombra en el suelo
var _saltar_espera := false      # el jugador tocó la pantalla para adelantar el texto
var _mensaje_actual := 0         # para que un mensaje viejo no pise al nuevo
var _turno_n := 0                # cuántos turnos van (el Grito de Guerra de Rictus es cada 3)
var _turnos_desde_cambio := 9    # para que el rival no cambie de bestia en todos los turnos
var _ultimo_fisico := false      # el último ataque de Pan fue un golpe físico fuerte
var _frases_dichas := {}         # frases del entrenador que ya dijo (cada una una vez)
var _tormenta := false           # tormenta de óxido en Bastión
var _estatica_pendiente := ""    # nombre de quien quedó paralizado por la estática (para el mensaje)


func _ready() -> void:
	Juego.cambiando_escena = false
	datos = Juego.encuentro
	if datos.is_empty():  # por si abres esta escena sola con F6 para probar
		datos = { "tipo": "salvaje", "equipo": [{ "id": "aves_negras", "nivel": 1 }] }
		if Juego.mochila.is_empty():
			Juego.agregar_carta("gato_mutado")
			Juego.dar_objeto("carta_vinculo", 3)
	tipo = datos.get("tipo", "salvaje")
	Sonido.musica(str(datos.get("musica", "combate")))
	_tormenta = bool(datos.get("tormenta", false))
	Sonido.ambiente("tormenta" if _tormenta else "viento")
	_armar_fondo(str(datos.get("fondo", "paramo")))
	var ceniza := Ambiente.ceniza(Vector2(480, 270))
	ceniza.position = Vector2(240, 135)
	ceniza.z_index = 0
	escenario.add_child(ceniza)
	if _tormenta:
		_armar_tormenta()
	equipo_enemigo = datos.get("equipo", []).duplicate(true)

	_preparar_barra(barra_aliado)
	_preparar_barra(barra_enemigo)
	_preparar_luchador(sprite_pan, POS_PAN, 0.5, 0.015)
	_preparar_luchador(sprite_aliado, POS_ALIADO, 1.0)
	_preparar_luchador(sprite_enemigo, POS_ENEMIGO, 1.0)
	_preparar_luchador(sprite_entrenador, POS_ENTRENADOR, 0.5, 0.015)
	sprite_aliado.visible = false
	hud_aliado.visible = false
	_limpiar_opciones()

	if tipo == "entrenador":
		var e: Dictionary = datos.get("entrenador", {})
		sprite_entrenador.texture = Juego.textura(e.get("sprite", "res://arte/personajes/recluta_combate.png"))
		sprite_entrenador.visible = true
	else:
		sprite_entrenador.visible = false
	if tipo == "tutorial_captura":
		_colocar(sprite_pan, POS_ALIADO + Vector2(-10, 0))  # Pan está en la posición del luchador

	_sacar_enemigo(equipo_enemigo.pop_front(), false)
	await _entrada_inicial()

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
			await _frase("inicio")
			await _decir("%s saca a %s (Nvl %d)." % [nombre_e, enemigo["nombre_especie"], enemigo["nivel"]])
		_:
			await _decir("¡Una criatura salvaje apareció: %s (Nvl %d)!" % [enemigo["nombre_especie"], enemigo["nivel"]])
	if _tormenta:
		await _decir("¡Una tormenta de óxido azota el campo! Solo la chatarra la aguanta.")
	if datos.get("grito_guerra", false):
		await _decir("Cada 3 turnos, el Grito de Guerra de %s cura a sus bestias." % datos.get("entrenador", {}).get("nombre", "el comandante"))

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


func _sacar_enemigo(info: Dictionary, animar := true) -> void:
	if info.has("hp_max"):   # una bestia que el entrenador ya había sacado (vuelve con la vida que tenía)
		enemigo = info
	else:
		enemigo = Juego.crear_luchador(info["id"], info["nivel"])
		enemigo["nombre_especie"] = enemigo["nombre"]
		enemigo["nombre"] += " rival" if tipo == "entrenador" else " salvaje"
	_turnos_desde_cambio = 0
	enemigo["bajo_tierra"] = false
	_quitar_hundido(sprite_enemigo)
	sprite_enemigo.texture = Juego.textura_criatura(info["id"])
	sprite_enemigo.flip_h = true  # las criaturas miran a la derecha; el enemigo mira a la izquierda
	sprite_enemigo.scale = Vector2.ONE
	sprite_enemigo.modulate = Color.WHITE
	sprite_enemigo.visible = true
	_ajustar_reposo(sprite_enemigo, info["id"])
	_actualizar_hud()
	if animar:  # el entrenador saca otra bestia: entra saltando desde la derecha
		_colocar(sprite_enemigo, POS_ENEMIGO)
		await _entrar(sprite_enemigo, Vector2(160, 0))


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


## Mochila: objetos (curas, comida, potenciadores, granada) y cartas para cambiar de criatura.
func _menu_mochila() -> void:
	var entradas: Array = []
	if Juego.tiene_objeto("granada_aturdidora"):
		entradas.append(["Granada x%d" % Juego.objetos["granada_aturdidora"], func(): _turno({ "tipo": "granada" })])
	if tipo != "tutorial_captura":
		for id in Juego.OBJETOS:
			if Juego.tipo_objeto(id) in ["cura", "comida", "potenciador"] and Juego.tiene_objeto(id):
				entradas.append(["%s x%d" % [Juego.nombre_objeto(id), Juego.objetos[id]], func(): _turno({ "tipo": "objeto", "id": id })])
		entradas.append(["Cartas", _menu_cartas])
	if entradas.is_empty():
		_limpiar_opciones()
		mensaje.text = "No tienes objetos."
		_agregar_boton("Volver", _menu_principal)
		return
	_menu_lista(entradas, "Mochila: elige un objeto.", _menu_principal)


func _menu_cartas() -> void:
	var entradas: Array = []
	var equipo := Juego.equipo()
	for i in equipo.size():
		var carta: Dictionary = equipo[i]
		if i == indice_aliado or carta["hp"] <= 0:
			continue
		var nombre: String = Juego.criaturas[carta["id"]]["nombre"]
		entradas.append(["%s %dHP" % [nombre, carta["hp"]], func(): _turno({ "tipo": "cambio", "indice": i })])
	if entradas.is_empty():
		_limpiar_opciones()
		mensaje.text = "No tienes otras cartas sanas."
		_agregar_boton("Volver", _menu_mochila)
		return
	_menu_lista(entradas, "¿Qué carta sacas?", _menu_mochila)


## Lista de botones con páginas (en el panel caben 4 botones).
func _menu_lista(entradas: Array, titulo: String, volver: Callable, pagina := 0) -> void:
	_limpiar_opciones()
	mensaje.text = titulo
	var por_pagina := 3 if entradas.size() <= 3 else 2
	var paginas := ceili(entradas.size() / float(por_pagina))
	for e in entradas.slice(pagina * por_pagina, (pagina + 1) * por_pagina):
		_agregar_boton(e[0], e[1])
	if paginas > 1:
		_agregar_boton("Más (%d/%d)" % [pagina + 1, paginas], _menu_lista.bind(entradas, titulo, volver, (pagina + 1) % paginas))
	_agregar_boton("Volver", volver)


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
		b.pressed.connect(Sonido.efecto.bind("boton"))
		b.pressed.connect(accion)
	opciones.add_child(b)


func _limpiar_opciones() -> void:
	mensaje.visible_characters = -1
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
	if accion["tipo"] == "objeto" and Juego.tipo_objeto(accion["id"]) in ["cura", "comida"] and aliado["hp"] >= aliado["hp_max"]:
		await _decir("%s ya tiene toda su vida." % aliado["nombre"])
		_menu_principal()
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
	_turno_n += 1
	_turnos_desde_cambio += 1

	# Iniciativa: objetos, cambio y captura tienen Prioridad +1. Si no, ataca el más rápido.
	var prioridad_j := 0 if accion["tipo"] == "ataque" else 1
	var prioridad_e := 0 if accion_enemigo["tipo"] == "ataque" else 1
	var jugador_primero := true
	if prioridad_j != prioridad_e:
		jugador_primero = prioridad_j > prioridad_e
	elif prioridad_j == 0:
		if aliado["velocidad"] == enemigo["velocidad"]:
			jugador_primero = randf() < 0.5
		else:
			jugador_primero = aliado["velocidad"] > enemigo["velocidad"]

	var orden := ["jugador", "enemigo"] if jugador_primero else ["enemigo", "jugador"]
	for actor in orden:
		if terminado or aliado["hp"] <= 0 or enemigo["hp"] <= 0:
			break  # si alguien cayó, el otro pierde su turno
		if actor == "jugador":
			if accion["tipo"] == "ataque" and await _paralizado_no_actua(aliado, sprite_aliado):
				continue
			await _accion_jugador(accion)
		else:
			if accion_enemigo["tipo"] == "ataque" and await _paralizado_no_actua(enemigo, sprite_enemigo):
				continue
			await _accion_enemigo(accion_enemigo)
	if terminado:
		return
	_ultimo_fisico = accion["tipo"] == "ataque" and accion["movimiento"]["tipo"] in TIPOS_FISICOS \
		and int(accion["movimiento"]["poder"]) * int(accion["movimiento"].get("golpes", 1)) >= 18

	# Fase de estados: infección (1/8 de la vida), parálisis, tormenta y el Grito de Guerra.
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
		"objeto":
			await _usar_objeto(accion["id"])


func _accion_enemigo(accion: Dictionary) -> void:
	match accion["tipo"]:
		"cambio_enemigo":
			var nombre_e: String = datos.get("entrenador", {}).get("nombre", "El bandido")
			await _decir("%s retira a %s." % [nombre_e, enemigo["nombre_especie"]])
			var t := create_tween()
			t.tween_property(sprite_enemigo, "position:x", sprite_enemigo.position.x + 160, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			await t.finished
			var nueva: Dictionary = equipo_enemigo[accion["indice"]]
			equipo_enemigo[accion["indice"]] = enemigo
			await _sacar_enemigo(nueva)
			await _decir("¡%s saca a %s (Nvl %d)!" % [nombre_e, enemigo["nombre_especie"], enemigo["nivel"]])
			return
		"cura_enemigo":
			datos["curas"] = int(datos.get("curas", 0)) - 1
			var nombre_e: String = datos.get("entrenador", {}).get("nombre", "El bandido")
			var cura := maxi(1, roundi(enemigo["hp_max"] * 0.4))
			enemigo["hp"] = mini(enemigo["hp_max"], enemigo["hp"] + cura)
			Sonido.efecto("objeto")
			_destello(sprite_enemigo, Color("#7bf09a"), 0.4)
			_texto_flotante(sprite_enemigo, "+%d" % cura, Color("#7bf09a"))
			_actualizar_hud()
			await _decir("¡%s usa una Cura 40%% en %s!" % [nombre_e, enemigo["nombre_especie"]])
			return
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
	if tipo_ataque in defensor.get("inmune", []):
		return 0.0
	if tipo_ataque in defensor["debil_a"]:
		return 2.0
	if tipo_ataque in defensor["resiste"]:
		return 0.5
	return 1.0


func _calcular_danio(atacante: Dictionary, defensor: Dictionary, mov: Dictionary) -> int:
	var poder := float(mov["poder"])
	var ratio: float = atacante["ataque"] / maxf(1.0, defensor["defensa"])
	var mult_nivel: float = 1.0 + atacante["nivel"] * 0.2
	var debilidad := _modificador_tipo(mov["tipo"], defensor)
	return maxi(1, roundi(poder * ratio * mult_nivel * debilidad * randf_range(0.85, 1.0)))


func _usar_movimiento(atacante: Dictionary, defensor: Dictionary, mov: Dictionary, spr_atacante: Sprite2D, spr_defensor: Sprite2D) -> void:
	await _decir("%s usa %s." % [atacante["nombre"], mov["nombre"]], 0.15)
	if atacante.get("bajo_tierra", false):   # sale de la arena para atacar
		atacante["bajo_tierra"] = false
		_salir_de_tierra(spr_atacante)

	if mov.get("efecto", "") == "defensa_arriba":
		Sonido.efecto("metal")
		_destello(spr_atacante, Color("#d98a4a"), 0.5)
		var t := create_tween()
		t.tween_property(spr_atacante, "scale", Vector2(1.15, 0.9), 0.1)
		t.tween_property(spr_atacante, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if atacante["defensa"] >= atacante["defensa_base"] * 2.0:
			await _decir("¡La defensa de %s ya no puede subir más!" % atacante["nombre"])
			return
		atacante["defensa"] = minf(atacante["defensa"] * 1.35, atacante["defensa_base"] * 2.0)
		_texto_flotante(spr_atacante, "DEF+", Color("#ffb070"))
		await _decir("¡%s se blinda con placas de chatarra! Su defensa subió." % atacante["nombre"])
		return

	if mov.get("efecto", "") == "evasion_arriba":
		await _animar_evasion(spr_atacante)
		atacante["evasion"] = minf(atacante["evasion"] + 0.15, 0.7)
		_texto_flotante(spr_atacante, "EVA+", Color("#9fe8ff"))
		await _decir("¡La evasión de %s subió!" % atacante["nombre"])
		return

	var golpes := int(mov.get("golpes", 1))
	var precision := float(mov.get("precision", 1.0))
	if _tormenta and atacante.get("tipo", "") != "chatarra":
		precision *= 0.85   # el polvo de óxido no deja ver
	var debilidad := _modificador_tipo(mov["tipo"], defensor)
	if debilidad == 0.0:
		await _acometer(spr_atacante, spr_defensor)
		_regresar(spr_atacante)
		_texto_flotante(spr_defensor, "Inmune", Color(1, 1, 1, 0.8))
		await _decir("No afecta a %s..." % defensor["nombre"])
		return
	if defensor.get("bajo_tierra", false):
		await _acometer(spr_atacante, spr_defensor)
		_regresar(spr_atacante)
		defensor["bajo_tierra"] = false
		_salir_de_tierra(spr_defensor)
		_texto_flotante(spr_defensor, "Fallo", Color(1, 1, 1, 0.7))
		await _decir("¡%s está bajo la arena! El ataque no lo alcanza." % defensor["nombre"])
		return
	var color_golpe: Color = COLOR_TIPO.get(mov["tipo"], Color.WHITE)
	var aciertos := 0
	await _acometer(spr_atacante, spr_defensor)
	for g in golpes:
		if defensor["hp"] <= 0:
			break
		if g > 0:
			await _rafaga(spr_atacante, spr_defensor)
		if randf() < defensor["evasion"] or randf() > precision:
			_esquivar(spr_defensor)
			Sonido.efecto("lanzar", 1.4, -4.0)
			_texto_flotante(spr_defensor, "Fallo", Color(1, 1, 1, 0.7))
			# Bailarina Eléctrica: al esquivar un golpe de cuerpo, la estática puede paralizar al atacante
			if defensor.get("pasiva", "") == "estatica" and mov["tipo"] in TIPOS_FISICOS and atacante["paralizado"] <= 0 and randf() < 0.35:
				atacante["paralizado"] = 3
				_destello(spr_atacante, COLOR_TIPO["energia"], 0.4)
				_actualizar_hud()
				_estatica_pendiente = atacante["nombre"]
			continue
		var danio := _calcular_danio(atacante, defensor, mov)
		defensor["hp"] = maxi(0, defensor["hp"] - danio)
		aciertos += 1
		_texto_flotante(spr_defensor, str(danio), COLOR_DEBILIDAD if debilidad > 1.0 else Color.WHITE, debilidad > 1.0)
		_actualizar_hud()
		await _impacto(spr_defensor, color_golpe, debilidad > 1.0)
	_regresar(spr_atacante)

	if golpes > 1:
		await _decir("¡%d de %d golpes acertaron!" % [aciertos, golpes])
	elif aciertos == 0:
		await _decir("¡%s esquivó el ataque!" % defensor["nombre"])
	if _estatica_pendiente != "":
		await _decir("¡La estática de %s paraliza a %s!" % [defensor["nombre"], _estatica_pendiente])
		_estatica_pendiente = ""
	if aciertos == 0:
		return
	if debilidad > 1.0:
		await _decir("¡Es súper efectivo!")
	elif debilidad < 1.0:
		await _decir("No es muy efectivo...")
	if atacante == enemigo and tipo == "entrenador" and (debilidad > 1.0 or aliado["hp"] < aliado["hp_max"] * 0.4):
		await _frase("golpe")
	var efecto: String = mov.get("efecto", "")
	if defensor["hp"] <= 0:
		return
	if efecto == "infectar" and not defensor["infectado"]:
		if defensor.get("pasiva", "") == "sin_infeccion":
			await _decir("%s es de metal: la infección no le hace nada." % defensor["nombre"])
		else:
			defensor["infectado"] = true
			_actualizar_hud()
			_destello(spr_defensor, COLOR_TIPO["toxico"], 0.4)
			await _decir("¡%s quedó infectado!" % defensor["nombre"])
	elif efecto == "paralizar" and defensor["paralizado"] <= 0:
		defensor["paralizado"] = 3
		_actualizar_hud()
		_destello(spr_defensor, COLOR_TIPO["energia"], 0.4)
		await _decir("¡%s quedó paralizado!" % defensor["nombre"])
	elif efecto == "defensa_abajo" and defensor["defensa"] > defensor["defensa_base"] * 0.45:
		defensor["defensa"] = maxf(defensor["defensa"] * 0.75, defensor["defensa_base"] * 0.4)
		_texto_flotante(spr_defensor, "DEF-", Color("#ff9a7a"))
		await _decir("¡Los nanobots se comen la defensa de %s!" % defensor["nombre"])
	elif efecto == "bajo_tierra":
		atacante["bajo_tierra"] = true
		_meter_en_tierra(spr_atacante)
		await _decir("¡%s se esconde bajo la arena!" % atacante["nombre"])


func _fase_estados() -> void:
	for pareja in [[aliado, sprite_aliado], [enemigo, sprite_enemigo]]:
		var luchador: Dictionary = pareja[0]
		if luchador["infectado"] and luchador["hp"] > 0:
			var danio := maxi(1, luchador["hp_max"] / 8)
			luchador["hp"] = maxi(0, luchador["hp"] - danio)
			_texto_flotante(pareja[1], str(danio), Color("#7bd13b"))
			_destello(pareja[1], COLOR_TIPO["toxico"], 0.4)
			_actualizar_hud()
			await _decir("%s sufre por la infección." % luchador["nombre"])
		if _tormenta and luchador["hp"] > 0 and luchador.get("tipo", "") != "chatarra":
			var raspon := maxi(1, luchador["hp_max"] / 16)
			luchador["hp"] = maxi(0, luchador["hp"] - raspon)
			_texto_flotante(pareja[1], str(raspon), Color("#e09050"))
			_actualizar_hud()
			await _decir("El óxido raspa a %s." % luchador["nombre"])
		if luchador["paralizado"] > 0:
			luchador["paralizado"] -= 1
			if luchador["paralizado"] == 0 and luchador["hp"] > 0:
				_actualizar_hud()
				await _decir("%s ya no está paralizado." % luchador["nombre"])
	# Grito de Guerra (Rictus): cada 3 turnos sus bestias recuperan un poco de vida
	if datos.get("grito_guerra", false) and _turno_n % 3 == 0 and enemigo["hp"] > 0:
		await _grito_de_guerra()


## Devuelve true si el combate terminó o si hay que elegir otra carta.
func _revisar_caidos() -> bool:
	if enemigo["hp"] <= 0:
		await _caer(sprite_enemigo)
		await _decir("¡%s fue derrotado!" % enemigo["nombre"])
		if tipo == "entrenador" and not equipo_enemigo.is_empty():
			var nombre_e: String = datos.get("entrenador", {}).get("nombre", "El bandido")
			_sacudir_entrenador()
			await _frase("pierde")
			await _sacar_enemigo(equipo_enemigo.pop_front())
			await _decir("%s saca a %s (Nvl %d)." % [nombre_e, enemigo["nombre_especie"], enemigo["nivel"]])
			if equipo_enemigo.is_empty():
				await _frase("ultima")
			return false
		if tipo == "entrenador":
			var nombre_e: String = datos.get("entrenador", {}).get("nombre", "El bandido")
			_sacudir_entrenador()
			await _decir("¡%s se quedó sin bestias!" % nombre_e)
			await _frase("derrota")
			var botin: Dictionary = datos.get("botin", {})
			if not botin.is_empty():
				Juego.monedas += int(botin.get("monedas", 0))
				Juego.chatarra += int(botin.get("reliquias", 0))
				await _decir("%s huye y suelta su botín: %d monedas y %d Reliquias del Viejo Mundo." % [
					nombre_e, int(botin.get("monedas", 0)), int(botin.get("reliquias", 0))])
		else:
			var parte: Dictionary = Juego.criaturas[enemigo["id"]].get("parte", {})
			if not parte.is_empty() and randf() < 0.7:
				Juego.partes[parte["id"]] = int(Juego.partes.get(parte["id"], 0)) + 1
				Sonido.efecto("objeto")
				await _decir("Pan recoge: %s. (Se vende en las tiendas.)" % parte["nombre"])
			await _decir("(Para capturar una criatura, debilítala sin derrotarla.)")
		_terminar("victoria")
		return true
	if aliado["hp"] <= 0:
		_guardar_aliado()
		await _caer(sprite_aliado)
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
	if Juego.bonus_ataque > 0.0:   # las fuerzas que te dieron las ciudades liberadas
		aliado["ataque"] *= 1.0 + Juego.bonus_ataque
		aliado["ataque_base"] = aliado["ataque"]
	_quitar_hundido(sprite_aliado)
	sprite_aliado.texture = Juego.textura_criatura(carta["id"])
	sprite_aliado.flip_h = false
	_ajustar_reposo(sprite_aliado, carta["id"])
	_colocar(sprite_aliado, POS_ALIADO)
	hud_aliado.visible = true
	_actualizar_hud()
	_decir("¡Adelante, %s!" % aliado["nombre"])
	# Pan lanza la carta, estalla en luz y la criatura aparece de golpe
	var c := await _lanzar(TEX_CARTA, POS_ALIADO + Vector2(0, -20), 0.3)
	c.queue_free()
	Sonido.efecto("aparecer")
	_chispa(POS_ALIADO + Vector2(0, -24), Color("#9fe8ff"), 1.5)
	sprite_aliado.visible = true
	sprite_aliado.modulate = Color.WHITE
	sprite_aliado.scale = Vector2(0.3, 1.6)
	_destello(sprite_aliado, Color("#9fe8ff"), 0.35)
	var t := create_tween()
	t.tween_property(sprite_aliado, "scale", Vector2(1.25, 0.8), 0.08)
	t.tween_property(sprite_aliado, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_polvo(POS_ALIADO)
	_sacudir_pantalla(2.0)
	await _esperar_lectura()


# ---------------------------------------------------------------------------
# Objetos
# ---------------------------------------------------------------------------

func _lanzar(textura: Texture2D, destino: Vector2, duracion := 0.4) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = textura
	s.position = sprite_pan.position + Vector2(8, -30)
	escenario.add_child(s)
	Sonido.efecto("lanzar")
	var inicio := s.position
	var medio := (inicio + destino) / 2.0 + Vector2(0, -50)
	var t := create_tween()
	# Curva en arco (Bézier cuadrática) desde Pan hasta el objetivo
	t.tween_method(func(k: float): s.position = inicio.lerp(medio, k).lerp(medio.lerp(destino, k), k), 0.0, 1.0, duracion)
	t.parallel().tween_property(s, "rotation", TAU * 2, duracion)
	await t.finished
	return s


func _usar_granada() -> void:
	Juego.usar_objeto("granada_aturdidora")
	await _decir("¡Pan lanza la Granada Aturdidora!")
	var g := await _lanzar(TEX_GRANADA, sprite_enemigo.position + Vector2(0, -24))
	g.queue_free()
	transicion.color = Color(1, 1, 1, 0.9)
	create_tween().tween_property(transicion, "color:a", 0.0, 0.4)
	_chispa(sprite_enemigo.position + Vector2(0, -24), Color("#fff2a8"), 2.0)
	Sonido.efecto("golpe_fuerte")
	_sacudir_pantalla(6.0)
	var objetivo := maxi(1, roundi(enemigo["hp_max"] * 0.15))
	var danio: int = enemigo["hp"] - objetivo if enemigo["hp"] > objetivo else mini(5, enemigo["hp"] - 1)
	enemigo["hp"] -= maxi(0, danio)
	_texto_flotante(sprite_enemigo, str(maxi(0, danio)), COLOR_DEBILIDAD, true)
	_destello(sprite_enemigo, Color.WHITE, 0.3)
	_actualizar_hud()
	await _decir("¡%s quedó aturdido! Su vida bajó a la zona roja." % enemigo["nombre"])


func _probabilidad_captura() -> float:
	var vida := float(enemigo["hp"]) / float(enemigo["hp_max"])
	return clampf((1.0 - vida) * 0.85 + 0.1, 0.05, 0.95) * enemigo["facilidad_captura"]


func _intentar_captura() -> void:
	var probabilidad := 1.0 if tipo == "tutorial_captura" else _probabilidad_captura()
	Juego.usar_objeto("carta_vinculo")
	await _decir("¡Pan lanza una Carta de Vínculo como un shuriken!")
	var carta := await _lanzar(TEX_CARTA, sprite_enemigo.position + Vector2(0, -24))
	_chispa(carta.position, Color("#9fe8ff"), 1.2)
	_destello(sprite_enemigo, Color("#9fe8ff"), 0.3)
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
		Sonido.efecto("captura")
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
		Sonido.efecto("fallo")
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
			var sirve: bool = not aliado.get("infectado", false) and aliado.get("pasiva", "") != "sin_infeccion"
			peso = 40.0 + (50.0 if sirve else 0.0)
		elif efecto == "paralizar":
			peso = 85.0 if aliado.get("paralizado", 0) <= 0 else 15.0
		elif efecto == "defensa_abajo":
			peso = 75.0 if aliado.get("defensa", 1.0) > aliado.get("defensa_base", 1.0) * 0.6 else 20.0
		elif efecto == "bajo_tierra":
			peso = 65.0 if not enemigo.get("bajo_tierra", false) else 10.0
		elif efecto == "defensa_arriba":
			# Arquetipo tanque: si Pan acaba de pegarle fuerte, se blinda
			peso = 15.0
			if enemigo["defensa"] < enemigo["defensa_base"] * 1.9:
				peso = 80.0 if _ultimo_fisico else (45.0 if vida > 0.6 else 25.0)
		elif efecto == "evasion_arriba":
			peso = 20.0
			if enemigo["ia"] == "evasivo" and vida < 0.5 and enemigo["evasion"] < 0.6:
				peso = 85.0
		elif poder_total == mas_fuerte and vida_rival < 0.3:
			peso = 100.0  # modo "rematar"
		elif _modificador_tipo(mov["tipo"], aliado) > 1.0:
			peso = 78.0   # sabe que es súper efectivo
		elif _modificador_tipo(mov["tipo"], aliado) == 0.0:
			peso = 5.0
		opciones_ia.append([peso + randf() * 5.0, { "tipo": "ataque", "movimiento": mov }])

	# Arquetipo evasivo (Bestia Blanca): en la zona roja intenta huir (solo si es salvaje).
	if enemigo["ia"] == "evasivo" and vida < 0.25 and tipo == "salvaje":
		opciones_ia.append([95.0 + randf() * 5.0, { "tipo": "huir" }])

	if tipo == "entrenador":
		# Los humanos SÍ usan objetos: una cura cuando su bestia está en rojo.
		if int(datos.get("curas", 0)) > 0 and vida < 0.3:
			opciones_ia.append([88.0, { "tipo": "cura_enemigo" }])
		# IA táctica: si tu criatura le hace daño súper efectivo, cambia a una que lo aguante.
		var tactico: bool = datos.get("comandante", false) or (datos.get("tactico", false) and randf() < 0.7)
		if tactico and _turnos_desde_cambio >= 2 and _pan_tiene_ventaja(enemigo):
			for i in equipo_enemigo.size():
				var cand: Dictionary = equipo_enemigo[i]
				var info_c: Dictionary = cand if cand.has("hp_max") else Juego.criaturas[cand["id"]]
				if (not cand.has("hp") or cand["hp"] > 0) and not _pan_tiene_ventaja(info_c):
					if not cand.has("hp_max"):
						var l := Juego.crear_luchador(cand["id"], cand["nivel"])
						l["nombre_especie"] = l["nombre"]
						l["nombre"] += " rival"
						equipo_enemigo[i] = l
					opciones_ia.append([92.0, { "tipo": "cambio_enemigo", "indice": i }])
					break

	opciones_ia.sort_custom(func(a, b): return a[0] > b[0])
	return opciones_ia[0][1]


## ¿La criatura de Pan tiene un ataque súper efectivo contra esta bestia?
func _pan_tiene_ventaja(objetivo: Dictionary) -> bool:
	if aliado.is_empty():
		return false
	for mov in aliado["movimientos"]:
		if int(mov["poder"]) > 0 and mov["tipo"] in objetivo.get("debil_a", []):
			return true
	return false


## Parálisis: la mitad de las veces no puede moverse.
func _paralizado_no_actua(l: Dictionary, s: Sprite2D) -> bool:
	if l["paralizado"] <= 0 or randf() >= 0.5:
		return false
	_destello(s, COLOR_TIPO["energia"], 0.3)
	Sonido.efecto("fallo", 1.3)
	await _decir("¡%s está paralizado y no puede moverse!" % l["nombre"])
	return true


## Curas, comida y potenciadores (siempre en la criatura que está peleando).
func _usar_objeto(id: String) -> void:
	var info: Dictionary = Juego.OBJETOS[id]
	Juego.usar_objeto(id)
	await _decir("Pan usa %s en %s." % [info["nombre"], aliado["nombre"]], 0.2)
	var o := await _lanzar(TEX_CARTA, sprite_aliado.position + Vector2(0, -24), 0.3)
	o.queue_free()
	Sonido.efecto("objeto")
	if info["tipo"] == "potenciador":
		var antes: float = aliado["ataque"]
		aliado["ataque"] = minf(aliado["ataque"] * (1.0 + float(info["valor"])), aliado["ataque_base"] * 2.2)
		_destello(sprite_aliado, Color("#ff5a3a"), 0.8)
		_chispa(sprite_aliado.position + Vector2(0, -24), Color("#ff6a4a"), 1.5)
		_texto_flotante(sprite_aliado, "ATK+", Color("#ff8a6a"))
		_actualizar_hud()
		if aliado["ataque"] <= antes:
			await _decir("El ataque de %s ya está al máximo." % aliado["nombre"])
		else:
			await _decir("¡Un aura roja envuelve a %s! Su ataque subió." % aliado["nombre"])
		return
	var cura := maxi(1, roundi(aliado["hp_max"] * float(info["valor"])))
	var antes_hp: int = aliado["hp"]
	aliado["hp"] = mini(aliado["hp_max"], aliado["hp"] + cura)
	_destello(sprite_aliado, Color("#7bf09a"), 0.5)
	_texto_flotante(sprite_aliado, "+%d" % (aliado["hp"] - antes_hp), Color("#7bf09a"))
	_actualizar_hud()
	_guardar_aliado()
	await _decir("%s recupera %d de vida." % [aliado["nombre"], aliado["hp"] - antes_hp])


## Rictus grita y sus bestias recuperan un 15% de vida (también las que esperan).
func _grito_de_guerra() -> void:
	var nombre_e: String = datos.get("entrenador", {}).get("nombre", "El comandante")
	Sonido.efecto("alerta", 0.7)
	_sacudir_pantalla(5.0)
	var t := create_tween()
	t.tween_property(sprite_entrenador, "scale", Vector2(1.2, 1.2), 0.1)
	t.tween_property(sprite_entrenador, "scale", Vector2.ONE, 0.2)
	await _decir("¡%s lanza su GRITO DE GUERRA!" % nombre_e)
	var cura := maxi(1, roundi(enemigo["hp_max"] * 0.15))
	enemigo["hp"] = mini(enemigo["hp_max"], enemigo["hp"] + cura)
	for b in equipo_enemigo:
		if b.has("hp_max") and b["hp"] > 0:
			b["hp"] = mini(b["hp_max"], b["hp"] + roundi(b["hp_max"] * 0.15))
	_destello(sprite_enemigo, Color("#ff7a3a"), 0.5)
	_texto_flotante(sprite_enemigo, "+%d" % cura, Color("#7bf09a"))
	_actualizar_hud()
	await _decir("Sus bestias recuperan vida.")


## Frases del entrenador (se burla, se enoja...). Cada una se dice una sola vez por combate.
func _frase(clave: String) -> void:
	var frases: Dictionary = datos.get("frases", {})
	if not frases.has(clave) or _frases_dichas.has(clave):
		return
	_frases_dichas[clave] = true
	var nombre_e: String = datos.get("entrenador", {}).get("nombre", "")
	var lista = frases[clave]
	if lista is String:
		lista = [lista]
	for linea in lista:
		if clave == "golpe":   # se ríe: da saltitos
			var t := create_tween()
			for i in 3:
				t.tween_property(sprite_entrenador, "position:y", sprite_entrenador.get_meta("base").y - 4, 0.07)
				t.tween_property(sprite_entrenador, "position:y", sprite_entrenador.get_meta("base").y, 0.07)
		await _decir("%s: \"%s\"" % [nombre_e, linea], 1.2)


## El entrenador se enoja cuando pierde una bestia.
func _sacudir_entrenador() -> void:
	if not sprite_entrenador.visible:
		return
	var base: Vector2 = sprite_entrenador.get_meta("base")
	var t := create_tween()
	for i in 5:
		t.tween_property(sprite_entrenador, "position:x", base.x + (3 if i % 2 == 0 else -3), 0.04)
	t.tween_property(sprite_entrenador, "position:x", base.x, 0.04)


func _estados_cortos(l: Dictionary) -> String:
	var lista: Array = []
	if l.get("infectado", false):
		lista.append("INF")
	if l.get("paralizado", 0) > 0:
		lista.append("PAR")
	if l.get("ataque", 0.0) > l.get("ataque_base", 1e9) + 0.01:
		lista.append("ATK+")
	if l.get("defensa", 0.0) > l.get("defensa_base", 1e9) + 0.01:
		lista.append("DEF+")
	elif l.get("defensa", 1e9) < l.get("defensa_base", 0.0) - 0.01:
		lista.append("DEF-")
	return "" if lista.is_empty() else "  " + " ".join(PackedStringArray(lista))


## El Gusano Devorador se mete bajo la arena: se ve hundido y medio transparente.
func _meter_en_tierra(s: Sprite2D) -> void:
	_polvo(s.get_meta("base"))
	var t := create_tween().set_parallel()
	t.tween_property(s, "offset:y", s.offset.y + 18, 0.2)
	t.tween_property(s, "modulate:a", 0.45, 0.2)
	s.set_meta("hundido", true)


## Al cambiar de criatura, el sprite vuelve a su altura normal.
func _quitar_hundido(s: Sprite2D) -> void:
	if s.get_meta("hundido", false):
		s.set_meta("hundido", false)
		s.offset.y -= 18
	s.modulate.a = 1.0


func _salir_de_tierra(s: Sprite2D) -> void:
	if not s.get_meta("hundido", false):
		return
	s.set_meta("hundido", false)
	_polvo(s.get_meta("base"))
	var t := create_tween().set_parallel()
	t.tween_property(s, "offset:y", s.offset.y - 18, 0.15)
	t.tween_property(s, "modulate:a", 1.0, 0.15)


## Tormenta de óxido: luz naranja y ráfagas de polvo que cruzan el campo.
func _armar_tormenta() -> void:
	var tinte := ColorRect.new()
	tinte.color = Color(0.85, 0.42, 0.18, 0.18)
	tinte.size = Vector2(480, 270)
	tinte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	escenario.add_child(tinte)
	var polvo := Ambiente.tormenta(Vector2(480, 270))
	polvo.z_index = 5
	escenario.add_child(polvo)


# ---------------------------------------------------------------------------
# Interfaz y "juice"
# ---------------------------------------------------------------------------

## Escribe el mensaje rápido letra por letra y espera un momento.
## Tocar la pantalla (o Espacio/Enter) completa el texto y lo adelanta.
func _decir(texto: String, pausa := PAUSA_MENSAJE) -> void:
	_mensaje_actual += 1
	var mi_mensaje := _mensaje_actual
	mensaje.text = texto
	mensaje.visible_characters = 0
	_saltar_espera = false
	var total := texto.length()
	var t := 0.0
	while mensaje.visible_characters < total and not _saltar_espera:
		await get_tree().process_frame
		if mi_mensaje != _mensaje_actual:
			return
		t += get_process_delta_time()
		mensaje.visible_characters = int(t * LETRAS_POR_SEGUNDO)
	mensaje.visible_characters = -1
	await _esperar_lectura(pausa)


func _esperar_lectura(pausa := PAUSA_MENSAJE) -> void:
	_saltar_espera = false
	var t := 0.0
	while t < pausa and not _saltar_espera:
		await get_tree().process_frame
		t += get_process_delta_time()


func _input(event: InputEvent) -> void:
	var toco: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or event.is_action_pressed("ui_accept") or event.is_action_pressed("interactuar")
	if toco and opciones.get_child_count() == 0:
		_saltar_espera = true


func _actualizar_hud() -> void:
	if not aliado.is_empty():
		nombre_aliado.text = "%s Nv%d%s" % [aliado["nombre"], aliado["nivel"], _estados_cortos(aliado)]
		_poner_barra(barra_aliado, aliado)
		vida_aliado.text = "HP %d/%d" % [aliado["hp"], aliado["hp_max"]]
	if not enemigo.is_empty():
		nombre_enemigo.text = "%s Nv%d" % [enemigo["nombre_especie"], enemigo["nivel"]]
		_poner_barra(barra_enemigo, enemigo)  # el enemigo no muestra número, solo la barra
		estado_enemigo.text = _estados_cortos(enemigo).strip_edges()


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


# ---------------------------------------------------------------------------
# Animaciones del combate ("juice"): todo rápido y con impacto
# ---------------------------------------------------------------------------

## Cada luchador tiene su shader (destello y respiración) y una sombra en el suelo.
func _preparar_luchador(s: Sprite2D, pos: Vector2, tam_sombra: float, respiracion := 0.025) -> void:
	var m := ShaderMaterial.new()
	m.shader = SHADER_LUCHADOR
	m.set_shader_parameter("respiracion", respiracion)
	m.set_shader_parameter("fase", randf() * TAU)
	s.material = m
	var sombra := Sprite2D.new()
	sombra.texture = TEX_SOMBRA
	sombra.scale = Vector2(tam_sombra, 1.0)
	escenario.add_child(sombra)
	escenario.move_child(sombra, _capas_fondo)  # justo encima del fondo, debajo de todos los sprites
	_sombras[s] = sombra
	_colocar(s, pos)


# ---------------------------------------------------------------------------
# Fondo por capas: cielo, nubes que pasan, montañas, ruinas con humo y suelo.
# Cada lugar tiene el suyo (arte/fondos/<lugar>_<capa>.png); el lugar viene en Juego.encuentro["fondo"].
# ---------------------------------------------------------------------------
var _capas_fondo := 1          # cuántos nodos de fondo hay al principio del escenario
var _nubes: Sprite2D
var _paralaje: Array = []      # [sprite, cuánto se mece]
var _t_fondo := 0.0


func _armar_fondo(lugar: String) -> void:
	var base := "res://arte/fondos/%s_" % lugar
	var cielo := Juego.textura(base + "cielo.png")
	if cielo == null:
		return  # se queda el fondo de siempre
	var fondo: TextureRect = $Escenario/Fondo
	fondo.texture = cielo
	var indice := fondo.get_index() + 1
	var humos: Array = Juego._leer_json("res://arte/fondos/fondos.json").get(lugar, {}).get("humo", [])
	for capa in ["nubes", "lejos", "medio", "suelo"]:
		var tex := Juego.textura(base + capa + ".png")
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		if capa == "nubes":   # se repite y se desplaza despacio
			s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			s.region_enabled = true
			s.region_rect = Rect2(0, 0, 480, tex.get_height())
			_nubes = s
		escenario.add_child(s)
		escenario.move_child(s, indice)
		indice += 1
		if capa == "lejos":
			_paralaje.append([s, 1.0])
		elif capa == "medio":
			_paralaje.append([s, 2.0])
			for p in humos:   # humo de las chimeneas, justo encima de las ruinas
				var h := Ambiente.humo(Vector2(p[0], p[1]))
				escenario.add_child(h)
				escenario.move_child(h, indice)
				indice += 1
	if lugar == "pastizal":
		var v := Ambiente.viento(Vector2(480, 120))
		v.position = Vector2(0, 200)
		escenario.add_child(v)
		escenario.move_child(v, indice)
		indice += 1
	_capas_fondo = indice


func _mover_fondo(delta: float) -> void:
	_t_fondo += delta
	if _nubes:
		_nubes.region_rect.position.x = fmod(_t_fondo * 3.0, float(_nubes.texture.get_width()))
	for par in _paralaje:   # las montañas y ruinas se mecen apenas (sensación de profundidad)
		par[0].position.x = roundf(sin(_t_fondo * 0.35) * par[1])


## Pone al sprite en su lugar de reposo (los pies tocan el suelo en `pos`).
func _colocar(s: Sprite2D, pos: Vector2) -> void:
	s.position = pos
	s.set_meta("base", pos)


func _process(delta: float) -> void:
	_mover_fondo(delta)
	for s in _sombras:
		var sombra: Sprite2D = _sombras[s]
		var base: Vector2 = s.get_meta("base", s.position)
		sombra.position = Vector2(s.position.x, base.y)  # la sombra se queda en el suelo aunque salte
		sombra.visible = s.visible
		sombra.modulate.a = s.modulate.a * clampf(s.scale.y, 0.0, 1.0)


## Las aves vuelan: en vez de respirar, suben y bajan un poquito.
func _ajustar_reposo(s: Sprite2D, id: String) -> void:
	var m: ShaderMaterial = s.material
	var vuela := id == "aves_negras"
	m.set_shader_parameter("respiracion", 0.0 if vuela else 0.025)
	m.set_shader_parameter("flotar", 3.0 if vuela else 0.0)
	m.set_shader_parameter("velocidad", 6.0 if vuela else 3.2)
	m.set_shader_parameter("destello", 0.0)


func _entrada_inicial() -> void:
	# Todos entran a escena desde los lados mientras se aclara la pantalla
	var f := create_tween()
	f.tween_property(transicion, "color:a", 0.0, 0.25)
	var hud_e: Control = $HUDEnemigo
	for p in [[hud_aliado, -170.0], [hud_e, 170.0]]:
		var panel: Control = p[0]
		var x := panel.position.x
		panel.position.x += p[1]
		create_tween().tween_property(panel, "position:x", x, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(0.25)
	if sprite_entrenador.visible:
		_entrar(sprite_entrenador, Vector2(120, 0))
	_entrar(sprite_pan, Vector2(-120, 0))
	await _entrar(sprite_enemigo, Vector2(220, 0))


## Entra corriendo desde `desde` (relativo) y aterriza con polvo.
func _entrar(s: Sprite2D, desde: Vector2) -> void:
	var base: Vector2 = s.get_meta("base")
	s.position = base + desde
	var t := create_tween()
	t.tween_property(s, "position", base, 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await t.finished
	_polvo(base)
	var t2 := create_tween()
	t2.tween_property(s, "scale", Vector2(1.15, 0.85), 0.05)
	t2.tween_property(s, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if s == sprite_enemigo:
		_sacudir_pantalla(2.0)


## Toma impulso hacia atrás y se lanza contra el rival.
func _acometer(at: Sprite2D, df: Sprite2D) -> void:
	var base: Vector2 = at.get_meta("base")
	var dir := signf(df.position.x - base.x)
	var t := create_tween()
	t.tween_property(at, "position", base + Vector2(-8 * dir, 0), 0.07).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(at, "scale", Vector2(0.9, 1.1), 0.07)
	t.tween_property(at, "position", base + Vector2(46 * dir, -10 * dir), 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(at, "scale", Vector2(1.15, 0.9), 0.08)
	await t.finished


## Golpes extra de un ataque múltiple: pequeños empujones rápidos.
func _rafaga(at: Sprite2D, df: Sprite2D) -> void:
	var dir := signf(df.position.x - at.position.x)
	var p := at.position
	var t := create_tween()
	t.tween_property(at, "position", p - Vector2(10 * dir, 0), 0.05)
	t.tween_property(at, "position", p, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await t.finished


func _regresar(at: Sprite2D) -> void:
	var t := create_tween().set_parallel()
	t.tween_property(at, "position", at.get_meta("base"), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(at, "scale", Vector2.ONE, 0.18)


## El golpe: congelado de un instante, destello blanco, retroceso, chispa y temblor.
func _impacto(df: Sprite2D, color: Color, fuerte: bool) -> void:
	var base: Vector2 = df.get_meta("base")
	var dir := -1.0 if df.flip_h else 1.0  # se lo empuja hacia atrás
	_destello(df, Color.WHITE, 0.18)
	Sonido.efecto("golpe_fuerte" if fuerte else "golpe", randf_range(0.9, 1.1))
	_chispa(base + Vector2(0, -26) + Vector2(randf_range(-6, 6), randf_range(-6, 6)), color, 1.6 if fuerte else 1.0)
	_sacudir_pantalla(6.0 if fuerte else 3.0)
	_sacudir_panel(hud_aliado if df == sprite_aliado else $HUDEnemigo)
	df.position = base + Vector2(-10 * dir, 0)
	await get_tree().create_timer(0.07).timeout  # "hit-stop": el golpe se siente
	var t := create_tween()
	t.tween_property(df, "position", base, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _esquivar(df: Sprite2D) -> void:
	var base: Vector2 = df.get_meta("base")
	var t := create_tween()
	t.tween_property(df, "position", base + Vector2(0, -16), 0.08).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(df, "modulate:a", 0.4, 0.08)
	t.tween_property(df, "position", base, 0.12).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(df, "modulate:a", 1.0, 0.12)


## Movimiento de evasión: zigzag rapidísimo con imágenes residuales.
func _animar_evasion(s: Sprite2D) -> void:
	var base: Vector2 = s.get_meta("base")
	for k in 4:
		var fantasma := Sprite2D.new()
		fantasma.texture = s.texture
		fantasma.flip_h = s.flip_h
		fantasma.offset = s.offset
		fantasma.position = s.position
		fantasma.modulate = Color(0.6, 0.9, 1.0, 0.5)
		escenario.add_child(fantasma)
		var tf := create_tween()
		tf.tween_property(fantasma, "modulate:a", 0.0, 0.25)
		tf.tween_callback(fantasma.queue_free)
		var t := create_tween()
		t.tween_property(s, "position", base + Vector2(14 if k % 2 == 0 else -14, 0), 0.05)
		await t.finished
	_regresar(s)
	await get_tree().create_timer(0.15).timeout


## Cae derrotado: destello rojo, se aplasta contra el suelo y desaparece.
func _caer(s: Sprite2D) -> void:
	_destello(s, COLOR_DEBILIDAD, 0.3)
	Sonido.efecto("caer")
	var t := create_tween()
	t.tween_interval(0.15)
	t.tween_property(s, "scale", Vector2(1.3, 0.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(s, "modulate:a", 0.0, 0.25)
	await t.finished
	_polvo(s.get_meta("base"))
	_sacudir_pantalla(3.0)
	s.scale = Vector2.ONE
	s.modulate.a = 0.0


func _destello(s: Sprite2D, color: Color, duracion: float) -> void:
	var m: ShaderMaterial = s.material
	if m == null:
		return
	m.set_shader_parameter("color_destello", color)
	var t := create_tween()
	t.tween_method(func(v: float): m.set_shader_parameter("destello", v), 1.0, 0.0, duracion)


## Chispa de impacto animada (4 cuadros) en `pos`.
func _chispa(pos: Vector2, color: Color, escala := 1.0) -> void:
	var s := Sprite2D.new()
	s.texture = TEX_IMPACTO
	s.hframes = 4
	s.position = pos.round()
	s.modulate = color
	s.scale = Vector2(escala, escala).round() if escala >= 1.5 else Vector2.ONE
	escenario.add_child(s)
	var t := create_tween()
	t.tween_property(s, "frame", 3, 0.2)
	t.tween_callback(s.queue_free)


func _polvo(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = TEX_POLVO
	s.hframes = 4
	s.offset = Vector2(0, -6)
	s.position = pos
	escenario.add_child(s)
	var t := create_tween()
	t.tween_property(s, "frame", 3, 0.3)
	t.tween_callback(s.queue_free)


func _texto_flotante(s: Sprite2D, texto: String, color: Color, grande := false) -> void:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.theme_type_variation = &"NumeroDanio"
	etiqueta.add_theme_color_override("font_color", color)
	if grande:
		etiqueta.add_theme_font_size_override("font_size", 16)
	var base: Vector2 = s.get_meta("base", s.position)
	etiqueta.position = base + Vector2(randf_range(-14, 6), -62)
	etiqueta.pivot_offset = Vector2(8, 8)
	etiqueta.scale = Vector2(2, 2)
	escenario.add_child(etiqueta)
	var t := create_tween()
	t.tween_property(etiqueta, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(etiqueta, "position:y", etiqueta.position.y - 6, 0.12)
	t.tween_interval(0.35)
	t.tween_property(etiqueta, "position:y", etiqueta.position.y - 12, 0.3)
	t.parallel().tween_property(etiqueta, "modulate:a", 0.0, 0.3)
	t.tween_callback(etiqueta.queue_free)


func _sacudir_pantalla(fuerza := 4.0) -> void:
	var inicio := Vector2(escenario.offset_left, escenario.offset_top)
	var t := create_tween()
	for i in 6:
		var f := fuerza * (1.0 - i / 6.0)
		t.tween_callback(func():
			escenario.offset_left = inicio.x + roundf(randf_range(-f, f))
			escenario.offset_top = inicio.y + roundf(randf_range(-f, f)))
		t.tween_interval(0.03)
	t.tween_callback(func():
		escenario.offset_left = inicio.x
		escenario.offset_top = inicio.y)


func _sacudir_panel(panel: Control) -> void:
	var x := panel.position.x
	var t := create_tween()
	for i in 4:
		t.tween_property(panel, "position:x", x + (3 if i % 2 == 0 else -3), 0.03)
	t.tween_property(panel, "position:x", x, 0.03)


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
