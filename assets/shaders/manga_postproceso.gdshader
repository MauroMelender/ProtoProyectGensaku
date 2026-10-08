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
uniform float umbral_blanco : hint_range(0.2, 1.0) = 0.9;
uniform float curva_sombra : hint_range(0.3, 3.0) = 1.0;
uniform float umbral_negro : hint_range(0.5, 1.0) = 0.93;

group_uniforms rayado;
uniform float espaciado_lineas : hint_range(2.0, 14.0) = 5.0;
uniform float ondulacion : hint_range(0.0, 0.2) = 0.12;
uniform float irregularidad : hint_range(0.0, 1.0) = 0.35;
uniform float angulo_base : hint_range(-90.0, 90.0) = -35.0;
uniform float separacion_angulos : hint_range(10.0, 90.0) = 40.0;
uniform float inicio_rayado : hint_range(0.0, 0.6) = 0.12;
uniform float paso_rayado : hint_range(0.05, 0.4) = 0.2;

group_uniforms contorno;
uniform float grosor_linea : hint_range(0.5, 5.0) = 2.0;
uniform float umbral_profundidad : hint_range(0.005, 0.5) = 0.06;
uniform float umbral_normal : hint_range(0.05, 1.5) = 0.4;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float capa_rayado(vec2 pix, float angulo, float espaciado, float umbral, float oscuridad) {
	float a = radians(angulo);
	vec2 dir = vec2(cos(a), sin(a));
	vec2 nor = vec2(-dir.y, dir.x);
	float u = dot(pix, nor) / espaciado;
	float v = dot(pix, dir);
	float indice = floor(u);

	float desvio = (ruido(vec2(v * 0.04, indice * 7.13 + angulo)) - 0.5) * 2.0 * ondulacion;
	float corte = ruido(vec2(v * 0.025 + indice * 13.7, indice * 2.9 + angulo));
	float o = oscuridad + (corte - 0.5) * irregularidad;

	float presencia = smoothstep(umbral, umbral + 0.08, o);
	float grosor = mix(0.12, 0.6, clamp((o - umbral) / 0.35, 0.0, 1.0));
	float dist = abs(fract(u) - 0.5 - desvio);
	float suavizado = 0.75 / espaciado;
	float linea = 1.0 - smoothstep(grosor * 0.5 - suavizado, grosor * 0.5 + suavizado, dist);
	return linea * presencia;
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

	vec3 base = texture(textura_pantalla, uv).rgb;
	float lum = dot(base, vec3(0.2126, 0.7152, 0.0722)) * exposicion;
	lum = clamp(pow(max(lum, 0.0), 0.4545), 0.0, 1.0);

	float oscuridad = clamp(1.0 - lum / umbral_blanco, 0.0, 1.0);
	oscuridad = pow(oscuridad, curva_sombra);

	vec2 pix = FRAGCOORD.xy;
	float rayado = 0.0;
	rayado = max(rayado, capa_rayado(pix, angulo_base, espaciado_lineas, inicio_rayado, oscuridad));
	rayado = max(rayado, capa_rayado(pix, angulo_base + separacion_angulos, espaciado_lineas * 1.12, inicio_rayado + paso_rayado, oscuridad));
	rayado = max(rayado, capa_rayado(pix, angulo_base - separacion_angulos * 0.5, espaciado_lineas * 0.92, inicio_rayado + paso_rayado * 2.0, oscuridad));
	rayado = max(rayado, capa_rayado(pix, angulo_base + separacion_angulos * 1.8, espaciado_lineas * 1.2, inicio_rayado + paso_rayado * 3.0, oscuridad));
	rayado = max(rayado, step(umbral_negro, oscuridad));

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

	vec3 color = mix(color_papel.rgb, color_tinta.rgb, rayado);
	color = mix(color, color_tinta.rgb, linea);
	ALBEDO = color;
}
