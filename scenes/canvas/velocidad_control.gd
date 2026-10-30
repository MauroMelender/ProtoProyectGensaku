class_name VelocidadControl
extends Control

# --- TEXTO ---
@export var SUFFIX: String = " m/s"
@export var INCLUDE_VERTICAL: bool = false # false = solo velocidad horizontal

# --- TAMAÑO DE LA FUENTE ---
@export var MIN_FONT_SIZE: int = 28   # Tamaño con velocidad base
@export var MAX_FONT_SIZE: int = 44   # Tamaño con velocidad máxima
@export var SPEED_MIN: float = -1.0   # Velocidad donde empieza a crecer (-1 = RUN_SPEED del Player)
@export var SPEED_MAX: float = -1.0   # Velocidad donde llega al tamaño máximo (-1 = MAX_SPEED del Player)
@export var SIZE_SMOOTH: float = 2.0  # Qué tan rápido crece y se achica (más alto = más rápido)

var player: Player
var _current_size: float

var label: RichTextLabel


func _ready() -> void:
	# El HUD no debe capturar el mouse: si lo hace, el Player no recibe el movimiento para girar la cámara
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Busca el RichTextLabel por tipo, sin importar cómo se llame el nodo
	var found := find_children("*", "RichTextLabel", true, false)
	if found.is_empty():
		push_warning("VelocidadControl no encontró ningún RichTextLabel dentro de la escena.")
		set_process(false)
		return
	label = found[0] as RichTextLabel

	player = get_parent() as Player

	if player == null:
		push_warning("VelocidadControl debe ser hijo directo del Player.")
		set_process(false)
		return

	if SPEED_MIN < 0.0:
		SPEED_MIN = player.RUN_SPEED
	if SPEED_MAX < 0.0:
		SPEED_MAX = player.MAX_SPEED

	label.fit_content = true # Para que el alto del texto crezca junto con la fuente
	_current_size = MIN_FONT_SIZE
	_set_font_size(MIN_FONT_SIZE)


func _process(delta: float) -> void:
	var speed: float
	if INCLUDE_VERTICAL:
		speed = player.velocity.length()
	else:
		speed = Vector2(player.velocity.x, player.velocity.z).length()

	label.text = "%d%s" % [roundi(speed), SUFFIX]

	# Crece al acelerar y vuelve a achicarse al frenar
	var t := clampf(inverse_lerp(SPEED_MIN, SPEED_MAX, speed), 0.0, 1.0)
	var target_size := lerpf(MIN_FONT_SIZE, MAX_FONT_SIZE, t)

	_current_size = lerpf(_current_size, target_size, 1.0 - exp(-SIZE_SMOOTH * delta))
	_set_font_size(roundi(_current_size))


# RichTextLabel usa un tamaño por cada estilo de texto (normal, negrita, etc.)
func _set_font_size(new_size: int) -> void:
	label.add_theme_font_size_override("normal_font_size", new_size)
	label.add_theme_font_size_override("bold_font_size", new_size)
	label.add_theme_font_size_override("italics_font_size", new_size)
	label.add_theme_font_size_override("bold_italics_font_size", new_size)
	label.add_theme_font_size_override("mono_font_size", new_size)
