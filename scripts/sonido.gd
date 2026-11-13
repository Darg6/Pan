extends Node
## Música, ambiente y efectos. Está registrado como Autoload con el nombre "Sonido".
##   Sonido.musica("paramo")     -> audio/musica/paramo.ogg (cambia con un fundido suave)
##   Sonido.ambiente("viento")   -> audio/ambiente/viento.ogg (bucle de fondo)
##   Sonido.efecto("golpe")      -> audio/sfx/golpe.ogg
## Pasa "" para apagar la música o el ambiente. Si un archivo no existe, simplemente no suena.

const VOLUMEN_MUSICA := -8.0      # en decibeles (0 = máximo)
const VOLUMEN_AMBIENTE := -12.0
const VOLUMEN_EFECTOS := -4.0
const FUNDIDO := 1.2              # segundos del cambio de música

var _musica: AudioStreamPlayer
var _musica_saliente: AudioStreamPlayer
var _ambiente: AudioStreamPlayer
var _efectos: Array[AudioStreamPlayer] = []
var _nombre_musica := ""
var _nombre_ambiente := ""
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_musica = _nuevo_reproductor()
	_musica_saliente = _nuevo_reproductor()
	_ambiente = _nuevo_reproductor()
	for i in 6:
		_efectos.append(_nuevo_reproductor())


func musica(nombre: String) -> void:
	if nombre == _nombre_musica:
		return
	_nombre_musica = nombre
	_cambiar(_musica, "musica", nombre, VOLUMEN_MUSICA, true)


func ambiente(nombre: String) -> void:
	if nombre == _nombre_ambiente:
		return
	_nombre_ambiente = nombre
	_cambiar(_ambiente, "ambiente", nombre, VOLUMEN_AMBIENTE, false)


func efecto(nombre: String, tono := 1.0, volumen_extra := 0.0) -> void:
	var s := _cargar("res://audio/sfx/%s.ogg" % nombre, false)
	if s == null:
		return
	for r in _efectos:
		if not r.playing:
			r.stream = s
			r.pitch_scale = tono
			r.volume_db = VOLUMEN_EFECTOS + volumen_extra
			r.play()
			return


func _cambiar(r: AudioStreamPlayer, carpeta: String, nombre: String, volumen: float, cruzar: bool) -> void:
	# La música que suena se apaga despacio mientras entra la nueva
	if r.playing:
		var viejo := _musica_saliente if cruzar else _nuevo_reproductor()
		viejo.stream = r.stream
		viejo.volume_db = r.volume_db
		viejo.play(r.get_playback_position())
		var t := create_tween()
		t.tween_property(viejo, "volume_db", -60.0, FUNDIDO)
		t.tween_callback(viejo.stop)
		if not cruzar:
			t.tween_callback(viejo.queue_free)
		r.stop()
	if nombre == "":
		return
	var s := _cargar("res://audio/%s/%s.ogg" % [carpeta, nombre], true)
	if s == null:
		return
	r.stream = s
	r.volume_db = -40.0
	r.play()
	create_tween().tween_property(r, "volume_db", volumen, FUNDIDO)


func _cargar(ruta: String, en_bucle: bool) -> AudioStream:
	if _cache.has(ruta):
		return _cache[ruta]
	var s: AudioStream = null
	if ResourceLoader.exists(ruta):
		s = load(ruta)
	if s is AudioStreamOggVorbis:
		s.loop = en_bucle
	_cache[ruta] = s
	return s


func _nuevo_reproductor() -> AudioStreamPlayer:
	var r := AudioStreamPlayer.new()
	add_child(r)
	return r
