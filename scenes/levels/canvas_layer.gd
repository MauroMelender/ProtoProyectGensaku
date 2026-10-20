
extends CanvasLayer

@onready var panel_resultado = $PanelResultado
@onready var label_tiempo_final = $PanelResultado/VBoxContainer/LabelTiempoFinal
@onready var label_record = $PanelResultado/VBoxContainer/LabelRecord
@onready var boton_siguiente = $PanelResultado/VBoxContainer/ButtonSiguienteNivel


func _ready() -> void:
	# Ocultar el panel al comenzar el nivel.
	panel_resultado.hide()

	# Permitir usar los botones aunque el juego esté pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS


func mostrar_resultado() -> void:
	# Liberar y mostrar el cursor del mouse.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Mostrar el panel de resultados.
	panel_resultado.show()

	# Mostrar el tiempo final.
	label_tiempo_final.text = "Tiempo final: %.2f segundos" % GameManager.tiempo_final

	# Mostrar el récord.
	if GameManager.nuevo_record:
		label_record.text = "¡Nuevo récord!"
	else:
		label_record.text = "Mejor tiempo: %.2f segundos" % GameManager.mejor_tiempo

	# Comprobar si existe un siguiente nivel.
	var escena_actual = get_tree().current_scene.scene_file_path
	var indice_actual = GameManager.niveles.find(escena_actual)

	boton_siguiente.disabled = (
		indice_actual == -1
		or indice_actual + 1 >= GameManager.niveles.size()
	)

	if boton_siguiente.disabled:
		boton_siguiente.text = "¡Todos los niveles completados!"
	else:
		boton_siguiente.text = "Siguiente nivel"


func _on_button_siguiente_nivel_pressed() -> void:
	GameManager.avanzar_nivel()


func _on_button_salir_menu_pressed():
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
