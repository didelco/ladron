shader_type spatial;
// The marble floor, drawn per pixel instead of painted into an image: sharp at
// any museum size, and nothing to build in GDScript pixel by pixel.
//
// Slabs two tiles across, each with its own tone and its own run of veins; a
// cut joint round every slab; and a soft shadow where the floor meets a wall
// or a case, read from a one-texel-per-tile map of the plan with linear
// filtering — the blur of that map *is* the contact shadow.

render_mode diffuse_toon, specular_disabled;

// r: how solid the tile is (1 wall, 0.6 case, 0 floor); g: 1 outside the building
uniform sampler2D plan : filter_linear, repeat_disable;
uniform sampler2D veins : filter_linear_mipmap, repeat_enable;
uniform vec2 size = vec2(23.0, 17.0);
uniform vec3 stone = vec3(0.118, 0.110, 0.145);
uniform vec3 joint = vec3(0.278, 0.263, 0.341);
uniform vec3 night = vec3(0.059, 0.051, 0.078);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 g = UV * size;                 // grid coordinates, in tiles
	vec2 slab = floor(g / 2.0);
	vec2 in_slab = fract(g / 2.0);

	// Each slab a shade of its own, lighter and darker ones alternating.
	float checker = mod(slab.x + slab.y, 2.0);
	vec3 base = stone * (0.92 + checker * 0.1 + (hash(slab) - 0.5) * 0.08);

	// Veins: thin bright ridges of a noise field, turned and shifted per slab
	// so neighbouring slabs do not line up.
	float turn = hash(slab + 7.0) * 6.2831;
	mat2 rot = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn)));
	vec2 vuv = rot * (g * 0.35) + hash(slab + 3.0) * 10.0;
	float n = texture(veins, vuv).r;
	float vein = 1.0 - smoothstep(0.0, 0.035, abs(n - 0.5));
	base = mix(base, base * 1.55 + vec3(0.02), vein * 0.35);

	// The joint: a darker cut, with a pale lip on one side.
	float edge = min(min(in_slab.x, 1.0 - in_slab.x), min(in_slab.y, 1.0 - in_slab.y)) * 2.0;
	base = mix(joint * 0.55, base, smoothstep(0.012, 0.03, edge));
	base += vec3(0.02) * (1.0 - smoothstep(0.03, 0.05, min(in_slab.x, in_slab.y) * 2.0));

	// Contact shadow: the plan map, blurred by filtering and a few taps.
	vec2 tuv = g / size;
	vec2 px = 1.0 / size;
	float solid = 0.0;
	solid += texture(plan, tuv).r * 0.4;
	solid += texture(plan, tuv + vec2(px.x, 0.0) * 0.35).r * 0.15;
	solid += texture(plan, tuv - vec2(px.x, 0.0) * 0.35).r * 0.15;
	solid += texture(plan, tuv + vec2(0.0, px.y) * 0.35).r * 0.15;
	solid += texture(plan, tuv - vec2(0.0, px.y) * 0.35).r * 0.15;
	base *= 1.0 - smoothstep(0.02, 0.45, solid) * 0.85;

	float outside = texture(plan, tuv).g;
	ALBEDO = mix(base, night, step(0.5, outside));
	ROUGHNESS = 0.6;
}
