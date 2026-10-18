shader_type spatial;
render_mode cull_back, specular_disabled;
// Horde monsters in the bright toon world: the pack's own texture, lifted in brightness and saturation, lit with the same soft
// two-step sun as the islands, plus a rim glow. The skinned meshes keep their original UVs and animation untouched.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float brightness = 2.1;
uniform float saturation = 1.5;
uniform float lift = 0.7;           // gamma lift (< 1 brightens the dark pack textures)
uniform vec3 tint : source_color = vec3(1.0);
uniform float rim_strength = 0.3;
uniform vec3 rim_color : source_color = vec3(1.0, 0.96, 0.85);
uniform vec3 shade_tint : source_color = vec3(0.80, 0.78, 0.92);

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = pow(max(c, vec3(0.0)), vec3(lift)) * brightness * tint;
	ALBEDO = clamp(c, 0.0, 1.0);
	ROUGHNESS = 0.9;
	SPECULAR = 0.0;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color * fres * rim_strength;
}

void light() {
	float wrap = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.26, 0.66, wrap) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * 0.95 / PI;
	DIFFUSE_LIGHT *= mix(vec3(1.0), shade_tint, (1.0 - lit) * 0.5);
}
