extends Node

var reproductor: AudioStreamPlayer

# Diccionario para canciones específicas por ruta de escena
var canciones_por_nivel: Dictionary = {
	"res://scenes/levels/lv_01.tscn": preload("res://Sounds/BackgroundMusic/GamePlayer1.wav"),
	"res://scenes/levels/lv_02.tscn": preload("res://Sounds/BackgroundMusic/Gameplay2.wav"),
	"res://scenes/levels/lv_04.tscn": preload("res://Sounds/BackgroundMusic/Gameplay2.wav"),
	"res://scenes/levels/lv_05.tscn": preload("res://Sounds/BackgroundMusic/Gameplay2.wav")
}

func _ready() -> void:
	reproductor = AudioStreamPlayer.new()
	reproductor.name = "ReproductorMusica"
	
	reproductor.volume_db = linear_to_db(0.75)
	
	add_child(reproductor)
	
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node == get_tree().current_scene:
		_verificar_musica_escena(node.scene_file_path)

func _verificar_musica_escena(ruta_escena: String) -> void:
	if canciones_por_nivel.has(ruta_escena):
		reproducir_cancion(canciones_por_nivel[ruta_escena])

func reproducir_cancion(stream: AudioStream, fundido: bool = true) -> void:
	if reproductor.stream == stream and reproductor.playing:
		return # Si ya está sonando esta misma canción, no la reinicia
		
	reproductor.stream = stream
	reproductor.play()

func detener() -> void:
	reproductor.stop()
