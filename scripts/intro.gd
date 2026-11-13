extends Control
## Fase 1 del prólogo: "El Recuerdo". Escenas en pixel art con lluvia de ceniza.
## Los textos están en datos/dialogos.json (intro_1 ... intro_4). Una frase con "imagen": "03_familia"
## cambia la ilustración a arte/cinematica/03_familia.png justo cuando empieza esa frase.

const REFUGIO := "res://escenas/mapas/refugio_cero.tscn"
const SUPERFICIE := "res://escenas/mapas/superficie.tscn"

@onready var imagen: TextureRect = $Imagen
@onready var dialogo: PanelContainer = $CajaDialogo
@onready var boton_saltar: Button = $Saltar
@onready var transicion: ColorRect = $Transicion

var _saltando := false
var _tween_imagen: Tween


func _ready() -> void:
	Juego.cambiando_escena = false
	Sonido.musica("recuerdo")
	Sonido.ambiente("")
	if Juego.SALTAR_PROLOGO:
		_preparar_partida_de_prueba()
		return
	boton_saltar.pressed.connect(_saltar)
	# Cada frase puede traer "imagen" en dialogos.json: la ilustración cambia justo cuando empieza esa frase.
	dialogo.linea_iniciada.connect(_al_iniciar_linea)
	imagen.modulate = Color.BLACK
	var t := create_tween()
	t.tween_property(transicion, "color:a", 0.0, 0.6)
	var recuerdo: Array = Juego.dialogos["intro_1"] + Juego.dialogos["intro_2"]
	var rejilla: Array = Juego.dialogos["intro_3"]
	await dialogo.mostrar(recuerdo + rejilla.slice(0, 2))
	if _saltando:
		return
	# Destello blanco: el disparo
	Sonido.efecto("golpe_fuerte", 0.6, 4.0)
	transicion.color = Color(1, 1, 1, 1)
	t = create_tween()
	t.tween_property(transicion, "color", Color(0, 0, 0, 1), 0.5)
	await t.finished
	await dialogo.mostrar(rejilla.slice(2))
	# Negro total: la última frase de su madre
	if _saltando:
		return
	imagen.texture = null
	transicion.color = Color(0, 0, 0, 0)
	await dialogo.mostrar("intro_4")
	_ir_al_refugio()


func _al_iniciar_linea(linea: Dictionary) -> void:
	var nombre: String = linea.get("imagen", "")
	if nombre == "":
		return
	var ruta := "res://arte/cinematica/%s.png" % nombre
	var tex := Juego.textura(ruta)
	if tex == null:
		push_warning("No existe la imagen de la intro: " + ruta)
		return
	if _tween_imagen:
		_tween_imagen.kill()
	_tween_imagen = create_tween()
	if imagen.texture != null:
		_tween_imagen.tween_property(imagen, "modulate", Color.BLACK, 0.25)  # se oscurece la anterior
	_tween_imagen.tween_callback(_poner_imagen.bind(tex))
	_tween_imagen.tween_property(imagen, "modulate", Color.WHITE, 0.35)
	_tween_imagen.parallel().tween_property(imagen, "scale", Vector2.ONE, 8.0)  # acercamiento lento


func _poner_imagen(tex: Texture2D) -> void:
	imagen.texture = tex
	imagen.pivot_offset = imagen.size / 2.0
	imagen.scale = Vector2(1.06, 1.06)


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
