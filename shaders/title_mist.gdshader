shader_type canvas_item;

// Gentle screen-space fog motion for the menu title.
uniform float wave_strength : hint_range(0.0, 0.03) = 0.006;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.72;
uniform vec4 mist_color : source_color = vec4(0.62, 0.38, 0.84, 1.0);

float mist_noise(vec2 p) {
	return sin(p.x * 7.1 + sin(p.y * 4.3)) * 0.5
		+ sin(p.y * 9.7 - p.x * 2.9) * 0.25
		+ sin((p.x + p.y) * 13.0) * 0.25;
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 screen_uv = SCREEN_UV;
	float broad_wave = mist_noise(screen_uv * 4.2 + vec2(t * 0.22, -t * 0.10));
	float fine_wave = mist_noise(screen_uv * 10.0 + vec2(-t * 0.36, t * 0.18));
	vec2 offset = vec2(broad_wave, fine_wave) * wave_strength;

	// Sample the letterform from a gently displaced coordinate.
	vec4 glyph = texture(TEXTURE, UV + offset);

	// Nearby alpha creates a restrained, drifting fog fringe on the glyph edges.
	float mist_alpha = texture(TEXTURE, UV + offset * 3.5 + vec2(0.0, wave_strength * 2.0)).a;
	float fog = max(mist_alpha - glyph.a * 0.72, 0.0) * (0.36 + fine_wave * 0.18);
	vec3 mist = mix(glyph.rgb, mist_color.rgb, 0.28);
	COLOR = vec4(mix(glyph.rgb, mist, fog), glyph.a + fog * 0.22);
}
