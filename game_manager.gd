extends Node

var nivel_actual: String = ""
var ultima_run: String = ""
var tiempo_actual: float = 0.0
var tiempo_final: float = 0.0
var mejor_tiempo: float = 0.0
var intentos: int = 0
var cronometro_activo: bool = false
var nivel_completado: bool = false

var nuevo_record: bool = false

func _ready():
	cargar_partida()


func guardar_nivel(ruta: String):
	nivel_actual = ruta
	ultima_run = ruta
	
	guardar_partida()
	
	print("Nivel guardado: ", nivel_actual)


func reiniciar_nivel():
	if nivel_actual != "":
		get_tree().change_scene_to_file(nivel_actual)
	else:
		print("ERROR: No hay un nivel guardado.")


func nueva_run():
	nivel_actual = "res://nivel1.tscn"
	ultima_run = nivel_actual
	
	guardar_partida()
	
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
	cronometro_activo = true

	intentos += 1


func _process(delta):
	if cronometro_activo:
		tiempo_actual += delta

func completar_nivel():
	if nivel_completado:
		return

	cronometro_activo = false
	nivel_completado = true

	tiempo_final = tiempo_actual

	nuevo_record = false

	if mejor_tiempo == 0.0 or tiempo_final < mejor_tiempo:
		mejor_tiempo = tiempo_final
		nuevo_record = true

	if nuevo_record:
		print("¡NUEVO RÉCORD!")

	print("Tiempo final: ", tiempo_final)
	print("Mejor tiempo: ", mejor_tiempo)
	print("Intentos: ", intentos)
