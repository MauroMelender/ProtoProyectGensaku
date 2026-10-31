extends Node

var nivel_actual: String = ""
var ultima_run: String = ""
var tiempo_actual: float = 0.0
var tiempo_final: float = 0.0
var mejor_tiempo: float = 0.0
var intentos: int = 0
var cronometro_activo: bool = false
var nivel_completado: bool = false
var conteo_inicio_activo: bool = false
var niveles: Array[String] = [
	"res://scenes/levels/lv_01.tscn",
	"res://scenes/levels/lv_2.tscn"
]
const STATS_PATH: String = "user://speedrun_stats.json"
var stats_por_nivel: Dictionary = {}
var mejor_rastro: Array = []
var rastro_actual: Array = []

var indice_nivel: int = 0

var nuevo_record: bool = false

func _ready():
	_cargar_estadisticas()
	cronometro_activo = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode != KEY_R:
		return
	if not _esta_en_nivel_o_game_over():
		return
	reiniciar_nivel()
	get_viewport().set_input_as_handled()

func _esta_en_nivel_o_game_over() -> bool:
	var escena := get_tree().current_scene
	if escena == null:
		return false
	return niveles.has(escena.scene_file_path) or escena.scene_file_path == "res://game_over.tscn"

func guardar_nivel(ruta: String):
	nivel_actual = ruta
	ultima_run = ruta
	
	guardar_partida()
	
	print("Nivel guardado: ", nivel_actual)


func reiniciar_nivel():
	var escena := get_tree().current_scene
	var ruta := escena.scene_file_path if escena != null and niveles.has(escena.scene_file_path) else nivel_actual
	if ruta != "":
		cronometro_activo = false
		conteo_inicio_activo = false
		get_tree().paused = false
		get_tree().change_scene_to_file(ruta)
	else:
		print("ERROR: No hay un nivel guardado.")


func nueva_run():
	indice_nivel = 0
	nivel_actual = niveles[indice_nivel]
	ultima_run = nivel_actual

	guardar_partida()

	get_tree().paused = false
	get_tree().change_scene_to_file(nivel_actual)

func continuar_run():
	if ultima_run != "":
		get_tree().change_scene_to_file(ultima_run)
	else:
		print("No existe una run guardada.")


func guardar_partida():
	var archivo = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	
	archivo.store_string(ultima_run)
	
	archivo.close()


func cargar_partida():
	if FileAccess.file_exists("user://savegame.save"):
		var archivo = FileAccess.open("user://savegame.save", FileAccess.READ)
		
		ultima_run = archivo.get_as_text()
		
		archivo.close()
		
		print("Partida encontrada: ", ultima_run)

func iniciar_cronometro():
	tiempo_actual = 0.0
	tiempo_final = 0.0

	nivel_completado = false
	cronometro_activo = false
	conteo_inicio_activo = false

	var clave := _clave_nivel_actual()
	var stats: Dictionary = stats_por_nivel.get(clave, {"record": 0.0, "intentos": 0})
	intentos = int(stats.get("intentos", 0)) + 1
	stats["intentos"] = intentos
	stats_por_nivel[clave] = stats
	mejor_tiempo = float(stats.get("record", 0.0))
	mejor_rastro = stats.get("recorrido", [])
	rastro_actual.clear()
	_guardar_estadisticas()

func registrar_paso_rastro(paso: Dictionary) -> void:
	if cronometro_activo:
		rastro_actual.append(paso)

func activar_cronometro():
	cronometro_activo = true

func _clave_nivel_actual() -> String:
	var escena := get_tree().current_scene
	if escena != null and not escena.scene_file_path.is_empty():
		return escena.scene_file_path
	return nivel_actual

func _cargar_estadisticas() -> void:
	if not FileAccess.file_exists(STATS_PATH):
		return
	var archivo := FileAccess.open(STATS_PATH, FileAccess.READ)
	if archivo == null:
		return
	var datos: Variant = JSON.parse_string(archivo.get_as_text())
	if datos is Dictionary:
		stats_por_nivel = datos

func _guardar_estadisticas() -> void:
	var archivo := FileAccess.open(STATS_PATH, FileAccess.WRITE)
	if archivo != null:
		archivo.store_string(JSON.stringify(stats_por_nivel))

func avanzar_nivel():
	print("Botón Siguiente nivel pulsado")
	var nivel_indice := obtener_indice_nivel_actual()
	print("Índice actual: ", nivel_indice)

	if nivel_indice + 1 < niveles.size():
		indice_nivel = nivel_indice + 1
		nivel_actual = niveles[indice_nivel]
		ultima_run = nivel_actual

		guardar_partida()

		get_tree().paused = false
		get_tree().change_scene_to_file(nivel_actual)
	else:
		print("¡Completaste todos los niveles!")

func obtener_indice_nivel_actual() -> int:
	var escena := get_tree().current_scene
	if escena != null:
		var indice_escena := niveles.find(escena.scene_file_path)
		if indice_escena >= 0:
			indice_nivel = indice_escena
	return indice_nivel

func _process(delta):
	if cronometro_activo:
		tiempo_actual += delta

func completar_nivel():
	if nivel_completado:
		return

	cronometro_activo = false
	nivel_completado = true

	tiempo_final = tiempo_actual

	var clave := _clave_nivel_actual()
	var stats: Dictionary = stats_por_nivel.get(clave, {"record": 0.0, "intentos": intentos})
	mejor_tiempo = float(stats.get("record", 0.0))
	nuevo_record = false

	if mejor_tiempo == 0.0 or tiempo_final < mejor_tiempo:
		mejor_tiempo = tiempo_final
		nuevo_record = true
		stats["record"] = mejor_tiempo
		stats["recorrido"] = rastro_actual.duplicate(true)
		stats_por_nivel[clave] = stats
		mejor_rastro = stats["recorrido"]
		_guardar_estadisticas()

	if nuevo_record:
		print("¡NUEVO RÉCORD!")

	print("Tiempo final: ", tiempo_final)
	print("Mejor tiempo: ", mejor_tiempo)
	print("Intentos: ", intentos)

func resetear_record_actual() -> void:
	var clave := _clave_nivel_actual()
	var stats: Dictionary = stats_por_nivel.get(clave, {"intentos": intentos})
	stats["record"] = 0.0
	stats.erase("recorrido")
	stats_por_nivel[clave] = stats
	mejor_tiempo = 0.0
	mejor_rastro.clear()
	nuevo_record = false
	_guardar_estadisticas()
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.clear_best_time_trail()
