shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D textura_pantalla : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D textura_profundidad : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D textura_normales : hint_normal_roughness_texture, repeat_disable, filter_nearest;

group_uniforms papel_y_tinta;
uniform vec4 color_papel : source_color = vec4(0.96, 0.96, 0.94, 1.0);
uniform vec4 color_tinta : source_color = vec4(0.04, 0.04, 0.05, 1.0);

group_uniforms tonos;
uniform float exposicion : hint_range(0.2, 3.0) = 1.0;
uniform float umbral_blanco : hint_range(0.2, 1.0) = 0.85;
uniform int niveles_tono : hint_range(2, 8) = 4;

group_uniforms trama;
uniform float tamano_punto : hint_range(2.0, 16.0) = 6.0;
uniform float angulo_trama : hint_range(0.0, 90.0) = 45.0;

group_uniforms contorno;
uniform float grosor_linea : hint_range(0.5, 4.0) = 1.5;
uniform float umbral_profundidad : hint_range(0.005, 0.5) = 0.06;
uniform float umbral_normal : hint_range(0.05, 1.5) = 0.4;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float profundidad_lineal(vec2 uv, mat4 inv_proyeccion) {
	float d = texture(textura_profundidad, uv).x;
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
	vec4 vista = inv_proyeccion * vec4(ndc, 1.0);
	vista.xyz /= vista.w;
	return -vista.z;
}

vec3 normal_pantalla(vec2 uv) {
	return normalize(texture(textura_normales, uv).xyz * 2.0 - 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Luminancia en espacio perceptual
	vec3 base = texture(textura_pantalla, uv).rgb;
	float lum = dot(base, vec3(0.2126, 0.7152, 0.0722)) * exposicion;
	lum = clamp(pow(max(lum, 0.0), 0.4545), 0.0, 1.0);

	// Oscuridad cuantizada en niveles de tono
	float oscuridad = clamp(1.0 - lum / umbral_blanco, 0.0, 1.0);
	float niveles = float(niveles_tono);
	float nivel = floor(oscuridad * niveles + 0.5) / niveles;

	// Trama de puntos (screentone)
	float a = radians(angulo_trama);
	mat2 rotacion = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a)));
	vec2 p = rotacion * (FRAGCOORD.xy / tamano_punto);
	float dist = length(fract(p) - 0.5);
	float radio = sqrt(nivel) * 0.7071;
	float suavizado = 0.75 / tamano_punto;
	float mascara = 1.0 - smoothstep(radio - suavizado, radio + suavizado, dist);
	mascara *= step(0.001, nivel);
	mascara = max(mascara, step(0.999, nivel));

	// Contorno por profundidad y normales
	vec2 px = grosor_linea / VIEWPORT_SIZE;
	vec2 izq = uv - vec2(px.x, 0.0);
	vec2 der = uv + vec2(px.x, 0.0);
	vec2 aba = uv - vec2(0.0, px.y);
	vec2 arr = uv + vec2(0.0, px.y);

	float dc = profundidad_lineal(uv, INV_PROJECTION_MATRIX);
	float di = profundidad_lineal(izq, INV_PROJECTION_MATRIX);
	float dd = profundidad_lineal(der, INV_PROJECTION_MATRIX);
	float da = profundidad_lineal(aba, INV_PROJECTION_MATRIX);
	float dr = profundidad_lineal(arr, INV_PROJECTION_MATRIX);
	float borde_prof = (abs(di + dd - 2.0 * dc) + abs(da + dr - 2.0 * dc)) / max(dc, 0.001);
	borde_prof = step(umbral_profundidad, borde_prof);

	vec3 nc = normal_pantalla(uv);
	float borde_norm = (1.0 - dot(nc, normal_pantalla(izq)))
			+ (1.0 - dot(nc, normal_pantalla(der)))
			+ (1.0 - dot(nc, normal_pantalla(aba)))
			+ (1.0 - dot(nc, normal_pantalla(arr)));
	borde_norm = step(umbral_normal, borde_norm);

	float linea = max(borde_prof, borde_norm);

	vec3 color = mix(color_papel.rgb, color_tinta.rgb, mascara);
	color = mix(color, color_tinta.rgb, linea);
	ALBEDO = color;
}
