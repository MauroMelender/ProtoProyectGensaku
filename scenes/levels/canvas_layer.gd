extends CanvasLayer

@onready var panel_resultado = $PanelResultado
@onready var label_tiempo_final = $PanelResultado/VBoxContainer/LabelTiempoFinal
@onready var label_record = $PanelResultado/VBoxContainer/LabelRecord
@onready var boton_siguiente = $PanelResultado/VBoxContainer/ButtonSiguienteNivel


func _ready():
	panel_resultado.visible = false


func mostrar_resultado():
	boton_siguiente.visible =true
	panel_resultado.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	boton_siguiente.disabled = (
	GameManager.indice_nivel + 1 >= GameManager.niveles.size()
)
	label_tiempo_final.text = "Tiempo: %.2f segundos" % GameManager.tiempo_final

	if GameManager.nuevo_record:
		label_record.text = "¡NUEVO RÉCORD!"
	else:
		label_record.text = "Mejor tiempo: %.2f segundos" % GameManager.mejor_tiempo
	


func _on_button_siguiente_nivel_pressed():
	GameManager.avanzar_nivel()
