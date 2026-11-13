extends Control
## Fase 1 del prólogo: "El Recuerdo". Viñetas en pixel art (sepia y rojo oscuro) con lluvia de ceniza.
## Las imágenes están en arte/cinematica/ y los textos en datos/dialogos.json (intro_1 ... intro_4).

const REFUGIO := "res://escenas/mapas/refugio_cero.tscn"
const SUPERFICIE := "res://escenas/mapas/superficie.tscn"

@onready var imagen: TextureRect = $Imagen
@onready var dialogo: PanelContainer = $CajaDialogo
@onready var boton_saltar: Button = $Saltar
@onready var transicion: ColorRect = $Transicion

var _saltando := false


func _ready() -> void:
	Juego.cambiando_escena = false
	Sonido.musica("recuerdo")
	Sonido.ambiente("viento" if false else "")
	if Juego.SALTAR_PROLOGO:
		_preparar_partida_de_prueba()
		return
	boton_saltar.pressed.connect(_saltar)
	await _vineta("res://arte/cinematica/01_callejon.png", "intro_1")
	await _vineta("res://arte/cinematica/02_acorralados.png", "intro_2")
	await _vineta("res://arte/cinematica/03_rejilla.png", "intro_3", true)
	# Negro total: la última frase de su madre
	if _saltando:
		return
	imagen.texture = null
	transicion.color = Color(0, 0, 0, 0)
	await dialogo.mostrar("intro_4")
	_ir_al_refugio()


func _vineta(ruta: String, id_dialogo: String, disparo := false) -> void:
	if _saltando:
		return
	var t := create_tween()
	t.tween_property(transicion, "color:a", 1.0, 0.4)
	await t.finished
	imagen.texture = load(ruta)
	imagen.scale = Vector2(1.08, 1.08)
	imagen.pivot_offset = imagen.size / 2.0
	var lento := create_tween()
	lento.tween_property(imagen, "scale", Vector2.ONE, 8.0)  # acercamiento lento
	t = create_tween()
	t.tween_property(transicion, "color:a", 0.0, 0.6)
	await t.finished
	if disparo:
		await dialogo.mostrar(Juego.dialogos[id_dialogo].slice(0, 2))
		# Destello blanco: el disparo
		Sonido.efecto("golpe_fuerte", 0.6, 4.0)
		transicion.color = Color(1, 1, 1, 1)
		t = create_tween()
		t.tween_property(transicion, "color", Color(0, 0, 0, 1), 0.5)
		await t.finished
		await dialogo.mostrar(Juego.dialogos[id_dialogo].slice(2))
	else:
		await dialogo.mostrar(id_dialogo)


func _saltar() -> void:
	_saltando = true
	_ir_al_refugio()


func _ir_al_refugio() -> void:
	if Juego.cambiando_escena:
		return
	Juego.ir_a_mapa(REFUGIO, "Cama")


## Atajo para probar: deja todo como si hubieras terminado el prólogo.
func _preparar_partida_de_prueba() -> void:
	for f in ["desperto", "tiene_mochila", "reviso_mesa", "tiene_collar", "salio_superficie",
			"gato_capturado", "recluta_derrotado", "durmio_refugio", "refugio_sellado", "titulo_visto", "mision_bastion"]:
		Juego.flags[f] = true
	Juego.agregar_carta("gato_mutado")
	Juego.dar_objeto("carta_vinculo", 5)
	Juego.dar_objeto("granada_aturdidora", 1)
	Juego.mision = "Llega a Bastión de Óxido y encuentra al Comandante Rictus."
	Juego.lugar_descanso = { "mapa": SUPERFICIE, "entrada": "Escotilla" }
	Juego.ir_a_mapa.call_deferred(SUPERFICIE, "Mirador")
