shader_type canvas_item;

// 화면 곡률 + 스캔라인 + 비네트. 이 게임의 아트는 전부 코드다 (CLAUDE.md 1.1).
// `tension`은 항상 켜져 있되 상황에 따라 변한다 (CLAUDE.md 5절).

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float curvature : hint_range(2.0, 24.0) = 14.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.22;
uniform float scanline_count : hint_range(120.0, 1200.0) = 620.0;
uniform float vignette : hint_range(0.0, 2.0) = 0.75;
uniform float tension : hint_range(0.0, 1.0) = 0.0;

vec2 curve_uv(vec2 uv, float amount) {
	uv = uv * 2.0 - 1.0;
	vec2 offset = abs(uv.yx) / amount;
	uv += uv * offset * offset;
	return uv * 0.5 + 0.5;
}

void fragment() {
	// 긴장이 오르면 관이 더 휘고 주사선이 굵어진다.
	float bend = mix(curvature, curvature * 0.72, tension);
	vec2 uv = curve_uv(SCREEN_UV, bend);

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 col = texture(screen_texture, uv).rgb;

		float line = sin(uv.y * scanline_count * 3.14159265) * 0.5 + 0.5;
		col *= 1.0 - scanline_strength * line * (0.65 + tension * 0.5);

		float d = distance(uv, vec2(0.5));
		col *= 1.0 - vignette * d * d * (1.0 + tension * 0.35);

		COLOR = vec4(col, 1.0);
	}
}
