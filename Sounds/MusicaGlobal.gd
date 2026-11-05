extends Node

var reproductor: AudioStreamPlayer

# Diccionario opcional para canciones específicas por ruta de escena (si quieres automatizarlo)
var canciones_por_nivel: Dictionary = {
	"res://scenes/menu.tscn": preload("res://Sounds/BackgroundMusic/Menu.wav"), 
	"res://scenes/levels/lv_01.tscn": preload("res://Sounds/BackgroundMusic/GamePlayer1.wav")
}

func _ready() -> void:
	# Creamos el nodo de audio por código para que viva siempre en la raíz
	reproductor = AudioStreamPlayer.new()
	reproductor.name = "ReproductorMusica"
	# Opcional: asígnalo a un Bus de Audio llamado "Musica" si tienes configurado el mezclador
	# reproductor.bus = "Musica"
	add_child(reproductor)
	
	# Nos conectamos a la notificación del motor para detectar cambios de escena automáticamente
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	# Cada vez que cambia de escena, Godot añade la nueva escena raíz a laJerarquía
	if node == get_tree().current_scene:
		_verificar_musica_escena(node.scene_file_path)

func _verificar_musica_escena(ruta_escena: String) -> void:
	# Si la escena actual está en nuestro diccionario, cambia de música automáticamente
	if canciones_por_nivel.has(ruta_escena):
		reproducir_cancion(canciones_por_nivel[ruta_escena])

func reproducir_cancion(stream: AudioStream, fundido: bool = true) -> void:
	if reproductor.stream == stream and reproductor.playing:
		return # Si ya está sonando esta misma canción, no la reinicia
		
	reproductor.stream = stream
	reproductor.play()

func detener() -> void:
	reproductor.stop()
