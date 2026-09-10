extends CharacterBody3D

# --- PARÁMETROS CONFIGURABLES ---
@export var SPEED: float = 8.0
@export var ACCEL: float = 20.0
@export var FRICTION: float = 30.0
@export var JUMP_VELOCITY: float = 6.0
@export var MAX_JUMPS: int = 2
@export var MOUSE_SENSITIVITY: float = 0.003
@export var FALL_LIMIT_Y: float = -10.0 

@export var CLIMB_SPEED: float = 2.5
@export var LEDGE_JUMP_FORWARD_FORCE: float = 3.0 

# --- CONFIGURACIÓN DE WALL RUNNING ---
@export var WALL_RUN_SPEED: float = 17.0
@export var WALL_JUMP_FORCE: float = 5.0 

# --- CONFIGURACIÓN DE DASH ---
@export var DASH_SPEED: float = 14.0 
@export var DASH_COOLDOWN_TIME: float = 1.2

var jump_count: int = 0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var spawn_position: Vector3 

var ledge_cooldown: float = 0.0
var wall_run_cooldown: float = 0.0
var dash_cooldown: float = 0.0 # Temporizador de recarga del Dash

enum State { NORMAL, AGARRADO, WALL_RUNNING }
var current_state: State = State.NORMAL

enum WallType { RECTA, RAMPA }
var current_wall_type: WallType = WallType.RECTA

var current_wall_normal: Vector3 = Vector3.ZERO

@onready var camera_pivot: Node3D = $CameraPivot
@onready var ray_pared: RayCast3D = $RayPared
@onready var ray_borde: RayCast3D = $RayBorde
@onready var ray_izquierda: RayCast3D = $RayIzquierda
@onready var ray_derecha: RayCast3D = $RayDerecha

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spawn_position = global_position 

	ray_pared.add_exception(self)
	ray_borde.add_exception(self)
	if ray_izquierda: ray_izquierda.add_exception(self)
	if ray_derecha: ray_derecha.add_exception(self)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	if global_position.y < FALL_LIMIT_Y:
		respawn()

	# Reducir temporizadores
	if ledge_cooldown > 0.0:
		ledge_cooldown -= delta
	if wall_run_cooldown > 0.0:
		wall_run_cooldown -= delta
	if dash_cooldown > 0.0:
		dash_cooldown -= delta

	match current_state:
		State.NORMAL:
			_process_normal_movement(delta)
			_check_dash() # Detección del Dash
			_check_ledge_grab()
			_check_wall_run()
		State.AGARRADO:
			_process_ledge_movement(delta)
		State.WALL_RUNNING:
			_process_wall_run_movement(delta)

func _process_normal_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		jump_count = 0

	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			jump_count = 1
		elif jump_count < MAX_JUMPS:
			velocity.y = JUMP_VELOCITY
			jump_count += 1

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * SPEED, ACCEL * delta)
		velocity.z = move_toward(velocity.z, direction.z * SPEED, ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)

	move_and_slide()

# --- LÓGICA DE DASH ---

func _check_dash() -> void:
	var dash_pressed = Input.is_key_pressed(KEY_Q) or Input.is_action_just_pressed("dash")

	if dash_pressed and dash_cooldown <= 0.0:
		dash_cooldown = DASH_COOLDOWN_TIME
		
		var forward_dir := -transform.basis.z
		
		# Aplicar impulso controlado hacia adelante
		velocity.x = forward_dir.x * DASH_SPEED
		velocity.z = forward_dir.z * DASH_SPEED
		
		# Si está en el aire, frena ligeramente la caída/subida para un impulso recto y seco
		if not is_on_floor():
			velocity.y = move_toward(velocity.y, 0, JUMP_VELOCITY * 0.5)

# --- LÓGICA DE LEDGE ---

func _check_ledge_grab() -> void:
	if is_on_floor() or ledge_cooldown > 0.0:
		return

	if ray_pared.is_colliding() and ray_borde.is_colliding():
		var collider = ray_pared.get_collider()
		var tiene_grupo = collider.is_in_group("Ledge") or collider.is_in_group("ledge") or collider.is_in_group("LEDGE") or (collider.get_parent() and collider.get_parent().is_in_group("Ledge"))
		
		if tiene_grupo:
			current_state = State.AGARRADO
			velocity = Vector3.ZERO
			jump_count = 0

func _process_ledge_movement(delta: float) -> void:
	if not ray_pared.is_colliding():
		current_state = State.NORMAL
		ledge_cooldown = 0.2
		return

	velocity = Vector3.ZERO

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	var right := transform.basis.x
	velocity = right * input_dir.x * CLIMB_SPEED

	if input_dir.y > 0:
		current_state = State.NORMAL
		ledge_cooldown = 0.3
		return

	if Input.is_action_just_pressed("ui_accept"):
		current_state = State.NORMAL
		ledge_cooldown = 0.35
		jump_count = 1
		
		var forward := -transform.basis.z
		velocity.y = JUMP_VELOCITY
		velocity += forward * LEDGE_JUMP_FORWARD_FORCE
		return

	move_and_slide()

# --- LÓGICA DE WALL RUNNING ---

func _is_wallrun_flat(collider: Object) -> bool:
	if not collider: return false
	return collider.is_in_group("WallRunFlat") or collider.is_in_group("wallrunflat") or collider.is_in_group("WALLRUNFLAT") or (collider.get_parent() and collider.get_parent().is_in_group("WallRunFlat"))

func _is_wallrun_ramp(collider: Object) -> bool:
	if not collider: return false
	return collider.is_in_group("WallRunRamp") or collider.is_in_group("wallrunramp") or collider.is_in_group("WALLRUNRAMP") or (collider.get_parent() and collider.get_parent().is_in_group("WallRunRamp"))

func _check_wall_run() -> void:
	if is_on_floor() or wall_run_cooldown > 0.0:
		return

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir.y >= 0:
		return

	var active_ray: RayCast3D = null
	if ray_izquierda and ray_izquierda.is_colliding():
		active_ray = ray_izquierda
	elif ray_derecha and ray_derecha.is_colliding():
		active_ray = ray_derecha

	if active_ray:
		var collider = active_ray.get_collider()
		
		if _is_wallrun_flat(collider):
			current_wall_type = WallType.RECTA
			current_wall_normal = active_ray.get_collision_normal()
			current_state = State.WALL_RUNNING
			jump_count = 0
		elif _is_wallrun_ramp(collider):
			current_wall_type = WallType.RAMPA
			current_wall_normal = active_ray.get_collision_normal()
			current_state = State.WALL_RUNNING
			jump_count = 0

func _process_wall_run_movement(delta: float) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if input_dir.y >= 0 or is_on_floor():
		current_state = State.NORMAL
		wall_run_cooldown = 0.3
		return

	var active_ray: RayCast3D = null
	if ray_izquierda and ray_izquierda.is_colliding():
		active_ray = ray_izquierda
	elif ray_derecha and ray_derecha.is_colliding():
		active_ray = ray_derecha

	if not active_ray:
		current_state = State.NORMAL
		wall_run_cooldown = 0.3
		return

	var collider = active_ray.get_collider()

	if not (_is_wallrun_flat(collider) or _is_wallrun_ramp(collider)):
		current_state = State.NORMAL
		wall_run_cooldown = 0.3
		return

	current_wall_normal = active_ray.get_collision_normal()
	var move_dir := -transform.basis.z

	if current_wall_type == WallType.RECTA:
		var wall_forward := Vector3.UP.cross(current_wall_normal)
		if move_dir.dot(wall_forward) < 0:
			wall_forward = -wall_forward

		velocity.x = wall_forward.x * WALL_RUN_SPEED
		velocity.z = wall_forward.z * WALL_RUN_SPEED
		velocity.y = 0.0

	elif current_wall_type == WallType.RAMPA:
		var ramp_node = collider as Node3D
		var ramp_forward = -transform.basis.z

		if ramp_node:
			var ramp_z = -ramp_node.global_transform.basis.z.normalized()
			var ramp_x = ramp_node.global_transform.basis.x.normalized()
			
			if abs(move_dir.dot(ramp_z)) > abs(move_dir.dot(ramp_x)):
				ramp_forward = ramp_z * sign(move_dir.dot(ramp_z))
			else:
				ramp_forward = ramp_x * sign(move_dir.dot(ramp_x))

		velocity = ramp_forward * WALL_RUN_SPEED

	# Saltar desde la pared al presionar Espacio
	if Input.is_action_just_pressed("ui_accept"):
		current_state = State.NORMAL
		wall_run_cooldown = 0.4
		jump_count = 1
		velocity = (current_wall_normal * WALL_JUMP_FORCE) + (Vector3.UP * JUMP_VELOCITY)
		return

	move_and_slide()

func respawn() -> void:
	current_state = State.NORMAL
	global_position = spawn_position
	velocity = Vector3.ZERO
