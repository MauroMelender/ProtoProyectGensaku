extends Area3D

@export var velocidad_crecimiento := 3.0

func _process(delta):
	scale += Vector3.ONE * velocidad_crecimiento * delta


func _on_body_entered(body):
	if body.is_in_group("player"):
		get_tree().change_scene_to_file("res://game_over.tscn")
