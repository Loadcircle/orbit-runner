// Orbit Runner toon lighting, shared by every world material.
// Works in the Compatibility renderer (GLES3): custom light() + global uniforms.
//
// Look: two soft-edged bands (lit / shadow) plus a narrow highlight band,
// coloured shadows (a biome tint instead of grey), a toon rim on the lit side
// and a small specular glint. Vertex colours multiply the albedo, so Blender
// assets can bake cheap gradients/AO without textures.
//
// Variants define, before including this file:
//   TOON_FADE   dithers out near the camera (decoration only: uses discard).
//   TOON_GHOST  alpha-blended "already collected" look.

global uniform vec4 toon_shadow_color;  // multiplies light in the shadow band
global uniform vec4 toon_rim_color;
global uniform float toon_band_softness;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.7;
// 0 = plain material, 1 = strong glossy glint (plastic, metal, gems).
uniform float gloss : hint_range(0.0, 1.0) = 0.0;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.35;
// Per-material shadow colour (alpha = how much it replaces the biome tint).
// Skin uses a warm shadow so it never turns grey.
uniform vec4 shadow_override : source_color = vec4(1.0, 1.0, 1.0, 0.0);
// Shifts the light/shadow terminator (positive = more surface in light).
uniform float band_offset : hint_range(-0.5, 0.5) = 0.0;
uniform bool use_vertex_color = true;
#ifdef TOON_FADE
uniform float fade_near = 3.0;
uniform float fade_far = 7.5;
#endif
#ifdef TOON_GHOST
uniform float ghost_alpha : hint_range(0.0, 1.0) = 0.45;
#endif

void fragment() {
	vec3 base = albedo.rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	ALBEDO = base;
	EMISSION = emission.rgb * emission_energy;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.0;
#ifdef TOON_FADE
	// 4x4 Bayer dither: opaque pipeline, no sorting, cheap on tilers.
	float dist = length(VERTEX);
	float visibility = clamp((dist - fade_near) / max(fade_far - fade_near, 0.001), 0.0, 1.0);
	int x = int(mod(FRAGCOORD.x, 4.0));
	int y = int(mod(FRAGCOORD.y, 4.0));
	const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
			3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	if (visibility < (bayer[y * 4 + x] + 0.5) / 16.0) {
		discard;
	}
#endif
#ifdef TOON_GHOST
	ALPHA = ghost_alpha;
#endif
}

void light() {
	float soft = max(toon_band_softness, 0.005);
	float ndl = dot(NORMAL, LIGHT) + band_offset;
	float lit = smoothstep(-soft, soft, ndl - 0.02);
	// Cast shadows join the shadow band with the same soft edge.
	lit *= smoothstep(0.35, 0.65, ATTENUATION);
	float high = smoothstep(0.55 - soft, 0.55 + soft, ndl) * lit;

	vec3 shadow_tint = mix(toon_shadow_color.rgb, shadow_override.rgb, shadow_override.a);
	vec3 band = mix(shadow_tint, vec3(1.0), lit) + vec3(0.1) * high;
	DIFFUSE_LIGHT += LIGHT_COLOR * band / PI;

	// Toon rim: brightens silhouettes facing the light so shapes pop off the sky.
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(0.62, 0.62 + soft * 1.5, fres) * rim_amount;
	rim *= 0.35 + 0.65 * clamp(dot(LIGHT, -VIEW) * 0.5 + 0.5 + lit * 0.5, 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * toon_rim_color.rgb * rim * 0.5 / PI;

	// Glossy glint: a crisp toon highlight on plastic, metal and gems.
	if (gloss > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float spec_power = mix(24.0, 160.0, 1.0 - roughness);
		float glint = smoothstep(0.5 - soft, 0.5 + soft, pow(max(dot(NORMAL, h), 0.0), spec_power));
		SPECULAR_LIGHT += LIGHT_COLOR * glint * gloss * lit * 0.6;
	}
}
