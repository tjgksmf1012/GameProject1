shader_type canvas_item;

// CCTV 채널 하나. 저해상도 흑백 감시 카메라.
// 채널마다 파라미터가 달라야 네 화면이 같은 화면처럼 보이지 않는다 (F-04).

uniform float noise_amount : hint_range(0.0, 0.5) = 0.14;
uniform float scanline_count : hint_range(40.0, 400.0) = 150.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.30;
uniform float roll_speed : hint_range(0.0, 2.0) = 0.15;
uniform float channel_seed = 0.0;
uniform float time_seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(23.1, 91.7))) * 41773.13);
}

void fragment() {
	vec3 col = COLOR.rgb;

	// 흑백. 감시 카메라는 색을 안 본다.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = vec3(luma);

	// 굵은 주사선
	float line = sin(UV.y * scanline_count * 3.14159265) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * line;

	// 천천히 흘러내리는 롤링 바
	float roll = fract(UV.y - time_seed * roll_speed - channel_seed);
	col += smoothstep(0.97, 1.0, roll) * 0.10;

	// 잡음. 채널마다 seed가 달라 서로 다른 화면으로 읽힌다.
	float n = hash(floor(UV * vec2(160.0, 120.0)) + vec2(time_seed * 37.0, channel_seed));
	col += (n - 0.5) * noise_amount;

	COLOR = vec4(col, COLOR.a);
}
