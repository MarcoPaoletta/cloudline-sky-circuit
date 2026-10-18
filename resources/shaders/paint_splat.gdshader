shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Cloudline flat paint splat (v2): a textured quad laid on flat ground. Replaces the Decal on flat floors because
// the Mobile renderer applies at most 8 decals per mesh (each arena floor is one mesh with 14 dirt decals, so paint
// decals never showed there). Same six splat shapes; tinted per instance; toon-lit like the floor it sits on;
// a little emission keeps it vivid (the reference's emission 1.2 look). The dissolve erodes the shape in blotches.

uniform sampler2D splat_0 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D splat_1 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D splat_2 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D splat_3 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D splat_4 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D splat_5 : source_color, filter_linear_mipmap, repeat_disable;
uniform float emission_gain = 0.28;
uniform float sun_gain = 0.95;
uniform float band_center = 0.46;
uniform float band_soft = 0.20;
uniform vec3 shade_tint : source_color = vec3(0.86, 0.80, 0.92);
uniform float shade_amount = 0.55;
uniform float gloss = 0.35;          // wet sheen: a soft stepped sun glint
uniform vec3 gloss_color : source_color = vec3(1.0, 0.98, 0.94);

instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float splat_idx = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	int i = int(splat_idx + 0.5);
	vec4 t;
	if (i == 0) { t = texture(splat_0, UV); }
	else if (i == 1) { t = texture(splat_1, UV); }
	else if (i == 2) { t = texture(splat_2, UV); }
	else if (i == 3) { t = texture(splat_3, UV); }
	else if (i == 4) { t = texture(splat_4, UV); }
	else { t = texture(splat_5, UV); }
	float n = vnoise(UV * 9.0) * 0.7 + vnoise(UV * 23.0) * 0.3;
	ALBEDO = t.rgb * tint.rgb;
	ALPHA = t.a * step(n * 0.96, tint.a);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	EMISSION = ALBEDO * emission_gain;
}

void light() {
	float wrap = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(band_center - band_soft, band_center + band_soft, wrap) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * sun_gain / PI;
	DIFFUSE_LIGHT *= mix(vec3(1.0), shade_tint, (1.0 - lit) * shade_amount);
	vec3 hv = normalize(LIGHT + VIEW);
	float sp = smoothstep(0.30, 0.62, pow(max(dot(NORMAL, hv), 0.0), 24.0));
	SPECULAR_LIGHT += LIGHT_COLOR * gloss_color * sp * gloss * ATTENUATION / PI;
}
