extends CanvasLayer

@onready var panel_resultado = $PanelResultado
@onready var label_tiempo_final = $PanelResultado/VBoxContainer/LabelTiempoFinal
@onready var label_record = $PanelResultado/VBoxContainer/LabelRecord

func _ready():
	panel_resultado.visible = false


func mostrar_resultado():
	panel_resultado.visible = true

	label_tiempo_final.text = "Tiempo: %.2f segundos" % GameManager.tiempo_final

	if GameManager.nuevo_record:
		label_record.text = "¡NUEVO RÉCORD!"
	else:
		label_record.text = "Mejor tiempo: %.2f segundos" % GameManager.mejor_tiempo
