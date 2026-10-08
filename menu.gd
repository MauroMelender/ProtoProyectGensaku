extends Control

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if GameManager.ultima_run == "":
		$Botones/continuar.disabled = true

func _on_continuar_pressed():
	GameManager.continuar_run()


func _on_nuevarun_pressed():
	GameManager.nueva_run()


func _on_salir_pressed():
	get_tree().quit()
