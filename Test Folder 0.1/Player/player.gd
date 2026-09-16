class_name Player
extends CharacterBody3D

# --- PARÁMETROS CONFIGURABLES ---
@export_group("Movimiento Base")
@export var SPEED: float = 8.0
@export var ACCEL: float = 20.0
@export var FRICTION: float = 30.0
@export var JUMP_VELOCITY: float = 6.0
@export var MAX_JUMPS: int = 2
@export var MOUSE_SENSITIVITY: float = 0.003
@export var FALL_LIMIT_Y: float = -10.0 

@export_group("Agarrado (Ledge)")
@export var CLIMB_SPEED: float = 2.5
@export var LEDGE_JUMP_FORWARD_FORCE: float = 3.0 

@export_group("Wall Running")
@export var WALL_RUN_SPEED: float = 17.0
@export var WALL_JUMP_FORCE: float = 5.0 

@export_group("Dash")
@export var DASH_SPEED: float = 14.0 
@export var DASH_COOLDOWN_TIME: float = 1.2

# Estructura de Estados
enum State { NORMAL, AGARRADO, WALL_RUNNING }
var current_state: State = State.NORMAL

var jump_count: int = 0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var spawn_position: Vector3 

# Referencias a Nodos
@onready var camera_pivot: Node3D = $CameraPivot
@onready var ray_pared: RayCast3D = $RayPared
@onready var ray_borde: RayCast3D = $RayBorde
@onready var ray_izquierda: RayCast3D = $RayIzquierda
@onready var ray_derecha: RayCast3D = $RayDerecha

# Referencias a Componentes de Habilidades
@onready var dash_ability: Dash = $Habilidades/Dash
@onready var ledge_ability: Ledge = $Habilidades/Ledge
@onready var wall_run_ability: WallRun = $Habilidades/WallRun
@onready var camera_controller: CameraController = $CameraPivot/CameraController

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

	match current_state:
		State.NORMAL:
			_process_normal_movement(delta)
			dash_ability.check_and_update(delta)
			
			if not ledge_ability.check_and_update(delta):
				wall_run_ability.check_and_update(delta)

		State.AGARRADO:
			ledge_ability.process_movement(delta)

		State.WALL_RUNNING:
			wall_run_ability.process_movement(delta)

	# Actualiza los efectos de cámara y FOV independientemente del estado
	if camera_controller:
		camera_controller.check_and_update(delta)

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

func respawn() -> void:
	current_state = State.NORMAL
	global_position = spawn_position
	velocity = Vector3.ZERO
