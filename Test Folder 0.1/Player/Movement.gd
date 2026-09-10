extends CharacterBody3D

# --- PARÁMETROS CONFIGURABLES ---
@export var SPEED: float = 4.0
@export var ACCEL: float = 12.0
@export var FRICTION: float = 20.0
@export var JUMP_VELOCITY: float = 6.0
@export var MAX_JUMPS: int = 2
@export var MOUSE_SENSITIVITY: float = 0.003
@export var FALL_LIMIT_Y: float = -10.0 

@export var CLIMB_SPEED: float = 2.5
@export var LEDGE_JUMP_FORWARD_FORCE: float = 3.0 

# --- CONFIGURACIÓN DE WALL RUNNING ---
@export var WALL_RUN_SPEED: float = 6.0
@export var WALL_JUMP_FORCE: float = 5.0 
@export var WALL_RUN_UP_FORCE: float = 2.5 # Fuerza para acompañar rampas ascendentes

var jump_count: int = 0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var spawn_position: Vector3 

var ledge_cooldown: float = 0.0
var wall_run_cooldown: float = 0.0

enum State { NORMAL, AGARRADO, WALL_RUNNING }
var current_state: State = State.NORMAL

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

	if ledge_cooldown > 0.0:
		ledge_cooldown -= delta
	if wall_run_cooldown > 0.0:
		wall_run_cooldown -= delta

	match current_state:
		State.NORMAL:
			_process_normal_movement(delta)
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

func _is_wallrun_object(collider: Object) -> bool:
	if not collider:
		return false
	return collider.is_in_group("WallRun") or collider.is_in_group("wallrun") or collider.is_in_group("WALLRUN") or (collider.get_parent() and collider.get_parent().is_in_group("WallRun"))

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

	if active_ray and _is_wallrun_object(active_ray.get_collider()):
		current_wall_normal = active_ray.get_collision_normal()
		current_state = State.WALL_RUNNING
		jump_count = 0

func _process_wall_run_movement(delta: float) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Finaliza si deja de presionar W o toca el piso
	if input_dir.y >= 0 or is_on_floor():
		current_state = State.NORMAL
		wall_run_cooldown = 0.3
		return

	# Busca la pared activa
	var active_ray: RayCast3D = null
	if ray_izquierda and ray_izquierda.is_colliding():
		active_ray = ray_izquierda
	elif ray_derecha and ray_derecha.is_colliding():
		active_ray = ray_derecha

	# Si el rayo no toca nada O tocó un objeto que NO es del grupo WallRun, cae
	if not active_ray or not _is_wallrun_object(active_ray.get_collider()):
		current_state = State.NORMAL
		wall_run_cooldown = 0.3
		return

	current_wall_normal = active_ray.get_collision_normal()

	# Dirección horizontal hacia la que apunta el personaje
	var move_dir := -transform.basis.z
	var wall_forward := Vector3.UP.cross(current_wall_normal)
	if move_dir.dot(wall_forward) < 0:
		wall_forward = -wall_forward

	# Aplica velocidad horizontal a lo largo de la pared
	velocity.x = wall_forward.x * WALL_RUN_SPEED
	velocity.z = wall_forward.z * WALL_RUN_SPEED

	# Toma la inclinación/orientación del objeto rampa
	var wall_collider = active_ray.get_collider()
	var wall_up_dir = Vector3.UP
	
	if wall_collider is Node3D:
		# Usa el eje Y local de la rampa para detectar hacia dónde sube
		wall_up_dir = wall_collider.global_transform.basis.y

	# Si la rampa está inclinada hacia arriba en la dirección de la marcha, impulsa en Y
	var climb_factor = move_dir.dot(wall_up_dir)
	if climb_factor > 0.1:
		velocity.y = climb_factor * WALL_RUN_SPEED
	else:
		# Si es una rampa plana, aplica un impulso suave hacia arriba para sostener el impulso
		velocity.y = WALL_RUN_UP_FORCE

	# Saltar de la pared
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
