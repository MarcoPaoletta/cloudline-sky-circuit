shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Arena portal energy: a bright spiral vortex inside the stone arch (procedural, no external asset). `tint` follows each portal's
// ring colour, `energy` pulses when the portal warms up and releases monsters.

uniform float radius = 0.43;          // vortex radius in UV units (the quad is 4.4 m wide, the opening 1.9 m radius)
uniform float arms = 4.0;
uniform float twist = 9.0;
uniform float speed = 0.55;
uniform float edge_glow = 0.55;
instance uniform vec3 tint : source_color = vec3(0.30, 0.80, 1.0);
instance uniform float energy = 1.0;

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) / radius;
	float ang = atan(p.y, p.x);
	float t = TIME * speed;
	// spiral arms winding inward, crisp bands so the rotation reads
	float s1 = 0.5 + 0.5 * sin(ang * arms + r * twist - t * 5.0);
	float band = smoothstep(0.30, 0.70, s1);
	float s2 = 0.5 + 0.5 * sin(ang * arms * 2.0 - r * twist * 1.4 - t * 8.0 + 1.7);
	float fine = smoothstep(0.55, 0.9, s2);
	float body = smoothstep(1.02, 0.88, r);
	float rim = smoothstep(0.62, 1.0, r) * body;
	vec3 dark = tint * 0.16;
	vec3 mid = tint * 0.95;
	vec3 bright = mix(tint, vec3(1.0), 0.8);
	vec3 col = mix(dark, mid, band);
	col = mix(col, bright, fine * 0.35 * (1.0 - r * 0.5));
	col = mix(col, bright, smoothstep(0.42, 0.0, r) * 0.95);
	col += bright * rim * band * 0.3 + tint * rim * edge_glow;
	float halo = smoothstep(1.55, 1.0, r) * (1.0 - body) * 0.35;
	ALBEDO = col * (0.8 + 0.35 * energy);
	ALPHA = clamp(body * 0.97 + halo, 0.0, 1.0);
}
