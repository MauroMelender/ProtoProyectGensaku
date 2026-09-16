class_name Ledge
extends Node

var player: Player
var cooldown_timer: float = 0.0

func _ready() -> void:
	player = get_parent().get_parent() as Player

func check_and_update(delta: float) -> bool:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	if player.is_on_floor() or cooldown_timer > 0.0:
		return false

	if player.ray_pared.is_colliding() and player.ray_borde.is_colliding():
		var collider = player.ray_pared.get_collider()
		var tiene_grupo = collider.is_in_group("Ledge") or collider.is_in_group("ledge") or collider.is_in_group("LEDGE") or (collider.get_parent() and collider.get_parent().is_in_group("Ledge"))
		
		if tiene_grupo:
			player.current_state = Player.State.AGARRADO
			player.velocity = Vector3.ZERO
			player.jump_count = 0
			return true

	return false

func process_movement(delta: float) -> void:
	if not player.ray_pared.is_colliding():
		player.current_state = Player.State.NORMAL
		cooldown_timer = 0.2
		return

	player.velocity = Vector3.ZERO
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	var right := player.transform.basis.x
	player.velocity = right * input_dir.x * player.CLIMB_SPEED

	if input_dir.y > 0:
		player.current_state = Player.State.NORMAL
		cooldown_timer = 0.3
		return

	if Input.is_action_just_pressed("ui_accept"):
		player.current_state = Player.State.NORMAL
		cooldown_timer = 0.35
		player.jump_count = 1
		
		var forward := -player.transform.basis.z
		player.velocity.y = player.JUMP_VELOCITY
		player.velocity += forward * player.LEDGE_JUMP_FORWARD_FORCE
		return

	player.move_and_slide()
