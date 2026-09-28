extends Control


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_salir_pressed():
	get_tree().quit()


func _on_reiniciar_pressed():
	GameManager.reiniciar_nivel()
