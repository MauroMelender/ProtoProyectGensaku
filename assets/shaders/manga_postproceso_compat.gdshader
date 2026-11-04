shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D textura_pantalla : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D textura_profundidad : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms barras_de_corte;
uniform float corte_1 : hint_range(0.0, 1.0, 0.005) = 0.03;
uniform float corte_2 : hint_range(0.0, 1.0, 0.005) = 0.22;
uniform float corte_3 : hint_range(0.0, 1.0, 0.005) = 0.45;
uniform float corte_4 : hint_range(0.0, 1.0, 0.005) = 0.68;
uniform float corte_5 : hint_range(0.0, 1.0, 0.005) = 0.88;
uniform float suavizado_borde : hint_range(0.0, 0.1, 0.001) = 0.006;
group_uniforms;

group_uniforms colores;
uniform vec4 color_negro : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 color_gris_5 : source_color = vec4(0.38, 0.38, 0.38, 1.0);
uniform vec4 color_gris_4 : source_color = vec4(0.52, 0.52, 0.52, 1.0);
uniform vec4 color_gris_3 : source_color = vec4(0.66, 0.66, 0.66, 1.0);
uniform vec4 color_gris_2 : source_color = vec4(0.79, 0.79, 0.79, 1.0);
uniform vec4 color_highlight : source_color = vec4(0.91, 0.91, 0.91, 1.0);
group_uniforms;

group_uniforms ajuste_luz;
group_uniforms contorno;
uniform bool activar_contorno = false;
uniform vec4 color_linea : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float grosor_linea : hint_range(0.5, 5.0, 0.1) = 2.0;
uniform float umbral_profundidad : hint_range(0.005, 0.5, 0.005) = 0.06;
uniform float exposicion : hint_range(0.2, 3.0, 0.01) = 1.0;
uniform bool usar_gamma = false;
group_uniforms;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float corte(float valor_corte, float lum) {
	float s = max(suavizado_borde, 0.0001);
	return smoothstep(valor_corte - s, valor_corte + s, lum);
}


float profundidad_lineal(vec2 uv, mat4 inv_proyeccion) {
	float d = texture(textura_profundidad, uv).x;
	vec3 ndc = vec3(uv * 2.0 - 1.0, d * 2.0 - 1.0);
	vec4 vista = inv_proyeccion * vec4(ndc, 1.0);
	vista.xyz /= vista.w;
	return -vista.z;
}

void fragment() {
	vec3 base = texture(textura_pantalla, SCREEN_UV).rgb;
	float lum = dot(base, vec3(0.2126, 0.7152, 0.0722)) * exposicion;
	if (usar_gamma) {
		lum = pow(max(lum, 0.0), 0.4545);
	}
	lum = clamp(lum, 0.0, 1.0);

	float t1 = corte_1;
	float t2 = max(corte_2, t1);
	float t3 = max(corte_3, t2);
	float t4 = max(corte_4, t3);
	float t5 = max(corte_5, t4);

	vec3 color = color_negro.rgb;
	color = mix(color, color_gris_5.rgb, corte(t1, lum));
	color = mix(color, color_gris_4.rgb, corte(t2, lum));
	color = mix(color, color_gris_3.rgb, corte(t3, lum));
	color = mix(color, color_gris_2.rgb, corte(t4, lum));
	color = mix(color, color_highlight.rgb, corte(t5, lum));
		if (activar_contorno) {
			if (activar_contorno) {
		vec2 px = grosor_linea / VIEWPORT_SIZE;
		float ic = 1.0 / profundidad_lineal(SCREEN_UV, INV_PROJECTION_MATRIX);
		float il = 1.0 / profundidad_lineal(SCREEN_UV - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
		float ir = 1.0 / profundidad_lineal(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
		float iu = 1.0 / profundidad_lineal(SCREEN_UV - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
		float id = 1.0 / profundidad_lineal(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
		float borde = (abs(il + ir - 2.0 * ic) + abs(iu + id - 2.0 * ic)) / max(ic, 0.0001);
		color = mix(color, color_linea.rgb, step(umbral_profundidad, borde));
	}
	}
	ALBEDO = color;
}