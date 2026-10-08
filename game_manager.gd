extends Node

var nivel_actual: String = ""
var ultima_run: String = ""
var tiempo_actual: float = 0.0

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
	nivel_actual = "res://scenes/levels/lv_01.tscn"
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
