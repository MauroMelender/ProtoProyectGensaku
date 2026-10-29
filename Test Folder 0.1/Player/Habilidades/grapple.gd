class_name Grapple
extends Node

# --- CONFIGURACIÓN DEL GANCHO ---
@export var MAX_DISTANCE: float = 45.0
@export var MIN_ROPE_LENGTH: float = 4.0
@export var SWING_ACCEL: float = 14.0
@export var REEL_SPEED: float = 5.0
@export var MAX_SWING_SPEED: float = 30.0
@export var RELEASE_JUMP_BOOST: float = 1.15
@export var COOLDOWN_TIME: float = 0.25
@export var HAND_OFFSET: Vector3 = Vector3(0, 1.2, 0)

# --- CONFIGURACIÓN DE LA CADENA ---
@export var CHAIN_LINK_SPACING: float = 0.14
@export var CHAIN_LINK_OUTER_RADIUS: float = 0.065
@export var CHAIN_LINK_INNER_RADIUS: float = 0.035
@export var CHAIN_COLOR: Color = Color(0.16, 0.17, 0.19)

# --- CONFIGURACIÓN DEL PROYECTIL ---
@export var PROJECTILE_SPEED: float = 45.0
@export var RETURN_SPEED: float = 45.0
@export var PROJECTILE_LENGTH: float = 0.8
@export var PROJECTILE_RADIUS: float = 0.09
@export var PROJECTILE_COLOR: Color = Color(0.22, 0.24, 0.27)

var _firing: bool = false
var _returning: bool = false
var _attached: bool = false

var _shot_origin: Vector3 = Vector3.ZERO
var _shot_direction: Vector3 = Vector3.FORWARD
var _shot_distance: float = 0.0

var player: Player
var anchor: Vector3 = Vector3.ZERO
var rope_length: float = 0.0
var cooldown_timer: float = 0.0

var _chain_links: Array[MeshInstance3D] = []
var _chain_material: StandardMaterial3D

var _projectile: MeshInstance3D
var _projectile_material: StandardMaterial3D

func _ready() -> void:
	player = get_parent().get_parent() as Player
	_ensure_input_action()
	_build_rope()
	_build_projectile()

# Crea la acción si todavía no existe.
# Controles: clic izquierdo o tecla E.
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
	_shot_origin = _hand()
	_shot_direction = _get_aim_direction()
	_shot_distance = 0.0

	_projectile.global_position = _shot_origin
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

	_projectile.global_basis = Basis.looking_at(dir, up).rotated(
		Vector3.RIGHT,
		PI * 0.5
	)


# Comprueba si el proyectil golpea una superficie durante su recorrido.
func _check_projectile_collision(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	return player.get_world_3d().direct_space_state.intersect_ray(query)


# Se llama mientras el jugador está en estado NORMAL.
func check_and_update(delta: float) -> bool:
	if cooldown_timer > 0.0:
		cooldown_timer = maxf(cooldown_timer - delta, 0.0)

	if _firing or _returning:
		_process_projectile(delta)
		return false

	if _attached:
		return false

	if cooldown_timer > 0.0:
		return false

	if not Input.is_action_just_pressed("gancho"):
		return false

	_start_shot()
	return false
	if cooldown_timer > 0.0:
		cooldown_timer = maxf(cooldown_timer - delta, 0.0)

	# El proyectil sigue funcionando mientras el jugador camina.
	if _firing or _returning:
		_process_projectile(delta)
		return player.current_state == Player.State.GANCHO

	_hide_chain()

	if cooldown_timer > 0.0:
		return false

	if not Input.is_action_just_pressed("gancho"):
		return false

	_start_shot()
	return false

# Movimiento del proyectil: sale, impacta o vuelve automáticamente.
func _process_projectile(delta: float) -> void:
	# Si soltás el botón durante el disparo, el proyectil regresa.
	if _firing:
		if not Input.is_action_pressed("gancho"):
			_begin_return()
			return

		var remaining := MAX_DISTANCE - _shot_distance

		if remaining <= 0.0:
			_begin_return()
			return

		var travel := minf(PROJECTILE_SPEED * delta, remaining)
		var current := _projectile.global_position
		var next_position := current + _shot_direction * travel

		var hit := _check_projectile_collision(current, next_position)

		if not hit.is_empty():
			anchor = hit["position"]
			rope_length = maxf(
				_hand().distance_to(anchor),
				MIN_ROPE_LENGTH
			)

			_firing = false
			_attached = true
			_projectile.global_position = anchor
			_projectile.visible = true

			player.current_state = Player.State.GANCHO
			return

		_projectile.global_position = next_position
		_orient_projectile(_shot_direction)
		_shot_distance += travel

		if _shot_distance >= MAX_DISTANCE:
			_begin_return()

		return

	# Regreso del proyectil hacia la mano.
	if _returning:
		var hand_position := _hand()
		var current_position := _projectile.global_position

		_projectile.global_position = current_position.move_toward(
			hand_position,
			RETURN_SPEED * delta
		)

		var return_direction := hand_position - current_position

		if return_direction.length_squared() > 0.001:
			_orient_projectile(return_direction.normalized())

		if _projectile.global_position.distance_to(hand_position) < 0.15:
			_projectile.global_position = hand_position
			_projectile.visible = false
			_returning = false
			_attached = false
			cooldown_timer = 0.0
	# El proyectil todavía está viajando hacia delante.
	if _firing:
		var remaining := MAX_DISTANCE - _shot_distance

		if remaining <= 0.0:
			_begin_return()
			return

		var travel := minf(PROJECTILE_SPEED * delta, remaining)
		var current := _projectile.global_position
		var next_position := current + _shot_direction * travel

		var hit := _check_projectile_collision(current, next_position)

		if not hit.is_empty():
			# El gancho llegó a una superficie.
			anchor = hit["position"]
			rope_length = maxf(_hand().distance_to(anchor), MIN_ROPE_LENGTH)

			_firing = false
			_returning = false
			_projectile.visible = false

			player.current_state = Player.State.GANCHO
			return

		_projectile.global_position = next_position
		_orient_projectile(_shot_direction)
		_shot_distance += travel

		# Si alcanzó el límite sin golpear nada, regresa.
		if _shot_distance >= MAX_DISTANCE:
			_begin_return()

		return

	# El proyectil vuelve hacia la mano del jugador.
	if _returning:
		var hand_position := _hand()
		var current_position := _projectile.global_position

		_projectile.global_position = current_position.move_toward(
			hand_position,
			RETURN_SPEED * delta
		)

		var return_direction := hand_position - current_position

		if return_direction.length_squared() > 0.001:
			_orient_projectile(return_direction.normalized())

		if _projectile.global_position.distance_to(hand_position) < 0.15:
			_projectile.global_position = hand_position
			_projectile.visible = false
			_returning = false
			cooldown_timer = COOLDOWN_TIME

# Comienza el regreso del proyectil.
func _begin_return() -> void:
	_firing = false
	_returning = true
	_attached = false
	_firing = false
	_returning = true

# Balanceo tipo péndulo mientras el gancho está anclado.
func process_movement(delta: float) -> void:
	var jumped := Input.is_action_just_pressed("saltar")

	# Soltar el botón o saltar libera al jugador.
	if not Input.is_action_pressed("gancho") or jumped:
		_release(jumped)
		return

	var input_dir := Input.get_vector(
		"mover_izquierda",
		"mover_derecha",
		"mover_adelante",
		"mover_atras"
	)

	var wish := (
		player.get_move_basis() *
		Vector3(input_dir.x, 0, input_dir.y)
	).normalized()

	# Gravedad y control durante el balanceo.
	player.velocity.y -= player.gravity * delta
	player.velocity += wish * SWING_ACCEL * delta

	# Mantener W recoge cuerda.
	if input_dir.y < 0.0:
		rope_length = maxf(
			rope_length - REEL_SPEED * delta,
			MIN_ROPE_LENGTH
		)

	# Evita que la velocidad se aleje del ancla cuando la cuerda está tensa.
	var to_anchor := anchor - _hand()
	var dist := to_anchor.length()

	if dist > 0.001 and dist >= rope_length:
		var dir := to_anchor / dist
		var radial := player.velocity.dot(dir)

		if radial < 0.0:
			player.velocity -= dir * radial

	# Limita la velocidad máxima del balanceo.
	if player.velocity.length() > MAX_SWING_SPEED:
		player.velocity = player.velocity.normalized() * MAX_SWING_SPEED

	player.move_and_slide()

	# Corrige el exceso de longitud de la cuerda.
	var offset := anchor - _hand()
	var d := offset.length()

	if d > rope_length and d > 0.001:
		player.move_and_collide(offset / d * (d - rope_length))

	_update_rope()


# Libera al jugador.
func _release(jumped: bool) -> void:
	player.current_state = Player.State.NORMAL
	player.jump_count = 1

	if _attached:
		_projectile.global_position = anchor
		_begin_return()
	elif _firing:
		_begin_return()

	_hide_chain()

	if jumped:
		player.velocity.x *= RELEASE_JUMP_BOOST
		player.velocity.z *= RELEASE_JUMP_BOOST
		player.velocity.y += player.JUMP_VELOCITY * 0.5
	player.current_state = Player.State.NORMAL
	player.jump_count = 1
	cooldown_timer = COOLDOWN_TIME

	_hide_chain()

	if jumped:
		player.velocity.x *= RELEASE_JUMP_BOOST
		player.velocity.z *= RELEASE_JUMP_BOOST
		player.velocity.y += player.JUMP_VELOCITY * 0.5


# Limpia el estado del gancho, por ejemplo, al reaparecer el jugador.
func reset() -> void:
	cooldown_timer = 0.0
	_firing = false
	_returning = false
	_attached = false

	if is_instance_valid(_projectile):
		_projectile.visible = false

	_hide_chain()
	cooldown_timer = 0.0
	_firing = false
	_returning = false

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

		var up_hint := (
			Vector3.UP
			if absf(dir.dot(Vector3.UP)) < 0.99
			else Vector3.RIGHT
		)

		link.look_at(link.global_position + dir, up_hint)

		if i % 2 == 1:
			link.rotate_object_local(Vector3.FORWARD, PI * 0.5)

		link.visible = true
