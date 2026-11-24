shader_type canvas_item;
// Sea between islands. UV.y = pixels below the water line.

uniform vec4 water : source_color = vec4(0.12, 0.7, 0.78, 1.0);
uniform vec4 foam : source_color = vec4(0.8, 1.0, 1.0, 1.0);

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float d = UV.y - 12.0; // mesh starts 12px above the water line so waves can rise
	float wave = sin(wpos.x * 0.03 + TIME * 2.0) * 3.0 + sin(wpos.x * 0.011 - TIME * 1.3) * 4.0;
	if (d < wave) {
		discard;
	}
	float dd = d - wave;
	vec3 c = mix(water.rgb, water.rgb * 0.45, smoothstep(0.0, 380.0, dd));
	float line = 1.0 - smoothstep(3.0, 7.0, dd);
	c = mix(c, foam.rgb, line);
	float glints = step(0.92, sin(wpos.x * 0.07 + sin(wpos.y * 0.05 + TIME) * 2.0)) * (1.0 - smoothstep(10.0, 80.0, dd));
	c += foam.rgb * glints * 0.35;
	COLOR = vec4(c, 0.92);
}
