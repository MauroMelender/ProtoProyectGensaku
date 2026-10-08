shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_test_disabled, depth_draw_never;

// ============================================================================
//  CEL SHADER DURO (post-proceso) - 4 tonos + contorno
// ============================================================================
//  Se lee la luminosidad de la pantalla (0 = oscuro, 1 = claro) y se corta en
//  4 bandas planas, sin degradado:
//
//   0.0 ─────────────────────────────────────────────────────────── 1.0
//   │  NEGRO   │    SOMBRA    │   LUZ PARCIAL   │      BLANCO       │
//   0.0        ▲              ▲                 ▲                   1.0
//        umbral_negro   umbral_sombra       umbral_luz
//
//  - Mueve un umbral a la DERECHA (valor mayor) -> esa banda oscura crece.
//  - Mueve un umbral a la IZQUIERDA (valor menor) -> esa banda oscura se achica.
//
//  Ejemplos rápidos:
//    * Más negro en general ........ sube umbral_negro (ej. 0.15 -> 0.30)
//    * Menos blanco / más gris ...... sube umbral_luz   (ej. 0.75 -> 0.90)
//    * Más highlights blancos ....... baja umbral_luz   (ej. 0.75 -> 0.55)
//
//  Todos los valores aparecen en el Inspector (uniforms con slider).
//  El orden se corrige solo: aunque cruces los sliders, nunca se invierten.
// ============================================================================

uniform sampler2D textura_pantalla : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D textura_profundidad : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D textura_normales : hint_normal_roughness_texture, repeat_disable, filter_nearest;

// ----------------------------------------------------------------------------
//  BARRAS DE CORTE (los 3 umbrales que separan las 4 bandas)
// ----------------------------------------------------------------------------
group_uniforms barras_de_corte;

// Debajo de este valor = NEGRO TOTAL (las sombras más oscuras).
uniform float umbral_negro : hint_range(0.0, 1.0, 0.005) = 0.05;

// Entre umbral_negro y este valor = GRIS (zona en sombra).
uniform float umbral_sombra : hint_range(0.0, 1.0, 0.005) = 0.40;

// Entre umbral_sombra y este valor = GRIS CLARO (parcialmente iluminado).
// Por encima de este valor = BLANCO PURO (highlights).
uniform float umbral_luz : hint_range(0.0, 1.0, 0.005) = 0.75;

// Dureza del corte entre bandas.
// 0.0 = totalmente duro (puede verse "dentado"), 0.01-0.02 = duro pero suave en el borde.
uniform float suavizado_borde : hint_range(0.0, 0.1, 0.001) = 0.01;
group_uniforms;

// ----------------------------------------------------------------------------
//  COLORES DE CADA BANDA
// ----------------------------------------------------------------------------
group_uniforms colores;
uniform vec4 color_negro : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 color_sombra : source_color = vec4(0.25, 0.25, 0.27, 1.0);
uniform vec4 color_luz_parcial : source_color = vec4(0.65, 0.65, 0.67, 1.0);
uniform vec4 color_blanco : source_color = vec4(1.0, 1.0, 1.0, 1.0);
group_uniforms;

// ----------------------------------------------------------------------------
//  AJUSTE DE LUMINOSIDAD (antes de cortar en bandas)
// ----------------------------------------------------------------------------
group_uniforms ajuste_luz;
// Multiplica la luz de la escena. Más alto = todo más claro (menos negro).
uniform float exposicion : hint_range(0.2, 3.0, 0.01) = 1.0;
// Aplica corrección gamma antes de cortar. Actívalo si las bandas se ven
// muy aplastadas hacia el negro; desactívalo para trabajar en luz lineal.
uniform bool usar_gamma = true;
group_uniforms;

// ----------------------------------------------------------------------------
//  CONTORNO (líneas de tinta en bordes de profundidad y de normales)
// ----------------------------------------------------------------------------
group_uniforms contorno;
uniform bool activar_contorno = true;
uniform vec4 color_linea : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Grosor en píxeles.
uniform float grosor_linea : hint_range(0.5, 5.0, 0.1) = 2.0;
// Más bajo = detecta más bordes por profundidad (siluetas).
uniform float umbral_profundidad : hint_range(0.005, 0.5, 0.005) = 0.06;
// Más bajo = detecta más bordes por cambios de normal (pliegues internos).
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

// Devuelve 0 si lum < corte, 1 si lum >= corte (con borde suavizado opcional).
float corte(float corte_valor, float lum) {
	float s = max(suavizado_borde, 0.0001);
	return smoothstep(corte_valor - s, corte_valor + s, lum);
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

	// ---- Umbrales siempre en orden (negro <= sombra <= luz) ----
	float t1 = umbral_negro;
	float t2 = max(umbral_sombra, t1);
	float t3 = max(umbral_luz, t2);

	// ---- Bandas: se parte de negro y cada corte "sube" un tono ----
	vec3 color = color_negro.rgb;
	color = mix(color, color_sombra.rgb, corte(t1, lum));
	color = mix(color, color_luz_parcial.rgb, corte(t2, lum));
	color = mix(color, color_blanco.rgb, corte(t3, lum));

	// ---- Contorno ----
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
