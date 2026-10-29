class_name Grapple
extends Node

# --- CONFIGURACIÓN DEL GANCHO ---
@export var MAX_DISTANCE: float = 45.0
@export var COOLDOWN_TIME: float = 0.25
@export var HAND_OFFSET: Vector3 = Vector3(0, 1.2, 0)

# --- TIRÓN (ACELERACIÓN PROGRESIVA) ---
@export_group("Tirón")
@export var IMPACT_IMPULSE: float = 6.0       # Empujón instantáneo hacia el ancla al enganchar
@export var PULL_ACCEL_START: float = 25.0    # Aceleración al empezar a tirar
@export var PULL_ACCEL_MAX: float = 90.0      # Aceleración después de RAMP_TIME segundos tirando
@export var RAMP_TIME: float = 1.2            # Tiempo hasta llegar a la aceleración máxima
@export var MAX_PULL_SPEED: float = 45.0      # El tirón deja de sumar velocidad hacia el ancla pasando esto (no recorta tu velocidad)
@export var GRAVITY_SCALE: float = 0.35       # Cuánta gravedad se aplica mientras te jala (0 = nada)
@export var STEER_ACCEL: float = 12.0         # Control lateral mientras te jala
@export var ARRIVE_DISTANCE: float = 2.5      # Al llegar a esta distancia del ancla te suelta conservando la velocidad
@export var CHAIN_RAMP_BONUS: float = 0.6     # Si enganchás ya rápido, la rampa arranca más adelantada (0 a 1)
@export var STUCK_RELEASE_TIME: float = 0.25  # Si quedás trabado contra una pared, suelta solo

# --- MOMENTUM ---
@export_group("Momentum")
@export var RELEASE_JUMP_BOOST: float = 1.15  # Multiplicador horizontal al soltar con salto
@export var MOMENTUM_GRACE_TIME: float = 1.0  # Segundos en el aire sin perder velocidad tras soltar

# --- CONFIGURACIÓN DE LA CADENA ---
@export_group("Cadena")
@export var CHAIN_LINK_SPACING: float = 0.14
@export var CHAIN_LINK_OUTER_RADIUS: float = 0.065
@export var CHAIN_LINK_INNER_RADIUS: float = 0.035
@export var CHAIN_COLOR: Color = Color(0.16, 0.17, 0.19)

# --- CONFIGURACIÓN DEL PROYECTIL ---
@export_group("Proyectil")
@export var PROJECTILE_SPEED: float = 45.0
@export var RETURN_SPEED: float = 45.0
@export var INHERIT_VELOCITY: float = 1.0 # Cuánta velocidad del jugador se suma al proyectil (0 = nada, 1 = toda)
@export var PROJECTILE_LENGTH: float = 0.8
@export var PROJECTILE_RADIUS: float = 0.09
@export var PROJECTILE_COLOR: Color = Color(0.22, 0.24, 0.27)

var _firing: bool = false
var _returning: bool = false
var _attached: bool = false

var _shot_direction: Vector3 = Vector3.FORWARD
var _shot_distance: float = 0.0

var player: Player
var anchor: Vector3 = Vector3.ZERO
var cooldown_timer: float = 0.0
var momentum_grace: float = 0.0 # Lo lee Player para no frenar el impulso en el aire

var _pull_time: float = 0.0
var _stuck_time: float = 0.0

var _chain_links: Array[MeshInstance3D] = []
var _chain_material: StandardMaterial3D

var _projectile: MeshInstance3D
var _projectile_material: StandardMaterial3D


func _ready() -> void:
	player = get_parent().get_parent() as Player
	_ensure_input_action()
	_build_rope()
	_build_projectile()


# Crea la acción si todavía no existe. Controles: clic izquierdo o tecla E.
func _ensure_input_action() -> void:
	if not InputMap.has_action("gancho"):
		InputMap.add_action("gancho")

		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("gancho", click)

		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		InputMap.action_add_event("gancho", key)


# Construye los eslabones metálicos de la cadena.
func _build_rope() -> void:
	_chain_material = StandardMaterial3D.new()
	_chain_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_chain_material.metallic = 0.78
	_chain_material.roughness = 0.32
	_chain_material.albedo_color = CHAIN_COLOR

	var link_count := ceili(MAX_DISTANCE / CHAIN_LINK_SPACING) + 2

	for i in range(link_count):
		var mesh := TorusMesh.new()
		mesh.inner_radius = CHAIN_LINK_INNER_RADIUS
		mesh.outer_radius = CHAIN_LINK_OUTER_RADIUS
		mesh.rings = 8
		mesh.ring_segments = 6
		mesh.material = _chain_material

		var link := MeshInstance3D.new()
		link.name = "Eslabon_%03d" % i
		link.mesh = mesh
		link.top_level = true
		link.visible = false
		link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		add_child(link)
		_chain_links.append(link)


# Construye el proyectil metálico que sale disparado.
func _build_projectile() -> void:
	_projectile_material = StandardMaterial3D.new()
	_projectile_material.metallic = 0.85
	_projectile_material.roughness = 0.25
	_projectile_material.albedo_color = PROJECTILE_COLOR

	var mesh := CylinderMesh.new()
	mesh.top_radius = PROJECTILE_RADIUS
	mesh.bottom_radius = PROJECTILE_RADIUS
	mesh.height = PROJECTILE_LENGTH
	mesh.radial_segments = 10
	mesh.material = _projectile_material

	_projectile = MeshInstance3D.new()
	_projectile.name = "ProyectilGancho"
	_projectile.mesh = mesh
	_projectile.top_level = true
	_projectile.visible = false
	_projectile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(_projectile)


# Posición aproximada de la mano del jugador.
func _hand() -> Vector3:
	return player.global_position + player.global_transform.basis * HAND_OFFSET


# Dirección de apuntado de la cámara.
func _get_aim_direction() -> Vector3:
	var cam := get_viewport().get_camera_3d()

	if cam == null:
		return -player.global_transform.basis.z

	return -cam.global_transform.basis.z.normalized()


# Inicia el disparo del proyectil.
func _start_shot() -> void:
	_shot_direction = _get_aim_direction()
	_shot_distance = 0.0

	_projectile.global_position = _hand()
	_orient_projectile(_shot_direction)

	_firing = true
	_returning = false
	_projectile.visible = true
	_hide_chain()


# Orienta el cilindro para que su eje apunte en la dirección del disparo.
func _orient_projectile(direction: Vector3) -> void:
	if direction.length_squared() < 0.001:
		return

	var dir := direction.normalized()
	var up := Vector3.UP

	if absf(dir.dot(up)) > 0.99:
		up = Vector3.RIGHT

	_projectile.global_basis = Basis.looking_at(dir, up).rotated(Vector3.RIGHT, PI * 0.5)


# Comprueba si el proyectil golpea una superficie durante su recorrido.
func _check_projectile_collision(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	return player.get_world_3d().direct_space_state.intersect_ray(query)


# Se llama mientras el jugador está en estado NORMAL.
# Devuelve true si el gancho tomó el control (así Player no revisa Ledge/WallRun).
func check_and_update(delta: float) -> bool:
	if cooldown_timer > 0.0:
		cooldown_timer = maxf(cooldown_timer - delta, 0.0)

	if momentum_grace > 0.0:
		momentum_grace = maxf(momentum_grace - delta, 0.0)

	if _firing or _returning:
		_process_projectile(delta)
		return player.current_state == Player.State.GANCHO

	if _attached or cooldown_timer > 0.0:
		return false

	if Input.is_action_just_pressed("gancho"):
		_start_shot()

	return false


# Movimiento del proyectil: sale, impacta o vuelve.
func _process_projectile(delta: float) -> void:
	if _firing:
		# Soltar el botón durante el disparo hace volver el proyectil.
		if not Input.is_action_pressed("gancho"):
			_begin_return()
			return

		var remaining := MAX_DISTANCE - _shot_distance

		if remaining <= 0.0:
			_begin_return()
			return

		# Suma la velocidad del jugador en la dirección del disparo (la mira no se desvía)
		var shot_speed := PROJECTILE_SPEED + maxf(player.velocity.dot(_shot_direction), 0.0) * INHERIT_VELOCITY
		var travel := minf(shot_speed * delta, remaining)
		var current := _projectile.global_position
		var next_position := current + _shot_direction * travel

		var hit := _check_projectile_collision(current, next_position)

		if not hit.is_empty():
			_attach(hit["position"])
			return

		_projectile.global_position = next_position
		_orient_projectile(_shot_direction)
		_shot_distance += travel

		if _shot_distance >= MAX_DISTANCE:
			_begin_return()

		return

	if _returning:
		var hand_position := _hand()
		var current_position := _projectile.global_position

		_projectile.global_position = current_position.move_toward(
			hand_position,
			(RETURN_SPEED + player.velocity.length() * INHERIT_VELOCITY) * delta
		)

		var return_direction := hand_position - current_position

		if return_direction.length_squared() > 0.001:
			_orient_projectile(return_direction.normalized())

		if _projectile.global_position.distance_to(hand_position) < 0.15:
			_projectile.visible = false
			_returning = false
			cooldown_timer = COOLDOWN_TIME


# El proyectil se clavó: empieza el tirón con un impulso inicial.
func _attach(hit_position: Vector3) -> void:
	anchor = hit_position
	_firing = false
	_attached = true
	_projectile.global_position = anchor
	_projectile.visible = true

	player.current_state = Player.State.GANCHO

	var dir := (anchor - _hand()).normalized()
	player.velocity += dir * IMPACT_IMPULSE

	# Si ya venías rápido, la aceleración arranca más adelantada en la rampa (encadenar gana velocidad).
	var speed_ratio := clampf(player.velocity.length() / MAX_PULL_SPEED, 0.0, 1.0)
	_pull_time = RAMP_TIME * speed_ratio * CHAIN_RAMP_BONUS
	_stuck_time = 0.0

	# Un enganche cancela la caída acumulada hacia abajo para que el tirón se sienta directo.
	if player.velocity.y < 0.0:
		player.velocity.y *= 0.3


func _begin_return() -> void:
	_firing = false
	_returning = true
	_attached = false


# Tirón con aceleración creciente. Nunca recorta la velocidad existente: la conserva y le suma.
func process_movement(delta: float) -> void:
	var jumped := Input.is_action_just_pressed("saltar")

	if not Input.is_action_pressed("gancho") or jumped:
		_release(jumped)
		return

	var to_anchor := anchor - _hand()
	var dist := to_anchor.length()

	# Llegaste: soltás conservando toda la velocidad.
	if dist <= ARRIVE_DISTANCE:
		_release(false)
		return

	var dir := to_anchor / dist
	_pull_time += delta

	# Aceleración que crece con el tiempo (curva suave).
	var t := clampf(_pull_time / RAMP_TIME, 0.0, 1.0)
	var accel := lerpf(PULL_ACCEL_START, PULL_ACCEL_MAX, t * t)

	# Suma velocidad hacia el ancla, hasta MAX_PULL_SPEED en esa dirección.
	var radial := player.velocity.dot(dir)
	var add := minf(accel * delta, maxf(MAX_PULL_SPEED - radial, 0.0))
	player.velocity += dir * add

	# Gravedad reducida y control lateral.
	player.velocity.y -= player.gravity * GRAVITY_SCALE * delta

	var input_dir := Input.get_vector(
		"mover_izquierda",
		"mover_derecha",
		"mover_adelante",
		"mover_atras"
	)
	var wish := player.get_move_basis() * Vector3(input_dir.x, 0, input_dir.y)
	player.velocity += wish.normalized() * STEER_ACCEL * delta * minf(input_dir.length(), 1.0)

	player.move_and_slide()

	# Si te trabás contra una pared, suelta solo.
	if player.get_real_velocity().length() < 2.0 and _pull_time > 0.3:
		_stuck_time += delta
		if _stuck_time >= STUCK_RELEASE_TIME:
			_release(false)
			return
	else:
		_stuck_time = 0.0

	_update_rope()


# Libera al jugador conservando su velocidad.
func _release(jumped: bool) -> void:
	player.current_state = Player.State.NORMAL
	player.jump_count = 1

	if _attached:
		_projectile.global_position = anchor
		_begin_return()
	elif _firing:
		_begin_return()

	_hide_chain()
	cooldown_timer = COOLDOWN_TIME
	momentum_grace = MOMENTUM_GRACE_TIME

	if jumped:
		player.velocity.x *= RELEASE_JUMP_BOOST
		player.velocity.z *= RELEASE_JUMP_BOOST
		player.velocity.y += player.JUMP_VELOCITY * 0.5


# Limpia el estado del gancho, por ejemplo, al reaparecer el jugador.
func reset() -> void:
	cooldown_timer = 0.0
	momentum_grace = 0.0
	_pull_time = 0.0
	_stuck_time = 0.0
	_firing = false
	_returning = false
	_attached = false

	if is_instance_valid(_projectile):
		_projectile.visible = false

	_hide_chain()


# Oculta todos los eslabones.
func _hide_chain() -> void:
	for link in _chain_links:
		link.visible = false


# Actualiza la cadena entre la mano y el ancla.
func _update_rope() -> void:
	var a := _hand()
	var b := anchor
	var offset := b - a
	var length := offset.length()

	if length < 0.01:
		_hide_chain()
		return

	var dir := offset / length
	var link_count := mini(
		_chain_links.size(),
		maxi(2, ceili(length / CHAIN_LINK_SPACING) + 1)
	)

	for i in range(_chain_links.size()):
		var link := _chain_links[i]

		if i >= link_count:
			link.visible = false
			continue

		var t := (float(i) + 0.5) / float(link_count)
		link.global_position = a.lerp(b, t)

		var up_hint := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT

		link.look_at(link.global_position + dir, up_hint)

		if i % 2 == 1:
			link.rotate_object_local(Vector3.FORWARD, PI * 0.5)

		link.visible = true
