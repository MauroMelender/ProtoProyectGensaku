extends Panel

@onready var label_tiempo_final = $VBoxContainer/LabelTiempoFinal
@onready var label_record = $VBoxContainer/LabelRecord

func _ready():
	visible = false


func mostrar_resultado():
	visible = true

	label_tiempo_final.text = "Tiempo: %.2f segundos" % GameManager.tiempo_final

	if GameManager.nuevo_record:
		label_record.text = "¡NUEVO RÉCORD!"
	else:
		label_record.text = "Mejor tiempo: %.2f segundos" % GameManager.mejor_tiempo
