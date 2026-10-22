extends Control

@onready var boton_continuar: Button = $Botones/continuar
@onready var boton_nueva_run: Button = $Botones/nuevarun
@onready var boton_salir: Button = $Botones/salir

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$AnimationPlayer.play("Menu_Buttons_Animation") 
	
	# Comprobar si se puede continuar
	if GameManager.ultima_run == "":
		boton_continuar.disabled = true
	
	# Animación de entrada para todo el menú (Fade In)
	modulate.a = 0.0
	var tween_fade = create_tween()
	tween_fade.tween_property(self, "modulate:a", 1.0, 0.4)
	
	# Conectar animaciones de Hover a los botones
	for boton in [boton_continuar, boton_nueva_run, boton_salir]:
		if not boton.disabled:
			# Ajustar el pivote al centro del botón para que escale desde el medio
			boton.pivot_offset = boton.size / 2.0
			boton.mouse_entered.connect(_animar_hover.bind(boton, 1.05))
			boton.mouse_exited.connect(_animar_hover.bind(boton, 1.0))


func _animar_hover(boton: Button, escala_objetivo: float):
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(boton, "scale", Vector2.ONE * escala_objetivo, 0.15)


func _animar_click_y_ejecutar(boton: Button, metodo_callback: Callable):
	# Efecto de pulsado (se achica un poco y vuelve a crecer rápido)
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(boton, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(boton, "scale", Vector2(1.05, 1.05), 0.08)
	
	# Ejecuta la función del botón al terminar la animación
	tween.finished.connect(metodo_callback)


func _on_continuar_pressed():
	_animar_click_y_ejecutar(boton_continuar, func(): GameManager.continuar_run())


func _on_nuevarun_pressed():
	_animar_click_y_ejecutar(boton_nueva_run, func(): GameManager.nueva_run())


func _on_salir_pressed():
	_animar_click_y_ejecutar(boton_salir, func(): get_tree().quit())
