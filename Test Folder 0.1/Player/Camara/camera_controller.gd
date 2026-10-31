class_name CameraController
extends Node

var player: Player
var camera: Camera3D

var current_tilt: float = 0.0
var current_strafe_tilt: float = 0.0

# Resorte amortiguado para el rebote de cámara al saltar y aterrizar
var action_velocity: Vector3 = Vector3.ZERO
var was_on_floor: bool = true
var initial_camera_pos: Vector3 = Vector3.ZERO
var initial_camera_rotation: Vector3 = Vector3.ZERO

@export_group("Seguimiento cinematográfico")
@export var POSITION_LAG: float = 0.12
@export var LATERAL_SWAY: float = 0.16
@export var SPEED_PULLBACK: float = 0.32
@export var ACCELERATION_KICK: float = 0.009
@export var SPEED_CHANGE_KICK: float = 0.014
@export var AIR_DROP: float = 0.10
@export var JUMP_KICK: float = 1.35
@export var DASH_KICK: float = 0.22
@export var SPRING_STRENGTH: float = 48.0
@export var SPRING_DAMPING: float = 11.5
@export var MOTION_ROLL: float = 2.4
@export var MOTION_PITCH: float = 2.0
@export var SIDE_SWITCH_SPEED: float = 2.8
@export var CAMERA_WALL_ESCAPE_SPEED: float = 16.0
@export var CAMERA_REPOSITION_SPEED: float = 3.5
@export var ORBIT_RECENTER_SPEED: float = 2.4
@export var CAMERA_COLLISION_MARGIN: float = 0.06
@export var CAMERA_COLLISION_RADIUS: float = 0.22
@export var ORBIT_CENTER_HEIGHT: float = 0.82

var action_offset: Vector3 = Vector3.ZERO
var action_rotation: Vector2 = Vector2.ZERO # pitch, roll
var camera_side_distance: float = 0.65
var camera_side_target: float = 1.0
var camera_side_current: float = 1.0
var camera_clearance: float = 1.0
var previous_velocity: Vector3 = Vector3.ZERO
var previous_state: int = -1
var previous_on_floor: bool = true
var previous_dash_cooldown: float = 0.0

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
		
	# Usa el centro del personaje como pivote de órbita, conservando el encuadre inicial.
	var pivot := get_parent() as Node3D
	if player and pivot:
		camera = pivot.get_node_or_null("Camera3D") as Camera3D
		if camera:
			_center_orbit_pivot(pivot)
			initial_camera_pos = camera.position
			initial_camera_rotation = camera.rotation
			camera_side_distance = maxf(absf(initial_camera_pos.x), 0.65)
			camera_side_target = signf(initial_camera_pos.x) if not is_zero_approx(initial_camera_pos.x) else 1.0
			camera_side_current = camera_side_target
			previous_velocity = player.velocity
			previous_state = player.current_state
			previous_on_floor = player.is_on_floor()

func _center_orbit_pivot(pivot: Node3D) -> void:
	var orbit_center := Vector3(0.0, ORBIT_CENTER_HEIGHT, 0.0)
	var camera_local_compensation := pivot.transform.basis.inverse() * (pivot.position - orbit_center)
	pivot.position = orbit_center
	if camera:
		camera.position += camera_local_compensation

func _find_camera() -> void:
	# Busca la Camera3D en cualquier nivel debajo del pivot
	if player and player.camera_pivot:
		var found := player.camera_pivot.find_children("*", "Camera3D", true, false)
		if found.size() > 0:
			camera = found[0] as Camera3D
			_center_orbit_pivot(player.camera_pivot)
			initial_camera_pos = camera.position
			initial_camera_rotation = camera.rotation
			camera_side_distance = maxf(absf(initial_camera_pos.x), 0.65)
			camera_side_target = signf(initial_camera_pos.x) if not is_zero_approx(initial_camera_pos.x) else 1.0
			camera_side_current = camera_side_target

# Se llama desde Player._physics_process para consultar el mundo físico en el momento seguro.
func update_camera_clearance() -> void:
	if not player or not player.camera_pivot or not camera:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		# Durante la órbita respeta el ángulo que mueve el jugador y solo evita paredes.
		camera_clearance = _trace_local_camera_path(camera.position)
		if camera_clearance < 1.0:
			camera.position *= maxf(camera_clearance - 0.01, 0.0)
		return

	var preferred_side := camera_side_target
	if player.current_state == Player.State.WALL_RUNNING:
		if player.ray_derecha and player.ray_derecha.is_colliding():
			preferred_side = -1.0
		elif player.ray_izquierda and player.ray_izquierda.is_colliding():
			preferred_side = 1.0

	var speed_ratio := clampf(Vector3(player.velocity.x, 0.0, player.velocity.z).length() / maxf(player.RUN_MAX_SPEED, 1.0), 0.0, 1.0)
	var candidate_y := initial_camera_pos.y - (AIR_DROP if not player.is_on_floor() else 0.0)
	var candidate_z := initial_camera_pos.z + SPEED_PULLBACK * speed_ratio
	var preferred_clearance := _trace_camera_path(preferred_side, candidate_y, candidate_z)
	var alternate_side := -preferred_side
	var alternate_clearance := _trace_camera_path(alternate_side, candidate_y, candidate_z)

	# Si el lado elegido está tapado, cambia al hombro que tenga más espacio.
	if alternate_clearance > preferred_clearance + 0.04:
		preferred_side = alternate_side
		preferred_clearance = alternate_clearance

	camera_side_target = preferred_side
	var current_side_clearance := _trace_camera_path(camera_side_current, candidate_y, candidate_z)
	camera_clearance = minf(preferred_clearance, current_side_clearance)
	var actual_camera_clearance := _trace_local_camera_path(camera.position)
	camera_clearance = minf(camera_clearance, actual_camera_clearance)
	if actual_camera_clearance < 1.0:
		# Recorta la posición en este mismo paso para que el lente no atraviese la pared.
		camera.position *= maxf(actual_camera_clearance - 0.01, 0.0)

func _trace_camera_path(side: float, height: float, distance: float) -> float:
	var local_target := Vector3(side * camera_side_distance, height, distance)
	return _trace_local_camera_path(local_target)

func _trace_local_camera_path(local_target: Vector3) -> float:
	if not player or not player.is_inside_tree():
		return 1.0
	var world := player.get_world_3d()
	if world == null:
		return 1.0
	var pivot := player.camera_pivot
	var origin := pivot.global_position
	var destination := pivot.to_global(local_target)
	var path_length := origin.distance_to(destination)
	if path_length <= 0.001:
		return 1.0
	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	query.exclude = [player.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 1.0
	var safe_length := maxf(
		origin.distance_to(hit["position"]) - CAMERA_COLLISION_RADIUS - CAMERA_COLLISION_MARGIN,
		0.0
	)
	return clampf(safe_length / path_length, 0.0, 1.0)

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
	_update_motion(delta)

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
		var orbit_camera_position := camera.global_position if camera else Vector3.ZERO
		if camera:
			var side_from_orbit := player.to_local(orbit_camera_position).x
			if absf(side_from_orbit) > 0.05:
				camera_side_target = signf(side_from_orbit)
		if not ORBIT_RETURNS:
			player.rotate_y(pivot.rotation.y)
			pivot.rotation.y = 0.0

	if ORBIT_RETURNS and absf(pivot.rotation.y) > 0.002:
		var return_weight := 1.0 - exp(-ORBIT_RECENTER_SPEED * delta)
		pivot.rotation.y = lerp_angle(pivot.rotation.y, 0.0, return_weight)
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

	camera.rotation.z = initial_camera_rotation.z + current_tilt + current_strafe_tilt + action_rotation.y
	camera.rotation.x = initial_camera_rotation.x + action_rotation.x

# Seguimiento con inercia y pequeños impulsos vinculados a las acciones del personaje.
func _update_motion(delta: float) -> void:
	var horizontal_velocity := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var local_velocity := player.global_transform.basis.inverse() * horizontal_velocity
	var local_acceleration := player.global_transform.basis.inverse() * (player.velocity - previous_velocity)
	var speed_ratio := clampf(horizontal_velocity.length() / maxf(player.RUN_MAX_SPEED, 1.0), 0.0, 1.5)
	var target_position := initial_camera_pos
	var side_speed := CAMERA_WALL_ESCAPE_SPEED if camera_clearance < 0.995 else SIDE_SWITCH_SPEED
	camera_side_current = lerpf(camera_side_current, camera_side_target, 1.0 - exp(-side_speed * delta))
	target_position.x = camera_side_distance * camera_side_current
	target_position.x += clampf(-local_acceleration.x * ACCELERATION_KICK, -LATERAL_SWAY, LATERAL_SWAY)
	if not player.is_on_floor():
		target_position.y -= AIR_DROP
	target_position.z += SPEED_PULLBACK * clampf(speed_ratio, 0.0, 1.0)
	# La cámara se retrasa al acelerar y se acerca suavemente al frenar.
	target_position.z += clampf(-local_acceleration.z * SPEED_CHANGE_KICK, -0.30, 0.30)
	# El retardo opuesto a la velocidad hace que la cámara acompañe aceleraciones y frenadas.
	target_position.x += clampf(-local_velocity.x * POSITION_LAG * 0.08, -LATERAL_SWAY, LATERAL_SWAY)
	target_position.z += clampf(-local_velocity.z * POSITION_LAG * 0.08, -0.18, 0.18)
	var spring_acceleration := -action_offset * SPRING_STRENGTH - action_velocity * SPRING_DAMPING
	action_velocity += spring_acceleration * delta
	action_offset += action_velocity * delta
	var safe_position := (target_position + action_offset) * camera_clearance
	camera.position = camera.position.lerp(safe_position, 1.0 - exp(-CAMERA_REPOSITION_SPEED * delta))

	var target_roll := clampf(-local_velocity.x * 0.012, -deg_to_rad(MOTION_ROLL), deg_to_rad(MOTION_ROLL))
	var target_pitch := clampf(local_velocity.y * 0.008, -deg_to_rad(MOTION_PITCH), deg_to_rad(MOTION_PITCH))
	action_rotation.y = lerpf(action_rotation.y, target_roll, 1.0 - exp(-5.0 * delta))
	action_rotation.x = lerpf(action_rotation.x, target_pitch, 1.0 - exp(-5.0 * delta))
	var takeoff := previous_on_floor and not player.is_on_floor() and player.velocity.y > 0.0
	var double_jump := (
		not previous_on_floor
		and player.current_state == Player.State.NORMAL
		and player.velocity.y - previous_velocity.y > player.DOUBLE_JUMP_VELOCITY * 0.5
	)
	if takeoff or double_jump:
		action_velocity.y -= JUMP_KICK
		action_velocity.z += 0.25
		action_rotation.x -= deg_to_rad(1.5)
	if player.current_state != previous_state:
		match player.current_state:
			Player.State.WALL_RUNNING:
				action_velocity.x += 0.45 if player.ray_izquierda and player.ray_izquierda.is_colliding() else -0.45
				current_tilt = 0.0
			Player.State.GANCHO:
				action_velocity.z += DASH_KICK * 4.0
			Player.State.NORMAL:
				if previous_state == Player.State.GANCHO:
					action_velocity.y += 0.55
	if player.dash_ability and previous_dash_cooldown <= 0.0 and player.dash_ability.cooldown_timer > 0.0:
		action_velocity.z += DASH_KICK * 6.0
		action_velocity.y += 0.30
	previous_dash_cooldown = player.dash_ability.cooldown_timer if player.dash_ability else 0.0
	previous_velocity = player.velocity
	previous_state = player.current_state
	previous_on_floor = player.is_on_floor()

# Aplica un rebote amortiguado proporcional a la fuerza de la caída
func _update_landing_impact(delta: float) -> void:
	if not was_on_floor and player.is_on_floor():
		var impact_speed := absf(player.last_fall_velocity)
		var fall_impact := clampf(impact_speed * player.LANDING_BOUNCE_FORCE, 0.05, 0.6)
		action_velocity.y -= fall_impact * 3.5
		action_velocity.z += fall_impact * 0.25
		# Una sacudida breve y sutil comunica el impacto sin depender de sonido.
		shake_intensity = maxf(shake_intensity, clampf(impact_speed * 0.0025, 0.015, 0.06))
	
	was_on_floor = player.is_on_floor()

# Aplica la sacudida de pantalla si la variable `shake_intensity` es mayor a 0
func _update_dash_shake(delta: float) -> void:
	if shake_intensity > 0.0:
		camera.h_offset = randf_range(-shake_intensity, shake_intensity)
		camera.v_offset = randf_range(-shake_intensity, shake_intensity)
		shake_intensity = move_toward(shake_intensity, 0.0, delta * 2.5)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
