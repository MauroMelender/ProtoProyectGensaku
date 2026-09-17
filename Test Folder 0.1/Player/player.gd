class_name Player
extends CharacterBody3D

# --- PARÁMETROS CONFIGURABLES ---
@export_group("Movimiento Base")
@export var SPEED: float = 8.0 # Velocidad normal al caminar
@export var RUN_SPEED: float = 14.0 # Velocidad al correr (con Shift)
@export var ACCEL: float = 20.0 # Qué tan rápido acelera
@export var FRICTION: float = 30.0 # Qué tan rápido frena al soltar las teclas
@export var AIR_CONTROL: float = 6.0 # Control que tenés sobre el personaje mientras está volando
@export var MOMENTUM_DECAY: float = 6.0 # Qué tan rápido pierde el "impulso" extra (del Dash o WallRun)
@export var JUMP_VELOCITY: float = 6.0 # Fuerza del salto
@export var MAX_JUMPS: int = 2 # Cantidad de saltos (2 = doble salto)
@export var MOUSE_SENSITIVITY: float = 0.003 # Sensibilidad de la cámara
@export var FALL_LIMIT_Y: float = -10.0 # Si cae más abajo de esta altura en Y, reaparece

@export_group("Agarrado (Ledge)")
@export var CLIMB_SPEED: float = 2.5 # Velocidad para moverse de lado al estar colgado
@export var LEDGE_JUMP_FORWARD_FORCE: float = 3.0 # Impulso hacia adelante al saltar estando colgado

@export_group("Wall Running")
@export var WALL_RUN_SPEED: float = 17.0 # Velocidad al correr por la pared
@export var WALL_JUMP_FORCE: float = 18.0 # Impulso lateral al saltar desde una pared
@export var WALL_JUMP_FORWARD_FORCE: float = 14.0 # Impulso hacia adelante al saltar desde una pared

@export_group("Dash")
@export var DASH_SPEED: float = 18.0 # Velocidad del impulso del Dash
@export var DASH_COOLDOWN_TIME: float = 1.2 # Tiempo de espera para volver a usar el Dash

@export_group("Cámara y FOV")
@export var BASE_FOV: float = 75.0 # Campo de visión normal
@export var MAX_FOV: float = 95.0 # Campo de visión máximo al ir rápido
@export var DASH_FOV: float = 102.0 # Campo de visión al hacer Dash
@export var FOV_CHANGE_SPEED: float = 6.0 # Velocidad con la que cambia el FOV
@export var TILT_ANGLE: float = 12.0 # Inclinación de la cámara en el Wall Run
@export var TILT_SPEED: float = 8.0 # Velocidad con la que se inclina la cámara
@export var STRAFE_TILT_ANGLE: float = 3.0 # Inclinación suave al moverse hacia los lados
@export var LANDING_BOUNCE_FORCE: float = 0.02 # Intensidad del rebote de cámara al caer
@export var DASH_SHAKE_AMOUNT: float = 0.07 # Temblor de cámara al usar el Dash
@export var CAMERA_RESET_SPEED: float = 8.0 # Velocidad con la que la cámara vuelve a su lugar tras usar el clic derecho

@export_group("Animaciones")
@export var ANIM_IDLE: String = "Anim_Z_IdleCycle"
@export var ANIM_WALK: String = "Anim_Z_WalkCycle"
@export var ANIM_RUN: String = "Anim_Z_RunCycle"
@export var ANIM_JUMP: String = "Anim_Z_RunJumping"
@export var ANIM_FALL: String = "Anim_Z_AirborneCycle"
@export var ANIM_BLEND_TIME: float = 0.2 # Duración del crossfade entre animaciones
@export var IDLE_SPEED_THRESHOLD: float = 0.3 # Por debajo de esta velocidad horizontal, se considera Idle

# Estados del jugador
enum State { NORMAL, AGARRADO, WALL_RUNNING }
var current_state: State = State.NORMAL

var jump_count: int = 0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var spawn_position: Vector3 
var last_fall_velocity: float = 0.0

# Nodos hijos que usa el personaje
@onready var camera_pivot: Node3D = $CameraPivot
@onready var ray_pared: RayCast3D = $RayPared
@onready var ray_borde: RayCast3D = $RayBorde
@onready var ray_izquierda: RayCast3D = $RayIzquierda
@onready var ray_derecha: RayCast3D = $RayDerecha
@onready var animation_player: AnimationPlayer = $Ziel/AnimationPlayer

# Referencias a los scripts de habilidades
@onready var dash_ability: Dash = $Habilidades/Dash
@onready var ledge_ability: Ledge = $Habilidades/Ledge
@onready var wall_run_ability: WallRun = $Habilidades/WallRun
@onready var camera_controller: CameraController = $CameraPivot/CameraController

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Oculta el mouse en la pantalla
	spawn_position = global_position 

	# Ignora el propio cuerpo del jugador para que los RayCasts no se chocan entre si
	ray_pared.add_exception(self)
	ray_borde.add_exception(self)
	if ray_izquierda: ray_izquierda.add_exception(self)
	if ray_derecha: ray_derecha.add_exception(self)

func _unhandled_input(event: InputEvent) -> void:
	# Maneja la rotación de la cámara con el mouse
	if event is InputEventMouseMotion:
		var is_orbiting := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		
		if is_orbiting:
			# Clic Derecho, gira la cámara libremente en 360° sin girar al personaje
			if camera_controller:
				camera_controller.add_orbit_rotation(event.relative * MOUSE_SENSITIVITY)
		else:
			# Mover el mouse gira todo el cuerpo del personaje
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	# Si cae al vacío, reaparece en el spawn
	if global_position.y < FALL_LIMIT_Y:
		respawn()

	# Va registrando la velocidad vertical mientras cae
	if not is_on_floor():
		last_fall_velocity = velocity.y
	
	# Ejecuta la lógica dependiendo del estado en el que esté
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

	# Actualiza los efectos de la cámara sin importar el estado
	if camera_controller:
		camera_controller.check_and_update(delta)

func _process_normal_movement(delta: float) -> void:
	# Aplica la gravedad si está en el aire
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		jump_count = 0 # Reinicia los saltos al tocar el suelo

	# Lógica para saltar y doble salto
	if Input.is_action_just_pressed("saltar"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			jump_count = 1
		elif jump_count < MAX_JUMPS:
			velocity.y = JUMP_VELOCITY
			jump_count += 1

	# Lee las teclas WASD para moverse
	var input_dir := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Sprint: corre en vez de caminar si se mantiene presionado, solo tiene efecto en el piso
	var is_sprinting := is_on_floor() and Input.is_action_pressed("correr")
	var target_speed: float = RUN_SPEED if is_sprinting else SPEED

	var current_h_vel := Vector3(velocity.x, 0, velocity.z)
	var speed_len := current_h_vel.length()

	# Manejo de inercia
	if speed_len > target_speed:
		if is_on_floor():
			# Si está tocando el suelo, frena ese exceso de velocidad poco a poco
			var target_h_vel = current_h_vel.normalized() * target_speed
			velocity.x = move_toward(velocity.x, target_h_vel.x, MOMENTUM_DECAY * 1.5 * delta)
			velocity.z = move_toward(velocity.z, target_h_vel.z, MOMENTUM_DECAY * 1.5 * delta)
		else:
			# Si está en el aire, permite redireccionar el vuelo sin perder todo el impulso seco
			if direction != Vector3.ZERO:
				var blended_dir = lerp(current_h_vel.normalized(), direction, AIR_CONTROL * 0.5 * delta).normalized()
				velocity.x = blended_dir.x * move_toward(speed_len, SPEED, MOMENTUM_DECAY * 0.8 * delta)
				velocity.z = blended_dir.z * move_toward(speed_len, SPEED, MOMENTUM_DECAY * 0.8 * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, MOMENTUM_DECAY * 0.5 * delta)
				velocity.z = move_toward(velocity.z, 0, MOMENTUM_DECAY * 0.5 * delta)
	else:
		# Movimiento básico cuando va a velocidad normal
		if is_on_floor():
			if direction != Vector3.ZERO:
				velocity.x = move_toward(velocity.x, direction.x * target_speed, ACCEL * delta)
				velocity.z = move_toward(velocity.z, direction.z * target_speed, ACCEL * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
				velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
		else:
			if direction != Vector3.ZERO:
				velocity.x = move_toward(velocity.x, direction.x * SPEED, AIR_CONTROL * delta)
				velocity.z = move_toward(velocity.z, direction.z * SPEED, AIR_CONTROL * delta)

	move_and_slide()

	_update_locomotion_animation(is_sprinting)

# Elige y reproduce la animación correspondiente al movimiento actual, con blend suave
func _update_locomotion_animation(is_sprinting: bool) -> void:
	if not animation_player:
		return

	var target_animation: String

	if not is_on_floor():
		if velocity.y > 0.0:
			target_animation = ANIM_JUMP
		else:
			target_animation = ANIM_FALL
	else:
		var horizontal_speed := Vector3(velocity.x, 0, velocity.z).length()
		if horizontal_speed < IDLE_SPEED_THRESHOLD:
			target_animation = ANIM_IDLE
		elif is_sprinting:
			target_animation = ANIM_RUN
		else:
			target_animation = ANIM_RUN ## Era ANIM_WALK, ahora corre siepre.

	if animation_player.current_animation != target_animation:
		animation_player.play(target_animation, ANIM_BLEND_TIME)

# Reinicia la posición del personaje si cae
func respawn() -> void:
	current_state = State.NORMAL
	global_position = spawn_position
	velocity = Vector3.ZERO
