class_name Dash
extends Node

var player: Player
var cooldown_timer: float = 0.0

func _ready() -> void:
	player = get_parent().get_parent() as Player

func check_and_update(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	var dash_pressed = Input.is_key_pressed(KEY_Q) or Input.is_action_just_pressed("dash")

	if dash_pressed and cooldown_timer <= 0.0:
		cooldown_timer = player.DASH_COOLDOWN_TIME
		
		# Lee la entrada del jugador (WASD)
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var dash_dir := Vector3.ZERO
		
		if input_dir != Vector2.ZERO:
			dash_dir = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		else:
			# Dash hacia adelante por defecto si no hay input
			dash_dir = -player.transform.basis.z

		player.velocity.x = dash_dir.x * player.DASH_SPEED
		player.velocity.z = dash_dir.z * player.DASH_SPEED
		
		if not player.is_on_floor():
			player.velocity.y = move_toward(player.velocity.y, 0, player.JUMP_VELOCITY * 0.5)
