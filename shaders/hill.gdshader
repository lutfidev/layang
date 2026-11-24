shader_type canvas_item;
// Hill surface. UV.x = world x, UV.y = pixels below the surface (set by Terrain mesh).

uniform vec4 col_a : source_color = vec4(0.58, 0.83, 0.42, 1.0);
uniform vec4 col_b : source_color = vec4(0.45, 0.74, 0.33, 1.0);
uniform vec4 col_top : source_color = vec4(0.84, 0.96, 0.54, 1.0);
uniform vec4 col_deep : source_color = vec4(0.17, 0.42, 0.23, 1.0);
uniform int pattern = 0;          // 0 = diagonal stripes, 1 = terraces, 2 = moss dots
uniform float stripe_w = 60.0;
uniform float glow_rim = 0.0;     // night islands get a glowing rim

varying vec2 wpos;
uniform float light_x = 0.6;     // sun direction: <0 sun on the left, >0 on the right

varying float slope;  // surface slope, packed in vertex color red

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	slope = (COLOR.r - 0.5) / 0.4;
}

void fragment() {
	float d = UV.y;
	float s = 0.0;
	if (pattern == 0) {
		s = step(0.5, fract((wpos.x * 0.55 + wpos.y) / stripe_w));
	} else if (pattern == 1) {
		float band = (d + sin(wpos.x * 0.004) * 10.0) / stripe_w;
		s = step(0.5, fract(band));
		float edge = smoothstep(0.0, 0.06, fract(band)) * (1.0 - smoothstep(0.44, 0.5, fract(band)));
		s = mix(s, 1.0, (1.0 - edge) * 0.25);
	} else {
		vec2 cell = wpos / stripe_w;
		vec2 g = fract(cell + vec2(floor(cell.y) * 0.5, 0.0)) - 0.5;
		s = 1.0 - smoothstep(0.18, 0.24, length(g));
	}
	vec3 c = mix(col_a.rgb, col_b.rgb, s * 0.9);
	c = mix(c, col_deep.rgb, smoothstep(30.0, 760.0, d));
	// slope lighting: strongest near the surface, fading into the hill body
	vec2 n = normalize(vec2(slope, -1.0));
	float lit = dot(n, normalize(vec2(light_x, -1.0)));
	float sun = smoothstep(0.35, 1.0, lit);
	float near = 1.0 - smoothstep(40.0, 520.0, d);
	c *= mix(1.0, mix(0.72, 1.1, sun), near);
	// soft inner shadow under the rim gives the surface some thickness
	c *= 1.0 - 0.18 * smoothstep(14.0, 22.0, d) * (1.0 - smoothstep(22.0, 90.0, d));
	float rim = 1.0 - smoothstep(9.0, 15.0, d);
	c = mix(c, mix(col_top.rgb * 0.85, col_top.rgb * 1.08, sun), rim);
	float shade = smoothstep(15.0, 30.0, d) * (1.0 - smoothstep(30.0, 70.0, d));
	c *= 1.0 - shade * 0.12;
	c += col_top.rgb * glow_rim * (1.0 - smoothstep(0.0, 26.0, d)) * 0.35;
	COLOR = vec4(c, 1.0);
}
