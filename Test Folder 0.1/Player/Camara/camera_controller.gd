class_name CameraController
extends Node

var player: Player
var camera: Camera3D
var current_tilt: float = 0.0

func _ready() -> void:
	player = get_parent().get_parent() as Player
	if not player:
		player = owner as Player
		
	if player and player.camera_pivot:
		camera = player.camera_pivot.get_node_or_null("Camera3D") as Camera3D

func check_and_update(delta: float) -> void:
	if not camera:
		if player and player.camera_pivot:
			camera = player.camera_pivot.find_child("*", true, false) as Camera3D
		if not camera:
			return

	_update_fov(delta)
	_update_tilt(delta)

func _update_fov(delta: float) -> void:
	var target_fov: float = player.BASE_FOV

	match player.current_state:
		Player.State.NORMAL:
			var horizontal_speed := Vector3(player.velocity.x, 0, player.velocity.z).length()
			
			if horizontal_speed > player.SPEED:
				var speed_ratio = clamp((horizontal_speed - player.SPEED) / (player.WALL_RUN_SPEED - player.SPEED), 0.0, 1.0)
				target_fov = lerp(player.BASE_FOV, player.MAX_FOV, speed_ratio)
			else:
				target_fov = player.BASE_FOV

		Player.State.WALL_RUNNING:
			target_fov = player.MAX_FOV

		Player.State.AGARRADO:
			target_fov = player.BASE_FOV

	if player.dash_ability and player.dash_ability.cooldown_timer > (player.DASH_COOLDOWN_TIME - 0.25):
		target_fov = player.DASH_FOV

	camera.fov = lerp(camera.fov, target_fov, player.FOV_CHANGE_SPEED * delta)

func _update_tilt(delta: float) -> void:
	var target_tilt: float = 0.0

	if player.current_state == Player.State.WALL_RUNNING:
		if player.ray_izquierda and player.ray_izquierda.is_colliding():
			target_tilt = -deg_to_rad(player.TILT_ANGLE)
		elif player.ray_derecha and player.ray_derecha.is_colliding():
			target_tilt = deg_to_rad(player.TILT_ANGLE)

	current_tilt = lerp(current_tilt, target_tilt, player.TILT_SPEED * delta)
	camera.rotation.z = current_tilt
