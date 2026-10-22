class_name CameraController
extends Node

var player: Player
var camera: Camera3D

var current_tilt: float = 0.0
var current_strafe_tilt: float = 0.0

# Variables para calcular el golpe de vista al caer al suelo
var landing_offset: float = 0.0
var was_on_floor: bool = true
var initial_camera_pos: Vector3 = Vector3.ZERO

# Intensidad del temblor
var shake_intensity: float = 0.0

# Estado de la órbita (clic derecho)
@export var ORBIT_RETURNS: bool = true
var was_orbiting: bool = false

func _ready() -> void:
	# Obtiene la referencia al script principal del jugador
	player = get_parent().get_parent() as Player
	if not player:
		player = owner as Player
		
	# Busca y guarda la cámara y su posición inicial de la escena
	if player and player.camera_pivot:
		camera = player.camera_pivot.get_node_or_null("Camera3D") as Camera3D
		if camera:
			initial_camera_pos = camera.position

func _find_camera() -> void:
	# Busca la Camera3D en cualquier nivel debajo del pivot
	if player and player.camera_pivot:
		var found := player.camera_pivot.find_children("*", "Camera3D", true, false)
		if found.size() > 0:
			camera = found[0] as Camera3D
			initial_camera_pos = camera.position

func check_and_update(delta: float) -> void:
	# El reset de la órbita NO depende de la cámara: se ejecuta siempre
	_update_orbit_mode(delta)

	if not camera:
		_find_camera()
		if not camera:
			push_warning("CameraController: no se encontró ninguna Camera3D debajo de CameraPivot")
			return
	_update_fov(delta)
	_update_tilt(delta)
	_update_landing_impact(delta)
	_update_dash_shake(delta)

# Función para orbitar la cámara 360 con clic derecho
func add_orbit_rotation(mouse_relative: Vector2) -> void:
	if not player or not player.camera_pivot:
		return
		
	var pivot := player.camera_pivot
	pivot.rotation.y = wrapf(pivot.rotation.y - mouse_relative.x, -PI, PI)
	pivot.rotation.x = clampf(pivot.rotation.x - mouse_relative.y, deg_to_rad(-80), deg_to_rad(80))
	pivot.rotation.z = 0.0

# Maneja qué pasa con la cámara al soltar el clic derecho
func _update_orbit_mode(delta: float) -> void:
	if not player or not player.camera_pivot:
		return

	var pivot := player.camera_pivot

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		was_orbiting = true
		return

	if was_orbiting:
		was_orbiting = false
		if not ORBIT_RETURNS:
			player.rotate_y(pivot.rotation.y)
			pivot.rotation.y = 0.0

	if ORBIT_RETURNS and pivot.rotation.y != 0.0:
		var t := 1.0 - exp(-player.CAMERA_RESET_SPEED * delta)
		pivot.rotation.y = lerp_angle(pivot.rotation.y, 0.0, t)
		if absf(pivot.rotation.y) < 0.002:
			pivot.rotation.y = 0.0

	pivot.rotation.z = 0.0

# Aumenta el campo de visión (FOV) cuanto más rápido se mueve el personaje
func _update_fov(delta: float) -> void:
	var target_fov: float = player.BASE_FOV
	var horizontal_speed := Vector3(player.velocity.x, 0, player.velocity.z).length()

	match player.current_state:
		Player.State.NORMAL:
			if horizontal_speed > player.SPEED:
				var speed_ratio = clamp((horizontal_speed - player.SPEED) / (player.DASH_SPEED - player.SPEED), 0.0, 1.0)
				target_fov = lerp(player.BASE_FOV, player.MAX_FOV, speed_ratio)
			else:
				target_fov = player.BASE_FOV

		Player.State.WALL_RUNNING:
			target_fov = player.MAX_FOV

		Player.State.AGARRADO:
			target_fov = player.BASE_FOV

	# Incremento de FOV al usar el Dash
	if player.dash_ability and player.dash_ability.cooldown_timer > (player.DASH_COOLDOWN_TIME - 0.25):
		target_fov = player.DASH_FOV
		if player.dash_ability.cooldown_timer > (player.DASH_COOLDOWN_TIME - 0.05):
			shake_intensity = player.DASH_SHAKE_AMOUNT

	camera.fov = lerp(camera.fov, target_fov, player.FOV_CHANGE_SPEED * delta)

# Inclina la cámara a los lados al estar en WallRun o al caminar de costado
func _update_tilt(delta: float) -> void:
	var target_wall_tilt: float = 0.0

	if player.current_state == Player.State.WALL_RUNNING:
		if player.ray_izquierda and player.ray_izquierda.is_colliding():
			target_wall_tilt = -deg_to_rad(player.TILT_ANGLE)
		elif player.ray_derecha and player.ray_derecha.is_colliding():
			target_wall_tilt = deg_to_rad(player.TILT_ANGLE)

	current_tilt = lerp(current_tilt, target_wall_tilt, player.TILT_SPEED * delta)

	var input_dir := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
	var target_strafe = -input_dir.x * deg_to_rad(player.STRAFE_TILT_ANGLE)
	current_strafe_tilt = lerp(current_strafe_tilt, target_strafe, player.TILT_SPEED * delta)

	camera.rotation.z = current_tilt + current_strafe_tilt

# Genera un hundimiento suave en la cámara por la fuerza de la caída al tocar el suelo
func _update_landing_impact(delta: float) -> void:
	if not was_on_floor and player.is_on_floor():
		var fall_impact = abs(player.last_fall_velocity) * player.LANDING_BOUNCE_FORCE
		landing_offset = -clamp(fall_impact, 0.05, 0.6)
		
		# Si la caída fue desde muy alto, tiembla levemente la cámara
		if abs(player.last_fall_velocity) > 15.0:
			shake_intensity = clamp(abs(player.last_fall_velocity) * 0.004, 0.03, 0.12)
	
	was_on_floor = player.is_on_floor()

	landing_offset = lerp(landing_offset, 0.0, 12.0 * delta)
	camera.position.y = initial_camera_pos.y + landing_offset

# Aplica la sacudida de pantalla si la variable `shake_intensity` es mayor a 0
func _update_dash_shake(delta: float) -> void:
	if shake_intensity > 0.0:
		camera.h_offset = randf_range(-shake_intensity, shake_intensity)
		camera.v_offset = randf_range(-shake_intensity, shake_intensity)
		shake_intensity = move_toward(shake_intensity, 0.0, delta * 2.5)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
