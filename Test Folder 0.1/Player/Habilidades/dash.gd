class_name Dash
extends Node

var player: Player
var cooldown_timer: float = 0.0 # Temporizador de espera

func _ready() -> void:
	# Obtiene la referencia al script principal del jugador
	player = get_parent().get_parent() as Player

func check_and_update(delta: float) -> void:
	# Reduce el tiempo de espera
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	# Detecta si se usa la tecla Q
	var dash_pressed = Input.is_key_pressed(KEY_Q) or Input.is_action_just_pressed("dash")

	# Si se utiliza la habilidad y no esta en temporizador, activa el impulso
	if dash_pressed and cooldown_timer <= 0.0:
		cooldown_timer = player.DASH_COOLDOWN_TIME
		
		# Lee hacia qué lado esta apuntando con WASD
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var dash_dir := Vector3.ZERO
		
		if input_dir != Vector2.ZERO:
			# Se impulsa hacia la dirección de la tecla presionada
			dash_dir = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		else:
			# Si no hay ninguna tecla presionada, hace el impulso hacia adelante
			dash_dir = -player.transform.basis.z

		# Aplica la velocidad del Dash
		player.velocity.x = dash_dir.x * player.DASH_SPEED
		player.velocity.z = dash_dir.z * player.DASH_SPEED
		
		# Si se usa en el aire, suaviza un poco la caída para que vuele recto
		if not player.is_on_floor():
			player.velocity.y = move_toward(player.velocity.y, 0, player.JUMP_VELOCITY * 0.5)
