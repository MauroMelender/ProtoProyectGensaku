extends CanvasLayer

@onready var panel_resultado = $PanelResultado
@onready var label_tiempo_final = $PanelResultado/VBoxContainer/LabelTiempoFinal
@onready var label_record = $PanelResultado/VBoxContainer/LabelRecord
@onready var boton_siguiente = $PanelResultado/VBoxContainer/ButtonSiguienteNivel
@onready var boton_reiniciar = $PanelResultado/VBoxContainer/ButtonReiniciar
@onready var tip_label = $"Tip Label"

var _countdown_label: Label

# Color de acento basado en la paleta del juego
const COLOR_AZUL_ACCENT: String = "#5352ED"

func _ready():
	panel_resultado.visible = false
	_iniciar_conteo()
	
	if tip_label is RichTextLabel:
		tip_label.text = "Dash = [color=%s]SHIFT [/color]\nCaminar = [color=%s]ALT [/color]\nCamara = [color=%s]Click Derecho [/color]" % [
			COLOR_AZUL_ACCENT, COLOR_AZUL_ACCENT, COLOR_AZUL_ACCENT
		]
	else:
		tip_label.text = "Dash = SHIFT\nCaminar = ALT\nCamara = Click Derecho"

func _iniciar_conteo() -> void:
	GameManager.iniciar_cronometro()
	GameManager.conteo_inicio_activo = true
	_countdown_label = Label.new()
	_countdown_label.name = "ConteoInicio"
	_countdown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 112)
	_countdown_label.add_theme_color_override("font_color", Color.WHITE)
	_countdown_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_countdown_label.add_theme_constant_override("outline_size", 8)
	_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_countdown_label)
	_run_countdown()

func _run_countdown() -> void:
	for number in ["3...", "2...", "1..."]:
		await _show_countdown_text(number, 0.8)
	GameManager.conteo_inicio_activo = false
	GameManager.activar_cronometro()
	await _show_countdown_text("RUN!", 0.9)
	_countdown_label.queue_free()

func _show_countdown_text(texto: String, duracion: float) -> void:
	_countdown_label.text = texto
	_countdown_label.modulate.a = 1.0
	_countdown_label.scale = Vector2(1.65, 1.65)
	_countdown_label.pivot_offset = _countdown_label.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_countdown_label, "scale", Vector2(0.55, 0.55), duracion)
	tween.tween_property(_countdown_label, "modulate:a", 0.0, duracion)
	await tween.finished

func mostrar_resultado():
	boton_siguiente.visible = true
	panel_resultado.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	boton_siguiente.disabled = GameManager.obtener_indice_nivel_actual() + 1 >= GameManager.niveles.size()
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and player.grapple_ability:
		player.grapple_ability.set_reticle_visible(false)
	
	if label_tiempo_final is RichTextLabel:
		label_tiempo_final.text = "[center]Tiempo: [color=%s]%.2f[/color][/center]" % [
			COLOR_AZUL_ACCENT, GameManager.tiempo_final
		]
	else:
		label_tiempo_final.text = "Tiempo: %.2f" % GameManager.tiempo_final

	var record_texto := "Mejor tiempo: %.2f" % GameManager.mejor_tiempo
	if GameManager.nuevo_record:
		record_texto = "[color=%s]¡NUEVO RÉCORD![/color]\n" % COLOR_AZUL_ACCENT + record_texto
	if label_record is RichTextLabel:
		label_record.text = "[center]%s\nIntentos: %d[/center]" % [record_texto, GameManager.intentos]
	else:
		var prefijo_record := "¡NUEVO RÉCORD!\n" if GameManager.nuevo_record else ""
		label_record.text = "%sMejor tiempo: %.2f\nIntentos: %d" % [
			prefijo_record, GameManager.mejor_tiempo, GameManager.intentos
		]

func _on_button_siguiente_nivel_pressed():
	GameManager.avanzar_nivel()

func _on_button_reiniciar_pressed():
	GameManager.reiniciar_nivel()
