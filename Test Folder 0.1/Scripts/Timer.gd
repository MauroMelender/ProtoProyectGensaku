extends Node3D

@onready var tiempo_label = $CanvasLayer/TiempoLabel

func _ready():
	GameManager.iniciar_cronometro()


func _process(_delta):
	tiempo_label.text = "Tiempo: %.2f" % GameManager.tiempo_actual
