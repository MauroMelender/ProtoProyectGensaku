extends Control

@onready var label2: RichTextLabel = $VBoxContainer/Label2
@onready var boton_reiniciar: Button = $VBoxContainer/Reiniciar
@onready var boton_salir: Button = $VBoxContainer/Salir


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Texto con "CONSUMIÓ" resplandeciendo en rojo
	label2.text = "[center]EL BORRADO TE [color=#FF3333]CONSUMIÓ[/color][/center]"
	
	# Configurar Tweens de Hover para los botones
	for boton in [boton_reiniciar, boton_salir]:
		boton.pivot_offset = boton.size / 2.0
		boton.mouse_entered.connect(_animar_hover.bind(boton, 1.05))
		boton.mouse_exited.connect(_animar_hover.bind(boton, 1.0))


func _animar_hover(boton: Button, escala_objetivo: float):
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(boton, "scale", Vector2.ONE * escala_objetivo, 0.15)


func _animar_click_y_ejecutar(boton: Button, metodo_callback: Callable):
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(boton, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(boton, "scale", Vector2(1.05, 1.05), 0.08)
	tween.finished.connect(metodo_callback)


func _on_reiniciar_pressed():
	_animar_click_y_ejecutar(boton_reiniciar, func(): GameManager.reiniciar_nivel())


func _on_salir_pressed():
	_animar_click_y_ejecutar(boton_salir, func(): get_tree().quit())
