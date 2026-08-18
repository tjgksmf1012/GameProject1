shader_type canvas_item;

// 화면 전체를 하나의 망가진 신호로 만든다.
// 8단계 휘도 팔레트와 베이어 디더가 모든 픽셀을 건드리고, 신호 결함은 긴장도에 따라 움직인다.
//
// 종이 단서는 평균 밝기가 3.8%밖에 다르지 않다. 균일한 양자화는 두 종이를 같은 칸에
// 넣으므로 밝은 두 단계를 0.79와 0.84에 둔다. 디더는 두 단계의 **면적 비율**로 원래 평균을
// 보존한다. `tools/paper_probe.gd`가 실제 프레임버퍼에서 이 약속을 검사한다.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float intensity : hint_range(0.0, 0.25) = 0.03;
uniform float chromatic : hint_range(0.0, 3.0) = 0.0;
uniform float ghost_strength : hint_range(0.0, 0.25) = 0.0;
uniform float jitter_pixels : hint_range(0.0, 2.0) = 0.0;
uniform float interlace_pixels : hint_range(0.0, 1.0) = 0.0;
uniform float tension : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;

uniform float dither_levels : hint_range(6.0, 8.0, 1.0) = 8.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 palette_dark = vec4(0.0, 0.07, 0.14, 0.24);
uniform vec4 palette_light = vec4(0.39, 0.59, 0.79, 0.84);

// 클립보드에서는 디더를 끄지 않는다. 그게 종이 두 종을 나누는 장치이기 때문이다.
// 대신 글자를 흐리는 지터·잔상·색 번짐·그레인만 줄인다.
uniform vec4 safe_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform float safe_signal : hint_range(0.0, 1.0) = 0.32;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}


float protect(vec2 uv, vec4 rect) {
	if (rect.z <= 0.0) {
		return 0.0;
	}
	vec2 margin = vec2(0.06);
	vec2 low = smoothstep(rect.xy - margin, rect.xy + margin, uv);
	vec2 high = 1.0 - smoothstep(
		rect.xy + rect.zw - margin, rect.xy + rect.zw + margin, uv);
	return low.x * low.y * high.x * high.y;
}


// 4x4 베이어. 텍스처를 쓰지 않아도 장치 픽셀에 고정된 규칙적인 점 밀도를 만든다.
float bayer4(vec2 pixel) {
	vec2 p = mod(floor(pixel), 4.0);
	if (p.y < 1.0) {
		if (p.x < 1.0) return 0.5 / 16.0;
		if (p.x < 2.0) return 8.5 / 16.0;
		if (p.x < 3.0) return 2.5 / 16.0;
		return 10.5 / 16.0;
	}
	if (p.y < 2.0) {
		if (p.x < 1.0) return 12.5 / 16.0;
		if (p.x < 2.0) return 4.5 / 16.0;
		if (p.x < 3.0) return 14.5 / 16.0;
		return 6.5 / 16.0;
	}
	if (p.y < 3.0) {
		if (p.x < 1.0) return 3.5 / 16.0;
		if (p.x < 2.0) return 11.5 / 16.0;
		if (p.x < 3.0) return 1.5 / 16.0;
		return 9.5 / 16.0;
	}
	if (p.x < 1.0) return 15.5 / 16.0;
	if (p.x < 2.0) return 7.5 / 16.0;
	if (p.x < 3.0) return 13.5 / 16.0;
	return 5.5 / 16.0;
}


float band(float value, float low, float high, float threshold) {
	float ratio = clamp((value - low) / max(0.0001, high - low), 0.0, 1.0);
	return mix(low, high, step(threshold, ratio));
}


float quantize_luma(float value, float threshold) {
	// dither_levels는 6~8에서 외부 조절 가능하다. 8보다 낮추면 위쪽 단계부터 합친다.
	float l6 = palette_light.y;
	float l7 = mix(palette_light.y, palette_light.z, step(6.5, dither_levels));
	float l8 = mix(l7, palette_light.w, step(7.5, dither_levels));
	if (value < palette_dark.y) return band(value, palette_dark.x, palette_dark.y, threshold);
	if (value < palette_dark.z) return band(value, palette_dark.y, palette_dark.z, threshold);
	if (value < palette_dark.w) return band(value, palette_dark.z, palette_dark.w, threshold);
	if (value < palette_light.x) return band(value, palette_dark.w, palette_light.x, threshold);
	if (value < l6) return band(value, palette_light.x, l6, threshold);
	if (value < l7) return band(value, l6, l7, threshold);
	return band(value, l7, l8, threshold);
}


void fragment() {
	float shield = protect(SCREEN_UV, safe_rect);
	float readable = mix(1.0, safe_signal, shield);
	float clock = floor(seed * 12.0);
	float gate = step(0.985 - tension * tension * 0.14, hash(vec2(clock, 31.7)));
	float shove = (hash(vec2(clock, 9.1)) * 2.0 - 1.0) * jitter_pixels * gate;
	float row_phase = mod(floor(FRAGCOORD.y), 2.0) * 2.0 - 1.0;
	float weave = row_phase * sin(seed * 17.0) * interlace_pixels;
	vec2 uv = SCREEN_UV + vec2((shove + weave) * SCREEN_PIXEL_SIZE.x * readable, 0.0);

	vec2 bleed = vec2(chromatic * SCREEN_PIXEL_SIZE.x * readable, 0.0);
	vec3 col;
	col.r = texture(screen_texture, uv + bleed).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - bleed).b;

	// 이전 프레임 버퍼를 따로 두지 않고, 시간에 따라 방향이 뒤집히는 짧은 인광 메아리를 만든다.
	float direction = mix(-1.0, 1.0, step(0.5, hash(vec2(clock, 2.4))));
	vec2 echo_offset = vec2(direction * (1.0 + tension * 2.0) * SCREEN_PIXEL_SIZE.x, 0.0);
	vec3 echo = texture(screen_texture, uv - echo_offset).rgb;
	col = mix(col, echo, ghost_strength * readable * (0.55 + gate * 0.45));

	float noise_frame = floor(seed * 60.0);
	float noise = hash(FRAGCOORD.xy + vec2(noise_frame, noise_frame * 1.37));
	col += (noise - 0.5) * intensity * readable;

	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	float quantized = quantize_luma(clamp(luma, 0.0, palette_light.w), bayer4(FRAGCOORD.xy));
	vec3 limited = clamp(col + vec3(quantized - luma), 0.0, palette_light.w);
	COLOR = vec4(mix(col, limited, dither_strength), 1.0);
}
