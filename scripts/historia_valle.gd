extends RefCounted
## CIUDAD 4: el Bosque Calcinado y Valle Ceniza (Kael, El Escudo Roto).
## Lo llama scripts/historia.gd (al entrar a estos mapas, en sus eventos y después de sus combates).
## Los TEXTOS están en datos/dialogos.json.
##
## Bosque Calcinado (salida norte de Ciudad Neón):
##   - Ceniza que cae como nieve y brasas escondidas que queman a la carta del frente.
##   - Brotes verdes para la misión de Lucía. Un recaudador de la Organización va a cobrarle al valle.
## Valle Ceniza ("La Excepción"):
##   - La gente AMA a Kael: caza para ellos y recibe los castigos de la Organización en silencio.
##     Nadie le pide ayuda a Pan: le piden que se vaya y que no le haga daño a Kael.
##   - La abuela Nita te da la cama gratis. Misión de Lucía (brotes). La olla común.
##   - Kael espera en el monumento a los caídos. Al perder, llora y suplica por su vida.
##   - LA DECISIÓN: primer plano del rostro de Pan. Perdonarlo o ejecutarlo.
##       Perdonar: Kael cuenta la verdad sobre mis padres y entrega los Códigos de la Capital,
##                 el Mapa de Debilidades del Líder y una grabación de mis padres.
##       Ejecutar: pantalla a negro (sin violencia en pantalla), botín por la fuerza, monólogo oscuro.
##                 El valle se vuelve frío y Pan tiene que buscar solo lo que Kael escondía (3 pistas).
##     Banderas: "kael_perdonado" o "kael_ejecutado" (los finales del juego dependen de esto).

const CERCA := "res://arte/cinematica/pan_cerca.png"
const CERCA_PIEDAD := "res://arte/cinematica/pan_cerca_piedad.png"
const CERCA_SOMBRA := "res://arte/cinematica/pan_cerca_sombra.png"
const PISTAS := ["pista_cabana", "pista_monumento", "pista_puesto"]
const BROTES := ["Brote1", "Brote2", "Brote3"]

var h: Node   # el autoload Historia


func _init(historia: Node) -> void:
	h = historia


func decir(id) -> void:
	await h.decir(id)


## Dice el diálogo según lo que pasó con Kael: "<id>_perdon", "<id>_ejecutado" o "<id>".
func _segun_kael(id: String) -> void:
	for sufijo in [["kael_perdonado", "_perdon"], ["kael_ejecutado", "_ejecutado"]]:
		if Juego.flag(sufijo[0]) and Juego.dialogos.has(id + sufijo[1]):
			await decir(id + sufijo[1])
			return
	await decir(id)


func _proxima_version() -> String:
	return "Valle Ceniza quedó atrás. Próximo destino: la Fortaleza de Hierro (llegará en una próxima versión)."


# ---------------------------------------------------------------------------
# Al entrar a los mapas
# ---------------------------------------------------------------------------

func al_entrar_mapa(nombre: String) -> void:
	match nombre:
		"bosque_calcinado":
			if not Juego.flag("bosque_visitado"):
				Juego.flags["bosque_visitado"] = true
				await decir("bosque_llegada")
				if not Juego.flag("valle_visitado"):
					h.poner_mision("Cruza el Bosque Calcinado hacia el este, hasta Valle Ceniza.")
		"valle_ceniza":
			if not Juego.flag("valle_visitado"):
				await _llegada_valle()


func _llegada_valle() -> void:
	Juego.flags["valle_visitado"] = true
	Juego.lugar_descanso = { "mapa": h.VALLE, "entrada": "Cama" }
	await decir("valle_llegada")
	await h.mapa.pan.caminar_a(h._px(26.5, 27))
	await h.mapa.pan.caminar_a(h._px(26.5, 23.2))
	# Kael baja del bosque con la caza del día y la deja en la olla común
	Juego.flags["kael_en_escena"] = true
	h.mapa.refrescar()
	var kael: Node2D = h._nodo("KaelEscena")
	h.mapa.pan.mirar_a(h._px(26.5, 10))
	await decir("valle_kael_baja")
	if kael:
		await h._caminar_npc(kael, h._px(26.5, 16.5), 40.0)
		await h._caminar_npc(kael, h._px(25.2, 19.2), 40.0)
	await decir("valle_kael_olla")
	if kael:
		await h._caminar_npc(kael, h._px(26.5, 21.6), 35.0)
		h.mapa.pan.mirar_a(kael.position)
	await decir("valle_kael_collar")
	# Se va hacia el monumento
	if kael:
		await h._caminar_npc(kael, h._px(26.5, 16), 45.0)
		var t: Tween = h.mapa.create_tween()
		t.tween_property(kael, "modulate:a", 0.0, 0.5)
		await t.finished
	Juego.flags["kael_en_escena"] = false
	Juego.flags["kael_en_monumento"] = true
	h.mapa.refrescar()
	if kael:
		kael.modulate.a = 1.0
		kael.position = h._px(26.5, 4)
	await decir("valle_nita_llegada")
	h.poner_mision("Habla con la gente del valle. Kael te espera en el monumento a los caídos (noreste).")
	Juego.guardar_pronto = true


# ---------------------------------------------------------------------------
# Eventos. Devuelve false si el evento no es de esta ciudad.
# ---------------------------------------------------------------------------

func ejecutar(evento: String, nodo: Node) -> bool:
	match evento:
		# --- Bosque Calcinado ---
		"salida_bosque_oeste":
			await h.mapa.hud.fundido(true, 0.4)
			Juego.ir_a_mapa(h.NEON, "Norte")
		"entrar_valle":
			await h.mapa.hud.fundido(true, 0.4)
			Juego.ir_a_mapa(h.VALLE, "Sur")
		"brote":
			await _brote(nodo)
		"inv_trampa":
			await decir("inv_trampa")
		"recaudador", "paso_recaudador":
			await _recaudador()

		# --- Valle Ceniza ---
		"salida_valle_sur":
			await h.mapa.hud.fundido(true, 0.4)
			Juego.ir_a_mapa(h.BOSQUE, "Este")
		"salida_valle_norte":
			if Juego.flag("kael_perdonado") or Juego.flag("kael_ejecutado"):
				await decir("valle_norte")
			else:
				await decir("valle_norte_antes")
			await h.mapa.retroceder_pan(Vector2.DOWN, 18.0)
		"cama_valle":
			Juego.lugar_descanso = { "mapa": h.VALLE, "entrada": "Cama" }
			if Juego.flag("kael_ejecutado"):
				await h._dormir("cama_valle_ejecutado")
			elif Juego.flag("kael_perdonado"):
				await h._dormir("cama_valle_perdon")
			else:
				await h._dormir("cama_valle")
		"tienda_valle":
			if not Juego.flag("hablo_hugo"):
				Juego.flags["hablo_hugo"] = true
				await decir("hugo")
			elif Juego.flag("kael_ejecutado") or Juego.flag("kael_perdonado"):
				await _segun_kael("hugo_vuelve")
			await h.mapa.hud.abrir_tienda("Despensa de Hugo", load("res://scripts/tienda_ui.gd").SURTIDO_VALLE)
		"olla_comun":
			await _olla()
		"lucia":
			await _lucia()
		"nita", "cocinera", "nina_valle", "aldeano_valle", "aldeana_valle", "ramiro", "ana", "teo", \
		"inv_invernadero", "inv_monumento", "inv_puesto_caza":
			await _segun_kael(evento)
		"kael":
			await _kael()
		"kael_perdonado":
			await decir("kael_perdonado_charla")
		"pista_cabana", "pista_monumento", "pista_puesto":
			await _pista(evento)
		"escuchar_grabacion":
			await decir("escuchar_grabacion")
		_:
			return false
	return true


func despues_de_combate(evento: String, resultado: String) -> bool:
	match evento:
		"recaudador":
			if resultado == "victoria":
				Juego.flags["recaudador_derrotado"] = true
				h.mapa.refrescar()
				await decir("recaudador_derrotado")
		"kael":
			if resultado == "victoria":
				await _piedad()
		_:
			return false
	return true


# ---------------------------------------------------------------------------
# Bosque Calcinado
# ---------------------------------------------------------------------------

func _brotes_juntados() -> int:
	var n := 0
	for b in BROTES:
		if Juego.flag("brote_" + b):
			n += 1
	return n


func _mision_lucia() -> String:
	return "Brotes para Lucía: junta 3 brotes verdes en el Bosque Calcinado (%d/3)." % _brotes_juntados()


func _brote(nodo: Node) -> void:
	if nodo == null:
		return
	Juego.flags["brote_" + str(nodo.name)] = true
	Sonido.efecto("objeto")
	h.mapa.refrescar()
	await decir("brote")
	if Juego.mision_activa("brotes_lucia"):
		Juego.misiones["brotes_lucia"]["titulo"] = _mision_lucia()
	await decir([{ "quien": "", "texto": "Brotes juntados: %d de 3." % _brotes_juntados() }])


## El recaudador de la Organización va al valle a cobrar la cuota (y amenaza con quemar el invernadero).
func _recaudador() -> void:
	if Juego.flag("recaudador_derrotado"):
		return
	Sonido.efecto("alerta")
	var r: Node2D = h._nodo("Recaudador")
	if r:
		h.mapa.pan.mirar_a(r.position)
	await decir("recaudador")
	if not Juego.hay_cartas_vivas():
		await decir("sin_cartas_pelea")
		await h.mapa.retroceder_pan(Vector2.LEFT, 18.0)
		return
	await h.mapa.iniciar_combate({
		"tipo": "entrenador",
		"evento": "recaudador",
		"fondo": "bosque",
		"tactico": true,
		"curas": 1,
		"potenciadores": 1,
		"intervencion": "molotov",
		"intervencion_cada": 3,
		"botin": { "monedas": 120, "reliquias": 3 },
		"entrenador": { "nombre": "Recaudador Grieta", "sprite": "res://arte/personajes/recaudador_combate.png" },
		"equipo": [{ "id": "humanoide_sin_consciencia", "nivel": 4 }, { "id": "bestia_blindada", "nivel": 4 },
			{ "id": "lobo_de_ceniza", "nivel": 5 }],
		"frases": {
			"inicio": "¿Me vas a cobrar tú a mí? ¡Ja! ¡A trabajar, bestias!",
			"golpe": "¡Eso! ¡Cuota pagada!",
			"pierde": "Inútil... ¡el siguiente!",
			"derrota": "¡Ya, ya! ¡Me voy! ¡Me voy!",
		},
	})


# ---------------------------------------------------------------------------
# Valle Ceniza
# ---------------------------------------------------------------------------

## La olla común: una vez, la cocinera te sirve un plato caliente (cura a todas tus cartas).
func _olla() -> void:
	if Juego.flag("kael_ejecutado"):
		await decir("olla_comun_ejecutado")
		return
	if Juego.flag("comio_olla"):
		await decir("olla_comun_despues")
		return
	Juego.flags["comio_olla"] = true
	await decir("olla_comun")
	Juego.dormir()
	Sonido.efecto("curar")
	await decir([{ "quien": "", "texto": "Tus cartas comieron guiso caliente. ¡Recuperaron toda su vida!" }])


## "Brotes para Lucía": 3 brotes del bosque para el invernadero -> 2 Curas 80% y 2 Piñas en lata.
func _lucia() -> void:
	if Juego.mision_completa("brotes_lucia"):
		await _segun_kael("lucia_despues")
		return
	if not Juego.mision_activa("brotes_lucia"):
		await _segun_kael("lucia_pide")
		Juego.empezar_mision("brotes_lucia", _mision_lucia())
		h.mapa.hud.mostrar_aviso("Nueva misión: Brotes para Lucía")
		if _brotes_juntados() < 3:
			return
	if _brotes_juntados() < 3:
		await decir("lucia_espera")
		await decir([{ "quien": "", "texto": "(Llevas %d de 3 brotes.)" % _brotes_juntados() }])
		return
	Juego.completar_mision("brotes_lucia")
	Juego.dar_objeto("cura_80", 2)
	Juego.dar_objeto("racion", 2)
	Sonido.efecto("objeto")
	await _segun_kael("lucia_gracias")
	await decir([{ "quien": "", "texto": "Lucía te dio 2 Curas 80% y 2 Piñas en lata." }])


func _kael() -> void:
	if Juego.flag("kael_derrotado"):
		return
	var kael: Node2D = h._nodo("Kael")
	if kael:
		h.mapa.pan.mirar_a(kael.position)
	if not Juego.flag("kael_hablo"):
		Juego.flags["kael_hablo"] = true
		await decir("kael_reto")
	else:
		await decir("kael_reto_otra")
	if not Juego.hay_cartas_vivas():
		await decir("sin_cartas_pelea")
		await h.mapa.retroceder_pan(Vector2.DOWN, 18.0)
		return
	await _pelear_con_kael()


func _pelear_con_kael() -> void:
	await h.mapa.iniciar_combate({
		"tipo": "entrenador",
		"evento": "kael",
		"fondo": "valle",
		"musica": "kael",
		"comandante": true,
		"postura_defensiva": true,
		"piedad": true,
		"tactico": true,
		"curas": 2,
		"entrenador": { "nombre": "Kael", "sprite": "res://arte/personajes/kael_combate.png",
			"sprite_rodillas": "res://arte/personajes/kael_rodillas_combate.png" },
		"equipo": [
			{ "id": "humanoide_sin_consciencia", "nivel": 5, "bloquea_curas": 0.35 },
			{ "id": "humanoide_sin_consciencia", "nivel": 5, "bloquea_curas": 0.35 },
			{ "id": "bestia_blindada", "nivel": 6 },
			{ "id": "vigilante_ciego", "nivel": 6 },
		],
		"frases": {
			"inicio": "No quiero hacer esto, chico. Mis bestias solo se van a defender.",
			"golpe": "Lo siento... de verdad.",
			"pierde": "Aguanta, amigo. Aguanta un poco más.",
			"ultima": ["Perdóname...", "Vigilante. Sal. Que la justicia sea ciega."],
			"rendicion": ["La música se detiene.", "Kael cae de rodillas y suelta su lanza.", "Kael: \"Basta... basta, por favor...\""],
		},
	})


## EL EVENTO DE PIEDAD: Kael llora y suplica. Primer plano de Pan y la decisión.
func _piedad() -> void:
	Juego.flags["kael_derrotado"] = true
	Juego.flags["kael_rodillas"] = true
	Sonido.musica("")
	h.mapa.refrescar()
	var rodillas: Node2D = h._nodo("KaelRodillas")
	if rodillas:
		h.mapa.pan.mirar_a(rodillas.position)
	await h.mapa.get_tree().create_timer(0.6).timeout
	Sonido.efecto("llanto")
	await decir("kael_suplica")
	# Primer plano del rostro de Pan: sus ojos verdes y el aro de mariposa
	await h.mapa.hud.mostrar_primer_plano(CERCA, 1.0)
	await decir("kael_decision_pan")
	var opcion: int = await h.mapa.hud.elegir("¿Qué hace Pan con Kael?", ["Perdonarlo", "Ejecutarlo"], true)
	if opcion == 0:
		await _perdonar(rodillas)
	else:
		await _ejecutar(rodillas)
	Juego.guardar_pronto = true


func _perdonar(rodillas: Node2D) -> void:
	await h.mapa.hud.mostrar_primer_plano(CERCA_PIEDAD, 0.8)   # los ojos de Pan se suavizan
	await decir("kael_perdon_pan")
	await h.mapa.hud.ocultar_primer_plano()
	Juego.flags["kael_perdonado"] = true
	# Kael se levanta
	if rodillas:
		rodillas.textura = Juego.textura("res://arte/personajes/kael_mapa.png")
	await decir("kael_verdad")
	Juego.dar_objeto("codigos_capital", 1)
	Juego.dar_objeto("mapa_debilidades", 1)
	Juego.dar_objeto("grabacion_padres", 1)
	Sonido.efecto("objeto")
	await decir([{ "quien": "", "texto": "Recibiste los Códigos de la Capital, el Mapa de Debilidades del Líder y la Grabación de tus padres." }])
	await decir("kael_grabacion")
	await decir("escuchar_grabacion")
	await decir("kael_despues_grabacion")
	await _celebracion_valle()


func _ejecutar(rodillas: Node2D) -> void:
	await h.mapa.hud.mostrar_primer_plano(CERCA_SOMBRA, 1.2)   # la sombra del pelo tapa sus ojos
	await decir("kael_ejecutar_pan")
	h.mapa.hud.ocultar_primer_plano(1.4)
	await h.mapa.hud.fundido(true, 1.4)
	await h.mapa.get_tree().create_timer(1.2).timeout
	await decir("kael_ejecutado_negro")
	Juego.flags["kael_ejecutado"] = true
	Juego.flags["kael_rodillas"] = false
	Juego.flags["kael_en_monumento"] = false
	Juego.flags["valle_liberado"] = true
	if rodillas:
		rodillas.visible = false
	h.mapa.refrescar()
	h.mapa.actualizar_ambiente(0.1)
	# El botín, por la fuerza
	Juego.monedas += 250
	Juego.chatarra += 5
	Juego.bonus_ataque += 0.10
	Juego.dormir()
	await h.mapa.get_tree().create_timer(0.8).timeout
	await h.mapa.hud.fundido(false, 1.2)
	await decir("kael_ejecutado_monologo")
	await decir([{ "quien": "", "texto": "Obtuviste 250 monedas y 5 Reliquias del Viejo Mundo. Una fuerza fría sube el ataque de tus criaturas un 10%." }])
	await decir("valle_reaccion_ejecutado")
	h.poner_mision(_mision_pistas())


func _pistas_encontradas() -> int:
	var n := 0
	for p in PISTAS:
		if Juego.flag(p):
			n += 1
	return n


func _mision_pistas() -> String:
	return "Busca lo que Kael escondía: su cabaña, el monumento y su puesto de caza (%d/3)." % _pistas_encontradas()


## Si ejecutaste a Kael, Pan tiene que encontrar solo lo que Kael le habría dado.
func _pista(evento: String) -> void:
	if Juego.flag(evento):
		return
	Juego.flags[evento] = true
	h.mapa.refrescar()
	Sonido.efecto("objeto")
	await decir(evento)
	match evento:
		"pista_cabana":
			Juego.dar_objeto("grabacion_padres", 1)
			await decir([{ "quien": "", "texto": "Encontraste la Grabación de tus padres." }])
			await decir("escuchar_grabacion")
			await decir("pista_grabacion_despues")
		"pista_monumento":
			Juego.dar_objeto("codigos_capital", 1)
			await decir([{ "quien": "", "texto": "Encontraste los Códigos de la Capital." }])
		"pista_puesto":
			Juego.dar_objeto("mapa_debilidades", 1)
			await decir([{ "quien": "", "texto": "Encontraste el Mapa de Debilidades del Líder." }])
	if _pistas_encontradas() >= 3:
		await decir("pistas_completas")
		h.poner_mision(_proxima_version())
	else:
		h.poner_mision(_mision_pistas())


const MULTITUD_VALLE := ["nita_mapa", "lucia_mapa", "hugo_mapa", "ana_mapa", "teo_mapa", "ramiro_mapa",
	"aldeano_mapa", "aldeana_mapa", "nina_valle_mapa", "aldeano_mapa", "aldeana_mapa", "aldeano_mapa",
	"aldeana_mapa", "aldeano_mapa", "aldeana_mapa", "aldeano_mapa"]


## Perdonaste a Kael: el valle entero sale a la plaza (y Kael con ellos).
func _celebracion_valle() -> void:
	await h.mapa.hud.fundido(true, 0.6)
	Juego.flags["kael_rodillas"] = false
	Juego.flags["kael_en_monumento"] = false
	Juego.flags["valle_liberado"] = true
	h.poner_mision("¡Valle Ceniza está en paz!")
	h.mapa.refrescar()
	var vecinos := ["Nita", "Lucia", "Ana", "Teo", "Ramiro", "Cocinera", "NinaValle", "Aldeano", "Aldeana"]
	var ocultos: Array = []
	for n in vecinos:
		var v: Node2D = h._nodo(n)
		if v and v.visible:
			v.visible = false
			ocultos.append(v)
	var centro: Vector2 = h._px(26.5, 20.5)
	h.mapa.pan.global_position = centro
	h.mapa.pan.mirar_a(centro + Vector2.DOWN)
	h.mapa.pan.get_node("Camara").reset_smoothing()
	var gente: Array = h._armar_multitud(centro, MULTITUD_VALLE)
	await h.mapa.get_tree().create_timer(0.2).timeout
	h.mapa.hud.fundido(false, 0.6)
	var t: Tween = h.mapa.create_tween().set_parallel()
	for p in gente:
		t.tween_property(p, "position", p.get_meta("destino"), randf_range(1.0, 1.6)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished
	h._aplaudir(gente)
	await decir("celebracion_valle")
	Juego.bonus_ataque += 0.10
	Juego.monedas += 120
	Juego.dar_objeto("cura_80", 2)
	Juego.dar_objeto("racion", 2)
	Juego.dormir()
	Sonido.efecto("objeto")
	await decir("celebracion_valle_fuerzas")
	h._parar_aplausos()
	await h.mapa.hud.fundido(true, 0.6)
	for p in gente:
		p.queue_free()
	for v in ocultos:
		v.visible = true
	h.mapa.refrescar()
	h.mapa.actualizar_ambiente(0.1)
	Juego.lugar_descanso = { "mapa": h.VALLE, "entrada": "Cama" }
	await h.mapa.hud.fundido(false, 0.6)
	await decir("valle_libre")
	h.poner_mision(_proxima_version())
