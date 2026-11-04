extends MeshInstance3D

const SHADER_COMPATIBILIDAD: Shader = preload("res://assets/shaders/manga_postproceso_compat.gdshader")
const PRIORIDAD_SIN_MANGA := 101

func _ready() -> void:
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		return
	var original := get_surface_override_material(0) as ShaderMaterial
	if original == null:
		return
	var copia := original.duplicate() as ShaderMaterial
	copia.shader = SHADER_COMPATIBILIDAD
	copia.set_shader_parameter("activar_contorno", true)
	copia.set_shader_parameter("grosor_linea", 2.0)
	copia.set_shader_parameter("umbral_profundidad", 0.02)
	set_surface_override_material(0, copia)
	_aplicar_excepciones.call_deferred()

func _aplicar_excepciones() -> void:
	for nodo in get_tree().get_nodes_in_group("sin_manga"):
		if nodo is SpriteBase3D:
			nodo.render_priority = PRIORIDAD_SIN_MANGA
