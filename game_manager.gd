extends Node

var niveles: Array[String] = [
	"res://scenes/levels/lv_collums.tscn",
	"res://scenes/levels/lv_01.tscn",
	"res://scenes/levels/lv_2.tscn"
]

var nivel_actual: String = ""
var ultima_run: String = ""

var tiempo_actual: float = 0.0
var tiempo_final: float = 0.0
var mejor_tiempo: float = 0.0
var intentos: int = 0

var cronometro_activo: bool = false
var nivel_completado: bool = false
var nuevo_record: bool = false

# Datos independientes para cada nivel.
var mejores_tiempos: Dictionary = {}
var tiempos_finales: Dictionary = {}
var intentos_por_nivel: Dictionary = {}


func _ready():
	cargar_partida()


func _process(delta):
	if cronometro_activo:
		tiempo_actual += delta


func guardar_nivel(ruta: String):
	nivel_actual = ruta
	ultima_run = ruta
	guardar_partida()


func nueva_run():
	get_tree().paused = false

	nivel_actual = niveles[0]
	ultima_run = nivel_actual

	guardar_partida()
	get_tree().change_scene_to_file(nivel_actual)


func continuar_run():
	if ultima_run != "":
		get_tree().paused = false
		get_tree().change_scene_to_file(ultima_run)
	else:
		print("No existe una run guardada.")


func reiniciar_nivel():
	if nivel_actual != "":
		get_tree().paused = false
		get_tree().change_scene_to_file(nivel_actual)
	else:
		print("ERROR: No hay un nivel guardado.")


func iniciar_cronometro():
	nivel_actual = get_tree().current_scene.scene_file_path
	ultima_run = nivel_actual

	tiempo_actual = 0.0
	tiempo_final = 0.0
	nivel_completado = false
	nuevo_record = false
	cronometro_activo = true

	intentos = int(intentos_por_nivel.get(nivel_actual, 0)) + 1
	intentos_por_nivel[nivel_actual] = intentos

	# Cargar el récord correspondiente a este nivel.
	mejor_tiempo = float(mejores_tiempos.get(nivel_actual, 0.0))

	guardar_partida()


func completar_nivel():
	if nivel_completado:
		return

	cronometro_activo = false
	nivel_completado = true

	tiempo_final = tiempo_actual
	tiempos_finales[nivel_actual] = tiempo_final

	mejor_tiempo = float(mejores_tiempos.get(nivel_actual, 0.0))
	nuevo_record = false

	if mejor_tiempo == 0.0 or tiempo_final < mejor_tiempo:
		mejor_tiempo = tiempo_final
		mejores_tiempos[nivel_actual] = mejor_tiempo
		nuevo_record = true

	guardar_partida()

	print("Nivel: ", nivel_actual)
	print("Tiempo final: ", tiempo_final)
	print("Mejor tiempo: ", mejor_tiempo)
	print("Intentos: ", intentos)

	if nuevo_record:
		print("¡NUEVO RÉCORD!")



func avanzar_nivel() -> void:
	print("Se pulsó avanzar nivel")

	var escena_actual = get_tree().current_scene.scene_file_path
	print("Escena actual: ", escena_actual)

	var indice_actual = niveles.find(escena_actual)

	if indice_actual == -1:
		push_error("La escena actual no está en la lista: " + escena_actual)
		return

	if indice_actual + 1 >= niveles.size():
		print("¡Completaste todos los niveles!")
		return

	var siguiente = niveles[indice_actual + 1]
	print("Cargando siguiente nivel: ", siguiente)

	nivel_actual = siguiente
	ultima_run = siguiente
	guardar_partida()

	get_tree().paused = false

	var error = get_tree().change_scene_to_file(siguiente)

	if error != OK:
		push_error("Error al cargar la escena: " + siguiente)



func guardar_partida():
	var datos = {
		"ultima_run": ultima_run,
		"mejores_tiempos": mejores_tiempos,
		"tiempos_finales": tiempos_finales,
		"intentos_por_nivel": intentos_por_nivel
	}

	var archivo = FileAccess.open(
		"user://savegame.save",
		FileAccess.WRITE
	)

	if archivo == null:
		push_error("No se pudo guardar la partida.")
		return

	archivo.store_string(JSON.stringify(datos))
	archivo.close()



func cargar_partida():
	if not FileAccess.file_exists("user://savegame.save"):
		return

	var archivo = FileAccess.open(
		"user://savegame.save",
		FileAccess.READ
	)

	if archivo == null:
		push_error("No se pudo abrir el archivo de guardado.")
		return

	var contenido = archivo.get_as_text().strip_edges()
	archivo.close()

	
	if contenido.begins_with("res://"):
		ultima_run = contenido
		nivel_actual = ultima_run
		guardar_partida()
		print("Guardado antiguo convertido correctamente.")
		return
	var datos = JSON.parse_string(contenido)

	if datos is Dictionary:
		ultima_run = str(datos.get("ultima_run", ""))
		mejores_tiempos = datos.get("mejores_tiempos", {})
		tiempos_finales = datos.get("tiempos_finales", {})
		intentos_por_nivel = datos.get("intentos_por_nivel", {})

		nivel_actual = ultima_run
		print("Partida y récords cargados.")
	else:
		push_error("El archivo de guardado no tiene un formato válido.")
