extends Area3D

const SHADER_RECORTE: Shader = preload("res://assets/shaders/borrado_recorte.gdshader")
const SHADER_EXCEPCION_MANGA: Shader = preload("res://assets/shaders/excepcion_manga.gdshader")
const SHADER_CENIZA: Shader = preload("res://assets/shaders/ceniza_cercana.gdshader")

@export var velocidad_crecimiento := 0.1
@export var radio_maximo := 500.0
@export var paso_actualizacion_colision := 0.25
@export var alcance_gancho := 67.5
@export var distancia_maxima_ceniza := 67.5
@export var intervalo_actualizacion_colision := 1.0
@export_range(100, 5000, 100) var triangulos_por_lote := 1000
@export_range(0.5, 5.0, 0.1) var ancho_borde_tinta := 3.8
@export_range(0.0, 2.0, 0.05) var fuerza_ruido_borde := 1.8
@export_range(0.5, 10.0, 0.1) var escala_ruido_borde := 2.0
@export_range(100, 3000, 100) var cantidad_ceniza := 1200
@export_range(20, 300, 10) var emisiones_ceniza_por_segundo := 100

@onready var forma: SphereShape3D = $CollisionShape3D.shape
@onready var visual: MeshInstance3D = $MeshInstance3D

var radio_actual := 1.0
var _tiempo_recorte := 0.0
var _piezas: Dictionary = {}
var _procesando: Dictionary = {}
var _ultima_actualizacion_colision: Dictionary = {}
var _materiales_shader: Array[ShaderMaterial] = []
var _shader_por_material: Dictionary = {}
var _emisor_ceniza: GPUParticles3D
var _material_ceniza: ParticleProcessMaterial
var _material_visual_ceniza: ShaderMaterial
var _muestras_ceniza: Dictionary = {}
var _muestras_emitidas: Dictionary = {}
var _tiempo_ceniza := 0.0
var _radio_anterior_ceniza := 1.0
var _cola_ceniza: Array[Dictionary] = []
var _indice_cola_ceniza := 0
var _acumulador_emision_ceniza := 0.0

func _ready() -> void:
	# Mantener la escala del cuerpo físico en 1 evita límites de Jolt.
	forma = forma.duplicate() as SphereShape3D
	$CollisionShape3D.shape = forma
	radio_actual = forma.radius
	_crear_emisor_ceniza()

func _process(delta: float) -> void:
	radio_actual = minf(radio_actual * exp(velocidad_crecimiento * delta), radio_maximo)
	forma.radius = radio_actual
	visual.scale = Vector3.ONE * radio_actual
	if _material_ceniza != null:
		_tiempo_ceniza += delta
		if _tiempo_ceniza >= 0.1:
			var incremento_radio := radio_actual - _radio_anterior_ceniza
			_emitir_ceniza_en_contactos(maxf(0.25, incremento_radio + 0.1))
			_radio_anterior_ceniza = radio_actual
			_tiempo_ceniza = 0.0
	if _emisor_ceniza != null:
		_emisor_ceniza.visibility_aabb = AABB(Vector3.ONE * -radio_actual, Vector3.ONE * radio_actual * 2.0)
	for material_shader in _materiales_shader:
		material_shader.set_shader_parameter("void_center", global_position)
		material_shader.set_shader_parameter("void_radius", radio_actual)
	_tiempo_recorte += delta
	if _tiempo_recorte < paso_actualizacion_colision:
		return
	_tiempo_recorte = 0.0
	# La CPU solo actualiza colisiones de objetos que el jugador puede alcanzar.
	if not _procesando.is_empty():
		return
	for instancia in _piezas.keys():
		if not is_instance_valid(instancia):
			_piezas.erase(instancia)
			_procesando.erase(instancia)
			_ultima_actualizacion_colision.erase(instancia)
			continue
		if _necesita_actualizar_colision(instancia):
			_recortar_malla(instancia, _piezas[instancia], radio_actual)
			break

func _necesita_actualizar_colision(instancia: MeshInstance3D) -> bool:
	var jugador := get_tree().get_first_node_in_group("player") as Node3D
	if jugador == null or instancia.global_position.distance_to(jugador.global_position) > alcance_gancho:
		return false
	if instancia.get_node_or_null("StaticBody3D/CollisionShape3D") == null:
		return false
	var ultima := float(_ultima_actualizacion_colision.get(instancia, -INF))
	return Time.get_ticks_msec() / 1000.0 - ultima >= intervalo_actualizacion_colision

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		return
	var pieza: Node = body
	while pieza != null and not pieza is MeshInstance3D:
		pieza = pieza.get_parent()
	if pieza is MeshInstance3D and pieza.mesh != null and not _piezas.has(pieza):
		_piezas[pieza] = pieza.mesh
		_muestras_ceniza[pieza] = _crear_muestras_ceniza(pieza)
		var emitidas := PackedByteArray()
		emitidas.resize(_muestras_ceniza[pieza].size())
		_muestras_emitidas[pieza] = emitidas
		_instalar_shader_recorte(pieza)

func _crear_muestras_ceniza(instancia: MeshInstance3D) -> PackedVector3Array:
	var puntos := PackedVector3Array()
	var malla := instancia.mesh
	for superficie in range(malla.get_surface_count()):
		if malla.surface_get_primitive_type(superficie) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays: Array = malla.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX]
		var cantidad := indices.size() if not indices.is_empty() else vertices.size()
		var triangulos := int(cantidad / 3)
		for tri in range(triangulos):
			var i := tri * 3
			var ia: int = int(indices[i]) if not indices.is_empty() else i
			var ib: int = int(indices[i + 1]) if not indices.is_empty() else i + 1
			var ic: int = int(indices[i + 2]) if not indices.is_empty() else i + 2
			var a := vertices[ia]
			var b := vertices[ib]
			var c := vertices[ic]
			var transformacion := instancia.global_transform
			var largo_maximo := maxf(
				(transformacion * a).distance_to(transformacion * b),
				maxf((transformacion * b).distance_to(transformacion * c), (transformacion * c).distance_to(transformacion * a))
			)
			var divisiones := clampi(ceili(largo_maximo / 0.5), 1, 48)
			var ab := b - a
			var ac := c - a
			for u in range(divisiones + 1):
				for v in range(divisiones + 1 - u):
					puntos.append(a + ab * (float(u) / divisiones) + ac * (float(v) / divisiones))
					if puntos.size() >= 3000:
						return puntos
	return puntos

func _emitir_ceniza_en_contactos(margen: float) -> void:
	for instancia in _muestras_ceniza.keys():
		if not is_instance_valid(instancia):
			_muestras_ceniza.erase(instancia)
			_muestras_emitidas.erase(instancia)
			continue
		var puntos: PackedVector3Array = _muestras_ceniza[instancia]
		var emitidas: PackedByteArray = _muestras_emitidas[instancia]
		for i in range(puntos.size()):
			if emitidas[i] != 0:
				continue
			var punto_mundo: Vector3 = instancia.global_transform * puntos[i]
			var distancia := punto_mundo.distance_to(global_position)
			if absf(distancia - radio_actual) > margen:
				continue
			var radial := (punto_mundo - global_position).normalized()
			var dispersion := Vector3(randf_range(-0.35, 0.35), randf_range(-0.35, 0.35), randf_range(-0.35, 0.35))
			var velocidad := (radial * 0.8 + dispersion).normalized() * randf_range(0.25, 1.0)
			# Con local_coords=false, emit_particle recibe una posición global.
			var transformacion := Transform3D(Basis.IDENTITY, punto_mundo)
			var flags := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_CUSTOM
			# CUSTOM.a define la vida útil; cero hacía que la ceniza desapareciera
			# en el mismo instante en que se emitía.
			_emisor_ceniza.emit_particle(transformacion, velocidad, Color.WHITE, Color(0.0, 0.0, 0.0, 1.0), flags)
			emitidas[i] = 1
		_muestras_emitidas[instancia] = emitidas

func _instalar_shader_recorte(instancia: MeshInstance3D) -> void:
	for superficie in range(instancia.mesh.get_surface_count()):
		var material_original := instancia.get_active_material(superficie)
		if not material_original is StandardMaterial3D:
			continue
		var material_shader: ShaderMaterial
		if _shader_por_material.has(material_original):
			material_shader = _shader_por_material[material_original]
		else:
			material_shader = ShaderMaterial.new()
			material_shader.shader = SHADER_RECORTE
			var base := material_original as StandardMaterial3D
			material_shader.set_shader_parameter("albedo_texture", base.albedo_texture)
			material_shader.set_shader_parameter("use_texture", base.albedo_texture != null)
			material_shader.set_shader_parameter("use_triplanar", base.uv1_triplanar and base.uv1_world_triplanar)
			material_shader.set_shader_parameter("albedo_color", base.albedo_color)
			material_shader.set_shader_parameter("uv_scale", base.uv1_scale)
			material_shader.set_shader_parameter("uv_offset", base.uv1_offset)
			material_shader.set_shader_parameter("material_roughness", base.roughness)
			material_shader.set_shader_parameter("material_metallic", base.metallic)
			material_shader.set_shader_parameter("material_specular", base.metallic_specular)
			material_shader.set_shader_parameter("ink_edge_width", ancho_borde_tinta)
			material_shader.set_shader_parameter("ink_noise_strength", fuerza_ruido_borde)
			material_shader.set_shader_parameter("ink_noise_scale", escala_ruido_borde)
			material_shader.set_shader_parameter("void_center", global_position)
			material_shader.set_shader_parameter("void_radius", radio_actual)
			_shader_por_material[material_original] = material_shader
			_materiales_shader.append(material_shader)
		instancia.set_surface_override_material(superficie, material_shader)

func _crear_emisor_ceniza() -> void:
	# El nodo está declarado en borrado.tscn: Godot 4.7 tiene un fallo con
	# emit_particle() en GPUParticles3D agregados dinámicamente.
	_emisor_ceniza = $CenizaDelVacio as GPUParticles3D
	_emisor_ceniza.add_to_group("sin_manga")
	var mascara_manga := ShaderMaterial.new()
	mascara_manga.shader = SHADER_EXCEPCION_MANGA
	_emisor_ceniza.material_overlay = mascara_manga
	# Alinear el eje frontal de cada quad hacia la cámara del jugador.
	_emisor_ceniza.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	_emisor_ceniza.amount = cantidad_ceniza
	_emisor_ceniza.lifetime = 1.8
	# Se deja capacidad completa para las emisiones manuales y se detiene el
	# nacimiento automático, que colocaría ceniza en el centro del borrado.
	_emisor_ceniza.amount_ratio = 1.0
	_emisor_ceniza.emitting = false
	_emisor_ceniza.local_coords = false
	_material_ceniza = ParticleProcessMaterial.new()
	_material_ceniza.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	_material_ceniza.emission_sphere_radius = 0.0
	_material_ceniza.direction = Vector3.UP
	_material_ceniza.spread = 180.0
	_material_ceniza.initial_velocity_min = 0.2
	_material_ceniza.initial_velocity_max = 1.2
	_material_ceniza.gravity = Vector3(0.0, 0.18, 0.0)
	_material_ceniza.damping_min = 0.2
	_material_ceniza.damping_max = 0.8
	_material_ceniza.scale_min = 0.6
	_material_ceniza.scale_max = 1.3
	_material_ceniza.color = Color(0.12, 0.115, 0.11, 0.98)
	var gradiente := Gradient.new()
	gradiente.colors = PackedColorArray([Color(0.12, 0.115, 0.11, 0.98), Color(0.18, 0.17, 0.16, 0.0)])
	var rampa := GradientTexture1D.new()
	rampa.gradient = gradiente
	_material_ceniza.color_ramp = rampa
	_emisor_ceniza.process_material = _material_ceniza
	var malla_particula := QuadMesh.new()
	malla_particula.size = Vector2(0.7, 0.7)
	_material_visual_ceniza = ShaderMaterial.new()
	_material_visual_ceniza.shader = SHADER_CENIZA
	_material_visual_ceniza.set_shader_parameter("color_ceniza", Color(0.12, 0.115, 0.11, 0.98))
	malla_particula.material = _material_visual_ceniza
	_emisor_ceniza.draw_pass_1 = malla_particula

func _recortar_malla(instancia: MeshInstance3D, original: Mesh, radio_corte: float) -> void:
	if not is_instance_valid(instancia):
		return
	if _procesando.has(instancia):
		return
	_procesando[instancia] = true
	var recortada := ArrayMesh.new()
	var centro := global_position
	var triangulos_procesados := 0
	for superficie in range(original.get_surface_count()):
		if original.surface_get_primitive_type(superficie) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var origen: Array = original.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = origen[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if origen[Mesh.ARRAY_INDEX] is PackedInt32Array: indices = origen[Mesh.ARRAY_INDEX]
		var salida_vertices := PackedVector3Array()
		var cantidad := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, cantidad - 2, 3):
			if not is_instance_valid(instancia):
				_procesando.erase(instancia)
				return
			var triangulo: Array[Dictionary] = []
			for j in range(3):
				var indice: int = int(indices[i + j]) if not indices.is_empty() else i + j
				triangulo.append({"p": vertices[indice]})
			var poligono := _recortar_triangulo(triangulo, instancia, centro, radio_corte)
			for k in range(1, poligono.size() - 1):
				salida_vertices.append(poligono[0]["p"])
				salida_vertices.append(poligono[k]["p"])
				salida_vertices.append(poligono[k + 1]["p"])
			triangulos_procesados += 1
			if triangulos_procesados >= triangulos_por_lote:
				triangulos_procesados = 0
				await get_tree().process_frame
		if not salida_vertices.is_empty():
			var destino: Array = []
			destino.resize(Mesh.ARRAY_MAX)
			destino[Mesh.ARRAY_VERTEX] = salida_vertices
			recortada.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, destino)
	var cuerpo: Node = instancia.get_node_or_null("StaticBody3D")
	var colision := instancia.get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
	var jugador := get_tree().get_first_node_in_group("player") as Node3D
	var puede_alcanzarse := jugador != null and instancia.global_position.distance_to(jugador.global_position) <= alcance_gancho
	var ultima_colision := float(_ultima_actualizacion_colision.get(instancia, -INF))
	var toca_actualizar_colision := puede_alcanzarse and (Time.get_ticks_msec() / 1000.0 - ultima_colision >= intervalo_actualizacion_colision or recortada.get_surface_count() == 0)
	if colision != null and cuerpo is CollisionObject3D and toca_actualizar_colision:
		var caras := PackedVector3Array()
		for superficie_nueva in range(recortada.get_surface_count()):
			var malla_arrays: Array = recortada.surface_get_arrays(superficie_nueva)
			caras.append_array(malla_arrays[Mesh.ARRAY_VERTEX])
		if caras.is_empty():
			cuerpo.collision_layer = 0
			cuerpo.collision_mask = 0
		else:
			var forma_recortada := ConcavePolygonShape3D.new()
			forma_recortada.set_faces(caras)
			colision.shape = forma_recortada
		_ultima_actualizacion_colision[instancia] = Time.get_ticks_msec() / 1000.0
	if recortada.get_surface_count() == 0:
		if cuerpo is CollisionObject3D and puede_alcanzarse:
			cuerpo.collision_layer = 0
			cuerpo.collision_mask = 0
	_procesando.erase(instancia)

func _recortar_triangulo(poligono: Array[Dictionary], instancia: MeshInstance3D, centro: Vector3, radio_corte: float) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for i in range(poligono.size()):
		var actual: Dictionary = poligono[i]
		var siguiente: Dictionary = poligono[(i + 1) % poligono.size()]
		var da := _distancia_esfera(instancia, actual["p"], centro, radio_corte)
		var db := _distancia_esfera(instancia, siguiente["p"], centro, radio_corte)
		var actual_fuera := da >= 0.0
		var siguiente_fuera := db >= 0.0
		if actual_fuera:
			resultado.append(actual)
		if actual_fuera != siguiente_fuera:
			var t := da / (da - db)
			var cruce := {"p": actual["p"].lerp(siguiente["p"], t)}
			if actual.has("n"): cruce["n"] = actual["n"].lerp(siguiente["n"], t).normalized()
			if actual.has("uv"): cruce["uv"] = actual["uv"].lerp(siguiente["uv"], t)
			if actual.has("c"): cruce["c"] = actual["c"].lerp(siguiente["c"], t)
			resultado.append(cruce)
	return resultado

func _distancia_esfera(instancia: MeshInstance3D, punto_local: Vector3, centro: Vector3, radio_corte: float) -> float:
	var punto_mundo: Vector3 = instancia.global_transform * punto_local
	return punto_mundo.distance_to(centro) - radio_corte
