class_name Player
extends CharacterBody3D

# --- PARÁMETROS CONFIGURABLES ---
@export_group("Movimiento Base")
@export var SPEED: float = 4.0 # Velocidad despacio al caminar (con Shift)
@export var RUN_SPEED: float = 9.0 # Velocidad normal al correr (Por defecto)
@export var ACCEL: float = 25.0 # Qué tan rápido acelera
@export var FRICTION: float = 50.0 # Qué tan rápido frena al soltar las teclas (freno seco)
@export var AIR_CONTROL: float = 6.0 # Control que tenés sobre el personaje mientras está volando
@export var GROUND_STEER: float = 8.0 # Qué tan rápido podés girar en el suelo yendo más rápido que RUN_SPEED
@export var MOMENTUM_DECAY: float = 8.0 # Qué tan rápido pierde el "impulso" extra (del Dash o WallRun)
@export var JUMP_VELOCITY: float = 6.0 # Fuerza del salto
@export var DOUBLE_JUMP_VELOCITY: float = 7.5 # Fuerza del segundo salto (en el aire)
@export var MAX_JUMPS: int = 2 # Cantidad de saltos (2 = doble salto)
@export var MOUSE_SENSITIVITY: float = 0.003 # Sensibilidad de la cámara
@export var FALL_LIMIT_Y: float = -10.0 # Si cae más abajo de esta altura en Y, reaparece

@export_group("Velocidad Progresiva")
@export var RUN_MAX_SPEED: float = 14.0 # Tope de la velocidad base al correr en el suelo
@export var RUN_BUILDUP: float = 2.0 # Velocidad base que gana por segundo mientras corrés
@export var SPEED_LOSS: float = 5.0 # Velocidad base que pierde por segundo al frenar o caminar
@export var OVER_MAX_LOSS: float = 2.0 # Pérdida lenta cuando estás por encima de RUN_MAX_SPEED (viene del Wall Run)
@export var MAX_SPEED: float = 50.0 # Tope absoluto de velocidad total, también vertical (incluye gancho, wall run y caída)

@export_group("Agarrado (Ledge)")
@export var CLIMB_SPEED: float = 2.5 # Velocidad para moverse de lado al estar colgado
@export var LEDGE_JUMP_FORWARD_FORCE: float = 3.0 # Impulso hacia adelante al saltar estando colgado

@export_group("Wall Running")
@export var WALL_RUN_SPEED: float = 22.0 # Tope de velocidad al correr por la pared
@export var WALL_RUN_ACCEL: float = 8.0 # Velocidad que gana por segundo en la pared (arranca desde la que traías)
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

@export_group("Animaciones Base")
@export var ANIM_IDLE: String = "Anim_Z_IdleCycle"
@export var ANIM_WALK: String = "Anim_Z_WalkCycle"
@export var ANIM_RUN: String = "Anim_Z_RunCycle"
@export var ANIM_JUMP: String = "Anim_Z_RunJumping"
@export var ANIM_FALL: String = "Anim_Z_AirborneCycle"

@export_group("Animaciones Parkour / WallRun")
@export var ANIM_HANGING: String = "Anim_Z_HangindOnLedge" # Colgado del borde
@export var ANIM_WALL_RUN_LEFT: String = "Anim_Z_WallRunCycle_L" # Correr pared izquierda
@export var ANIM_WALL_RUN_RIGHT: String = "Anim_Z_WallRunCycle_R" # Correr pared derecha
@export var ANIM_WALL_JUMP_LEFT: String = "Anim_Z_WallRunJump_L" # Saltar pared izquierda
@export var ANIM_WALL_JUMP_RIGHT: String = "Anim_Z_WallRunJump_R" # Saltar pared derecha

@export var ANIM_BLEND_TIME: float = 0.15 # Duración de la transición entre animaciones
@export var IDLE_SPEED_THRESHOLD: float = 0.3 # Por debajo de esta velocidad horizontal, se considera Idle

# Estados del jugador
enum State { NORMAL, AGARRADO, WALL_RUNNING, GANCHO }
var current_state: State = State.NORMAL

var jump_count: int = 0
var speed_level: float = 9.0 # Velocidad base actual: sube al correr y más rápido en wall run (ver RUN_SPEED / RUN_MAX_SPEED)
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var spawn_position: Vector3 
var last_fall_velocity: float = 0.0
var _was_on_floor: bool = true

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
@onready var grapple_ability: Grapple = $Habilidades/Gancho
@onready var camera_controller: CameraController = $CameraPivot/CameraController

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Oculta el mouse en la pantalla
	spawn_position = global_position 
	speed_level = RUN_SPEED

	# Ignora el propio cuerpo del jugador para que los RayCasts no se chocan entre sí
	ray_pared.add_exception(self)
	ray_borde.add_exception(self)
	if ray_izquierda: ray_izquierda.add_exception(self)
	if ray_derecha: ray_derecha.add_exception(self)

func _unhandled_input(event: InputEvent) -> void:
	# Maneja la rotación de la cámara con el mouse
	if event is InputEventMouseMotion:
		var is_orbiting := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		
		if is_orbiting:
			# Clic Derecho: gira la cámara libremente en 360° sin girar al personaje
			if camera_controller:
				camera_controller.add_orbit_rotation(event.relative * MOUSE_SENSITIVITY)
		else:
			# Mover el mouse gira todo el cuerpo del personaje
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
			
			# El gancho tiene prioridad sobre el borde y el wall run.
			if not grapple_ability.check_and_update(delta):
				if not ledge_ability.check_and_update(delta):
					wall_run_ability.check_and_update(delta)

		State.GANCHO:
			_was_on_floor = false
			grapple_ability.process_movement(delta)

		State.AGARRADO:
			_was_on_floor = false
			ledge_ability.process_movement(delta)

		State.WALL_RUNNING:
			_was_on_floor = false
			wall_run_ability.process_movement(delta)

	# Tope absoluto de velocidad total (horizontal + vertical, es la que muestra el HUD)
	if velocity.length() > MAX_SPEED:
		velocity = velocity.normalized() * MAX_SPEED

	# Actualiza las animaciones según el estado en que esté
	_update_animations()

# La cámara se actualiza en cada frame de render para que no se vea a tirones
func _process(delta: float) -> void:
	if camera_controller:
		camera_controller.check_and_update(delta)

# Hacia dónde es "adelante": el cuerpo, o la cámara mientras la orbitás con el clic derecho
func get_move_basis() -> Basis:
	if camera_pivot and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return Basis(Vector3.UP, rotation.y + camera_pivot.rotation.y)
	return transform.basis

func _process_normal_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		# Si se cae de un borde sin saltar, ya gastó el salto "del suelo" 
		if _was_on_floor and jump_count == 0:
			jump_count = 1
	else:
		jump_count = 0
	_was_on_floor = is_on_floor()

	if Input.is_action_just_pressed("saltar"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			jump_count = 1
		elif jump_count < MAX_JUMPS:
			velocity.y = DOUBLE_JUMP_VELOCITY
			jump_count += 1

	var input_dir := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
	var direction := (get_move_basis() * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var is_walking := is_on_floor() and Input.is_action_pressed("correr")

	var current_h_vel := Vector3(velocity.x, 0, velocity.z)
	var speed_len := current_h_vel.length()

	_update_speed_level(delta, direction, is_walking, speed_len)

	var target_speed: float = SPEED if is_walking else speed_level

	if is_on_floor():
		if direction == Vector3.ZERO:
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
			velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
		else:
			if speed_len > speed_level + 0.5:
				# Con impulso extra: baja la velocidad de a poco pero te deja girar
				var steer_dir := current_h_vel.normalized().lerp(direction, clampf(GROUND_STEER * delta, 0.0, 1.0)).normalized()
				var new_speed := move_toward(speed_len, target_speed, MOMENTUM_DECAY * 1.5 * delta)
				velocity.x = steer_dir.x * new_speed
				velocity.z = steer_dir.z * new_speed
			else:
				velocity.x = move_toward(velocity.x, direction.x * target_speed, ACCEL * delta)
				velocity.z = move_toward(velocity.z, direction.z * target_speed, ACCEL * delta)
	else:
		# Justo después de soltar el gancho, el impulso no se pierde en el aire
		var decay_scale: float = 0.0 if grapple_ability.momentum_grace > 0.0 else 1.0
		if speed_len > speed_level:
			if direction != Vector3.ZERO:
				var blended_dir = lerp(current_h_vel.normalized(), direction, AIR_CONTROL * 0.5 * delta).normalized()
				var kept_speed := move_toward(speed_len, speed_level, MOMENTUM_DECAY * 0.8 * decay_scale * delta)
				velocity.x = blended_dir.x * kept_speed
				velocity.z = blended_dir.z * kept_speed
			else:
				velocity.x = move_toward(velocity.x, 0, MOMENTUM_DECAY * 0.5 * decay_scale * delta)
				velocity.z = move_toward(velocity.z, 0, MOMENTUM_DECAY * 0.5 * decay_scale * delta)
		else:
			if direction != Vector3.ZERO:
				velocity.x = move_toward(velocity.x, direction.x * speed_level, AIR_CONTROL * delta)
				velocity.z = move_toward(velocity.z, direction.z * speed_level, AIR_CONTROL * delta)

	move_and_slide()

# Velocidad base progresiva: sube mientras corrés a buena velocidad y baja al frenar
func _update_speed_level(delta: float, direction: Vector3, is_walking: bool, speed_len: float) -> void:
	if is_on_floor():
		var running := direction != Vector3.ZERO and not is_walking
		if running and speed_len >= speed_level * 0.85:
			if speed_level < RUN_MAX_SPEED:
				speed_level = minf(speed_level + RUN_BUILDUP * delta, RUN_MAX_SPEED)
			else:
				speed_level = move_toward(speed_level, RUN_MAX_SPEED, OVER_MAX_LOSS * delta)
		else:
			speed_level = move_toward(speed_level, RUN_SPEED, SPEED_LOSS * delta)
	speed_level = clampf(speed_level, RUN_SPEED, MAX_SPEED)

# Gestor general de animaciones (Caminar, Correr, Colgarse, Wall Run)
func _update_animations() -> void:
	if not animation_player:
		return

	var target_animation: String = ""

	match current_state:
		State.AGARRADO:
			target_animation = ANIM_HANGING

		State.GANCHO:
			target_animation = ANIM_FALL # Animación provisoria mientras se balancea

		State.WALL_RUNNING:
			# Elige animación si la pared está a la izquierda o derecha
			if ray_izquierda and ray_izquierda.is_colliding():
				target_animation = ANIM_WALL_RUN_LEFT
			elif ray_derecha and ray_derecha.is_colliding():
				target_animation = ANIM_WALL_RUN_RIGHT

		State.NORMAL:
			var is_walking := is_on_floor() and Input.is_action_pressed("correr")
			
			if not is_on_floor():
				if velocity.y > 0.0:
					target_animation = ANIM_JUMP
				else:
					target_animation = ANIM_FALL
			else:
				var horizontal_speed := Vector3(velocity.x, 0, velocity.z).length()
				if horizontal_speed < IDLE_SPEED_THRESHOLD:
					target_animation = ANIM_IDLE
				elif is_walking:
					target_animation = ANIM_WALK
				else:
					target_animation = ANIM_RUN

	if target_animation != "" and animation_player.has_animation(target_animation):
		if animation_player.current_animation != target_animation:
			animation_player.play(target_animation, ANIM_BLEND_TIME)

func respawn() -> void:
	current_state = State.NORMAL
	grapple_ability.reset()
	global_position = spawn_position
	velocity = Vector3.ZERO
	speed_level = RUN_SPEED
