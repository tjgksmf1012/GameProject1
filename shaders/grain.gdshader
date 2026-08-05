shader_type canvas_item;

// 필름 그레인 + 색수차. CRT 위에 한 겹 더 얹는다.
// `intensity`와 `chromatic`이 긴장도에 연동된다 (04-functional-spec F-09).

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float intensity : hint_range(0.0, 0.4) = 0.05;
uniform float chromatic : hint_range(0.0, 6.0) = 0.0;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 offset = vec2(chromatic / 1400.0, 0.0);

	vec3 col;
	col.r = texture(screen_texture, SCREEN_UV + offset).r;
	col.g = texture(screen_texture, SCREEN_UV).g;
	col.b = texture(screen_texture, SCREEN_UV - offset).b;

	// seed를 코드에서 매 프레임 흔들어야 그레인이 살아 움직인다.
	float n = hash(SCREEN_UV * vec2(1937.0, 1091.0) + vec2(seed, seed * 1.37));
	col += (n - 0.5) * intensity;

	COLOR = vec4(col, 1.0);
}
