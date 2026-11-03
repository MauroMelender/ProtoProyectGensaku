shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform bool use_triplanar = true;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float material_roughness = 1.0;
uniform float material_metallic = 0.0;
uniform float material_specular = 0.5;
uniform vec3 void_center = vec3(0.0);
uniform float void_radius = 0.0;
uniform float ink_edge_width = 3.8;
uniform float ink_noise_strength = 1.8;
uniform float ink_noise_scale = 2.0;

varying vec3 world_position;
varying vec3 world_normal;

float hash_cell(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise_3d(vec3 p) {
	vec3 cell = floor(p);
	vec3 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	float n000 = hash_cell(cell + vec3(0.0, 0.0, 0.0));
	float n100 = hash_cell(cell + vec3(1.0, 0.0, 0.0));
	float n010 = hash_cell(cell + vec3(0.0, 1.0, 0.0));
	float n110 = hash_cell(cell + vec3(1.0, 1.0, 0.0));
	float n001 = hash_cell(cell + vec3(0.0, 0.0, 1.0));
	float n101 = hash_cell(cell + vec3(1.0, 0.0, 1.0));
	float n011 = hash_cell(cell + vec3(0.0, 1.0, 1.0));
	float n111 = hash_cell(cell + vec3(1.0, 1.0, 1.0));
	float z0 = mix(mix(n000, n100, local.x), mix(n010, n110, local.x), local.y);
	float z1 = mix(mix(n001, n101, local.x), mix(n011, n111, local.x), local.y);
	return mix(z0, z1, local.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float distancia_borde = distance(world_position, void_center) - void_radius;
	if (distancia_borde < -ink_noise_strength * 0.5) {
		discard;
	}
	float ruido = 0.5;
	float distancia_con_ruido = distancia_borde;
	if (distancia_borde < ink_edge_width + ink_noise_strength * 0.5) {
		ruido = noise_3d(world_position * ink_noise_scale);
		distancia_con_ruido += (ruido - 0.5) * ink_noise_strength;
		if (distancia_con_ruido < 0.0) {
			discard;
		}
	}

	vec3 texture_color = vec3(1.0);
	if (use_texture) {
		if (use_triplanar) {
			vec3 weights = pow(abs(normalize(world_normal)), vec3(4.0));
			weights /= max(weights.x + weights.y + weights.z, 0.0001);
			vec3 p = world_position * uv_scale + uv_offset;
			texture_color = texture(albedo_texture, p.yz).rgb * weights.x;
			texture_color += texture(albedo_texture, p.xz).rgb * weights.y;
			texture_color += texture(albedo_texture, p.xy).rgb * weights.z;
		} else {
			texture_color = texture(albedo_texture, UV * uv_scale.xy + uv_offset.xy).rgb;
		}
	}

	vec3 color_superficie = texture_color * albedo_color.rgb;
	if (distancia_con_ruido < ink_edge_width) {
		float tinta = smoothstep(0.0, ink_edge_width, distancia_con_ruido);
		float grano_tinta = smoothstep(0.28, 0.78, ruido);
		vec3 tinta_oscura = color_superficie * mix(0.02, 0.25, grano_tinta);
		color_superficie = mix(tinta_oscura, color_superficie, tinta);
	}
	ALBEDO = color_superficie;
	ROUGHNESS = material_roughness;
	METALLIC = material_metallic;
	SPECULAR = material_specular;
}
