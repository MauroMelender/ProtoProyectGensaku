class_name Grapple
extends Node

class GrappleReticle extends Control:
	var target_available: bool = false
	var cooldown_progress: float = 1.0
	var recharging: bool = false
	var reticle_size: float = 1.0
	var cooldown_ring_scale: float = 1.8

	func set_state(has_target: bool, progress: float, is_recharging: bool) -> void:
		var clamped_progress := clampf(progress, 0.0, 1.0)
		if (
			target_available == has_target
			and recharging == is_recharging
			and is_equal_approx(cooldown_progress, clamped_progress)
		):
			return
		target_available = has_target
		cooldown_progress = clamped_progress
		recharging = is_recharging
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var base_radius := 9.0 * reticle_size
		var outline := Color(0.0, 0.0, 0.0, 0.85)
		var white := Color(1.0, 1.0, 1.0, 0.95)

		if recharging:
			var recharge_radius := base_radius * cooldown_ring_scale
			var end_angle := -PI * 0.5 + TAU * cooldown_progress
			draw_arc(center, recharge_radius, 0.0, TAU, 48, outline, 3.0 * reticle_size, true)
			draw_arc(center, recharge_radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.35), 1.2 * reticle_size, true)
			if cooldown_progress > 0.0:
				draw_arc(center, recharge_radius, -PI * 0.5, end_angle, 48, outline, 3.4 * reticle_size, true)
				draw_arc(center, recharge_radius, -PI * 0.5, end_angle, 48, white, 2.0 * reticle_size, true)

		if target_available:
			draw_arc(center, base_radius, 0.0, TAU, 32, outline, 3.0 * reticle_size, true)
			draw_arc(center, base_radius, 0.0, TAU, 32, white, 1.2 * reticle_size, true)
			return

		var arm_length := 11.0 * reticle_size
		var gap := 4.0 * reticle_size
		var cross_lines: Array[Vector2] = [
			Vector2(-arm_length, 0), Vector2(-gap, 0), Vector2(gap, 0), Vector2(arm_length, 0),
			Vector2(0, -arm_length), Vector2(0, -gap), Vector2(0, gap), Vector2(0, arm_length)
		]
		for i in range(0, cross_lines.size(), 2):
			draw_line(center + cross_lines[i], center + cross_lines[i + 1], outline, 3.0 * reticle_size, true)
			draw_line(center + cross_lines[i], center + cross_lines[i + 1], white, 1.3 * reticle_size, true)

# --- CONFIGURACIÓN DEL GANCHO ---
@export var MAX_DISTANCE: float = 67.5 # 50 % más de alcance
@export var COOLDOWN_TIME: float = 2.2
@export var HAND_OFFSET: Vector3 = Vector3(0, 1.2, 0)

# --- IMPULSO ÚNICO AL ENGANCHAR ---
@export_group("Impulso del gancho")
@export var FORWARD_IMPULSE: float = 18.0 # Impulso horizontal hacia el anclaje
@export var UPWARD_IMPULSE: float = 10.0 # Impulso vertical para formar una parábola
@export var ATTACH_HOLD_TIME: float = 0.6 # Tiempo que permanece clavado antes del retorno automático

# --- PREPARACIÓN DEL GANCHO EN EL AIRE ---
@export_group("Preparación en el aire")
@export var AIR_LAUNCH_BRAKE_DURATION: float = 0.17
@export var AIR_LAUNCH_BRAKE_STRENGTH: float = 6.0

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
@export var ROPE_SIMULATION_SEGMENTS: int = 24
@export var ROPE_SLACK: float = 1.02
@export var ROPE_GRAVITY: float = 2.5
@export var ROPE_DRAG: float = 0.94
@export var ROPE_RETRACT_SPEED: float = 32.0
@export var ROPE_SOLVER_ITERATIONS: int = 4

# --- CONFIGURACIÓN DEL PROYECTIL ---
@export_group("Proyectil")
@export var PROJECTILE_SPEED: float = 90.0
@export var RETURN_SPEED: float = 45.0
@export var INHERIT_VELOCITY: float = 1.0 # Cuánta velocidad del jugador se suma al proyectil (0 = nada, 1 = toda)
@export var PROJECTILE_LENGTH: float = 0.8
@export var PROJECTILE_RADIUS: float = 0.09
@export var PROJECTILE_COLOR: Color = Color(0.22, 0.24, 0.27)

@export_group("Retícula")
@export_range(0.5, 3.0, 0.1) var RETICLE_SIZE: float = 1.0
@export_range(1.2, 3.5, 0.1) var COOLDOWN_RING_SCALE: float = 1.8

var _firing: bool = false
var _returning: bool = false
var _attached: bool = false
var _launch_slow_timer: float = 0.0

var _shot_direction: Vector3 = Vector3.FORWARD
var _shot_distance: float = 0.0
var _attached_timer: float = 0.0
var _rope_deployed_length: float = 0.0
var _rope_sim_initialized: bool = false
var _rope_positions: Array[Vector3] = []
var _rope_previous_positions: Array[Vector3] = []

var player: Player
var anchor: Vector3 = Vector3.ZERO
var cooldown_timer: float = 0.0
var momentum_grace: float = 0.0 # Lo lee Player para no frenar el impulso en el aire

var _chain_links: Array[MeshInstance3D] = []
var _chain_material: StandardMaterial3D

var _projectile: MeshInstance3D
var _projectile_material: StandardMaterial3D
var _reticle: GrappleReticle


func _ready() -> void:
	player = get_parent().get_parent() as Player
	_ensure_input_action()
	_build_rope()
	_build_projectile()
	_build_reticle()


func _build_reticle() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ReticulaGancho"
	canvas.layer = 10
	add_child(canvas)

	_reticle = GrappleReticle.new()
	_reticle.name = "Reticula"
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.reticle_size = RETICLE_SIZE
	_reticle.cooldown_ring_scale = COOLDOWN_RING_SCALE
	canvas.add_child(_reticle)
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func update_reticle() -> void:
	if not _reticle or not player or not player.is_inside_tree():
		return
	# Al completar el nivel se muestra la pantalla de resultado; no dibujar la retícula encima.
	_reticle.visible = not GameManager.nivel_completado
	if not _reticle.visible:
		return
	var world := player.get_world_3d()
	if world == null:
		return

	var origin := _hand()
	var direction := _get_aim_direction()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * MAX_DISTANCE)
	query.exclude = [player.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := world.direct_space_state.intersect_ray(query)
	var progress := 1.0 - cooldown_timer / COOLDOWN_TIME if COOLDOWN_TIME > 0.0 else 1.0
	_reticle.set_state(not hit.is_empty(), progress, cooldown_timer > 0.0)

func set_reticle_visible(should_be_visible: bool) -> void:
	if is_instance_valid(_reticle):
		_reticle.visible = should_be_visible


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
	cooldown_timer = COOLDOWN_TIME
	_rope_deployed_length = 0.0
	_rope_sim_initialized = false
	_rope_positions.clear()
	_rope_previous_positions.clear()
	_launch_slow_timer = AIR_LAUNCH_BRAKE_DURATION if not player.is_on_floor() else 0.0

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

		_apply_air_launch_brake(delta)

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
			_attach(hit["position"], delta)
			return

		_projectile.global_position = next_position
		_orient_projectile(_shot_direction)
		_shot_distance += travel
		_rope_deployed_length = maxf(_rope_deployed_length, _shot_distance)
		_update_rope(delta, _projectile.global_position)

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
			_hide_chain()


# Reduce brevemente la velocidad horizontal antes del tirón, conservando la caída y el salto.
func _apply_air_launch_brake(delta: float) -> void:
	if _launch_slow_timer <= 0.0 or player.is_on_floor():
		_launch_slow_timer = 0.0
		return
	var brake_delta := minf(delta, _launch_slow_timer)
	var retention := exp(-AIR_LAUNCH_BRAKE_STRENGTH * brake_delta)
	player.velocity.x *= retention
	player.velocity.z *= retention
	_launch_slow_timer = maxf(_launch_slow_timer - delta, 0.0)


# El proyectil se clava durante unos segundos y da un solo impulso hacia el anclaje.
func _attach(hit_position: Vector3, delta: float) -> void:
	anchor = hit_position
	_firing = false
	_attached = true
	_attached_timer = ATTACH_HOLD_TIME
	_projectile.global_position = anchor
	_projectile.visible = true

	player.current_state = Player.State.GANCHO

	var to_anchor := anchor - _hand()
	var forward_dir := Vector3(to_anchor.x, 0.0, to_anchor.z)
	if forward_dir.length_squared() < 0.001:
		forward_dir = -player.global_transform.basis.z
	else:
		forward_dir = forward_dir.normalized()
	_launch_slow_timer = 0.0
	# Primero amortigua solo la caída acumulada; después aplica completo el tirón del ancla.
	if player.velocity.y < 0.0:
		player.velocity.y *= 0.3
	player.velocity += forward_dir * FORWARD_IMPULSE + Vector3.UP * UPWARD_IMPULSE
	_rope_deployed_length = maxf(_rope_deployed_length, _hand().distance_to(anchor))
	_update_rope(delta, anchor)

func _begin_return() -> void:
	_firing = false
	_returning = true
	_attached = false
	_launch_slow_timer = 0.0
	_attached_timer = 0.0
	_hide_chain()


# Mantiene un solo impulso; durante el anclaje Ziel conserva el movimiento normal.
func process_movement(delta: float) -> void:
	cooldown_timer = maxf(cooldown_timer - delta, 0.0)
	var jumped := Input.is_action_just_pressed("saltar")
	if jumped or _attached_timer <= 0.0:
		_release(jumped)
		if jumped:
			player.move_and_slide()
		else:
			player._process_normal_movement(delta)
		return

	_attached_timer = maxf(_attached_timer - delta, 0.0)
	player._process_normal_movement(delta)
	_update_rope(delta, anchor)
	if _attached_timer <= 0.0:
		_release(false)


# Libera al jugador conservando su velocidad.
func _release(jumped: bool) -> void:
	player.current_state = Player.State.NORMAL
	player.jump_count = maxi(player.jump_count, 1)

	if _attached:
		_projectile.global_position = anchor
		_begin_return()
	elif _firing:
		_begin_return()

	_hide_chain()
	momentum_grace = MOMENTUM_GRACE_TIME

	if jumped:
		player.velocity.x *= RELEASE_JUMP_BOOST
		player.velocity.z *= RELEASE_JUMP_BOOST
		player.velocity.y += player.JUMP_VELOCITY * 0.5


# Limpia el estado del gancho, por ejemplo, al reaparecer el jugador.
func reset() -> void:
	cooldown_timer = 0.0
	momentum_grace = 0.0
	_launch_slow_timer = 0.0
	_attached_timer = 0.0
	_rope_deployed_length = 0.0
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
	_rope_sim_initialized = false
	_rope_positions.clear()
	_rope_previous_positions.clear()


# Actualiza la cadena desde la mano hasta el proyectil o el punto anclado.
func _update_rope(delta: float, rope_end: Vector3) -> void:
	var rope_start := _hand()
	var straight_length := rope_start.distance_to(rope_end)
	if straight_length < 0.03:
		return

	if _firing:
		_rope_deployed_length = maxf(_rope_deployed_length, straight_length)
	elif _attached:
		# La cadena se recoge siguiendo la distancia de Ziel al anclaje.
		_rope_deployed_length = move_toward(_rope_deployed_length, straight_length, ROPE_RETRACT_SPEED * delta)
	else:
		_rope_deployed_length = move_toward(_rope_deployed_length, straight_length, RETURN_SPEED * delta)

	var segment_count := maxi(4, ROPE_SIMULATION_SEGMENTS)
	if not _rope_sim_initialized or _rope_positions.size() != segment_count + 1:
		_rope_positions.clear()
		_rope_previous_positions.clear()
		for i in range(segment_count + 1):
			var point := rope_start.lerp(rope_end, float(i) / float(segment_count))
			_rope_positions.append(point)
			_rope_previous_positions.append(point)
		_rope_sim_initialized = true

	if _firing:
		# Durante el disparo la cadena acompaña recta al proyectil, sin fuerzas físicas.
		for i in range(segment_count + 1):
			var point := rope_start.lerp(rope_end, float(i) / float(segment_count))
			_rope_positions[i] = point
			_rope_previous_positions[i] = point
	else:
		_rope_positions[0] = rope_start
		_rope_positions[segment_count] = rope_end
		var effective_length := maxf(straight_length, _rope_deployed_length) * ROPE_SLACK
		var rest_length := effective_length / float(segment_count)
		var frame_delta := minf(delta, 0.05)
		var gravity_step := Vector3.DOWN * ROPE_GRAVITY * frame_delta * frame_delta

		# Integración Verlet ligera: la cadena conserva algo de inercia y cae suavemente.
		for i in range(1, segment_count):
			var current := _rope_positions[i]
			var inherited_motion := (current - _rope_previous_positions[i]) * ROPE_DRAG
			_rope_previous_positions[i] = current
			_rope_positions[i] = current + inherited_motion + gravity_step

		# Mantiene la longitud entre eslabones y deja que la cadena se curve en movimiento.
		for _iteration in range(maxi(1, ROPE_SOLVER_ITERATIONS)):
			_rope_positions[0] = rope_start
			_rope_positions[segment_count] = rope_end
			for i in range(segment_count):
				var difference := _rope_positions[i + 1] - _rope_positions[i]
				var segment_length := difference.length()
				if segment_length < 0.001:
					continue
				var correction := difference * ((segment_length - rest_length) / segment_length)
				if i == 0:
					_rope_positions[i + 1] -= correction
				elif i == segment_count - 1:
					_rope_positions[i] += correction
				else:
					_rope_positions[i] += correction * 0.5
					_rope_positions[i + 1] -= correction * 0.5
		_rope_positions[0] = rope_start
		_rope_positions[segment_count] = rope_end

	var visible_length := maxf(_rope_deployed_length, straight_length) * ROPE_SLACK
	var link_count := mini(_chain_links.size(), maxi(2, ceili(visible_length / CHAIN_LINK_SPACING)))
	for i in range(_chain_links.size()):
		var link := _chain_links[i]
		if i >= link_count:
			link.visible = false
			continue

		var t0 := float(i) / float(link_count)
		var t1 := float(i + 1) / float(link_count)
		var point_a := _sample_rope(t0, segment_count)
		var point_b := _sample_rope(t1, segment_count)
		var direction := point_b - point_a
		if direction.length_squared() < 0.0001:
			link.visible = false
			continue
		link.global_position = (point_a + point_b) * 0.5
		var up_hint := Vector3.UP if absf(direction.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		link.look_at(link.global_position + direction, up_hint)
		if i % 2 == 1:
			link.rotate_object_local(Vector3.FORWARD, PI * 0.5)
		link.visible = true

func _sample_rope(t: float, segment_count: int) -> Vector3:
	var scaled_t := clampf(t, 0.0, 1.0) * float(segment_count)
	var index := mini(floori(scaled_t), segment_count - 1)
	return _rope_positions[index].lerp(_rope_positions[index + 1], scaled_t - float(index))
