extends MeshInstance3D

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameManager.completar_nivel()
		if body.has_method("hide_character"):
			body.hide_character()

		var interfaz = get_tree().current_scene.get_node("CanvasLayer")
		interfaz.mostrar_resultado()

		get_tree().paused = true
