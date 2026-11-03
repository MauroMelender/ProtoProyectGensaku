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
	"res://scenes/levels/lv_02.tscn"
]
const LEGACY_STATS_PATH: String = "user://speedrun_stats.json"
const METRICS_FOLDER: String = "Metricas"
var stats_por_nivel: Dictionary = {}
var mejor_rastro: Array = []
var rastro_actual: Array = []

var indice_nivel: int = 0

var nuevo_record: bool = false
var tiempo_partida: float = 0.0
var tiempo_ultima_muerte: float = 0.0
var muertes_partida: Array = []

func _ready():
	_asegurar_carpeta_metricas()
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
	tiempo_partida = 0.0
	tiempo_ultima_muerte = 0.0
	muertes_partida.clear()

	nivel_completado = false
	cronometro_activo = false
	conteo_inicio_activo = false

	var clave := _clave_nivel_actual()
	var stats: Dictionary = stats_por_nivel.get(clave, {"record": 0.0, "intentos": 0, "runs": [], "caidas": []})
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
	var ruta := _ruta_metrica("speedrun_stats.json")
	if not FileAccess.file_exists(ruta):
		if not FileAccess.file_exists(LEGACY_STATS_PATH):
			return
		ruta = LEGACY_STATS_PATH
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return
	var datos: Variant = JSON.parse_string(archivo.get_as_text())
	if datos is Dictionary:
		stats_por_nivel = datos.get("levels", datos)

func _guardar_estadisticas() -> void:
	var archivo := FileAccess.open(_ruta_metrica("speedrun_stats.json"), FileAccess.WRITE)
	if archivo != null:
		archivo.store_string(JSON.stringify({"version": 2, "levels": stats_por_nivel}))
		archivo.close()
	_exportar_tablas_csv()

func _csv_celda(valor: Variant) -> String:
	var texto := str(valor)
	if valor is float:
		texto = texto.replace(".", ",")
	texto = texto.replace("\"", "\"\"")
	return "\"%s\"" % texto

func _escribir_csv(ruta: String, filas: Array) -> void:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_warning("No se pudo exportar CSV: %s" % ruta)
		return
	for fila in filas:
		var celdas: PackedStringArray = []
		for valor in fila:
			celdas.append(_csv_celda(valor))
		archivo.store_line(";".join(celdas))
	archivo.close()

func _exportar_tablas_csv() -> void:
	var filas_partidas: Array = [["nivel", "intento_acumulado", "resultado", "duracion_segundos", "tiempo_hasta_meta_segundos", "mejor_tiempo_segundos", "muertes_en_partida", "tiempo_ultima_muerte_segundos"]]
	var filas_caidas: Array = [["nivel", "x", "y", "z", "tiempo_en_partida_segundos"]]
	var filas_resumen: Array = [["nivel", "intentos", "partidas_completadas", "promedio_completadas_segundos", "mejor_tiempo_segundos", "caidas_registradas"]]
	for clave in stats_por_nivel:
		var stats: Dictionary = stats_por_nivel[clave]
		var runs: Array = stats.get("runs", [])
		var caidas: Array = stats.get("caidas", [])
		var tiempos: Array[float] = []
		var numero_intento: int = maxi(1, int(stats.get("intentos", 0)) - runs.size() + 1)
		for run in runs:
			var tiempo_meta: Variant = run.get("tiempo_hasta_meta", null)
			var muertes_run: Array = run.get("caidas", [])
			if tiempo_meta != null:
				tiempos.append(float(tiempo_meta))
			filas_partidas.append([clave, numero_intento, run.get("resultado", ""), run.get("duracion", 0.0), tiempo_meta if tiempo_meta != null else "", stats.get("record", 0.0), muertes_run.size(), run.get("tiempo_ultima_muerte", 0.0)])
			numero_intento += 1
		for caida in caidas:
			filas_caidas.append([clave, caida.get("x", 0.0), caida.get("y", 0.0), caida.get("z", 0.0), caida.get("t", 0.0)])
		var promedio := 0.0
		if not tiempos.is_empty():
			for tiempo in tiempos:
				promedio += tiempo
			promedio /= tiempos.size()
		filas_resumen.append([clave, stats.get("intentos", 0), tiempos.size(), promedio if not tiempos.is_empty() else "", stats.get("record", 0.0), caidas.size()])
	_escribir_csv(_ruta_metrica("metricas_partidas.csv"), filas_partidas)
	_escribir_csv(_ruta_metrica("mapa_calor_caidas.csv"), filas_caidas)
	_escribir_csv(_ruta_metrica("resumen_metricas.csv"), filas_resumen)

func _directorio_metricas() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://" + METRICS_FOLDER)
	return "user://" + METRICS_FOLDER

func _ruta_metrica(nombre_archivo: String) -> String:
	return _directorio_metricas().path_join(nombre_archivo)

func _asegurar_carpeta_metricas() -> void:
	var directorio := _directorio_metricas()
	if directorio.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directorio))
	else:
		DirAccess.make_dir_recursive_absolute(directorio)

func registrar_caida(posicion: Vector3) -> void:
	if not cronometro_activo:
		return
	tiempo_ultima_muerte = tiempo_actual
	tiempo_partida = tiempo_actual
	var punto := {"x": posicion.x, "y": posicion.y, "z": posicion.z, "t": tiempo_actual}
	muertes_partida.append(punto)
	var clave := _clave_nivel_actual()
	var stats: Dictionary = stats_por_nivel.get(clave, {"record": 0.0, "intentos": intentos, "runs": [], "caidas": []})
	var caidas: Array = stats.get("caidas", [])
	caidas.append(punto.duplicate(true))
	stats["caidas"] = caidas
	stats_por_nivel[clave] = stats
	_guardar_estadisticas()

func finalizar_por_caida(posicion: Vector3) -> void:
	if not niveles.has(_clave_nivel_actual()):
		return
	registrar_caida(posicion)
	cronometro_activo = false
	conteo_inicio_activo = false
	guardar_nivel(_clave_nivel_actual())
	_registrar_resultado("caida", tiempo_actual)
	get_tree().call_deferred("change_scene_to_file", "res://game_over.tscn")

func _registrar_resultado(resultado: String, duracion: float) -> void:
	var clave := _clave_nivel_actual()
	var stats: Dictionary = stats_por_nivel.get(clave, {"record": 0.0, "intentos": intentos, "runs": [], "caidas": []})
	var runs: Array = stats.get("runs", [])
	runs.append({"resultado": resultado, "duracion": duracion, "tiempo_hasta_meta": duracion if resultado == "completada" else null, "tiempo_ultima_muerte": tiempo_ultima_muerte, "caidas": muertes_partida.duplicate(true)})
	stats["runs"] = runs
	stats["intentos"] = maxi(int(stats.get("intentos", 0)), intentos)
	stats_por_nivel[clave] = stats
	_guardar_estadisticas()

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
	tiempo_partida = tiempo_final

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
	_registrar_resultado("completada", tiempo_final)

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
