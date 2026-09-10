extends CharacterBody3D

# --- PARÁMETROS CONFIGURABLES ---
@export var SPEED: float = 4.0
@export var ACCEL: float = 12.0
@export var FRICTION: float = 20.0
@export var JUMP_VELOCITY: float = 4.0
@export var MAX_JUMPS: int = 2
@export var MOUSE_SENSITIVITY: float = 0.003
@export var FALL_LIMIT_Y: float = -10.0 

var jump_count: int = 0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var spawn_position: Vector3 # Guarda la posición inicial

@onready var camera_pivot: Node3D = $CameraPivot

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spawn_position = global_position # Guarda donde arranca el nivel

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	# Verificación de caída por debajo del nivel
	if global_position.y < FALL_LIMIT_Y:
		respawn()

	# Aplicar gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		jump_count = 0

	# Manejo del Doble Salto
	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			jump_count = 1
		elif jump_count < MAX_JUMPS:
			velocity.y = JUMP_VELOCITY
			jump_count += 1

	# Obtener dirección de entrada
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Movimiento suave
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * SPEED, ACCEL * delta)
		velocity.z = move_toward(velocity.z, direction.z * SPEED, ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)

	move_and_slide()

# Función para reiniciar posición y velocidad
func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
