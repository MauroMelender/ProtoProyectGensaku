class_name WallRun
extends Node

enum WallType { RECTA, RAMPA }

# --- CONFIGURACIÓN DE CAÍDA PROGRESIVA ---
@export var WALL_GRAVITY_SPEED: float = 0.5 # Velocidad a la que empieza a caer despacio por la pared
@export var WALL_SLIDE_ACCEL: float = 2.0   # Qué tan rápido aumenta la caída cuanto más tiempo te quedás en la pared

var player: Player
var cooldown_timer: float = 0.0
var current_wall_type: WallType = WallType.RECTA
var current_wall_normal: Vector3 = Vector3.ZERO
var last_wall_normal: Vector3 = Vector3.ZERO 

var wall_run_time: float = 0.0 # Contador para acumular la caída mientras corres

func _ready() -> void:
	player = get_parent().get_parent() as Player

func _is_wallrun_flat(collider: Object) -> bool:
	if not collider: return false
	return collider.is_in_group("WallRunFlat") or collider.is_in_group("wallrunflat") or collider.is_in_group("WALLRUNFLAT") or (collider.get_parent() and collider.get_parent().is_in_group("WallRunFlat"))

func _is_wallrun_ramp(collider: Object) -> bool:
	if not collider: return false
	return collider.is_in_group("WallRunRamp") or collider.is_in_group("wallrunramp") or collider.is_in_group("WALLRUNRAMP") or (collider.get_parent() and collider.get_parent().is_in_group("WallRunRamp"))

func check_and_update(delta: float) -> bool:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	if player.is_on_floor():
		last_wall_normal = Vector3.ZERO
		return false

	var input_dir := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
	if input_dir.y >= 0:
		return false

	var active_ray = _get_active_ray()

	if active_ray:
		var collider = active_ray.get_collider()
		var new_normal = active_ray.get_collision_normal()

		var is_different_wall = last_wall_normal != Vector3.ZERO and new_normal.dot(last_wall_normal) < 0.2
		
		if cooldown_timer > 0.0 and not is_different_wall:
			return false

		if _is_wallrun_flat(collider) or _is_wallrun_ramp(collider):
			current_wall_type = WallType.RECTA if _is_wallrun_flat(collider) else WallType.RAMPA
			current_wall_normal = new_normal
			player.current_state = Player.State.WALL_RUNNING
			player.jump_count = 0
			cooldown_timer = 0.0
			wall_run_time = 0.0 # Reinicia el temporizador de caída al tocar la pared
			return true

	return false

func process_movement(delta: float) -> void:
	var input_dir := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")

	if input_dir.y >= 0 or player.is_on_floor():
		_exit_wall_run()
		return

	var active_ray = _get_active_ray()
	if not active_ray:
		_exit_wall_run()
		return

	var collider = active_ray.get_collider()
	if not (_is_wallrun_flat(collider) or _is_wallrun_ramp(collider)):
		_exit_wall_run()
		return

	current_wall_normal = active_ray.get_collision_normal()
	var forward_look := -player.transform.basis.z

	# Suma tiempo corriendo en la pared
	wall_run_time += delta

	if current_wall_type == WallType.RECTA:
		var wall_forward := Vector3.UP.cross(current_wall_normal)
		if forward_look.dot(wall_forward) < 0:
			wall_forward = -wall_forward

		# Avance horizontal
		player.velocity.x = wall_forward.x * player.WALL_RUN_SPEED
		player.velocity.z = wall_forward.z * player.WALL_RUN_SPEED

		# CAÍDA PROGRESIVA: Empieza cayendo despacio y acelera cuanto más tiempo pase en la pared
		var target_drop_speed = -(WALL_GRAVITY_SPEED + (wall_run_time * WALL_SLIDE_ACCEL))
		player.velocity.y = move_toward(player.velocity.y, target_drop_speed, 12.0 * delta)

	elif current_wall_type == WallType.RAMPA:
		var ramp_node = collider as Node3D
		var ramp_forward = forward_look

		if ramp_node:
			var ramp_z = -ramp_node.global_transform.basis.z.normalized()
			var ramp_x = ramp_node.global_transform.basis.x.normalized()
			
			if abs(forward_look.dot(ramp_z)) > abs(forward_look.dot(ramp_x)):
				ramp_forward = ramp_z * sign(forward_look.dot(ramp_z))
			else:
				ramp_forward = ramp_x * sign(forward_look.dot(ramp_x))

		player.velocity = ramp_forward * player.WALL_RUN_SPEED

	# Salto desde la pared (Espacio / "saltar")
	if Input.is_action_just_pressed("saltar"):
		player.current_state = Player.State.NORMAL
		last_wall_normal = current_wall_normal
		cooldown_timer = 0.25
		player.jump_count = 1

		var is_pushing_away = false
		if active_ray == player.ray_izquierda and input_dir.x > 0:
			is_pushing_away = true
		elif active_ray == player.ray_derecha and input_dir.x < 0:
			is_pushing_away = true

		var side_force_multiplier = 1.0 if is_pushing_away else 0.4
		
		var jump_direction = (current_wall_normal * player.WALL_JUMP_FORCE * side_force_multiplier) + (forward_look * player.WALL_JUMP_FORWARD_FORCE)
		
		player.velocity.x = jump_direction.x
		player.velocity.z = jump_direction.z
		player.velocity.y = player.JUMP_VELOCITY
		return

	player.move_and_slide()

func _exit_wall_run() -> void:
	player.current_state = Player.State.NORMAL
	cooldown_timer = 0.25
	wall_run_time = 0.0

func _get_active_ray() -> RayCast3D:
	if player.ray_izquierda and player.ray_izquierda.is_colliding():
		return player.ray_izquierda
	elif player.ray_derecha and player.ray_derecha.is_colliding():
		return player.ray_derecha
	return null
