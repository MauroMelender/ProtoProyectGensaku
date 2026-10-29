extends Node

@export var grupo: StringName = &"sin_manga"
@export var material_excepcion: ShaderMaterial

func _ready() -> void:
	for nodo in get_tree().get_nodes_in_group(grupo):
		aplicar(nodo)

func aplicar(nodo: Node) -> void:
	if nodo is GeometryInstance3D:
		nodo.material_overlay = material_excepcion
	for hijo in nodo.get_children():
		aplicar(hijo)
