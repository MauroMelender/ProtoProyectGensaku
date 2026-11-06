shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 color_ceniza : source_color = vec4(0.12, 0.115, 0.11, 0.98);
varying float opacidad_instancia;

void vertex() {
	opacidad_instancia = INSTANCE_CUSTOM.a;
}

void fragment() {
	ALBEDO = color_ceniza.rgb;
	ALPHA = color_ceniza.a * opacidad_instancia;
}
