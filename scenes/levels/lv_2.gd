extends Node3D

var tiempo_transcurrido := 0.0
var jugando := true
var tiempo_actual: float = 0.0
@onready var tiempo_label = $CanvasLayer/TiempoLabel


func _process(delta):
	if jugando:
		tiempo_transcurrido += delta
		GameManager.tiempo_actual = tiempo_transcurrido

		tiempo_label.text = "Tiempo: %.2f" % tiempo_transcurrido
