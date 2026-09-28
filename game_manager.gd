extends Node

var nivel_actual: String = ""
var tiempo_actual: float = 0.0


func guardar_nivel(ruta: String):
	nivel_actual = ruta
	print("Nivel guardado: ", nivel_actual)


func reiniciar_nivel():
	print("Reiniciando: ", nivel_actual)

	if nivel_actual != "":
		get_tree().change_scene_to_file(nivel_actual)
	else:
		print("ERROR: No hay un nivel guardado.")
