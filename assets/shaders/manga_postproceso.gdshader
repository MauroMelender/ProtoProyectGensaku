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
uniform float espaciado_lineas : hint_range(0.005, 0.5) = 0.03;
uniform float espaciado_minimo_px : hint_range(2.0, 14.0) = 5.0;
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

float capa_rayado(vec2 coord, float angulo, float espaciado, float umbral, float oscuridad, float pixel_mundo) {
	float a = radians(angulo);
	vec2 dir = vec2(cos(a), sin(a));
	vec2 nor = vec2(-dir.y, dir.x);
	float u = dot(coord, nor) / espaciado;
	float v = dot(coord, dir) / espaciado;
	float indice = floor(u);

	float desvio = (ruido(vec2(v * 0.2, indice * 7.13 + angulo)) - 0.5) * 2.0 * ondulacion;
	float corte = ruido(vec2(v * 0.125 + indice * 13.7, indice * 2.9 + angulo));
	float o = oscuridad + (corte - 0.5) * irregularidad;

	float presencia = smoothstep(umbral, umbral + 0.08, o);
	float grosor = mix(0.12, 0.6, clamp((o - umbral) / 0.35, 0.0, 1.0));
	float dist = abs(fract(u) - 0.5 - desvio);
	float suavizado = 0.75 * pixel_mundo / espaciado;
	float linea = 1.0 - smoothstep(grosor * 0.5 - suavizado, grosor * 0.5 + suavizado, dist);
	return linea * presencia;
}

float rayado_en_escala(vec2 coord, float espaciado, float oscuridad, float pixel_mundo) {
	float r = 0.0;
	r = max(r, capa_rayado(coord, angulo_base, espaciado, inicio_rayado, oscuridad, pixel_mundo));
	r = max(r, capa_rayado(coord, angulo_base + separacion_angulos, espaciado * 1.12, inicio_rayado + paso_rayado, oscuridad, pixel_mundo));
	r = max(r, capa_rayado(coord, angulo_base - separacion_angulos * 0.5, espaciado * 0.92, inicio_rayado + paso_rayado * 2.0, oscuridad, pixel_mundo));
	r = max(r, capa_rayado(coord, angulo_base + separacion_angulos * 1.8, espaciado * 1.2, inicio_rayado + paso_rayado * 3.0, oscuridad, pixel_mundo));
	return r;
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

	float prof_centro = texture(textura_profundidad, uv).x;
	vec4 vista = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, prof_centro, 1.0);
	vista.xyz /= vista.w;
	vec3 posicion_mundo = (INV_VIEW_MATRIX * vec4(vista.xyz, 1.0)).xyz;
	float dc = -vista.z;

	vec3 normal_vista = normal_pantalla(uv);
	vec3 normal_mundo = abs(mat3(INV_VIEW_MATRIX) * normal_vista);

	vec2 coord;
	if (normal_mundo.y >= normal_mundo.x && normal_mundo.y >= normal_mundo.z) {
		coord = posicion_mundo.xz;
	} else if (normal_mundo.x >= normal_mundo.z) {
		coord = posicion_mundo.zy;
	} else {
		coord = posicion_mundo.xy;
	}

	float pixel_mundo = max(dc, 0.001) * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float nivel = max(log2(pixel_mundo * espaciado_minimo_px / espaciado_lineas), 0.0);
	float octava = floor(nivel) + 1.0;
	float fraccion = fract(nivel);
	float espaciado = espaciado_lineas * exp2(octava);
	float peso_anterior = 1.0 - smoothstep(0.0, 0.25, fraccion);

	float rayado = 0.0;
	if (peso_anterior > 0.0) {
		rayado += rayado_en_escala(coord, espaciado * 0.5, oscuridad, pixel_mundo) * peso_anterior;
	}
	if (peso_anterior < 1.0) {
		rayado += rayado_en_escala(coord, espaciado, oscuridad, pixel_mundo) * (1.0 - peso_anterior);
	}
	rayado = max(rayado, step(umbral_negro, oscuridad));

	vec2 px = grosor_linea / VIEWPORT_SIZE;
	vec2 izq = uv - vec2(px.x, 0.0);
	vec2 der = uv + vec2(px.x, 0.0);
	vec2 aba = uv - vec2(0.0, px.y);
	vec2 arr = uv + vec2(0.0, px.y);

	float di = profundidad_lineal(izq, INV_PROJECTION_MATRIX);
	float dd = profundidad_lineal(der, INV_PROJECTION_MATRIX);
	float da = profundidad_lineal(aba, INV_PROJECTION_MATRIX);
	float dr = profundidad_lineal(arr, INV_PROJECTION_MATRIX);
	float borde_prof = (abs(di + dd - 2.0 * dc) + abs(da + dr - 2.0 * dc)) / max(dc, 0.001);
	borde_prof = step(umbral_profundidad, borde_prof);

	float borde_norm = (1.0 - dot(normal_vista, normal_pantalla(izq)))
			+ (1.0 - dot(normal_vista, normal_pantalla(der)))
			+ (1.0 - dot(normal_vista, normal_pantalla(aba)))
			+ (1.0 - dot(normal_vista, normal_pantalla(arr)));
	borde_norm = step(umbral_normal, borde_norm);

	float linea = max(borde_prof, borde_norm);

	vec3 color = mix(color_papel.rgb, color_tinta.rgb, rayado);
	color = mix(color, color_tinta.rgb, linea);
	ALBEDO = color;
}
