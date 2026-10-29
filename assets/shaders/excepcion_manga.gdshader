shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
stencil_mode write, compare_always, 1;

void fragment() {
	ALBEDO = vec3(0.0);
}