extends Node3D
var tiempo_transcurrido := 0.0
var jugando := true

func _process(delta):
	if jugando:
		tiempo_transcurrido += delta
		GameManager.tiempo_actual = tiempo_transcurrido
