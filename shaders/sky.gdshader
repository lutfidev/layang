shader_type canvas_item;
// Full-screen sky: 3-stop gradient, sun/moon with halo, twinkling stars, dusk grading.

uniform vec4 top_color : source_color;
uniform vec4 mid_color : source_color;
uniform vec4 horizon_color : source_color;
uniform vec4 sun_color : source_color;
uniform vec2 sun_pos = vec2(0.7, 0.3);
uniform float sun_size = 0.08;
uniform float stars = 0.0;
uniform float dusk = 0.0;
uniform float aspect = 1.777;
uniform float scroll = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float y = uv.y;
	vec3 c = mix(top_color.rgb, mid_color.rgb, smoothstep(0.0, 0.62, y));
	c = mix(c, horizon_color.rgb, smoothstep(0.5, 0.95, y));

	// Dusk: everything slides toward violet with a burning horizon.
	vec3 dusk_top = vec3(0.10, 0.07, 0.24);
	vec3 dusk_hor = vec3(0.98, 0.45, 0.32);
	vec3 dc = mix(dusk_top, dusk_hor, smoothstep(0.35, 1.0, y));
	c = mix(c, dc, dusk * 0.75);
	c *= 1.0 - dusk * 0.25;

	// Stars
	float star_amt = clamp(stars + dusk * 0.8, 0.0, 1.0);
	if (star_amt > 0.0) {
		vec2 sp = vec2(uv.x * aspect + scroll, uv.y) * 90.0;
		vec2 cell = floor(sp);
		float h = hash(cell);
		vec2 f = fract(sp) - vec2(hash(cell + 3.1), hash(cell + 7.7));
		float tw = 0.5 + 0.5 * sin(TIME * (1.5 + h * 3.0) + h * 40.0);
		float st = step(0.965, h) * (1.0 - smoothstep(0.0, 0.08, length(f))) * tw;
		c += vec3(st) * star_amt * (1.0 - smoothstep(0.35, 0.8, y));
	}

	// Sun / moon
	vec2 d = (uv - sun_pos) * vec2(aspect, 1.0);
	float dist = length(d);
	float disk = 1.0 - smoothstep(sun_size - 0.004, sun_size, dist);
	float halo = exp(-dist * 7.0) * 0.55 + exp(-dist * 2.2) * 0.18;
	vec3 sc = mix(sun_color.rgb, vec3(1.0, 0.55, 0.35), dusk * 0.8);
	c += sc * halo;
	c = mix(c, sc, disk);

	COLOR = vec4(c, 1.0);
}
