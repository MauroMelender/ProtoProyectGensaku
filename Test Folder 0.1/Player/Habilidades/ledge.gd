class_name Ledge
extends Node

var player: Player
var cooldown_timer: float = 0.0

func _ready() -> void:
	# Obtiene la referencia al script principal del jugador
	player = get_parent().get_parent() as Player

# Revisa si hay un borde cerca para engancharse
func check_and_update(delta: float) -> bool:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	# No es posible engancharse si esta pisando el suelo o si esta en cooldown
	if player.is_on_floor() or cooldown_timer > 0.0:
		return false

	# Detecta si los RayCasts superiores están tocando una pared colgable
	if player.ray_pared.is_colliding() and player.ray_borde.is_colliding():
		var collider = player.ray_pared.get_collider()
		var tiene_grupo = collider.is_in_group("Ledge") or collider.is_in_group("ledge") or collider.is_in_group("LEDGE") or (collider.get_parent() and collider.get_parent().is_in_group("Ledge"))
		
		# Si la pared tiene la etiqueta "Ledge", se cuelga
		if tiene_grupo:
			player.current_state = Player.State.AGARRADO
			player.velocity = Vector3.ZERO
			player.jump_count = 0
			return true

	return false

# Maneja los controles mientras este colgado
func process_movement(delta: float) -> void:
	# Si la pared desaparece, se suelta
	if not player.ray_pared.is_colliding():
		player.current_state = Player.State.NORMAL
		cooldown_timer = 0.2
		return

	player.velocity = Vector3.ZERO
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Permite moverse horizontalmente a lo largo del borde con A y D
	var right := player.transform.basis.x
	player.velocity = right * input_dir.x * player.CLIMB_SPEED

	# Si se utiliza la tecla "S" (hacia atrás/abajo), se suelta
	if input_dir.y > 0:
		player.current_state = Player.State.NORMAL
		cooldown_timer = 0.3
		return

	# Si se utiliza "Espacio", salta hacia arriba y adelante para trepar
	if Input.is_action_just_pressed("ui_accept"):
		player.current_state = Player.State.NORMAL
		cooldown_timer = 0.35
		player.jump_count = 1
		
		var forward := -player.transform.basis.z
		player.velocity.y = player.JUMP_VELOCITY
		player.velocity += forward * player.LEDGE_JUMP_FORWARD_FORCE
		return

	player.move_and_slide()
