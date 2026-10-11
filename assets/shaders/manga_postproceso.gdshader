shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_test_disabled, depth_draw_never;

// ============================================================================
//  CEL SHADER DE 6 TONOS DE GRIS (post-proceso)
//  Pensado para imitar una esfera con bandas concéntricas duras:
//  highlight claro -> 4 grises -> sliver negro en el borde de sombra.
// ============================================================================
//  Se corta la luminosidad (0 = oscuro, 1 = claro) con 5 barras:
//
//   0.0 ──────────────────────────────────────────────────────────── 1.0
//   │ NEGRO │ GRIS 5 │ GRIS 4 │  GRIS 3  │  GRIS 2  │  HIGHLIGHT    │
//   0.0     ▲        ▲        ▲          ▲          ▲               1.0
//         corte_1  corte_2  corte_3    corte_4    corte_5
//
//  - Subir un corte  -> la banda que queda DEBAJO de él crece.
//  - Bajar un corte  -> esa banda se achica.
//  - corte_1 muy bajo = sliver negro finito (como en la referencia).
//  - corte_5 alto     = highlight pequeño; bajo = highlight grande.
//
//  Con usar_gamma = false (por defecto), los valores equivalen al
//  "coseno de la luz": 1.0 = mirando directo a la luz, 0.0 = perpendicular.
//  Los 5 cortes se reordenan solos, nunca se cruzan.
// ============================================================================

uniform sampler2D textura_pantalla : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D textura_profundidad : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D textura_normales : hint_normal_roughness_texture, repeat_disable, filter_nearest;

// ----------------------------------------------------------------------------
//  BARRAS DE CORTE
// ----------------------------------------------------------------------------
group_uniforms barras_de_corte;
uniform float corte_1 : hint_range(0.0, 1.0, 0.005) = 0.03; // negro | gris 5
uniform float corte_2 : hint_range(0.0, 1.0, 0.005) = 0.22; // gris 5 | gris 4
uniform float corte_3 : hint_range(0.0, 1.0, 0.005) = 0.45; // gris 4 | gris 3
uniform float corte_4 : hint_range(0.0, 1.0, 0.005) = 0.68; // gris 3 | gris 2
uniform float corte_5 : hint_range(0.0, 1.0, 0.005) = 0.88; // gris 2 | highlight

// 0.0 = corte totalmente duro. 0.005-0.02 = duro pero sin dientes de sierra.
uniform float suavizado_borde : hint_range(0.0, 0.1, 0.001) = 0.006;
group_uniforms;

// ----------------------------------------------------------------------------
//  COLORES (de más oscuro a más claro)
// ----------------------------------------------------------------------------
group_uniforms colores;
uniform vec4 color_negro : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 color_gris_5 : source_color = vec4(0.38, 0.38, 0.38, 1.0);
uniform vec4 color_gris_4 : source_color = vec4(0.52, 0.52, 0.52, 1.0);
uniform vec4 color_gris_3 : source_color = vec4(0.66, 0.66, 0.66, 1.0);
uniform vec4 color_gris_2 : source_color = vec4(0.79, 0.79, 0.79, 1.0);
uniform vec4 color_highlight : source_color = vec4(0.91, 0.91, 0.91, 1.0);
group_uniforms;

// ----------------------------------------------------------------------------
//  AJUSTE DE LUMINOSIDAD
// ----------------------------------------------------------------------------
group_uniforms ajuste_luz;
// Más alto = escena más clara (las bandas se desplazan hacia la sombra).
uniform float exposicion : hint_range(0.2, 3.0, 0.01) = 1.0;
// false: bandas siguen el coseno de la luz (más fiel a la referencia).
// true : se aplica gamma, las bandas oscuras se hacen más anchas.
uniform bool usar_gamma = false;
group_uniforms;

// ----------------------------------------------------------------------------
//  CONTORNO (apagado por defecto: la referencia no tiene línea)
// ----------------------------------------------------------------------------
group_uniforms contorno;
uniform bool activar_contorno = false;
uniform vec4 color_linea : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float grosor_linea : hint_range(0.5, 5.0, 0.1) = 2.0;
uniform float umbral_profundidad : hint_range(0.005, 0.5, 0.005) = 0.06;
uniform float umbral_normal : hint_range(0.05, 1.5, 0.01) = 0.4;
group_uniforms;

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

float corte(float valor_corte, float lum) {
	float s = max(suavizado_borde, 0.0001);
	return smoothstep(valor_corte - s, valor_corte + s, lum);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// ---- Luminosidad ----
	vec3 base = texture(textura_pantalla, uv).rgb;
	float lum = dot(base, vec3(0.2126, 0.7152, 0.0722)) * exposicion;
	if (usar_gamma) {
		lum = pow(max(lum, 0.0), 0.4545);
	}
	lum = clamp(lum, 0.0, 1.0);

	// ---- Cortes siempre en orden ----
	float t1 = corte_1;
	float t2 = max(corte_2, t1);
	float t3 = max(corte_3, t2);
	float t4 = max(corte_4, t3);
	float t5 = max(corte_5, t4);

	// ---- Bandas ----
	vec3 color = color_negro.rgb;
	color = mix(color, color_gris_5.rgb, corte(t1, lum));
	color = mix(color, color_gris_4.rgb, corte(t2, lum));
	color = mix(color, color_gris_3.rgb, corte(t3, lum));
	color = mix(color, color_gris_2.rgb, corte(t4, lum));
	color = mix(color, color_highlight.rgb, corte(t5, lum));

	// ---- Contorno opcional ----
	if (activar_contorno) {
		float dc = profundidad_lineal(uv, INV_PROJECTION_MATRIX);
		vec3 normal_vista = normal_pantalla(uv);

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
		color = mix(color, color_linea.rgb, linea);
	}

	ALBEDO = color;
}
