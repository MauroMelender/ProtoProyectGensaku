class_name Dash
extends Node

var player: Player
var cooldown_timer: float = 0.0

# Referencia al nodo de audio dentro del Dash
@onready var audio_dash: AudioStreamPlayer3D = $AudioDash

func _ready() -> void:
	player = get_parent().get_parent() as Player

func check_and_update(delta: float) -> void:
	if player.current_state == Player.State.SLIDING:
		return
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	var dash_pressed = Input.is_key_pressed(KEY_SHIFT) or Input.is_action_just_pressed("dash")

	if dash_pressed and cooldown_timer <= 0.0:
		cooldown_timer = player.DASH_COOLDOWN_TIME
		
		# 🔊 Reproducir sonido del Dash con variación sutil de tono
		if audio_dash and audio_dash.stream:
			audio_dash.pitch_scale = randf_range(0.92, 1.08)
			audio_dash.play()
		
		var input_dir := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
		var dash_dir := Vector3.ZERO
		
		if input_dir != Vector2.ZERO:
			dash_dir = (player.get_move_basis() * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		else:
			dash_dir = -player.get_move_basis().z

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
