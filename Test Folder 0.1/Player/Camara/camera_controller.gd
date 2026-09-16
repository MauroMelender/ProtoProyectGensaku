class_name CameraController
extends Node

var player: Player
var camera: Camera3D

var current_tilt: float = 0.0
var current_strafe_tilt: float = 0.0

# Variables para el efecto de aterrizaje/salto
var landing_offset: float = 0.0
var was_on_floor: bool = true
var initial_camera_pos: Vector3 = Vector3.ZERO # Posición inicial guardada de la escena

# Variables para el micro-shake del dash
var shake_intensity: float = 0.0

func _ready() -> void:
	player = get_parent().get_parent() as Player
	if not player:
		player = owner as Player
		
	if player and player.camera_pivot:
		camera = player.camera_pivot.get_node_or_null("Camera3D") as Camera3D
		if camera:
			# Guarda la posición
			initial_camera_pos = camera.position

func check_and_update(delta: float) -> void:
	if not camera:
		if player and player.camera_pivot:
			camera = player.camera_pivot.find_child("*", true, false) as Camera3D
			if camera:
				initial_camera_pos = camera.position
		if not camera:
			return

	_update_fov(delta)
	_update_tilt(delta)
	_update_landing_impact(delta)
	_update_dash_shake(delta)

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

	if player.dash_ability and player.dash_ability.cooldown_timer > (player.DASH_COOLDOWN_TIME - 0.2):
		target_fov = player.DASH_FOV
		if player.dash_ability.cooldown_timer > (player.DASH_COOLDOWN_TIME - 0.05):
			shake_intensity = player.DASH_SHAKE_AMOUNT

	camera.fov = lerp(camera.fov, target_fov, player.FOV_CHANGE_SPEED * delta)

func _update_tilt(delta: float) -> void:
	var target_wall_tilt: float = 0.0

	if player.current_state == Player.State.WALL_RUNNING:
		if player.ray_izquierda and player.ray_izquierda.is_colliding():
			target_wall_tilt = -deg_to_rad(player.TILT_ANGLE)
		elif player.ray_derecha and player.ray_derecha.is_colliding():
			target_wall_tilt = deg_to_rad(player.TILT_ANGLE)

	current_tilt = lerp(current_tilt, target_wall_tilt, player.TILT_SPEED * delta)

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var target_strafe = -input_dir.x * deg_to_rad(player.STRAFE_TILT_ANGLE)
	current_strafe_tilt = lerp(current_strafe_tilt, target_strafe, player.TILT_SPEED * delta)

	camera.rotation.z = current_tilt + current_strafe_tilt

func _update_landing_impact(delta: float) -> void:
	if not was_on_floor and player.is_on_floor():
		landing_offset = -player.LANDING_BOUNCE_FORCE
	
	was_on_floor = player.is_on_floor()

	landing_offset = lerp(landing_offset, 0.0, 10.0 * delta)
	
	# Aplica el impacto de caída
	camera.position.y = initial_camera_pos.y + landing_offset

func _update_dash_shake(delta: float) -> void:
	if shake_intensity > 0.0:
		camera.h_offset = randf_range(-shake_intensity, shake_intensity)
		camera.v_offset = randf_range(-shake_intensity, shake_intensity)
		shake_intensity = move_toward(shake_intensity, 0.0, delta * 2.0)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
