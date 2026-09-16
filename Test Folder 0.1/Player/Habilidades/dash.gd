class_name Dash
extends Node

var player: Player
var cooldown_timer: float = 0.0

func _ready() -> void:
	player = get_parent().get_parent() as Player # Accede al Player raíz

func check_and_update(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	var dash_pressed = Input.is_key_pressed(KEY_Q) or Input.is_action_just_pressed("dash")

	if dash_pressed and cooldown_timer <= 0.0:
		cooldown_timer = player.DASH_COOLDOWN_TIME
		
		var forward_dir := -player.transform.basis.z
		player.velocity.x = forward_dir.x * player.DASH_SPEED
		player.velocity.z = forward_dir.z * player.DASH_SPEED
		
		if not player.is_on_floor():
			player.velocity.y = move_toward(player.velocity.y, 0, player.JUMP_VELOCITY * 0.5)
