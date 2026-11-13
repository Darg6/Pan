extends Node
## LA HISTORIA DE PAN. Está registrado como Autoload con el nombre "Historia".
## Aquí se programa qué pasa en cada evento: al entrar a un mapa, al tocar un objeto
## (interactuable.gd) o al pisar una zona (disparador.gd).
## Los TEXTOS están en datos/dialogos.json; aquí solo va el orden y las consecuencias.
##
## Prólogo (según el GDD):
##   1. El Recuerdo (escenas/intro.tscn)
##   2. El Despertar en el Refugio Cero: mochila, mesa de trabajo y collar
##   3. El Encuentro: el Gato Mutado atrapado bajo la viga (tutorial de captura)
##   4. La Prueba de Fuego: el Recluta de Chatarra y su Oso de Escoria
##   5. Consecuencias: volver a dormir al refugio, que luego se sella para siempre
##   6. Título: el acantilado y la misión de llegar a Bastión de Óxido
##
## Ciudad 1, Bastión de Óxido (Comandante Rictus):
##   - Llegada: Rictus patea el balde de Odila y te reta a subir al puerto.
##   - Misión secundaria "El agua de Lía" (Odila) y "Herramientas de Bruno" (la grúa).
##   - Cosas para investigar: trituradora, tanque, tablón, estatua, mural, radio, cinta, buque.
##   - Dos guardias en la Avenida del Impuesto y Rictus en el trono del puerto.
##   - Al salvarla, la ciudad te aplaude y te da fuerzas (+10% de ataque para siempre).

const REFUGIO := "res://escenas/mapas/refugio_cero.tscn"
const SUPERFICIE := "res://escenas/mapas/superficie.tscn"
const ESCENA_TITULO := "res://escenas/titulo.tscn"
const BASTION := "res://escenas/mapas/bastion_oxido.tscn"
const T := 16.0  # tamaño de un tile en píxeles

var mapa: Node = null  # el mapa actual (scripts/mapa.gd)


func decir(id) -> void:
	await mapa.hud.dialogo.mostrar(id)


func poner_mision(texto: String) -> void:
	Juego.mision = texto
	mapa.hud.actualizar()


func _equipo_listo() -> int:
	var n := 0
	for f in ["tiene_mochila", "reviso_mesa", "tiene_collar"]:
		if Juego.flag(f):
			n += 1
	return n


func _mision_equipo() -> void:
	var n := _equipo_listo()
	if n < 3:
		poner_mision("Preparar el equipo (%d/3)" % n)
	else:
		poner_mision("Sal del refugio por la escalera.")


# ---------------------------------------------------------------------------
# Al entrar a un mapa (también al volver de un combate)
# ---------------------------------------------------------------------------

func al_entrar_mapa(m: Node) -> void:
	mapa = m
	var r: Dictionary = Juego.resultado_combate
	Juego.resultado_combate = {}
	if not r.is_empty():
		await _despues_de_combate(r)
		return

	match m.nombre_mapa:
		"refugio_cero":
			if not Juego.flag("desperto"):
				Juego.flags["desperto"] = true
				await decir("despertar")
				_mision_equipo()
		"superficie":
			if Juego.flag("durmio_refugio") and not Juego.flag("refugio_sellado"):
				Juego.flags["refugio_sellado"] = true
				Juego.lugar_descanso = { "mapa": SUPERFICIE, "entrada": "Escotilla" }
				await decir("refugio_sellado")
				poner_mision("Sigue el camino hacia el este.")
			elif not Juego.flag("salio_superficie"):
				Juego.flags["salio_superficie"] = true
				await decir("superficie")
				poner_mision("Explora los alrededores del refugio.")
			elif Juego.flag("titulo_visto") and not Juego.flag("mision_bastion"):
				Juego.flags["mision_bastion"] = true
				await decir("mision_bastion")
				poner_mision("Llega a Bastión de Óxido y encuentra al Comandante Rictus.")
		"bastion_oxido":
			if not Juego.flag("bastion_visitado"):
				await _llegada_bastion()


func _despues_de_combate(r: Dictionary) -> void:
	var resultado: String = r.get("resultado", "")
	if resultado == "derrota":
		await decir("derrota")
		return
	match r.get("evento", ""):
		"gato":
			if resultado == "captura":
				Juego.flags["gato_capturado"] = true
				await _recluta_aparece()
		"recluta":
			if resultado == "victoria":
				Juego.flags["recluta_derrotado"] = true
				Juego.flags["debe_dormir"] = true
				Juego.monedas += 50
				Juego.chatarra += 3
				mapa.refrescar()
				await decir("recluta_derrotado")
				poner_mision("Vuelve al Refugio Cero y duerme en la cama.")
		# --- Bastión de Óxido ---
		"guardia_1", "guardia_2":
			if resultado == "victoria":
				Juego.flags[r["evento"] + "_derrotado"] = true
				await decir(r["evento"] + "_derrotado")
				mapa.refrescar()
		"nido":
			if resultado in ["victoria", "captura"]:
				Juego.flags["nido_libre"] = true
				mapa.refrescar()
				await decir("nido_libre")
		"rictus":
			if resultado == "victoria":
				await _victoria_rictus()


func _recluta_aparece() -> void:
	Juego.flags["recluta_visible"] = true
	mapa.refrescar()
	var recluta: Node2D = mapa.get_node_or_null("Entidades/Recluta")
	if recluta:
		var destino := recluta.position
		recluta.position += Vector2(80, 0)
		var t := mapa.create_tween()
		t.tween_property(recluta, "position", destino, 1.2)
		await t.finished
	Sonido.efecto("alerta")
	await decir("recluta_aparece")
	await _pelear_con_recluta()


func _pelear_con_recluta() -> void:
	await mapa.iniciar_combate({
		"tipo": "entrenador",
		"evento": "recluta",
		"fondo": "chatarra",
		"tutorial": true,
		"entrenador": { "nombre": "Recluta de Chatarra", "sprite": "res://arte/personajes/recluta_combate.png" },
		"equipo": [{ "id": "oso_de_escoria", "nivel": 1 }],
	})


# ---------------------------------------------------------------------------
# Eventos (interactuables y disparadores). `nodo` es quien lo activó.
# ---------------------------------------------------------------------------

func ejecutar(evento: String, nodo: Node = null) -> void:
	match evento:
		# --- Refugio Cero ---
		"mochila":
			Juego.flags["tiene_mochila"] = true
			Sonido.efecto("objeto")
			await decir("mochila")
			_mision_equipo()
		"mesa":
			if Juego.flag("reviso_mesa"):
				await decir([{ "quien": "", "texto": "La mesa de trabajo de papá. Ya no queda nada útil." }])
				return
			Juego.flags["reviso_mesa"] = true
			Juego.dar_objeto("carta_vinculo", 3)
			Juego.dar_objeto("granada_aturdidora", 1)
			Sonido.efecto("objeto")
			await decir("mesa")
			_mision_equipo()
		"collar":
			Juego.flags["tiene_collar"] = true
			Sonido.efecto("objeto")
			await decir("collar")
			_mision_equipo()
		"cama":
			if Juego.flag("debe_dormir") or Juego.hay_cartas_heridas():
				await _dormir("cama_dormir")
				if Juego.flag("debe_dormir"):
					Juego.flags["debe_dormir"] = false
					Juego.flags["durmio_refugio"] = true
					poner_mision("Sal del Refugio Cero.")
			else:
				await decir("cama_no")
		"escalera":
			if _equipo_listo() < 3:
				await decir("falta_equipo")
			else:
				Sonido.efecto("metal")
				await mapa.hud.fundido(true, 0.4)
				Juego.ir_a_mapa(SUPERFICIE, "Escotilla")

		# --- Superficie: prólogo ---
		"escotilla":
			if Juego.flag("refugio_sellado"):
				await decir("escotilla_sellada")
			else:
				Sonido.efecto("metal")
				await mapa.hud.fundido(true, 0.4)
				Juego.ir_a_mapa(REFUGIO, "Escalera")
		"gato_atrapado":
			if Juego.flag("gato_capturado"):
				return
			await decir("gato_atrapado")
			await mapa.iniciar_combate({
				"tipo": "tutorial_captura",
				"evento": "gato",
				"fondo": "paramo",
				"equipo": [{ "id": "gato_mutado", "nivel": 1 }],
			})
		"recluta":
			# Si perdiste contra el Recluta, puedes volver a hablarle para pelear otra vez.
			await decir([{ "quien": "Recluta de Chatarra", "retrato": "recluta", "texto": "¿Otra vez tú? ¡Esta vez me quedo con tu bestia!" }])
			await _pelear_con_recluta()
		"camino":
			if Juego.flag("refugio_sellado"):
				return
			if Juego.flag("recluta_derrotado"):
				await decir("camino_herido")
			else:
				await decir("camino_escombros")
			await mapa.retroceder_pan(Vector2.LEFT, 14.0)
		"acantilado":
			if not Juego.flag("refugio_sellado") or Juego.flag("titulo_visto"):
				return
			Juego.flags["titulo_visto"] = true
			await decir("titulo")
			await mapa.hud.fundido(true, 0.8)
			Juego.entrada = "Mirador"
			Juego.posicion_pan = null
			Juego.cambiar_escena(ESCENA_TITULO)

		# --- Exploración ---
		"saqueo":
			var bandera := "saqueo_" + str(nodo.name)
			if Juego.flag(bandera):
				await decir("saqueo_vacio")
				return
			Juego.flags[bandera] = true
			var monedas := randi_range(5, 20)
			Juego.dar_objeto("carta_vinculo", 2)
			Juego.monedas += monedas
			Juego.chatarra += 1
			await decir("saqueo")
			await decir([{ "quien": "", "texto": "Encontraste 2 Cartas de Vínculo, %d monedas y una Reliquia del Viejo Mundo." % monedas }])

		# --- Afueras de Bastión de Óxido ---
		"cartel_bastion":
			await decir("cartel_bastion")
		"ciudadano":
			if Juego.flag("hablo_ciudadano"):
				await decir("ciudadano_despues")
			else:
				Juego.flags["hablo_ciudadano"] = true
				await decir("ciudadano")
		"cama_carton":
			Juego.lugar_descanso = { "mapa": SUPERFICIE, "entrada": "Fogata" }
			await _dormir("cama_carton")
		"porton":
			if not Juego.flag("bastion_visitado"):
				await decir("porton")
			Sonido.efecto("metal")
			await mapa.hud.fundido(true, 0.4)
			Juego.ir_a_mapa(BASTION, "Puerta")

		# --- Bastión de Óxido ---
		"salida_bastion":
			await mapa.hud.fundido(true, 0.4)
			Juego.ir_a_mapa(SUPERFICIE, "Porton")
		"odila":
			await _odila()
		"lia":
			if Juego.flag("bastion_liberado"):
				await decir("lia_libre")
			elif Juego.flag("lia_sana"):
				await decir("lia_sana")
			else:
				await decir("lia_enferma")
		"cama_posada":
			await _cama_posada()
		"tienda":
			if not Juego.flag("hablo_mila"):
				Juego.flags["hablo_mila"] = true
				await _decir_bastion("mila")
			await mapa.hud.abrir_tienda("Tienda de Mila")
		"bruno":
			await _bruno()
		"nido":
			if Juego.flag("nido_libre"):
				await decir("nido_vacio")
				return
			await decir("nido")
			if not await _puede_pelear():
				return
			await mapa.iniciar_combate({
				"tipo": "salvaje",
				"evento": "nido",
				"fondo": "dunas",
				"tormenta": Juego.tormenta,
				"equipo": [{ "id": "aves_negras", "nivel": 3 }],
			})
		"caja_bruno":
			Juego.flags["caja_recogida"] = true
			Sonido.efecto("objeto")
			await decir("caja_bruno")
			if Juego.mision_activa("nido_grua"):
				Juego.misiones["nido_grua"]["titulo"] = "Herramientas de Bruno: lleva la caja a Bruno (este de la plaza)."
		"rosa":
			if Juego.flag("pista_mural"):
				await _decir_bastion("rosa_despues")
			else:
				Juego.flags["pista_mural"] = true
				Juego.dar_objeto("carta_vinculo", 2)
				Sonido.efecto("objeto")
				await decir("rosa")
		"tavo", "vecino_cola", "vecina_cola", "guardia_puerta", "inv_trituradora", "inv_tanque", \
		"inv_tablon", "inv_estatua", "inv_mural", "inv_radio":
			await _decir_bastion(evento)
		"inv_cinta":
			await _decir_bastion("inv_cinta")
			if not Juego.flag("cinta_revisada"):
				Juego.flags["cinta_revisada"] = true
				Juego.chatarra += 1
				Juego.monedas += 5
				Sonido.efecto("objeto")
				await decir([{ "quien": "", "texto": "Entre los restos de la cinta encontraste 5 monedas y una Reliquia del Viejo Mundo." }])
		"inv_buque":
			await _decir_bastion("inv_buque")
			if not Juego.flag("buque_revisado"):
				Juego.flags["buque_revisado"] = true
				Juego.chatarra += 1
				Juego.dar_objeto("carta_vinculo", 2)
				Sonido.efecto("objeto")
				await decir([{ "quien": "", "texto": "En un camarote seco encontraste 2 Cartas de Vínculo y una Reliquia del Viejo Mundo." }])
		"guardia_1", "guardia_2":
			await _guardia(evento)
		"rictus":
			if Juego.flag("rictus_derrotado"):
				return
			await decir("rictus_reto")
			if not await _puede_pelear():
				return
			await _pelear_con_rictus()
		_:
			push_warning("Evento sin programar: " + evento)


func _dormir(id_dialogo: String) -> void:
	await mapa.hud.fundido(true, 0.6)
	Juego.dormir()
	await mapa.get_tree().create_timer(0.6).timeout
	await mapa.hud.fundido(false, 0.6)
	await decir(id_dialogo)



# ---------------------------------------------------------------------------
# Bastión de Óxido (Ciudad 1)
# ---------------------------------------------------------------------------

func _px(tx: float, ty: float) -> Vector2:
	return Vector2(tx * T + T / 2.0, ty * T + T / 2.0)


func _nodo(nombre: String) -> Node2D:
	return mapa.get_node_or_null("Entidades/" + nombre)


## Dice un diálogo; si la ciudad ya es libre y existe "<id>_libre", dice ese.
func _decir_bastion(id: String) -> void:
	var libre := id + "_libre"
	if Juego.flag("bastion_liberado") and Juego.dialogos.has(libre):
		await decir(libre)
	else:
		await decir(id)


## Antes de una pelea obligatoria: si todas tus cartas están rotas, Pan retrocede.
func _puede_pelear() -> bool:
	if Juego.hay_cartas_vivas():
		return true
	await decir("sin_cartas_pelea")
	await mapa.retroceder_pan(Vector2.DOWN, 18.0)
	return false


func _caminar_npc(nodo: Node2D, destino: Vector2, rapidez := 50.0) -> void:
	if nodo == null:
		return
	var t := mapa.create_tween()
	t.tween_property(nodo, "position", destino, nodo.position.distance_to(destino) / rapidez)
	# pasitos: sube y baja un poco mientras camina
	var sprite: Node2D = nodo.get_child(0) if nodo.get_child_count() > 0 else null
	var saltos: Tween = null
	if sprite:
		saltos = mapa.create_tween().set_loops()
		saltos.tween_property(sprite, "position:y", -1.0, 0.12)
		saltos.tween_property(sprite, "position:y", 0.0, 0.12)
	await t.finished
	if saltos:
		saltos.kill()
		sprite.position.y = 0.0


func _llegada_bastion() -> void:
	Juego.flags["bastion_visitado"] = true
	Juego.tiempo_clima = 0.0
	mapa.poner_tormenta(false)
	Juego.lugar_descanso = { "mapa": BASTION, "entrada": "Posada" }
	await decir("bastion_llegada")
	await mapa.pan.caminar_a(_px(29.5, 32))
	await mapa.pan.caminar_a(_px(27.5, 31))
	# Rictus baja por la avenida hasta el tanque de agua
	Juego.flags["rictus_en_plaza"] = true
	mapa.refrescar()
	var rictus := _nodo("RictusEscena")
	Sonido.efecto("alerta")
	await _caminar_npc(rictus, _px(30.5, 25.5), 55.0)
	await _caminar_npc(rictus, _px(26, 28.4), 55.0)
	mapa.pan.mirar_a(rictus.position)
	await decir("rictus_tanque")
	# ¡Patea el balde!
	var balde := _nodo("Balde")
	if balde:
		Sonido.efecto("metal")
		var t := mapa.create_tween().set_parallel()
		t.tween_property(balde, "position", balde.position + Vector2(-22, 6), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(balde, "rotation", -PI * 0.6, 0.35)
		await t.finished
	await decir("rictus_patea")
	await _caminar_npc(rictus, _px(26.5, 30), 55.0)
	mapa.pan.mirar_a(rictus.position)
	await decir("rictus_a_pan")
	await _caminar_npc(rictus, _px(30.5, 24), 70.0)
	await _caminar_npc(rictus, _px(30.5, 16), 70.0)
	Juego.flags["rictus_en_plaza"] = false
	await decir("odila_tras_rictus")
	await mapa.hud.fundido(true, 0.4)
	Juego.flags["escena_rictus_vista"] = true
	if balde:
		balde.rotation = 0.0
	mapa.refrescar()
	await mapa.hud.fundido(false, 0.4)
	await decir("pan_prepararse")
	poner_mision("Prepárate y enfrenta al Comandante Rictus en el puerto (al norte de la avenida).")


func _odila() -> void:
	if Juego.mision_completa("agua_lia"):
		await _decir_bastion("odila_despues")
		return
	if Juego.flag("bastion_liberado"):
		Juego.completar_mision("agua_lia")
		await decir("odila_libre")
		return
	if not Juego.mision_activa("agua_lia"):
		await decir("odila_pide")
		Juego.empezar_mision("agua_lia", "El agua de Lía: lleva 3 Reliquias a Odila (posada, suroeste).")
		mapa.hud.mostrar_aviso("Nueva misión: El agua de Lía")
		return
	if Juego.chatarra < 3:
		await decir([{ "quien": "Odila", "retrato": "odila", "texto": "¿Encontraste las Reliquias? Necesito 3 para pagar la cuota del agua. Llevas %d." % Juego.chatarra }])
		return
	Juego.chatarra -= 3
	Juego.flags["lia_sana"] = true
	Juego.completar_mision("agua_lia")
	Juego.dar_objeto("racion", 1)
	Juego.dar_objeto("cura_40", 2)
	Sonido.efecto("objeto")
	mapa.refrescar()
	await decir("odila_gracias")
	await decir([{ "quien": "", "texto": "Odila te dio una Piña en lata y 2 Curas 40%. Desde ahora duermes gratis en la posada." }])


func _cama_posada() -> void:
	Juego.lugar_descanso = { "mapa": BASTION, "entrada": "Posada" }
	if Juego.mision_completa("agua_lia") or Juego.flag("bastion_liberado"):
		await _dormir("cama_posada_gratis")
	elif Juego.monedas >= 5:
		Juego.monedas -= 5
		await _dormir("cama_posada")
	else:
		await _dormir("cama_posada_fiada")


func _bruno() -> void:
	if Juego.mision_completa("nido_grua"):
		await _decir_bastion("bruno_despues")
		return
	if Juego.flag("caja_recogida"):
		Juego.empezar_mision("nido_grua", "")
		Juego.completar_mision("nido_grua")
		Juego.dar_objeto("potenciador_20", 2)
		Juego.monedas += 40
		Sonido.efecto("objeto")
		await decir("bruno_gracias")
		await decir([{ "quien": "", "texto": "Bruno te dio 2 Potenciadores 20% y 40 monedas." }])
		return
	if Juego.mision_activa("nido_grua"):
		await decir("bruno_espera")
		return
	await _decir_bastion("bruno_pide")
	Juego.empezar_mision("nido_grua", "Herramientas de Bruno: espanta a las Aves Negras de la grúa (dunas del este).")
	mapa.hud.mostrar_aviso("Nueva misión: Herramientas de Bruno")


func _guardia(evento: String) -> void:
	if Juego.flag(evento + "_derrotado") or Juego.flag("bastion_liberado"):
		return
	Sonido.efecto("alerta")
	var guardia := _nodo("Guardia1" if evento == "guardia_1" else "Guardia2")
	if guardia:
		mapa.pan.mirar_a(guardia.position)
	await decir(evento)
	if not await _puede_pelear():
		return
	var datos := {
		"tipo": "entrenador",
		"evento": evento,
		"fondo": "bastion",
		"tormenta": Juego.tormenta,
		"curas": 1,
	}
	if evento == "guardia_1":
		datos["tactico"] = true
		datos["botin"] = { "monedas": 40, "reliquias": 1 }
		datos["entrenador"] = { "nombre": "Recluta Brizna", "sprite": "res://arte/personajes/recluta_combate.png" }
		datos["equipo"] = [{ "id": "enjambre_mecanico", "nivel": 2 }, { "id": "gato_mutado", "nivel": 1 }]
		datos["frases"] = { "inicio": "¡Nadie pasa sin pagar la cuota!", "derrota": "Rictus me va a mandar a la trituradora..." }
	else:
		datos["botin"] = { "monedas": 50, "reliquias": 2 }
		datos["entrenador"] = { "nombre": "Recluta Toño", "sprite": "res://arte/personajes/recluta_combate.png" }
		datos["equipo"] = [{ "id": "oso_de_escoria", "nivel": 2 }, { "id": "aves_negras", "nivel": 2 }]
		datos["frases"] = { "inicio": "¿Pasaste a Brizna? Conmigo no tendrás tanta suerte.", "derrota": "Ve, pues. El jefe te va a hacer pedazos." }
	await mapa.iniciar_combate(datos)


func _pelear_con_rictus() -> void:
	await mapa.iniciar_combate({
		"tipo": "entrenador",
		"evento": "rictus",
		"fondo": "bastion",
		"musica": "jefe",
		"tormenta": Juego.tormenta,
		"comandante": true,
		"grito_guerra": true,
		"curas": 2,
		"botin": { "monedas": 200, "reliquias": 4 },
		"entrenador": { "nombre": "Comandante Rictus", "sprite": "res://arte/personajes/rictus_combate.png" },
		"equipo": [
			{ "id": "gato_mutado", "nivel": 2 },
			{ "id": "titan_de_chatarra", "nivel": 2 },
			{ "id": "oso_de_escoria", "nivel": 1 },
		],
		"frases": {
			"inicio": "¡Gatos! ¡Despedácenlo!",
			"golpe": "¡JA! ¡Eso es lo que pasa cuando no pagas!",
			"pierde": "¡Levántate, inútil! ¡Te alimento para esto!",
			"ultima": "Muy bien, mocoso. Ahora vas a conocer el miedo.",
			"derrota": "No... ¡NO! ¡Esto no se queda así!",
		},
	})


func _victoria_rictus() -> void:
	Juego.flags["rictus_derrotado_combate"] = true
	await decir("rictus_derrotado")
	# Rictus huye por el muelle
	var rictus := _nodo("Rictus")
	if rictus:
		await _caminar_npc(rictus, rictus.position + Vector2(-90, 10), 110.0)
	Juego.flags["rictus_derrotado"] = true
	mapa.refrescar()
	await decir("palanca")
	# Pan baja la palanca del trono: la trituradora se apaga
	Sonido.efecto("metal")
	await _temblor(0.5)
	Juego.flags["trituradora_apagada"] = true
	Sonido.efecto("caer", 0.6)
	await decir("trituradora_apagada")
	await _celebracion()


func _temblor(duracion: float) -> void:
	var camara: Camera2D = mapa.pan.get_node("Camara")
	var t := mapa.create_tween()
	var pasos := int(duracion / 0.05)
	for i in pasos:
		t.tween_property(camara, "offset", Vector2(randf_range(-3, 3), randf_range(-2, 2)), 0.05)
	t.tween_property(camara, "offset", Vector2.ZERO, 0.05)
	await t.finished


## Cada ciudad que salvas te aplaude y te da fuerzas para continuar.
func _celebracion() -> void:
	await mapa.hud.fundido(true, 0.6)
	Juego.flags["bastion_liberado"] = true
	Juego.flags["lia_sana"] = true
	poner_mision("¡Bastión de Óxido es libre!")
	mapa.refrescar()
	# Los vecinos de verdad se esconden mientras la multitud llena la plaza
	var vecinos := ["Odila", "Lia", "Mila", "Bruno", "Rosa", "Tavo", "VecinoCola1", "VecinaCola2"]
	for n in vecinos:
		var v := _nodo(n)
		if v:
			v.visible = false
	var centro := _px(30.5, 31.5)
	mapa.pan.global_position = centro
	mapa.pan.mirar_a(centro + Vector2.DOWN)
	mapa.pan.get_node("Camara").reset_smoothing()
	var gente := _armar_multitud(centro)
	await mapa.get_tree().create_timer(0.2).timeout
	mapa.hud.fundido(false, 0.6)
	# Llegan corriendo desde todos lados
	var t := mapa.create_tween().set_parallel()
	for p in gente:
		t.tween_property(p, "position", p.get_meta("destino"), randf_range(0.9, 1.4)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished
	_aplaudir(gente)
	await decir("celebracion")
	Juego.bonus_ataque += 0.10
	Juego.monedas += 100
	Juego.dar_objeto("cura_50", 2)
	Juego.dar_objeto("racion", 1)
	Juego.dormir()
	Sonido.efecto("objeto")
	await decir("celebracion_fuerzas")
	_parar_aplausos()
	await mapa.hud.fundido(true, 0.6)
	for p in gente:
		p.queue_free()
	for n in vecinos:
		var v := _nodo(n)
		if v:
			v.visible = true
	mapa.refrescar()
	if Juego.mision_activa("agua_lia"):
		Juego.completar_mision("agua_lia")
	Juego.lugar_descanso = { "mapa": BASTION, "entrada": "Posada" }
	await mapa.hud.fundido(false, 0.6)
	await decir("bastion_libre")
	poner_mision("Bastión es libre. Próximo destino: El Sumidero (llegará en una próxima versión).")


func _armar_multitud(centro: Vector2) -> Array:
	var gente: Array = []
	var nombres := ["odila_mapa", "lia_mapa", "mila_mapa", "bruno_mapa", "rosa_mapa", "tavo_mapa",
		"vecina_mapa", "ciudadano_mapa", "vecina_mapa", "ciudadano_mapa", "vecina_mapa", "ciudadano_mapa",
		"ciudadano_mapa", "vecina_mapa", "ciudadano_mapa", "vecina_mapa"]
	var colores := [Color.WHITE, Color(1, 0.9, 0.8), Color(0.85, 0.95, 1), Color(1, 1, 0.85), Color(0.9, 0.85, 0.85)]
	for i in nombres.size():
		var ang := TAU * i / nombres.size() + 0.2
		var radio := 46.0 + (i % 2) * 18.0
		var destino := centro + Vector2(cos(ang) * radio * 1.4, sin(ang) * radio * 0.8)
		var p := Node2D.new()
		p.set_meta("destino", destino)
		p.position = centro + Vector2(cos(ang), sin(ang)) * 260.0
		var s := Sprite2D.new()
		s.texture = Juego.textura("res://arte/personajes/%s.png" % nombres[i])
		s.offset = Vector2(0, -9)
		if i >= 6:
			s.modulate = colores[i % colores.size()]
		p.add_child(s)
		mapa.get_node("Entidades").add_child(p)
		gente.append(p)
	return gente


## Saltitos y "¡Clap!" mientras dura la fiesta (hasta _parar_aplausos).
var _tweens_fiesta: Array = []


func _aplaudir(gente: Array) -> void:
	Sonido.efecto("aplausos")
	var t := mapa.create_tween().set_loops()
	t.tween_callback(_ronda_aplausos.bind(gente))
	t.tween_interval(0.55)
	var sonido := mapa.create_tween().set_loops()
	sonido.tween_interval(2.4)
	sonido.tween_callback(Sonido.efecto.bind("aplausos"))
	_tweens_fiesta = [t, sonido]


func _parar_aplausos() -> void:
	for t in _tweens_fiesta:
		if t.is_valid():
			t.kill()
	_tweens_fiesta.clear()


func _ronda_aplausos(gente: Array) -> void:
	for p in gente:
		if not is_instance_valid(p):
			continue
		var s: Node2D = p.get_child(0)
		var salto := mapa.create_tween()
		salto.tween_interval(randf_range(0.0, 0.25))
		salto.tween_property(s, "position:y", -4.0, 0.12).set_ease(Tween.EASE_OUT)
		salto.tween_property(s, "position:y", 0.0, 0.12).set_ease(Tween.EASE_IN)
	for i in 3:
		var p = gente.pick_random()
		if is_instance_valid(p):
			_clap(p.position + Vector2(randf_range(-6, 6), -26))


func _clap(pos: Vector2) -> void:
	var l := Label.new()
	l.text = "¡Clap!"
	l.theme_type_variation = &"TextoChico"
	l.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.05))
	l.add_theme_constant_override("outline_size", 3)
	l.position = pos - Vector2(14, 0)
	l.z_index = 20
	mapa.add_child(l)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", pos.y - 16, 0.8)
	t.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)
