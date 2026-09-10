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

var jump_count: int = 0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var spawn_position: Vector3 

enum State { NORMAL, AGARRADO }
var current_state: State = State.NORMAL

@onready var camera_pivot: Node3D = $CameraPivot
@onready var ray_pared: RayCast3D = $RayPared
@onready var ray_borde: RayCast3D = $RayBorde

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spawn_position = global_position 

	ray_pared.add_exception(self)
	ray_borde.add_exception(self)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	if global_position.y < FALL_LIMIT_Y:
		respawn()

	match current_state:
		State.NORMAL:
			_process_normal_movement(delta)
			_check_ledge_grab()
		State.AGARRADO:
			_process_ledge_movement(delta)

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

# --- LÓGICA DE PARKOUR ---

func _check_ledge_grab() -> void:
	if is_on_floor():
		return

	# Verifica que ambos rayos estén colisionando
	if ray_pared.is_colliding() and ray_borde.is_colliding():
		var collider = ray_pared.get_collider()
		
		# FILTRO POR GRUPO: Solo se agarra si el objeto pertenece al grupo Ledge
		if collider and (collider.is_in_group("Ledge") or collider.is_in_group("ledge") or collider.is_in_group("LEDGE")):
			current_state = State.AGARRADO
			velocity = Vector3.ZERO

func _process_ledge_movement(delta: float) -> void:
	# SI SE DESPEGA DE LA PARED O SE TERMINA EL SALIENTE, CAE AUTOMÁTICAMENTE
	if not ray_pared.is_colliding():
		current_state = State.NORMAL
		return

	velocity = Vector3.ZERO

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Moverse lateralmente a lo largo de la cornisa (A y D)
	var right := transform.basis.x
	velocity = right * input_dir.x * CLIMB_SPEED

	# Presionar S para soltarse y caer
	if input_dir.y > 0:
		current_state = State.NORMAL
		return

	# Presionar Espacio para saltar o subir
	if Input.is_action_just_pressed("ui_accept"):
		current_state = State.NORMAL
		velocity.y = JUMP_VELOCITY
		return

	move_and_slide()

func respawn() -> void:
	current_state = State.NORMAL
	global_position = spawn_position
	velocity = Vector3.ZERO
