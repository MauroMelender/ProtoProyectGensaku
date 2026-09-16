class_name CameraController
extends Node

var player: Player
var camera: Camera3D

# --- PARÁMETROS CONFIGURABLES ---
@export_group("FOV")
@export var BASE_FOV: float = 75.0
@export var MAX_FOV: float = 90.0
@export var DASH_FOV: float = 95.0
@export var FOV_CHANGE_SPEED: float = 6.0 # Velocidad de transición del FOV

@export_group("Inclinación de Cámara (Tilt)")
@export var TILT_ANGLE: float = 12.0 # Grados de inclinación en WallRun
@export var TILT_SPEED: float = 8.0  # Velocidad con la que se inclina la cámara

var current_tilt: float = 0.0

func _ready() -> void:
	player = get_parent().get_parent() as Player
	if not player:
		player = owner as Player
		
	# Busca la cámara dentro del CameraPivot
	if player and player.camera_pivot:
		camera = player.camera_pivot.get_node_or_null("Camera3D") as Camera3D

func check_and_update(delta: float) -> void:
	if not camera:
		# Si no encontró la cámara automáticamente, busca cualquier Camera3D en el pivot
		if player and player.camera_pivot:
			camera = player.camera_pivot.find_child("*", true, false) as Camera3D
		if not camera:
			return

	_update_fov(delta)
	_update_tilt(delta)

func _update_fov(delta: float) -> void:
	var target_fov: float = BASE_FOV

	match player.current_state:
		Player.State.NORMAL:
			# Calcula la velocidad
			var horizontal_speed := Vector3(player.velocity.x, 0, player.velocity.z).length()
			
			# Si supera la velocidad base (por ejemplo, tras un impulso o sprint)
			if horizontal_speed > player.SPEED:
				var speed_ratio = clamp((horizontal_speed - player.SPEED) / (player.WALL_RUN_SPEED - player.SPEED), 0.0, 1.0)
				target_fov = lerp(BASE_FOV, MAX_FOV, speed_ratio)
			else:
				target_fov = BASE_FOV

		Player.State.WALL_RUNNING:
			target_fov = MAX_FOV

		Player.State.AGARRADO:
			target_fov = BASE_FOV

	# Si el dash se activó recientemete, le damos un boost adicional de FOV
	if player.dash_ability and player.dash_ability.cooldown_timer > (player.DASH_COOLDOWN_TIME - 0.25):
		target_fov = DASH_FOV

	# Transición suave del FOV
	camera.fov = lerp(camera.fov, target_fov, FOV_CHANGE_SPEED * delta)

func _update_tilt(delta: float) -> void:
	var target_tilt: float = 0.0

	if player.current_state == Player.State.WALL_RUNNING:
		# Determina hacia qué lado está la pared para inclinar la cámara
		if player.ray_izquierda and player.ray_izquierda.is_colliding():
			target_tilt = -deg_to_rad(TILT_ANGLE) # Inclina a la derecha
		elif player.ray_derecha and player.ray_derecha.is_colliding():
			target_tilt = deg_to_rad(TILT_ANGLE)  # Inclina a la izquierda

	current_tilt = lerp(current_tilt, target_tilt, TILT_SPEED * delta)
	camera.rotation.z = current_tilt
