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
	var dash_pressed = Input.is_key_pressed(KEY_SHIFT) or Input.is_action_just_pressed("dash")

	# Si se utiliza la habilidad y no esta en temporizador, activa el impulso
	if dash_pressed and cooldown_timer <= 0.0:
		cooldown_timer = player.DASH_COOLDOWN_TIME
		
		# Lee hacia qué lado esta apuntando con WASD
		var input_dir := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
		var dash_dir := Vector3.ZERO
		
		if input_dir != Vector2.ZERO:
			# Se impulsa hacia la dirección de la tecla presionada
			dash_dir = (player.get_move_basis() * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		else:
			# Si no hay ninguna tecla presionada, hace el impulso hacia adelante
			dash_dir = -player.get_move_basis().z

		# Mantiene la velocidad existente y orienta parte del impulso hacia el dash.
		var horizontal_velocity := Vector3(player.velocity.x, 0.0, player.velocity.z)
		var dash_speed := maxf(horizontal_velocity.length(), player.DASH_SPEED)
		var redirect := clampf(player.DASH_REDIRECT_STRENGTH, 0.0, 1.0)
		var preserved_direction: Vector3
		if horizontal_velocity.length_squared() > 0.001:
			preserved_direction = horizontal_velocity.normalized().slerp(dash_dir, redirect).normalized()
		else:
			preserved_direction = dash_dir
		player.velocity.x = preserved_direction.x * dash_speed
		player.velocity.z = preserved_direction.z * dash_speed
