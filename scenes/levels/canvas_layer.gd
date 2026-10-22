extends CanvasLayer

@onready var panel_resultado = $PanelResultado
@onready var label_tiempo_final = $PanelResultado/VBoxContainer/LabelTiempoFinal
@onready var label_record = $PanelResultado/VBoxContainer/LabelRecord
@onready var boton_siguiente = $PanelResultado/VBoxContainer/ButtonSiguienteNivel


func _ready():
	panel_resultado.visible = false


func mostrar_resultado():
	boton_siguiente.visible = true
	panel_resultado.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	boton_siguiente.disabled = (
		GameManager.indice_nivel + 1 >= GameManager.niveles.size()
	)
	
	# El texto base mantendrá el color del tema (negro), y el BBCode resalta el número con un color vistoso
	label_tiempo_final.text = "[center]Tiempo: [color=#FFD700]%.2f[/color][/center]" % GameManager.tiempo_final

	if GameManager.nuevo_record:
		label_record.text = "[center][color=#FFD700]¡NUEVO RÉCORD![/color][/center]"
	else:
		label_record.text = "[center]Mejor tiempo: [color=#00AA00]%.2f[/color][/center]" % GameManager.mejor_tiempo
	


func _on_button_siguiente_nivel_pressed():
	GameManager.avanzar_nivel()
