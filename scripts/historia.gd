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

const REFUGIO := "res://escenas/mapas/refugio_cero.tscn"
const SUPERFICIE := "res://escenas/mapas/superficie.tscn"
const ESCENA_TITULO := "res://escenas/titulo.tscn"

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
	await decir("recluta_aparece")
	await _pelear_con_recluta()


func _pelear_con_recluta() -> void:
	await mapa.iniciar_combate({
		"tipo": "entrenador",
		"evento": "recluta",
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
			await decir("mochila")
			_mision_equipo()
		"mesa":
			if Juego.flag("reviso_mesa"):
				await decir([{ "quien": "", "texto": "La mesa de trabajo de papá. Ya no queda nada útil." }])
				return
			Juego.flags["reviso_mesa"] = true
			Juego.dar_objeto("carta_vinculo", 3)
			Juego.dar_objeto("granada_aturdidora", 1)
			await decir("mesa")
			_mision_equipo()
		"collar":
			Juego.flags["tiene_collar"] = true
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
				await mapa.hud.fundido(true, 0.4)
				Juego.ir_a_mapa(SUPERFICIE, "Escotilla")

		# --- Superficie: prólogo ---
		"escotilla":
			if Juego.flag("refugio_sellado"):
				await decir("escotilla_sellada")
			else:
				await mapa.hud.fundido(true, 0.4)
				Juego.ir_a_mapa(REFUGIO, "Escalera")
		"gato_atrapado":
			if Juego.flag("gato_capturado"):
				return
			await decir("gato_atrapado")
			await mapa.iniciar_combate({
				"tipo": "tutorial_captura",
				"evento": "gato",
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
			await decir("porton")
		_:
			push_warning("Evento sin programar: " + evento)


func _dormir(id_dialogo: String) -> void:
	await mapa.hud.fundido(true, 0.6)
	Juego.dormir()
	await mapa.get_tree().create_timer(0.6).timeout
	await mapa.hud.fundido(false, 0.6)
	await decir(id_dialogo)
