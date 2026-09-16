class_name Player
extends CharacterBody3D

# --- PARÁMETROS CONFIGURABLES ---
@export_group("Movimiento Base")
@export var SPEED: float = 8.0
@export var ACCEL: float = 20.0
@export var FRICTION: float = 30.0
@export var AIR_CONTROL: float = 6.0 # Control horizontal en aire
@export var MOMENTUM_DECAY: float = 6.0 # Velocidad a la que se pierde el exceso de inercia (Dash/WallRun)
@export var JUMP_VELOCITY: float = 6.0
@export var MAX_JUMPS: int = 2
@export var MOUSE_SENSITIVITY: float = 0.003
@export var FALL_LIMIT_Y: float = -10.0 

@export_group("Agarrado (Ledge)")
@export var CLIMB_SPEED: float = 2.5
@export var LEDGE_JUMP_FORWARD_FORCE: float = 3.0 

@export_group("Wall Running")
@export var WALL_RUN_SPEED: float = 17.0
@export var WALL_JUMP_FORCE: float = 7.0 
@export var WALL_JUMP_FORWARD_FORCE: float = 12.0 # Inercia frontal al saltar de la pared

@export_group("Dash")
@export var DASH_SPEED: float = 18.0 
@export var DASH_COOLDOWN_TIME: float = 1.2

@export_group("Cámara y FOV")
@export var BASE_FOV: float = 75.0
@export var MAX_FOV: float = 95.0
@export var DASH_FOV: float = 102.0
@export var FOV_CHANGE_SPEED: float = 6.0
@export var TILT_ANGLE: float = 12.0
@export var TILT_SPEED: float = 8.0
@export var STRAFE_TILT_ANGLE: float = 3.0
@export var LANDING_BOUNCE_FORCE: float = 0.02 # Factor de impacto por velocidad de caída
@export var DASH_SHAKE_AMOUNT: float = 0.07
@export var CAMERA_RESET_SPEED: float = 8.0

# Estructura de Estados
enum State { NORMAL, AGARRADO, WALL_RUNNING }
var current_state: State = State.NORMAL

var jump_count: int = 0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var spawn_position: Vector3 
var last_fall_velocity: float = 0.0 # Registra la velocidad vertical máxima antes de aterrizar

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
		var is_orbiting := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		
		if is_orbiting:
			if camera_controller:
				camera_controller.add_orbit_rotation(event.relative * MOUSE_SENSITIVITY)
		else:
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	if global_position.y < FALL_LIMIT_Y:
		respawn()

	if not is_on_floor():
		last_fall_velocity = velocity.y
	
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

	var current_h_vel := Vector3(velocity.x, 0, velocity.z)
	var speed_len := current_h_vel.length()

	# --- GESTIÓN DE INERCIA Y DASH ---
	if speed_len > SPEED:
		if is_on_floor():
			# En el suelo: Reduce el exceso de velocidad progresivamente hasta SPEED
			var target_h_vel = current_h_vel.normalized() * SPEED
			velocity.x = move_toward(velocity.x, target_h_vel.x, MOMENTUM_DECAY * 1.5 * delta)
			velocity.z = move_toward(velocity.z, target_h_vel.z, MOMENTUM_DECAY * 1.5 * delta)
		else:
			# En el aire: Permite redirigir un poco la trayectoria sin perder el impulso bruscamente
			if direction != Vector3.ZERO:
				# Suaviza el cambio de dirección en aire para que no "patine" hacia los lados
				var blended_dir = lerp(current_h_vel.normalized(), direction, AIR_CONTROL * 0.5 * delta).normalized()
				velocity.x = blended_dir.x * move_toward(speed_len, SPEED, MOMENTUM_DECAY * 0.8 * delta)
				velocity.z = blended_dir.z * move_toward(speed_len, SPEED, MOMENTUM_DECAY * 0.8 * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, MOMENTUM_DECAY * 0.5 * delta)
				velocity.z = move_toward(velocity.z, 0, MOMENTUM_DECAY * 0.5 * delta)
	else:
		# Movimiento normal estándar cuando vas a velocidad base o menor
		if is_on_floor():
			if direction != Vector3.ZERO:
				velocity.x = move_toward(velocity.x, direction.x * SPEED, ACCEL * delta)
				velocity.z = move_toward(velocity.z, direction.z * SPEED, ACCEL * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
				velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
		else:
			if direction != Vector3.ZERO:
				velocity.x = move_toward(velocity.x, direction.x * SPEED, AIR_CONTROL * delta)
				velocity.z = move_toward(velocity.z, direction.z * SPEED, AIR_CONTROL * delta)

	move_and_slide()

func respawn() -> void:
	current_state = State.NORMAL
	global_position = spawn_position
	velocity = Vector3.ZERO
