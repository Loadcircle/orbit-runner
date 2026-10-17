// Rising air: additive scrolling streaks, fades at the top and bottom.
// Works in Mobile and Compatibility renderers.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.55, 0.95, 1.0, 1.0);
uniform float speed = 1.4;
uniform float bands = 7.0;
uniform float strength = 0.45;

void fragment() {
	float swirl = UV.x * 3.0;
	float streak = smoothstep(0.62, 0.95, fract(UV.y * bands + TIME * speed + swirl));
	float fade = smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.75, UV.y);
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = tint.rgb * (streak * strength + rim * 0.12 + 0.03) * fade;
}
