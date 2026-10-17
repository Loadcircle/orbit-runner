shader_type spatial;
// Flat ink colour for the inverted-hull outline shells baked into the GLBs
// (materials named M_Outline*). Front faces of the shell point inwards, so
// default back-face culling leaves only the rim visible: no extra pass needed.
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 albedo : source_color = vec4(0.08, 0.09, 0.16, 1.0);

void fragment() {
	ALBEDO = albedo.rgb;
}
