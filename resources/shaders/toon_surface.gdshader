shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Cloudline toon surface (grass, dirt, rock, props): flat facets, soft two-step sun light, warm shade, rim glow.
// Colors are the lit surface colors seen in the concept art; the sun brightens them toward yellow and the shaded
// faces keep their hue (never go grey or blue).

uniform vec3 color_a : source_color = vec3(0.80, 0.93, 0.18);   // main color
uniform vec3 color_b : source_color = vec3(0.66, 0.86, 0.16);   // patch color (noise / vertical gradient)
uniform float patch_scale = 0.28;
uniform float patch_mix = 0.55;
uniform bool top_only_patches = true;
uniform float top_gain = 1.0;       // extra lightness for faces looking up
uniform vec3 shade_tint : source_color = vec3(0.86, 0.80, 0.92); // multiplies the albedo in shadow
uniform float shade_amount = 0.55;  // how strongly the shade tint shows (0..1)
uniform float band_center = 0.46;
uniform float band_soft = 0.20;
uniform float sun_gain = 0.95;
uniform float rim_strength = 0.22;
uniform float rim_power = 3.0;
uniform vec3 rim_color : source_color = vec3(1.0, 0.95, 0.80);
uniform float flat_faces = 1.0;     // 1 = faceted normals from screen derivatives, 0 = mesh normals
uniform float gradient_height = 0.0; // != 0 : deepens the color away from gradient_top_y over this many metres (object space y, signed)
uniform float gradient_top_y = 0.0;
uniform float taper = 0.0;          // 0 = off; 0.8 pulls the far end of the gradient axis in to 20% of its width
uniform float taper_curve = 1.0;
uniform float facet_jitter = 0.0;   // per-facet brightness variation (crystal look), uses the flat normal as the facet id
uniform float spec_strength = 0.0;   // toon highlight: a soft, stepped sun glint (plastic / metal / glass sheen)
uniform float spec_size = 0.5;       // 0 = tight glint, 1 = broad sheen
uniform vec3 spec_color : source_color = vec3(1.0, 0.98, 0.92);
uniform float checker_size = 0.0;   // metres; > 0 paints a mowed-lawn checker on upward faces (arena floors)
uniform float checker_mix = 0.1;
uniform float wobble = 0.0;         // organic sideways wobble (metres at the far end), differs per island by world position

varying vec3 wpos;
varying float objy;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}
float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i);
	float n100 = hash31(i + vec3(1, 0, 0));
	float n010 = hash31(i + vec3(0, 1, 0));
	float n110 = hash31(i + vec3(1, 1, 0));
	float n001 = hash31(i + vec3(0, 0, 1));
	float n101 = hash31(i + vec3(1, 0, 1));
	float n011 = hash31(i + vec3(0, 1, 1));
	float n111 = hash31(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

void vertex() {
	if (taper > 0.001) {
		float t = clamp((VERTEX.y - gradient_top_y) / gradient_height, 0.0, 1.0);
		float s = mix(1.0, 1.0 - taper, pow(t, taper_curve));
		VERTEX.xz *= s;
		if (wobble > 0.001) {
			vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
			VERTEX.x += (vnoise3(w * 0.33) - 0.5) * wobble * t;
			VERTEX.z += (vnoise3(w * 0.33 + 17.0) - 0.5) * wobble * t;
		}
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	objy = VERTEX.y;
}

void fragment() {
	vec3 n = NORMAL;
	if (flat_faces > 0.5) {
		n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		if (dot(n, VIEW) < 0.0) {
			n = -n;
		}
	}
	NORMAL = n;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float upness = clamp(wn.y, 0.0, 1.0);
	float nz = vnoise(wpos.xz * patch_scale) * 0.65 + vnoise(wpos.xz * patch_scale * 2.7 + 9.1) * 0.35;
	float pm = patch_mix * nz;
	if (top_only_patches) {
		pm *= step(0.5, wn.y);
	}
	vec3 col = mix(color_a, color_b, pm);
	if (checker_size > 0.01) {
		float ck = mod(floor(wpos.x / checker_size) + floor(wpos.z / checker_size), 2.0);
		col *= 1.0 + (ck - 0.5) * 2.0 * checker_mix * step(0.5, wn.y);
	}
	if (facet_jitter > 0.0) {
		vec3 q = floor(wn * 3.0 + 0.5);
		col *= 1.0 + (hash31(q + 3.7) - 0.5) * facet_jitter;
	}
	col *= 1.0 + (top_gain - 1.0) * upness;
	if (abs(gradient_height) > 0.001) {
		float g = clamp((objy - gradient_top_y) / gradient_height, 0.0, 1.0);
		col = mix(col, col * vec3(0.92, 0.78, 0.74), g);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color * fres * rim_strength * (0.4 + 0.6 * upness);
}

void light() {
	float wrap = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(band_center - band_soft, band_center + band_soft, wrap) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * sun_gain / PI;
	// tint the shadowed part toward a warm/cool shade (applied as a multiplicative darkening of the albedo term)
	float shade = 1.0 - lit;
	DIFFUSE_LIGHT *= mix(vec3(1.0), shade_tint, shade * shade_amount);
	if (spec_strength > 0.001) {
		vec3 hv = normalize(LIGHT + VIEW);
		float ndh = max(dot(NORMAL, hv), 0.0);
		float sp = smoothstep(0.30, 0.62, pow(ndh, mix(90.0, 14.0, spec_size)));
		SPECULAR_LIGHT += LIGHT_COLOR * spec_color * sp * spec_strength * ATTENUATION / PI;
	}
}
