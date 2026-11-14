extends RefCounted
## CIUDAD 3: el Paso del Smog y Ciudad Neón (Silas, El Ilusionista).
## Lo llama scripts/historia.gd (al entrar a estos mapas, en sus eventos y después de sus combates).
## Los TEXTOS están en datos/dialogos.json.
##
## Paso del Smog (salida este del Sumidero):
##   - La "nube de gas" del camino es una película de luz (un proyector): el aire se puede respirar.
##   - Leo, un pedalero que escapó, te pide llevarle una carta a su hermana Mara ("La carta de Leo").
##   - Un patrullero de Silas cuida la entrada de la ciudad.
## Ciudad Neón:
##   - Siempre es de noche. Los ciudadanos pedalean 16 horas al día en los generadores y creen que el
##     aire de afuera mata. Sonríen a la fuerza porque Silas tiene micrófonos por todas partes.
##   - Misiones: el turno de Tobi (pedalear), los micrófonos de Rina (Visor Polarizado) y la carta de Leo.
##   - Dos guardias cuidan el escenario del Palacio Lumen; luego Silas y la ilusión de mis padres.
##   - Al ganar: las luces se apagan, la gente respira el aire de afuera y se abre la puerta norte.

var h: Node   # el autoload Historia


func _init(historia: Node) -> void:
	h = historia


func decir(id) -> void:
	await h.decir(id)


func _libre(id: String) -> void:
	await h._decir_libre(id, "neon_liberado")


# ---------------------------------------------------------------------------
# Al entrar a los mapas
# ---------------------------------------------------------------------------

func al_entrar_mapa(nombre: String) -> void:
	match nombre:
		"paso_smog":
			if not Juego.flag("smog_visitado"):
				Juego.flags["smog_visitado"] = true
				await decir("smog_llegada")
				if not Juego.flag("neon_visitado"):
					h.poner_mision("Cruza el Paso del Smog hacia el este, hasta Ciudad Neón.")
		"ciudad_neon":
			if not Juego.flag("neon_visitado"):
				await _llegada_neon()


func _llegada_neon() -> void:
	Juego.flags["neon_visitado"] = true
	Juego.lugar_descanso = { "mapa": h.NEON, "entrada": "Motel" }
	await decir("neon_llegada")
	await h.mapa.pan.caminar_a(h._px(27.5, 33))
	var pedalero: Node2D = h._nodo("Pedalero1")
	if pedalero:
		h.mapa.pan.mirar_a(pedalero.position)
	await decir("neon_pedalero")
	await decir("neon_pan")
	h.poner_mision("Vence a los guardias del Palacio Lumen (noreste) y enfrenta a Silas.")


# ---------------------------------------------------------------------------
# Eventos. Devuelve false si el evento no es de esta ciudad.
# ---------------------------------------------------------------------------

func ejecutar(evento: String, nodo: Node) -> bool:
	match evento:
		# --- Paso del Smog ---
		"salida_smog_oeste":
			await h.mapa.hud.fundido(true, 0.4)
			Juego.ir_a_mapa(h.SUMIDERO, "Este")
		"entrar_neon":
			await h.mapa.hud.fundido(true, 0.4)
			Juego.ir_a_mapa(h.NEON, "Sur")
		"gas_falso":
			if Juego.flag("gas_falso_visto") or Juego.flag("neon_liberado"):
				return true
			Juego.flags["gas_falso_visto"] = true
			Sonido.efecto("alerta", 0.8)
			await decir("gas_falso")
		"inv_proyector":
			if not Juego.flag("neon_liberado"):
				Juego.flags["gas_falso_visto"] = true
			await _libre("inv_proyector")
		"inv_letrero_aire":
			await _libre("inv_letrero_aire")
		"leo":
			await _leo()
		"patrullero", "paso_patrullero":
			await _patrullero()

		# --- Ciudad Neón ---
		"salida_neon_sur":
			await h.mapa.hud.fundido(true, 0.4)
			Juego.ir_a_mapa(h.PASO_SMOG, "Este")
		"salida_neon_norte":
			if not Juego.flag("neon_liberado"):
				await decir("puerta_norte_cerrada")
				await h.mapa.retroceder_pan(Vector2.DOWN, 16.0)
				return true
			await h.mapa.hud.fundido(true, 0.4)
			Juego.ir_a_mapa(h.BOSQUE, "Oeste")
		"tienda_neon":
			if not Juego.flag("hablo_coral"):
				Juego.flags["hablo_coral"] = true
				await decir("coral")
			elif Juego.flag("neon_liberado") and not Juego.flag("coral_libre_visto"):
				Juego.flags["coral_libre_visto"] = true
				await decir("coral_libre")
			await h.mapa.hud.abrir_tienda("Neones de Coral", load("res://scripts/tienda_ui.gd").SURTIDO_NEON)
		"cama_neon":
			Juego.lugar_descanso = { "mapa": h.NEON, "entrada": "Motel" }
			if Juego.flag("neon_liberado"):
				await h._dormir("cama_neon_gratis")
			elif Juego.monedas >= 10:
				Juego.monedas -= 10
				await h._dormir("cama_neon")
			else:
				await h._dormir("cama_neon_fiada")
		"tobi":
			await _tobi()
		"mama_tobi", "pedalero", "vigia_neon", "ciro", "bar_comodin", "leo_neon", \
		"inv_generador", "inv_holograma", "inv_torre", "inv_casino", "inv_arcade", "inv_letrero_neon":
			await _libre(evento)
		"rina":
			await _rina()
		"microfono":
			await _microfono(nodo)
		"mara":
			await _mara()
		"guardia_neon_1", "guardia_neon_2":
			await _guardia_neon(evento)
		"paso_escenario":
			if Juego.flag("neon_liberado") or Juego.flag("guardia_neon_2_derrotado"):
				return true
			await _guardia_neon("guardia_neon_2" if Juego.flag("guardia_neon_1_derrotado") else "guardia_neon_1", true)
		"silas":
			await _silas()
		_:
			return false
	return true


func despues_de_combate(evento: String, resultado: String) -> bool:
	match evento:
		"patrullero":
			if resultado == "victoria":
				Juego.flags["patrullero_derrotado"] = true
				h.mapa.refrescar()
				await decir("patrullero_derrotado")
		"guardia_neon_1", "guardia_neon_2":
			if resultado == "victoria":
				Juego.flags[evento + "_derrotado"] = true
				h.mapa.refrescar()
				await decir(evento + "_derrotado")
				await _guardias_vencidos()
		"silas":
			if resultado == "victoria":
				await _victoria_silas()
		_:
			return false
	return true


# ---------------------------------------------------------------------------
# Paso del Smog
# ---------------------------------------------------------------------------

## "La carta de Leo": Leo escapó de los pedales y cree que el aire lo va a matar.
func _leo() -> void:
	if Juego.mision_completa("carta_leo"):
		await decir("leo_despues")
		return
	if Juego.mision_activa("carta_leo"):
		await decir("leo_espera")
		return
	await decir("leo_pide")
	Juego.dar_objeto("carta_leo", 1)
	Sonido.efecto("objeto")
	Juego.empezar_mision("carta_leo", "La carta de Leo: llévale la carta a su hermana Mara (Ciudad Neón, cerca del bar).")
	h.mapa.hud.mostrar_aviso("Nueva misión: La carta de Leo")
	await decir([{ "quien": "", "texto": "Recibiste la Carta de Leo." }])


## El patrullero de Silas cuida la entrada de Ciudad Neón.
func _patrullero() -> void:
	if Juego.flag("patrullero_derrotado"):
		return
	Sonido.efecto("alerta")
	var p: Node2D = h._nodo("Patrullero")
	if p:
		h.mapa.pan.mirar_a(p.position)
	await decir("patrullero")
	if not Juego.hay_cartas_vivas():
		await decir("sin_cartas_pelea")
		await h.mapa.retroceder_pan(Vector2.LEFT, 18.0)
		return
	await h.mapa.iniciar_combate({
		"tipo": "entrenador",
		"evento": "patrullero",
		"fondo": "smog",
		"tactico": true,
		"curas": 1,
		"botin": { "monedas": 80, "reliquias": 2 },
		"entrenador": { "nombre": "Patrullero Brillo", "sprite": "res://arte/personajes/guardia_org_combate.png" },
		"equipo": [{ "id": "espectro_sonico", "nivel": 3 }, { "id": "caballero_de_neon", "nivel": 3 }],
		"frases": {
			"inicio": "¡Nadie sale de Ciudad Neón! ¡Y nadie entra sin sonreír!",
			"golpe": "¡Sonríe, que te están grabando!",
			"derrota": "¡Ay! Silas me va a cortar la luz...",
		},
	})


# ---------------------------------------------------------------------------
# Ciudad Neón
# ---------------------------------------------------------------------------

## El turno de Tobi: su mamá se desmayó en el pedal y él pedalea por ella.
func _tobi() -> void:
	if Juego.flag("turno_tobi"):
		await _libre("tobi_despues")
		return
	if Juego.flag("neon_liberado"):
		await decir("tobi_libre")
		return
	await decir("tobi_pide")
	var opcion: int = await h.mapa.hud.elegir("¿Pedaleas el turno de la mamá de Tobi?", ["Sí, yo pedaleo", "Ahora no"])
	if opcion != 0:
		await decir("tobi_no")
		return
	await decir("tobi_pedal_empieza")
	var vueltas := 6
	for i in vueltas:
		var barra := "[" + "#".repeat(i) + "-".repeat(vueltas - i) + "]"
		var frases := ["¡Pedalear!", "¡Más fuerte!", "¡Sigue!", "¡No pares!", "¡Ya casi!", "¡Última vuelta!"]
		await h.mapa.hud.elegir("Generador: %s" % barra, [frases[i]])
		Sonido.efecto("pedal", 1.0 + i * 0.06)
		await h._temblor(0.15)
	Sonido.efecto("objeto")
	await h.mapa.hud.fundido(true, 0.5)
	Juego.flags["turno_tobi"] = true
	h.mapa.refrescar()
	await h.mapa.hud.fundido(false, 0.5)
	await decir("tobi_gracias")
	Juego.dar_objeto("granada_luz", 2)
	await decir([{ "quien": "", "texto": "La mamá de Tobi te dio 2 Granadas de Luz." }])


## "Los micrófonos de Rina": 3 micrófonos escondidos de Silas -> Visor Polarizado.
const MICROFONOS := ["Microfono1", "Microfono2", "Microfono3"]


func _microfonos_encontrados() -> int:
	var n := 0
	for m in MICROFONOS:
		if Juego.flag("mic_" + m):
			n += 1
	return n


func _mision_rina() -> String:
	return "Los micrófonos de Rina: encuentra los 3 micrófonos de Silas (%d/3)." % _microfonos_encontrados()


func _rina() -> void:
	if Juego.mision_completa("microfonos_rina"):
		await _libre("rina_despues")
		return
	if not Juego.mision_activa("microfonos_rina"):
		await decir("rina_pide")
		Juego.empezar_mision("microfonos_rina", _mision_rina())
		h.mapa.hud.mostrar_aviso("Nueva misión: Los micrófonos de Rina")
		if _microfonos_encontrados() < 3:
			return
	if _microfonos_encontrados() < 3:
		await decir("rina_espera")
		await decir([{ "quien": "", "texto": "(Llevas %d de 3 micrófonos.)" % _microfonos_encontrados() }])
		return
	Juego.completar_mision("microfonos_rina")
	Juego.dar_objeto("visor_polarizado", 1)
	Sonido.efecto("objeto")
	await decir("rina_gracias")
	await decir([{ "quien": "", "texto": "Recibiste el Visor Polarizado. Contra el Juego de Luces de Silas, tus criaturas fallan mucho menos." }])


func _microfono(nodo: Node) -> void:
	if nodo == null:
		return
	Juego.flags["mic_" + str(nodo.name)] = true
	Sonido.efecto("metal", 1.4)
	h.mapa.refrescar()
	await decir("microfono")
	if Juego.mision_activa("microfonos_rina"):
		Juego.misiones["microfonos_rina"]["titulo"] = _mision_rina()
	await decir([{ "quien": "", "texto": "Micrófonos encontrados: %d de 3." % _microfonos_encontrados() }])


## Mara, la hermana de Leo. Si le llevas la carta, Leo vuelve cuando la ciudad sea libre.
func _mara() -> void:
	if Juego.objetos.get("carta_leo", 0) > 0 and Juego.mision_activa("carta_leo"):
		Juego.objetos["carta_leo"] = 0
		Juego.completar_mision("carta_leo")
		Juego.dar_objeto("carta_vinculo", 3)
		Juego.dar_objeto("cura_80", 1)
		Sonido.efecto("objeto")
		await decir("mara_carta")
		await decir([{ "quien": "", "texto": "Mara te dio 3 Cartas de Vínculo y una Cura 80%." }])
		if Juego.flag("neon_liberado"):
			Juego.flags["leo_en_neon"] = true
			h.mapa.refrescar()
			await decir("mara_leo_vuelve")
		return
	if Juego.mision_completa("carta_leo"):
		if Juego.flag("leo_en_neon"):
			await decir("mara_con_leo")
		else:
			await decir("mara_espera_leo")
		return
	await _libre("mara")


## Los dos guardias del escenario del Palacio Lumen.
func _guardia_neon(evento: String, al_pasar := false) -> void:
	if Juego.flag(evento + "_derrotado") or Juego.flag("neon_liberado"):
		return
	Sonido.efecto("alerta")
	var guardia: Node2D = h._nodo("GuardiaNeon1" if evento == "guardia_neon_1" else "GuardiaNeon2")
	if guardia:
		h.mapa.pan.mirar_a(guardia.position)
	if al_pasar:
		await decir("paso_escenario")
	await decir(evento)
	if not Juego.hay_cartas_vivas():
		await decir("sin_cartas_pelea")
		await h.mapa.retroceder_pan(Vector2.DOWN, 18.0)
		return
	var datos := {
		"tipo": "entrenador",
		"evento": evento,
		"fondo": "neon",
		"tactico": true,
		"curas": 1,
	}
	if evento == "guardia_neon_1":
		datos["potenciadores"] = 1
		datos["botin"] = { "monedas": 90, "reliquias": 2 }
		datos["entrenador"] = { "nombre": "Guardia Destello", "sprite": "res://arte/personajes/guardia_org_combate.png" }
		datos["equipo"] = [{ "id": "caballero_de_neon", "nivel": 3 }, { "id": "bailarina_electrica", "nivel": 3 }]
		datos["frases"] = { "inicio": "¡El show de Silas no se interrumpe!", "golpe": "¡Aplausos, por favor!",
			"derrota": "Se... se me cayó la sonrisa." }
	else:
		datos["potenciadores"] = 2
		datos["intervencion"] = "molotov"
		datos["intervencion_cada"] = 4
		datos["botin"] = { "monedas": 110, "reliquias": 3 }
		datos["entrenador"] = { "nombre": "Guardia Reflejo", "sprite": "res://arte/personajes/guardia_org_combate.png" }
		datos["equipo"] = [{ "id": "espectro_sonico", "nivel": 4 }, { "id": "tejedor_de_sombras", "nivel": 3 },
			{ "id": "caballero_de_neon", "nivel": 3 }]
		datos["frases"] = { "inicio": "Tú no entras al escenario. Aquí el único que brilla es Silas.",
			"golpe": "¿Te cegó la luz? ¡Ja!", "pierde": "Siguiente número...", "derrota": "Bien... sube. Que Silas te haga desaparecer." }
	await h.mapa.iniciar_combate(datos)


## Cuando caen los dos guardias, Silas aparece en el escenario.
func _guardias_vencidos() -> void:
	if not (Juego.flag("guardia_neon_1_derrotado") and Juego.flag("guardia_neon_2_derrotado")):
		h.poner_mision("Vence al otro guardia del escenario del Palacio Lumen.")
		return
	if Juego.flag("silas_espera"):
		return
	Juego.flags["silas_espera"] = true
	h.mapa.refrescar()
	var silas: Node2D = h._nodo("Silas")
	if silas:
		Sonido.efecto("destello")
		silas.modulate = Color(3, 3, 3, 0)
		var t: Tween = h.mapa.create_tween()
		t.tween_property(silas, "modulate", Color.WHITE, 0.7)
		await t.finished
		h.mapa.pan.mirar_a(silas.position)
	await decir("silas_aparece")
	h.poner_mision("Prepárate y sube al escenario: Silas te espera en el Palacio Lumen.")
	Juego.guardar_pronto = true


func _silas() -> void:
	if Juego.flag("silas_derrotado"):
		return
	var silas: Node2D = h._nodo("Silas")
	if silas:
		h.mapa.pan.mirar_a(silas.position)
	if not Juego.flag("ilusion_vista"):
		await _ilusion_padres()
	else:
		await decir("silas_reto")
	if not Juego.hay_cartas_vivas():
		await decir("sin_cartas_pelea")
		await h.mapa.retroceder_pan(Vector2.DOWN, 18.0)
		return
	await _pelear_con_silas()


## Antes de pelear, Silas proyecta a mis padres: le piden a Pan que se quede.
func _ilusion_padres() -> void:
	await decir("silas_reto_primera")
	Juego.flags["ilusion_padres"] = true
	h.mapa.refrescar()
	var holos: Array = [h._nodo("HoloPapa"), h._nodo("HoloMama")]
	Sonido.efecto("destello", 0.8)
	var t: Tween = h.mapa.create_tween().set_parallel()
	for holo in holos:
		if holo:
			holo.modulate = Color(0.6, 1.0, 1.2, 0.0)
			t.tween_property(holo, "modulate:a", 0.85, 0.9)
	await t.finished
	# Las ilusiones parpadean mientras hablan
	var parpadeo: Tween = h.mapa.create_tween().set_loops()
	for holo in holos:
		if holo:
			parpadeo.tween_property(holo, "modulate:a", 0.5, 0.08)
			parpadeo.tween_property(holo, "modulate:a", 0.85, 0.08)
			parpadeo.tween_interval(0.9)
	await decir("silas_ilusion")
	parpadeo.kill()
	Sonido.efecto("destello", 1.2)
	var fuera: Tween = h.mapa.create_tween().set_parallel()
	for holo in holos:
		if holo:
			fuera.tween_property(holo, "modulate:a", 0.0, 0.25)
	await fuera.finished
	Juego.flags["ilusion_padres"] = false
	Juego.flags["ilusion_vista"] = true
	h.mapa.refrescar()
	await decir("silas_ilusion_rota")


func _pelear_con_silas() -> void:
	await h.mapa.iniciar_combate({
		"tipo": "entrenador",
		"evento": "silas",
		"fondo": "casino",
		"musica": "silas",
		"comandante": true,
		"juego_de_luces": true,
		"intervencion": "ilusion",
		"intervencion_cada": 3,
		"tactico": true,
		"curas": 2,
		"potenciadores": 1,
		"botin": { "monedas": 300, "reliquias": 5 },
		"entrenador": { "nombre": "Silas", "sprite": "res://arte/personajes/silas_combate.png" },
		"equipo": [
			{ "id": "bestia_blanca", "nivel": 5, "esquiva_inicial": 3 },
			{ "id": "bailarina_electrica", "nivel": 4, "represalia": 0.5 },
			{ "id": "caballero_de_neon", "nivel": 5 },
		],
		"frases": {
			"inicio": "¡Damas y caballeros! ¡El niño del collar contra el gran Silas! ¡Luces!",
			"golpe": "¿Lo viste venir? No. Nadie lo ve venir.",
			"pierde": "Un pequeño error de iluminación. ¡Siguiente acto!",
			"ultima": "Basta de juegos. Caballero, apágale los ojos.",
			"derrota": "¡No! ¡Mi rostro! ¡Mi público!",
			"ilusion": ["Mira, Pan: tu mamá te está llamando...", "¿Escuchas a tu papá? Te pide que te rindas.",
				"Quédate con ellos, Pan. Aquí la luz no se apaga nunca."],
		},
	})


func _victoria_silas() -> void:
	await decir("silas_derrotado")
	var silas: Node2D = h._nodo("Silas")
	if silas:
		# Un destello y desaparece (su último truco)
		Sonido.efecto("destello")
		var t: Tween = h.mapa.create_tween()
		t.tween_property(silas, "modulate", Color(4, 4, 4, 1), 0.2)
		t.tween_property(silas, "modulate", Color(4, 4, 4, 0), 0.5)
		await t.finished
	Juego.flags["silas_derrotado"] = true
	h.mapa.refrescar()
	await decir("silas_escapa")
	# Pan arranca los cables del escenario: se apagan hologramas, torres y altavoces
	Sonido.efecto("metal")
	await h._temblor(0.5)
	Juego.flags["torres_apagadas"] = true
	await decir("neon_apagon")
	await _celebracion_neon()


const MULTITUD_NEON := ["coral_mapa", "tobi_mapa", "rina_mapa", "mara_mapa", "ciro_mapa", "pedalera_mapa",
	"pedalero_mapa", "pedalera_mapa", "pedalero_mapa", "ciudadano_mapa", "vecina_mapa", "pedalero_mapa",
	"pedalera_mapa", "ciudadano_mapa", "pedalero_mapa", "vecina_mapa"]


## Ciudad Neón libre: se apagan los generadores y todos salen a respirar el aire de afuera.
func _celebracion_neon() -> void:
	await h.mapa.hud.fundido(true, 0.6)
	Juego.flags["neon_liberado"] = true
	if Juego.mision_completa("carta_leo"):
		Juego.flags["leo_en_neon"] = true
	h.poner_mision("¡Ciudad Neón es libre!")
	h.mapa.refrescar()
	var vecinos := ["Coral", "Tobi", "MamaTobi", "Pedalero1", "Pedalera1", "Rina", "Mara", "LeoNeon", "DonCiro"]
	var ocultos: Array = []
	for n in vecinos:
		var v: Node2D = h._nodo(n)
		if v and v.visible:
			v.visible = false
			ocultos.append(v)
	var centro: Vector2 = h._px(28, 20)
	h.mapa.pan.global_position = centro
	h.mapa.pan.mirar_a(centro + Vector2.DOWN)
	h.mapa.pan.get_node("Camara").reset_smoothing()
	var gente: Array = h._armar_multitud(centro, MULTITUD_NEON)
	await h.mapa.get_tree().create_timer(0.2).timeout
	h.mapa.hud.fundido(false, 0.6)
	var t: Tween = h.mapa.create_tween().set_parallel()
	for p in gente:
		t.tween_property(p, "position", p.get_meta("destino"), randf_range(0.9, 1.4)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished
	h._aplaudir(gente)
	await decir("celebracion_neon")
	Juego.bonus_ataque += 0.10
	Juego.monedas += 150
	Juego.dar_objeto("granada_luz", 2)
	Juego.dar_objeto("cura_80", 1)
	Juego.dormir()
	Sonido.efecto("objeto")
	await decir("celebracion_neon_fuerzas")
	h._parar_aplausos()
	await h.mapa.hud.fundido(true, 0.6)
	for p in gente:
		p.queue_free()
	for v in ocultos:
		v.visible = true
	h.mapa.refrescar()
	Juego.lugar_descanso = { "mapa": h.NEON, "entrada": "Motel" }
	await h.mapa.hud.fundido(false, 0.6)
	await decir("neon_libre")
	h.poner_mision("Ciudad Neón es libre. Sal por la puerta norte, cruza el Bosque Calcinado y llega a Valle Ceniza.")
	Juego.guardar_pronto = true
