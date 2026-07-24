shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float zoom_amount : hint_range(0.0, 0.15) = 0.0;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.0;
uniform float bloom_strength : hint_range(0.0, 1.0) = 1;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	vec2 zoomed_uv = centered_uv / (1.0 + zoom_amount) + vec2(0.5);
	vec4 screen_color = texture(SCREEN_TEXTURE, zoomed_uv);

	// A lower mip level supplies a soft, blurred version of the screen.
	// Only its brighter areas are added back, creating a lightweight bloom.
	vec3 blurred_screen = textureLod(SCREEN_TEXTURE, zoomed_uv, 3.0).rgb;
	vec3 highlights = max(blurred_screen - vec3(0.45), vec3(0.0));
	float bloom_pulse = pulse_strength * bloom_strength;
	screen_color.rgb += (highlights * 0.7 + blurred_screen * 0.06) * bloom_pulse;

	COLOR = screen_color;
}
