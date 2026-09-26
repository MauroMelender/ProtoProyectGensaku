extends Node

var nivel_actual: String = ""
var siguiente_nivel: String = ""
var reiniciar

func guardar_nivel_actual(ruta: String):
	nivel_actual = ruta


func reiniciar_nivel():
	if nivel_actual != "":
		get_tree().change_scene_to_file(nivel_actual)


func ir_al_siguiente_nivel():
	if siguiente_nivel != "":
		get_tree().change_scene_to_file(siguiente_nivel)
