extends Node2D
## Controla cualquier mapa top-down (Refugio Cero, Superficie, ...).
## Estructura que espera la escena:
##   Suelo (TileMapLayer)          -> los tiles del mapa
##   Entidades (Node2D, y-sort)    -> Pan, personajes e interactuables
##   Zonas (Node2D)                -> zonas de encuentro con criaturas
##   Disparadores (Node2D)         -> eventos al pisar una zona
##   Entradas (Node2D)             -> Marker2D donde aparece Pan al llegar
##   HUD (escenas/ui/hud.tscn)
## Lo que pasa en cada evento está en scripts/historia.gd.

const ESCENA_COMBATE := "res://escenas/combate.tscn"

## Nombre corto del mapa, lo usa historia.gd ("refugio_cero", "superficie")
@export var nombre_mapa := ""
## Acercamiento de la cámara (los interiores pequeños se ven mejor más cerca)
@export var zoom_camara := 1.0

@onready var pan: CharacterBody2D = $Entidades/Pan
@onready var suelo: TileMapLayer = $Suelo
@onready var hud: CanvasLayer = $HUD

var ocupado := false            # true mientras corre un evento o diálogo
var _dentro_de: Dictionary = {}  # disparadores que Pan está pisando
var _exclamacion: Sprite2D
var _aviso_sin_cartas := false
var _aviso_infeccion := false
var _pasos := 0


func _ready() -> void:
	Juego.cambiando_escena = false
	Juego.mapa_actual = scene_file_path
	pan.joystick = hud.joystick
	pan.paso_dado.connect(_on_paso_dado)
	hud.accion_pulsada.connect(interactuar)

	# ¿Dónde aparece Pan?
	if Juego.posicion_pan != null:
		pan.global_position = Juego.posicion_pan
		Juego.posicion_pan = null
	elif Juego.entrada != "" and has_node("Entradas/" + Juego.entrada):
		pan.global_position = get_node("Entradas/" + Juego.entrada).global_position

	# La cámara no sale del mapa (si el mapa es más chico que la pantalla, queda centrado)
	var camara: Camera2D = pan.get_node("Camara")
	camara.zoom = Vector2(zoom_camara, zoom_camara)
	var usado := suelo.get_used_rect()
	var rect := Rect2(Vector2(usado.position) * 16, Vector2(usado.size) * 16)
	var vista := get_viewport_rect().size / zoom_camara
	if rect.size.x < vista.x:
		rect = rect.grow_individual((vista.x - rect.size.x) / 2.0, 0, (vista.x - rect.size.x) / 2.0, 0)
	if rect.size.y < vista.y:
		rect = rect.grow_individual(0, (vista.y - rect.size.y) / 2.0, 0, (vista.y - rect.size.y) / 2.0)
	camara.limit_left = floori(rect.position.x)
	camara.limit_top = floori(rect.position.y)
	camara.limit_right = ceili(rect.end.x)
	camara.limit_bottom = ceili(rect.end.y)
	camara.reset_smoothing()

	_exclamacion = Sprite2D.new()
	_exclamacion.texture = preload("res://arte/interfaz/exclamacion.png")
	_exclamacion.z_index = 10
	_exclamacion.visible = false
	add_child(_exclamacion)

	# No disparar eventos de zonas en las que Pan ya aparece parado
	for d in get_tree().get_nodes_in_group("disparadores"):
		_dentro_de[d] = d.contiene(pan.global_position)

	refrescar()
	_preparar_ambiente()
	_velocidad_pan = pan.velocidad
	if _hay_tormentas():
		var pantalla := get_viewport_rect().size / zoom_camara
		_polvo_tormenta = Ambiente.tormenta(pantalla)
		_polvo_tormenta.position = Vector2(-pantalla.x / 2.0 - 20.0, 0)
		_polvo_tormenta.z_index = 25
		pan.get_node("Camara").add_child(_polvo_tormenta)
		poner_tormenta(Juego.tormenta)
	else:
		Juego.tormenta = false
	Historia.mapa = self
	ocupado = true   # nadie interactúa hasta que la historia revise este mapa
	hud.transicion.color.a = 1.0
	await hud.fundido(false, 0.5)
	await correr(Historia.al_entrar_mapa.bind(self))
	Juego.guardar()   # guardado automático al llegar a cada lugar
	for m in Juego.mensajes_pendientes:
		hud.mostrar_aviso(m)
	Juego.mensajes_pendientes.clear()


## Ejecuta un evento de la historia bloqueando el movimiento mientras dura.
func correr(evento: Callable) -> void:
	ocupado = true
	pan.puede_moverse = false
	hud.set_controles(false)
	_exclamacion.visible = false
	await evento.call()
	if Juego.cambiando_escena or not is_inside_tree():
		return  # el evento cambió de escena
	ocupado = false
	pan.puede_moverse = true
	hud.set_controles(true)
	refrescar()
	if Juego.guardar_pronto:   # ej. después de dormir
		Juego.guardar_pronto = false
		if Juego.guardar():
			hud.mostrar_aviso("Partida guardada")


## ¿Se puede guardar ahora? (no en medio de un diálogo, un evento o un cambio de mapa)
func puede_guardar() -> bool:
	return is_inside_tree() and not ocupado and not Juego.cambiando_escena and nombre_mapa != ""


# ---------------------------------------------------------------------------
# Ambiente de cada mapa: música, sonido de fondo, color de la luz y partículas.
# Cambia los valores aquí para darle otro clima a un mapa.
# ---------------------------------------------------------------------------
const AMBIENTACION := {
	"refugio_cero": { "musica": "", "ambiente": "bunker", "tinte": Color(0.86, 0.88, 1.0), "particulas": "polvo",
		"luces": { "generador": Color(0.45, 1.0, 0.55), "escalera": Color(1.0, 0.85, 0.6) } },
	"superficie": { "musica": "paramo", "ambiente": "viento", "tinte": Color(1.0, 0.9, 0.8), "particulas": "ceniza",
		"luces": { "fogata": Color(1.0, 0.6, 0.25) } },
	"bastion_oxido": { "musica": "bastion", "ambiente": "ciudad", "tinte": Color(1.0, 0.88, 0.76), "particulas": "ceniza",
		"luces": { "fogata": Color(1.0, 0.6, 0.25), "farol": Color(1.0, 0.78, 0.4) }, "tormentas": true },
	"autopista": { "musica": "paramo", "ambiente": "viento", "tinte": Color(0.9, 0.84, 0.82), "particulas": "ceniza" },
	# El Sumidero: verde enfermizo y violeta, hongos que brillan, burbujas en el lodo y goteras de ácido
	"sumidero": { "musica": "sumidero", "ambiente": "subterraneo", "tinte": Color(0.66, 0.78, 0.74), "particulas": "niebla",
		"luces": { "fogon": Color(1.0, 0.6, 0.25), "hongo_grande": Color(0.35, 1.0, 0.9), "hongos_1": Color(0.75, 0.5, 1.0),
			"escalera": Color(1.0, 0.95, 0.8), "cristal": Color(0.6, 1.0, 0.8) },
		"burbujas": ["lodo_1", "lodo_2"] },
	# El Paso del Smog: aire violeta y espeso (pero respirable: el "gas" es una mentira de Silas)
	"paso_smog": { "musica": "paramo", "ambiente": "viento", "tinte": Color(0.82, 0.74, 0.9), "particulas": "smog",
		"luces": { "charco_luz": Color(0.4, 0.95, 1.0) } },
	# Ciudad Neón: siempre de noche, letreros cian y magenta, altavoces que repiten la voz de Silas
	"ciudad_neon": { "musica": "neon", "ambiente": "neon", "tinte": Color(0.78, 0.74, 0.95), "particulas": "smog",
		"luces": { "charco_luz": Color(0.4, 0.95, 1.0), "linea_cian": Color(0.35, 0.95, 1.0), "linea_magenta": Color(1.0, 0.35, 0.85) },
		"cada_luz": 3,
		"anuncios_hasta": "neon_liberado",
		"anuncios": ["ALTAVOZ: ¡Sonrían! Silas los está mirando.", "ALTAVOZ: El aire de afuera es GAS LETAL. No salgan.",
			"ALTAVOZ: Turno de pedales: ¡las luces nos protegen de los monstruos!", "ALTAVOZ: Quien deja de pedalear, deja a todos a oscuras.",
			"ALTAVOZ: Silas los ama. Silas los cuida. Silas los escucha."] },
	# El Bosque Calcinado: ceniza que cae como nieve y brasas escondidas que queman
	"bosque_calcinado": { "musica": "paramo", "ambiente": "bosque", "tinte": Color(0.86, 0.84, 0.86), "particulas": "nieve",
		"luces": { "brasa_1": Color(1.0, 0.45, 0.15), "brasa_2": Color(1.0, 0.45, 0.15) }, "cada_luz": 2, "brasas": true },
	# Valle Ceniza: melancólico pero en paz. Si Pan ejecuta a Kael, el valle se vuelve frío y callado.
	"valle_ceniza": { "musica": "valle", "ambiente": "bosque", "tinte": Color(0.95, 0.9, 0.86), "particulas": "nieve",
		"tinte_si": { "kael_ejecutado": Color(0.62, 0.62, 0.7) }, "musica_si": { "kael_ejecutado": "" } },
}

# ---------------------------------------------------------------------------
# Tormentas de óxido (mecánica de Bastión de Óxido): cada cierto tiempo el viento levanta
# polvo oxidado. Pan camina más lento, se ve menos, aparecen más bestias de chatarra y en
# combate todos fallan más (menos la chatarra) y el óxido raspa la vida al final del turno.
# ---------------------------------------------------------------------------
const CLIMA_CALMA := 45.0
const CLIMA_TORMENTA := 20.0
var _polvo_tormenta: CPUParticles2D
var _velocidad_pan := 70.0


func _hay_tormentas() -> bool:
	return AMBIENTACION.get(nombre_mapa, {}).get("tormentas", false)


func _clima(delta: float) -> void:
	if not _hay_tormentas() or ocupado:
		return
	Juego.tiempo_clima += delta
	if Juego.tiempo_clima >= (CLIMA_TORMENTA if Juego.tormenta else CLIMA_CALMA):
		Juego.tiempo_clima = 0.0
		poner_tormenta(not Juego.tormenta, true)


func poner_tormenta(activa: bool, avisar := false) -> void:
	Juego.tormenta = activa and _hay_tormentas()
	hud.set_tormenta(Juego.tormenta)
	if _polvo_tormenta:
		_polvo_tormenta.emitting = Juego.tormenta
		_polvo_tormenta.visible = Juego.tormenta
	pan.velocidad = _velocidad_pan * (0.7 if Juego.tormenta else 1.0)
	var a: Dictionary = AMBIENTACION.get(nombre_mapa, {})
	Sonido.ambiente("tormenta" if Juego.tormenta else a.get("ambiente", ""))
	if avisar:
		hud.mostrar_aviso("¡Tormenta de óxido! Las bestias de chatarra salen a cazar." if Juego.tormenta else "La tormenta de óxido se calma.")


## Un valor del ambiente que puede cambiar con la historia (ej. "tinte_si": { "bandera": color }).
func _ambiente_valor(a: Dictionary, clave: String, por_defecto):
	var segun: Dictionary = a.get(clave + "_si", {})
	for bandera in segun:
		if Juego.flag(bandera):
			return segun[bandera]
	return a.get(clave, por_defecto)


var _tinte: CanvasModulate
var _coords_brasa: Array[Vector2i] = []
var _t_anuncio := 0.0


## Vuelve a revisar la música y el color del mapa (cuando la historia cambia algo, ej. tras decidir sobre Kael).
func actualizar_ambiente(duracion := 1.5) -> void:
	var a: Dictionary = AMBIENTACION.get(nombre_mapa, {})
	Sonido.musica(_ambiente_valor(a, "musica", ""))
	if _tinte:
		create_tween().tween_property(_tinte, "color", _ambiente_valor(a, "tinte", Color.WHITE), duracion)


func _preparar_ambiente() -> void:
	var a: Dictionary = AMBIENTACION.get(nombre_mapa, {})
	Sonido.musica(_ambiente_valor(a, "musica", ""))
	Sonido.ambiente(a.get("ambiente", ""))
	_tinte = CanvasModulate.new()
	_tinte.color = _ambiente_valor(a, "tinte", Color.WHITE)
	add_child(_tinte)
	if a.get("brasas", false):
		_coords_brasa = Ambiente.coords_de(suelo, ["brasa_1", "brasa_2"])
	var camara: Camera2D = pan.get_node("Camara")
	match a.get("particulas", ""):
		"ceniza":
			camara.add_child(Ambiente.ceniza(get_viewport_rect().size / zoom_camara))
		"polvo":
			camara.add_child(Ambiente.polvo(get_viewport_rect().size / zoom_camara))
		"niebla":
			camara.add_child(Ambiente.niebla(get_viewport_rect().size / zoom_camara))
			camara.add_child(Ambiente.polvo(get_viewport_rect().size / zoom_camara))
		"smog":
			camara.add_child(Ambiente.niebla(get_viewport_rect().size / zoom_camara, Color(0.72, 0.45, 0.95)))
			camara.add_child(Ambiente.polvo(get_viewport_rect().size / zoom_camara))
		"nieve":
			camara.add_child(Ambiente.nieve_ceniza(get_viewport_rect().size / zoom_camara))
	# Luces: un brillo suave que titila sobre ciertos tiles (fogatas, generadores...)
	var luces: Dictionary = a.get("luces", {})
	var cada_luz: int = maxi(1, int(a.get("cada_luz", 1)))   # en mapas con muchos tiles de luz, solo una de cada tantas
	var n_luz := 0
	for nombre_tile in luces:
		for celda in Ambiente.celdas_con_tile(suelo, nombre_tile):
			n_luz += 1
			if n_luz % cada_luz != 0:
				continue
			var centro := suelo.map_to_local(celda)
			$Entidades.add_child(Ambiente.luz(centro, luces[nombre_tile], nombre_tile == "fogata"))
			if nombre_tile == "fogata":
				$Entidades.add_child(Ambiente.brasas(centro))
	# Luces de las construcciones grandes (hongos gigantes, el laboratorio...): metadato "luz" del nodo
	for nodo in $Entidades.get_children():
		if nodo.has_meta("luz") and nodo.visible:
			var l := Ambiente.luz(nodo.position + nodo.get_meta("luz_pos", Vector2(0, -24)), nodo.get_meta("luz"), false)
			l.scale = Vector2(2.2, 2.2)
			$Entidades.add_child(l)
			if nodo.has_meta("esporas"):
				$Entidades.add_child(Ambiente.esporas(nodo.position + Vector2(0, -26), nodo.get_meta("luz"), 18.0))
	# Burbujas que suben del lodo tóxico (una de cada tantas celdas, para no llenar todo)
	var k := 0
	for nombre_tile in a.get("burbujas", []):
		for celda in Ambiente.celdas_con_tile(suelo, nombre_tile):
			k += 1
			if k % 9 == 0:
				var b := Ambiente.burbujas(Vector2(14, 6))
				b.amount = 3
				b.position = suelo.map_to_local(celda)
				b.z_index = 1
				$Entidades.add_child(b)
	hud.agregar_vineta()


func refrescar() -> void:
	for nodo in get_tree().get_nodes_in_group("interactuables"):
		nodo.actualizar()
	for nodo in get_tree().get_nodes_in_group("interactuables_flags"):
		nodo.actualizar()
	hud.actualizar()


func _process(_delta: float) -> void:
	_clima(_delta)
	_anuncios(_delta)
	if ocupado or hud.menu_abierto():
		_exclamacion.visible = false
		pan.puede_moverse = not ocupado and not hud.menu_abierto()
		return
	pan.puede_moverse = true
	var cercano = _interactuable_cercano()
	_exclamacion.visible = cercano != null
	if cercano != null:
		var rebote := roundf(sin(Time.get_ticks_msec() / 160.0) * 1.5)  # el "!" sube y baja
		_exclamacion.global_position = cercano.global_position + Vector2(0, (-24 if cercano.solido else -14) + rebote)

	for d in get_tree().get_nodes_in_group("disparadores"):
		var dentro: bool = d.contiene(pan.global_position)
		if dentro and not _dentro_de.get(d, false):
			_dentro_de[d] = true
			correr(Historia.ejecutar.bind(d.evento, d))
			return
		_dentro_de[d] = dentro


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interactuar") and not ocupado:
		get_viewport().set_input_as_handled()
		interactuar()


func _interactuable_cercano():
	var punto: Vector2 = pan.global_position + pan.direccion_mirada() * 8.0
	var mejor = null
	var mejor_dist := INF
	for nodo in get_tree().get_nodes_in_group("interactuables"):
		if not nodo.activo():
			continue
		var dist := punto.distance_to(nodo.global_position)
		if dist <= nodo.radio and dist < mejor_dist:
			mejor = nodo
			mejor_dist = dist
	return mejor


func interactuar() -> void:
	if ocupado or hud.menu_abierto():
		return
	var nodo = _interactuable_cercano()
	if nodo != null:
		correr(Historia.ejecutar.bind(nodo.evento, nodo))


## Altavoces de la ciudad (Ciudad Neón): cada tanto se oye la voz de Silas.
func _anuncios(delta: float) -> void:
	var a: Dictionary = AMBIENTACION.get(nombre_mapa, {})
	var lista: Array = a.get("anuncios", [])
	if lista.is_empty() or Juego.flag(a.get("anuncios_hasta", "")) or ocupado or hud.menu_abierto():
		return
	_t_anuncio += delta
	if _t_anuncio < 35.0:
		return
	_t_anuncio = 0.0
	Sonido.efecto("alerta", 1.5, -10.0)
	hud.mostrar_aviso(lista.pick_random())


# ---------------------------------------------------------------------------
# Encuentros con criaturas salvajes (solo en tiles de pasto)
# ---------------------------------------------------------------------------

func pisando_pasto() -> bool:
	var datos := suelo.get_cell_tile_data(suelo.local_to_map(suelo.to_local(pan.global_position)))
	return datos != null and datos.get_custom_data("pasto")


func _celda_con(dato: String) -> bool:
	var datos := suelo.get_cell_tile_data(suelo.local_to_map(suelo.to_local(pan.global_position)))
	return datos != null and datos.get_custom_data(dato)


func _on_paso_dado() -> void:
	if ocupado:
		return
	_pasos += 1
	# La infección sigue fuera del combate: cada 10 pasos quita un poquito de vida (nunca rompe la carta)
	if _pasos % 10 == 0 and Juego.hay_cartas_infectadas():
		var nombres := Juego.infeccion_al_caminar()
		if not nombres.is_empty() and not _aviso_infeccion:
			_aviso_infeccion = true
			hud.mostrar_aviso("%s sigue infectado y pierde vida. (Un Antídoto o dormir lo cura.)" % nombres[0])
	# Charcos tóxicos: pueden infectar a la carta que va al frente
	if _celda_con("toxico") and randf() < 0.3:
		var i := Juego.carta_al_frente()
		if i >= 0 and not Juego.mochila[i].get("infectada", false):
			Juego.mochila[i]["infectada"] = true
			Sonido.efecto("burbuja", 1.2)
			hud.mostrar_aviso("¡El lodo tóxico salpica a %s! Quedó infectado." % Juego.criaturas[Juego.mochila[i]["id"]]["nombre"])
	# Brasas escondidas bajo la ceniza (Bosque Calcinado): queman un poco a la carta del frente
	if not _coords_brasa.is_empty() and randf() < 0.25:
		var celda := suelo.local_to_map(suelo.to_local(pan.global_position))
		if suelo.get_cell_atlas_coords(celda) in _coords_brasa:
			_quemadura_brasa()
	if not pisando_pasto():
		return
	if Juego.pasos_sin_encuentro > 0:
		Juego.pasos_sin_encuentro -= 1
		return
	for zona in get_tree().get_nodes_in_group("zonas_encuentro"):
		if not zona.contiene(pan.global_position):
			continue
		if not Juego.hay_cartas_vivas():
			if not _aviso_sin_cartas:
				_aviso_sin_cartas = true
				correr(hud.decir.bind("sin_cartas_vivas"))
			return
		if randf() < zona.probabilidad * (1.6 if Juego.tormenta else 1.0):
			correr(iniciar_combate.bind(zona.elegir_encuentro()))
		return


func iniciar_combate(datos: Dictionary) -> void:
	ocupado = true
	pan.puede_moverse = false
	Juego.posicion_pan = pan.global_position
	Juego.encuentro = datos
	Sonido.efecto("alerta")
	var t := create_tween()
	for i in 2:
		t.tween_property(hud.transicion, "color", Color(1, 1, 1, 0.8), 0.07)
		t.tween_property(hud.transicion, "color", Color(1, 1, 1, 0.0), 0.07)
	t.tween_property(hud.transicion, "color", Color(0, 0, 0, 1), 0.3)
	await t.finished
	Juego.cambiar_escena(ESCENA_COMBATE)


## Empuja a Pan un poco hacia atrás (para caminos bloqueados).
func retroceder_pan(direccion: Vector2, distancia := 12.0) -> void:
	var t := create_tween()
	t.tween_property(pan, "global_position", pan.global_position + direccion * distancia, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished


## Una gota de ácido del techo cayó sobre Pan (scripts/gotera.gd): la carta del frente pierde un poco de vida.
func gota_de_acido() -> void:
	var i := Juego.carta_al_frente()
	if i < 0:
		hud.mostrar_aviso("¡Una gota de ácido! Pan se cubre con la capucha.")
		return
	var carta: Dictionary = Juego.mochila[i]
	var danio := mini(carta["hp"] - 1, maxi(1, Juego.hp_max_carta(carta) / 16))
	carta["hp"] -= maxi(0, danio)
	var nombre: String = Juego.criaturas[carta["id"]]["nombre"]
	var aviso := "¡Gota de ácido! %s pierde %d de vida." % [nombre, danio] if danio > 0 else "¡Gota de ácido! %s está muy débil, pero aguanta." % nombre
	hud.mostrar_aviso(aviso)
	var t := create_tween()
	t.tween_property(pan, "modulate", Color(0.6, 1.0, 0.5), 0.1)
	t.tween_property(pan, "modulate", Color.WHITE, 0.3)


## Pan pisó una brasa: la carta del frente pierde 1/20 de su vida (nunca se rompe por esto).
func _quemadura_brasa() -> void:
	var i := Juego.carta_al_frente()
	if i < 0:
		return
	var carta: Dictionary = Juego.mochila[i]
	var danio := mini(carta["hp"] - 1, maxi(1, Juego.hp_max_carta(carta) / 20))
	if danio <= 0:
		return
	carta["hp"] -= danio
	Sonido.efecto("quemar", 1.3, -6.0)
	hud.mostrar_aviso("¡Una brasa escondida! %s se quema y pierde %d de vida." % [Juego.criaturas[carta["id"]]["nombre"], danio])
	var t := create_tween()
	t.tween_property(pan, "modulate", Color(1.0, 0.55, 0.35), 0.1)
	t.tween_property(pan, "modulate", Color.WHITE, 0.3)
