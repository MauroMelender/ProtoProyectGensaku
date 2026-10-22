extends CanvasLayer

@onready var panel_resultado = $PanelResultado
@onready var label_tiempo_final = $PanelResultado/VBoxContainer/LabelTiempoFinal
@onready var label_record = $PanelResultado/VBoxContainer/LabelRecord
@onready var boton_siguiente = $PanelResultado/VBoxContainer/ButtonSiguienteNivel
@onready var tip_label: RichTextLabel = $"Tip Label"

# Color de acento basado en la paleta del juego
const COLOR_AZUL_ACCENT: String = "#5352ED"

func _ready():
	panel_resultado.visible = false
	
	tip_label.text = "Dash = [color=%s]Q [/color]\nCaminar = [color=%s]SHIFT [/color]\nCamara = [color=%s]Click Derecho [/color]" % [
		COLOR_AZUL_ACCENT, COLOR_AZUL_ACCENT, COLOR_AZUL_ACCENT
	]

func mostrar_resultado():
	boton_siguiente.visible = true
	panel_resultado.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	boton_siguiente.disabled = (
		GameManager.indice_nivel + 1 >= GameManager.niveles.size()
	)
	
	label_tiempo_final.text = "[center]Tiempo: [color=%s]%.2f[/color][/center]" % [
		COLOR_AZUL_ACCENT, GameManager.tiempo_final
	]

	if GameManager.nuevo_record:
		label_record.text = "[center][color=%s]¡NUEVO RÉCORD![/color][/center]" % COLOR_AZUL_ACCENT
	else:
		label_record.text = "[center]Mejor tiempo: %.2f[/center]" % GameManager.mejor_tiempo

func _on_button_siguiente_nivel_pressed():
	GameManager.avanzar_nivel()
