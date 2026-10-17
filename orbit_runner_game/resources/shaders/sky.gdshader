shader_type sky;
// Stylised biome sky: three-stop vertical gradient, soft sun with halo and a
// bright horizon band. Background only (ambient light comes from a colour).

uniform vec4 top_color : source_color = vec4(0.12, 0.36, 0.86, 1.0);
uniform vec4 mid_color : source_color = vec4(0.35, 0.66, 0.98, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.82, 0.93, 1.0, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.45, 0.7, 0.95, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float sun_size = 0.035;
uniform float halo_strength = 0.35;
uniform float horizon_sharpness = 6.0;

void sky() {
	float y = EYEDIR.y;
	vec3 col;
	if (y >= 0.0) {
		float h = pow(clamp(y, 0.0, 1.0), 0.55);
		col = mix(horizon_color.rgb, mid_color.rgb, smoothstep(0.0, 0.35, h));
		col = mix(col, top_color.rgb, smoothstep(0.35, 1.0, h));
	} else {
		col = mix(horizon_color.rgb, bottom_color.rgb, clamp(-y * horizon_sharpness, 0.0, 1.0));
	}
	vec3 sun_dir = LIGHT0_DIRECTION;
	float d = dot(EYEDIR, sun_dir);
	float disc = smoothstep(cos(sun_size), cos(sun_size * 0.8), d);
	float halo = pow(max(d, 0.0), 24.0) * halo_strength;
	col += sun_color.rgb * (halo + disc * 1.6) * float(LIGHT0_ENABLED);
	COLOR = col;
}
