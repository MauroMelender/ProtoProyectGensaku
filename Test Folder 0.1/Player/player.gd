class_name Player
extends CharacterBody3D

const ZIEL_MODEL_SCENE: PackedScene = preload("res://assets/models/characters/ziel/ziel.tscn")

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
@export_range(0.0, 0.3, 0.01) var COYOTE_TIME: float = 0.12 # Ventana para saltar justo después de dejar un borde
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
@export_range(0.0, 1.0, 0.05) var DASH_REDIRECT_STRENGTH: float = 0.65 # Conserva velocidad y curva hacia la dirección del dash

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

@export_group("Rastro del récord")
@export_range(0.05, 0.8, 0.01) var BEST_TRAIL_DOT_SPACING: float = 0.12
@export_range(0.04, 0.2, 0.01) var BEST_TRAIL_DOT_RADIUS: float = 0.095
@export_range(0.05, 0.8, 0.05) var BEST_TRAIL_OPACITY: float = 0.3
@export_range(0.05, 0.8, 0.05) var BEST_RUNNER_OPACITY: float = 0.3

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
var _coyote_timer: float = 0.0
var _coyote_jump_available: bool = true
var _best_trail: MultiMeshInstance3D
var _best_runner: Node3D
var _best_runner_animation: AnimationPlayer
var _best_runner_index: int = 0
var _best_trail_times: PackedFloat32Array = PackedFloat32Array()
var _best_trail_visible_count: int = 0
var _record_elapsed: float = 0.0

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
	# Espera al CanvasLayer del nivel, que carga el récord de esta escena.
	if _best_trail == null and not GameManager.mejor_rastro.is_empty():
		_create_best_time_trail()
	if global_position.y < FALL_LIMIT_Y:
		respawn()

	if GameManager.conteo_inicio_activo:
		# Congela el cuerpo durante el conteo sin detener animaciones ni cámara.
		velocity = Vector3.ZERO
		current_state = State.NORMAL
		_update_animations()
		_update_best_time_trail()
		if grapple_ability:
			grapple_ability.update_reticle()
		if camera_controller:
			camera_controller.update_camera_clearance()
		return
	if GameManager.cronometro_activo:
		_record_elapsed += delta

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
	if grapple_ability:
		grapple_ability.update_reticle()
	if camera_controller:
		camera_controller.update_camera_clearance()
	_record_best_route_step()

# La cámara se actualiza en cada frame de render para que no se vea a tirones
func _process(delta: float) -> void:
	if camera_controller:
		camera_controller.check_and_update(delta)
	_update_best_time_trail()

# Hacia dónde es "adelante": el cuerpo, o la cámara mientras la orbitás con el clic derecho
func get_move_basis() -> Basis:
	if camera_pivot and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return Basis(Vector3.UP, rotation.y + camera_pivot.rotation.y)
	return transform.basis

func _create_best_time_trail() -> void:
	var best_run: Array = GameManager.mejor_rastro
	if best_run.is_empty() or get_tree().current_scene == null:
		return

	var positions := PackedVector3Array()
	_best_trail_times = PackedFloat32Array()
	var first_step: Dictionary = best_run[0]
	var first_position := _route_position(first_step)
	var previous_position := first_position
	var previous_time := float(first_step.get("t", 0.0))
	positions.append(first_position)
	_best_trail_times.append(previous_time)
	var distance_to_next_dot := BEST_TRAIL_DOT_SPACING
	var travelled_distance := 0.0

	for i in range(1, best_run.size()):
		var step: Dictionary = best_run[i]
		var current_position := _route_position(step)
		var current_time := float(step.get("t", previous_time))
		var segment := current_position - previous_position
		var segment_length := segment.length()
		while segment_length > 0.001 and travelled_distance + segment_length >= distance_to_next_dot:
			var segment_distance := distance_to_next_dot - travelled_distance
			var weight := clampf(segment_distance / segment_length, 0.0, 1.0)
			positions.append(previous_position.lerp(current_position, weight))
			_best_trail_times.append(lerpf(previous_time, current_time, weight))
			distance_to_next_dot += BEST_TRAIL_DOT_SPACING
		travelled_distance += segment_length
		previous_position = current_position
		previous_time = current_time

	if positions[-1].distance_to(previous_position) > 0.05:
		positions.append(previous_position)
		_best_trail_times.append(previous_time)

	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = BEST_TRAIL_DOT_RADIUS
	dot_mesh.height = BEST_TRAIL_DOT_RADIUS * 2.0
	dot_mesh.radial_segments = 6
	dot_mesh.rings = 3
	var dot_material := StandardMaterial3D.new()
	dot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot_material.albedo_color = Color(0.08, 0.82, 1.0, BEST_TRAIL_OPACITY)
	dot_material.emission_enabled = true
	dot_material.emission = Color(0.02, 0.22, 0.32)
	dot_material.no_depth_test = false
	dot_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	dot_material.render_priority = 10
	dot_mesh.material = dot_material

	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = dot_mesh
	multi_mesh.instance_count = positions.size()
	multi_mesh.visible_instance_count = 0
	var bounds := AABB(positions[0], Vector3.ZERO)
	for i in range(positions.size()):
		multi_mesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, positions[i]))
		bounds = bounds.expand(positions[i])

	_best_trail = MultiMeshInstance3D.new()
	_best_trail.name = "RastroMejorTiempo"
	_best_trail.multimesh = multi_mesh
	_best_trail.custom_aabb = bounds.grow(BEST_TRAIL_DOT_RADIUS * 2.0)
	get_tree().current_scene.add_child(_best_trail)
	_best_trail.global_transform = Transform3D.IDENTITY
	_best_trail.add_to_group("sin_manga")
	var exception_manager := get_node_or_null("GestorExcepciones")
	if exception_manager and exception_manager.has_method("aplicar"):
		exception_manager.call("aplicar", _best_trail)
	_create_best_run_figure(best_run)

func _create_best_run_figure(best_run: Array) -> void:
	if best_run.is_empty() or get_tree().current_scene == null:
		return
	_best_runner = ZIEL_MODEL_SCENE.instantiate() as Node3D
	_best_runner.name = "CorredorRecord"
	get_tree().current_scene.add_child(_best_runner)
	_best_runner_animation = _best_runner.get_node_or_null("AnimationPlayer") as AnimationPlayer
	_make_runner_translucent(_best_runner)
	_update_best_run_figure()

func _make_runner_translucent(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var mesh_instance := nodo as MeshInstance3D
		if mesh_instance.mesh:
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var source_material := mesh_instance.get_active_material(surface)
				var material: BaseMaterial3D
				if source_material is BaseMaterial3D:
					material = (source_material as BaseMaterial3D).duplicate() as BaseMaterial3D
				else:
					material = StandardMaterial3D.new()
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				var tint := material.albedo_color
				tint.a = BEST_RUNNER_OPACITY
				material.albedo_color = tint
				material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
				mesh_instance.set_surface_override_material(surface, material)
	for hijo in nodo.get_children():
		_make_runner_translucent(hijo)

func _update_best_run_figure() -> void:
	if _best_runner == null or GameManager.mejor_rastro.is_empty():
		return
	var best_run: Array = GameManager.mejor_rastro
	var elapsed := GameManager.tiempo_actual
	if elapsed > float(best_run[-1].get("t", 0.0)):
		_best_runner.visible = false
		return
	_best_runner.visible = true
	while _best_runner_index + 1 < best_run.size() and float(best_run[_best_runner_index + 1].get("t", 0.0)) < elapsed:
		_best_runner_index += 1
	var step_a: Dictionary = best_run[_best_runner_index]
	var next_index := mini(_best_runner_index + 1, best_run.size() - 1)
	var step_b: Dictionary = best_run[next_index]
	var time_a := float(step_a.get("t", 0.0))
	var time_b := float(step_b.get("t", time_a))
	var weight := 0.0 if time_b <= time_a else clampf((elapsed - time_a) / (time_b - time_a), 0.0, 1.0)
	_best_runner.global_position = _route_position(step_a).lerp(_route_position(step_b), weight)
	var yaw := lerp_angle(float(step_a.get("y", 0.0)), float(step_b.get("y", step_a.get("y", 0.0))), weight)
	_best_runner.global_rotation = Vector3(0.0, yaw, 0.0)
	if _best_runner_animation:
		var animation_name := str(step_a.get("a", ANIM_RUN))
		if not _best_runner_animation.has_animation(animation_name):
			animation_name = ANIM_IDLE
		if _best_runner_animation.has_animation(animation_name):
			if _best_runner_animation.current_animation != animation_name:
				_best_runner_animation.play(animation_name, 0.0)
			var animation_position := float(step_a.get("ap", 0.0))
			_best_runner_animation.seek(animation_position, true)

func _route_position(step: Dictionary) -> Vector3:
	var point: Array = step.get("p", [0.0, 0.0, 0.0])
	return Vector3(float(point[0]), float(point[1]), float(point[2]))

func _update_best_time_trail() -> void:
	if _best_trail == null or _best_trail.multimesh == null:
		return
	var elapsed := GameManager.tiempo_actual
	while _best_trail_visible_count < _best_trail_times.size() and _best_trail_times[_best_trail_visible_count] <= elapsed:
		_best_trail_visible_count += 1
	_best_trail.multimesh.visible_instance_count = _best_trail_visible_count
	_update_best_run_figure()

func clear_best_time_trail() -> void:
	if is_instance_valid(_best_trail):
		_best_trail.queue_free()
	if is_instance_valid(_best_runner):
		_best_runner.queue_free()
	_best_trail = null
	_best_runner = null
	_best_runner_animation = null
	_best_trail_times.clear()
	_best_trail_visible_count = 0

func _record_best_route_step() -> void:
	if not GameManager.cronometro_activo:
		return
	GameManager.registrar_paso_rastro({
		"t": _record_elapsed,
		"p": [global_position.x, global_position.y, global_position.z],
		"y": rotation.y,
		"a": animation_player.current_animation if animation_player else ANIM_IDLE,
		"ap": animation_player.current_animation_position if animation_player else 0.0
	})

func hide_character() -> void:
	$Ziel.visible = false
	if _best_runner:
		_best_runner.visible = false
	if _best_trail and _best_trail.multimesh:
		_best_trail_visible_count = _best_trail_times.size()
		_best_trail.multimesh.visible_instance_count = _best_trail_visible_count

func _process_normal_movement(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = COYOTE_TIME
		_coyote_jump_available = true
		jump_count = 0
		velocity.y = minf(velocity.y, 0.0)
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
		if _coyote_timer <= 0.0:
			_coyote_jump_available = false
		velocity.y -= gravity * delta
		# Si se cae de un borde sin saltar, ya gastó el salto "del suelo" 
		if _was_on_floor and jump_count == 0:
			jump_count = 1
	_was_on_floor = is_on_floor()

	if Input.is_action_just_pressed("saltar"):
		if is_on_floor() or (_coyote_jump_available and _coyote_timer > 0.0):
			# El salto suma impulso hacia arriba sin borrar la componente horizontal.
			velocity.y = maxf(velocity.y, 0.0) + JUMP_VELOCITY
			jump_count = maxi(jump_count, 1)
			_coyote_jump_available = false
			_coyote_timer = 0.0
		elif jump_count < MAX_JUMPS:
			velocity.y = maxf(velocity.y, 0.0) + DOUBLE_JUMP_VELOCITY
			jump_count += 1

	var input_dir := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
	var direction := (get_move_basis() * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var is_walking := is_on_floor() and Input.is_action_pressed("correr")

	var current_h_vel := Vector3(velocity.x, 0, velocity.z)
	var speed_len := current_h_vel.length()

	_update_speed_level(delta, direction, is_walking, speed_len)

	var target_speed: float = SPEED if is_walking else speed_level

	if is_on_floor() and velocity.y <= 0.0:
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
				var kept_speed := move_toward(speed_len, speed_level, MOMENTUM_DECAY * 0.25 * decay_scale * delta)
				velocity.x = blended_dir.x * kept_speed
				velocity.z = blended_dir.z * kept_speed
			else:
				velocity.x = move_toward(velocity.x, 0, MOMENTUM_DECAY * 0.15 * decay_scale * delta)
				velocity.z = move_toward(velocity.z, 0, MOMENTUM_DECAY * 0.15 * decay_scale * delta)
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
	if GameManager.conteo_inicio_activo:
		if animation_player.has_animation(ANIM_IDLE) and animation_player.current_animation != ANIM_IDLE:
			animation_player.play(ANIM_IDLE, ANIM_BLEND_TIME)
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
	_coyote_timer = 0.0
	_coyote_jump_available = false
