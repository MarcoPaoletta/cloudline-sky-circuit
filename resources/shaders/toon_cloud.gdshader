shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
// Cloudline toon cloud: warm white tops, pink-lavender undersides, bright sun-side rim. Shaded by HEIGHT inside
// the puff (stable from any camera angle) plus the surface normal; ignores scene lights on purpose so every puff
// stays soft and clean in any lighting. Fog still blends distant clouds into the haze.

uniform vec3 color_top : source_color = vec3(1.0, 1.0, 0.99);
uniform vec3 color_mid : source_color = vec3(1.0, 0.95, 0.96);
uniform vec3 color_bottom : source_color = vec3(0.84, 0.76, 0.93);
uniform vec3 sun_color : source_color = vec3(1.0, 0.86, 0.68);
uniform vec3 sun_dir = vec3(-0.55, 0.43, -0.72);   // direction TOWARD the sun (world space)
uniform float h_min = -0.3;
uniform float h_max = 2.6;
uniform float height_weight = 0.65;
uniform float sun_wrap = 0.3;
uniform float rim_strength = 0.35;
uniform float contrast = 1.0;
uniform float tint_variation = 0.08;   // per-puff brightness / hue variation so overlapping puffs read as cauliflower

varying float hh;
varying float puff_id;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	hh = clamp((VERTEX.y - h_min) / (h_max - h_min), 0.0, 1.0);
	puff_id = hash13(floor(MODEL_MATRIX[3].xyz * 0.5));
}

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float lit = mix(wn.y * 0.5 + 0.5, hh, height_weight);
	lit = clamp((lit - 0.5) * contrast + 0.5, 0.0, 1.0);
	vec3 col = mix(color_bottom, color_mid, smoothstep(0.10, 0.50, lit));
	col = mix(col, color_top, smoothstep(0.50, 0.90, lit));
	float v = (puff_id - 0.5) * 2.0;
	col *= 1.0 - tint_variation * (0.5 + 0.5 * v) * (1.2 - lit);
	col += vec3(0.02, -0.01, 0.03) * v * tint_variation * 4.0 * (1.1 - lit);
	float s = clamp(dot(wn, normalize(sun_dir)) * (1.0 - sun_wrap) + sun_wrap, 0.0, 1.0);
	col = mix(col, col * 0.86 + sun_color * 0.18, smoothstep(0.35, 0.95, s));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	col += sun_color * fres * rim_strength * 0.5 * s;
	ALBEDO = clamp(col, 0.0, 1.2);
}
