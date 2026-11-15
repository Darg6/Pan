@tool
extends EditorPlugin
## Después de un Pull, a veces Godot no importa los PNG / OGG / TTF nuevos (por ejemplo si
## estaba abierto mientras GitHub Desktop cambiaba los archivos, o si se pulsa F5 antes de que
## termine la barra de importación). Entonces los tilesets y mapas no cargan.
##
## Este plugin revisa cada archivo que tiene su ".import" y, si a Godot le falta la versión
## importada (o quedó de una versión vieja del archivo), la importa en el momento:
##   - al abrir Godot y cada vez que Godot termina de revisar los archivos,
##   - y justo antes de correr el juego (F5 / F6).
## Así nunca hace falta borrar la carpeta .godot a mano.

var _intentados := {}  # ruta -> md5 ya intentado, para no reintentar en bucle un archivo roto
var _importando := false  # Godot está importando por su cuenta: no hay que meterse


func _enter_tree() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	fs.filesystem_changed.connect(_al_cambiar_archivos)
	fs.resources_reimporting.connect(_al_empezar_importacion)
	fs.resources_reimported.connect(_al_terminar_importacion)
	_al_cambiar_archivos.call_deferred()


func _exit_tree() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	fs.filesystem_changed.disconnect(_al_cambiar_archivos)
	fs.resources_reimporting.disconnect(_al_empezar_importacion)
	fs.resources_reimported.disconnect(_al_terminar_importacion)


## Se llama justo antes de correr el juego (F5 / F6). Importa lo que falte y deja correr.
func _build() -> bool:
	if not _importando:
		reimportar_faltantes()
	return true


func _al_empezar_importacion(_archivos: PackedStringArray) -> void:
	_importando = true


func _al_terminar_importacion(_archivos: PackedStringArray) -> void:
	_importando = false


func _al_cambiar_archivos() -> void:
	if not _importando and not EditorInterface.get_resource_filesystem().is_scanning():
		reimportar_faltantes()


## Devuelve los archivos que importó (vacío si todo estaba al día).
func reimportar_faltantes() -> PackedStringArray:
	var faltan := PackedStringArray()
	_buscar("res://", faltan)
	var nuevos := PackedStringArray()
	for ruta in faltan:
		var md5 := FileAccess.get_md5(ruta)
		if _intentados.get(ruta, "") != md5:
			_intentados[ruta] = md5
			nuevos.append(ruta)
	if nuevos.is_empty():
		return nuevos
	_importando = true
	print("Importador Pan: importando %d archivo(s) que Godot no tenía al día: %s" % [nuevos.size(), ", ".join(nuevos)])
	EditorInterface.get_resource_filesystem().reimport_files(nuevos)
	_importando = false
	return nuevos


func _buscar(carpeta: String, faltan: PackedStringArray) -> void:
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return
	dir.include_hidden = false
	for sub in dir.get_directories():
		if sub.begins_with(".") or sub == "addons" or sub == "android" or sub == "exportar":
			continue
		_buscar(carpeta.path_join(sub), faltan)
	for archivo in dir.get_files():
		if archivo.ends_with(".import"):
			var fuente := carpeta.path_join(archivo.trim_suffix(".import"))
			if FileAccess.file_exists(fuente) and necesita_importar(fuente):
				faltan.append(fuente)


## true si Godot no tiene la versión importada de este archivo, o la tiene de una versión vieja.
static func necesita_importar(fuente: String) -> bool:
	var info := ConfigFile.new()
	if info.load(fuente + ".import") != OK:
		return false
	var importador := str(info.get_value("remap", "importer", ""))
	if importador == "" or importador == "keep" or importador == "skip":
		return false
	var destinos: Array = info.get_value("deps", "dest_files", [])
	if destinos.is_empty():
		return true
	for destino in destinos:
		if not FileAccess.file_exists(str(destino)):
			return true
	# Godot guarda la huella del archivo original junto a lo importado.
	var md5 := ConfigFile.new()
	var ruta_md5 := "res://.godot/imported/%s-%s.md5" % [fuente.get_file(), fuente.md5_text()]
	if md5.load(ruta_md5) != OK:
		return true
	return str(md5.get_value("", "source_md5", "")) != FileAccess.get_md5(fuente)
