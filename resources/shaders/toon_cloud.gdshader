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
uniform float bob_amount = 0.45;       // metres, gentle vertical bob (vertex animation: no per-frame script work)
uniform float drift_amount = 1.2;      // metres of slow horizontal drift
uniform float anim_speed = 1.0;
uniform float alt_low = -40.0;          // world height where clouds get their deepest lavender shade
uniform float alt_high = 25.0;          // ... and where they are fully sunlit
uniform float alt_dark = 0.14;
uniform float mottle = 0.30;            // large soft lobes of shade painted by world-space noise (reads as cumulus billows)
uniform float mottle_scale = 0.11;
uniform float edge_shade = 0.35;      // soft blue-grey outline where a lobe turns away (cumulus definition)
uniform float facet = 0.0;             // 0 = smooth mesh normals, 1 = flat low-poly facets (the concept clouds are chunky and faceted)
uniform vec3 low_tint : source_color = vec3(0.90, 0.86, 0.98);     // tint of clouds low in the world (shade of the ones above)
uniform vec3 mottle_tint : source_color = vec3(0.86, 0.82, 0.96);  // tint of the shaded lobes

varying float hh;
varying float puff_id;
varying vec3 wp;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}
float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	hh = clamp((VERTEX.y - h_min) / (h_max - h_min), 0.0, 1.0);
	puff_id = hash13(floor(MODEL_MATRIX[3].xyz * 0.5));
	float ph = puff_id * 6.2831;
	float sc = max(length(MODEL_MATRIX[0].xyz), 0.001);
	vec3 off = vec3(sin(TIME * 0.07 * anim_speed + ph) * drift_amount, sin(TIME * 0.18 * anim_speed + ph * 1.7) * bob_amount, cos(TIME * 0.05 * anim_speed + ph * 1.3) * drift_amount);
	VERTEX += off / sc;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = NORMAL;
	if (facet > 0.001) {
		vec3 nf = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		if (dot(nf, VIEW) < 0.0) {
			nf = -nf;
		}
		n = normalize(mix(n, nf, facet));
	}
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float lit = mix(wn.y * 0.5 + 0.5, hh, height_weight);
	lit = clamp((lit - 0.5) * contrast + 0.5, 0.0, 1.0);
	vec3 col = mix(color_bottom, color_mid, smoothstep(0.10, 0.50, lit));
	col = mix(col, color_top, smoothstep(0.50, 0.90, lit));
	float v = (puff_id - 0.5) * 2.0;
	col *= 1.0 - tint_variation * (0.5 + 0.5 * v) * (1.2 - lit);
	col += vec3(0.02, -0.01, 0.03) * v * tint_variation * 4.0 * (1.1 - lit);
	float alt = smoothstep(alt_low, alt_high, wp.y);
	col = mix(col * low_tint, col, alt);          // clouds low in the world sit in the shade of the ones above
	col *= 1.0 - alt_dark * (1.0 - alt);
	float mt = vnoise3(wp * mottle_scale) * 0.65 + vnoise3(wp * mottle_scale * 2.3 + 7.0) * 0.35;
	col = mix(col, col * mottle_tint, mottle * smoothstep(0.35, 0.8, mt) * (1.15 - lit));
	float s = clamp(dot(wn, normalize(sun_dir)) * (1.0 - sun_wrap) + sun_wrap, 0.0, 1.0);
	col = mix(col, col * 0.86 + sun_color * 0.18, smoothstep(0.35, 0.95, s));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	col = mix(col, color_bottom, smoothstep(0.25, 0.85, fres) * edge_shade * (1.0 - s * 0.6));
	col += sun_color * fres * rim_strength * 0.5 * s;
	ALBEDO = clamp(col, 0.0, 1.2);
}
