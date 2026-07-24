shader_type canvas_item;

// Slow, glossy pools of magical ink. Designed to stay dark enough for menu text.
uniform float motion_speed : hint_range(0.0, 2.0) = 0.20;
uniform float distortion : hint_range(0.0, 1.5) = 0.72;
uniform vec4 ink_black : source_color = vec4(0.1, 0.08, 0.018, 1.0);
uniform vec4 shadow_violet : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 liquid_violet : source_color = vec4(0.24, 0.15, 0.34, 1.0);
uniform vec4 lavender_sheen : source_color = vec4(0.52, 0.36, 0.68, 1.0);
uniform vec4 vaporwave_tint : source_color = vec4(0.42, 0.10, 0.52, 1.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amplitude * noise(p);
		p = p * 2.03 + vec2(17.2, 9.1);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float t = TIME * motion_speed;

	// Nested domain warps make the contours stretch and fold like a thick liquid.
	vec2 flow = vec2(
		fbm(p * 1.15 + vec2(t * 0.24, -t * 0.16)),
		fbm(p * 1.15 + vec2(8.3 - t * 0.18, 2.7 + t * 0.20))
	);
	vec2 warped_p = p + (flow - 0.5) * distortion;
	float large_flow = fbm(warped_p * 2.15 + vec2(-t * 0.16, t * 0.10));
	float detail_flow = fbm(warped_p * 5.4 - flow * 1.6);
	float liquid = large_flow * 0.72 + detail_flow * 0.28;

	// Broad violet bodies broken up by pooled, almost-black cavities.
	float body = smoothstep(0.36, 0.67, liquid);
	float voids = smoothstep(0.55, 0.78, fbm(warped_p * 3.05 + flow * 2.0));
	float pinched_voids = smoothstep(0.67, 0.82, fbm(warped_p * 7.0 - vec2(t * 0.08)));
	voids = max(voids * 0.92, pinched_voids * 0.68) * body;

	vec3 color = mix(ink_black.rgb, shadow_violet.rgb, body * 0.72);
	color = mix(color, liquid_violet.rgb, body * 0.78);
	color = mix(color, ink_black.rgb, voids);

	// Thin contour lights sell the glossy, rippling surface in the reference.
	float contour = 1.0 - smoothstep(0.014, 0.052, abs(liquid - 0.57));
	float void_edge = 1.0 - smoothstep(0.018, 0.065, abs(fbm(warped_p * 3.05 + flow * 2.0) - 0.56));
	float sheen_noise = smoothstep(0.48, 0.72, fbm(warped_p * 9.0 + vec2(t * 0.3)));
	vec3 sheen = mix(lavender_sheen.rgb, vaporwave_tint.rgb, detail_flow);
	color += sheen * contour * body * (0.18 + sheen_noise * 0.16);
	color += lavender_sheen.rgb * void_edge * body * 0.09;

	// Nearly black edges keep the liquid mass framed and the centre subdued.
	float vignette = smoothstep(0.28, 0.90, length(p * vec2(0.98, 0.85)));
	color = mix(color, ink_black.rgb, vignette * 0.78);
	COLOR = vec4(color, 1.0);
}
