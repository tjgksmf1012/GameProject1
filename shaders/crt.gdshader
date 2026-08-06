shader_type canvas_item;

// 화면 곡률 + 주사선 + 비네트. 이 게임의 아트는 전부 코드다 (CLAUDE.md 1.1).
// `tension`은 항상 켜져 있되 강도가 상황에 따라 변한다 (CLAUDE.md 5절).
//
// **이 셰이더는 퍼즐 위에 올라간다.** 클립보드의 종이 두 종은 밝기가 3.8% 다르고
// 그게 이 게임의 핵심 단서다(F-05). 그런데 분위기를 내는 효과 대부분은 **같은 양** —
// 휘도 — 을 곱한다. 그래서 여기서 무엇을 하든 단서와 직접 경쟁한다.
//
// 실제로 그랬다. 비네트가 `distance(uv, vec2(0.5))`로 돌던 때, UV가 종횡비 보정이 안 돼
// 16:9를 정사각형으로 취급했고 세로로 1.78배 빠르게 떨어졌다. 클립보드는 왼쪽 가장자리에
// 붙은 세로 기둥이라 그 경사면 한복판에 얹혀 있었다. 측정: **같은 종이인데 위치만으로 8.6%**,
// 단서의 2.3배. 위아래가 바뀌면 단서가 상쇄될 수도 있었다.
//
// 원칙: **매끄러운 곱셈 효과는 단서와 경쟁하고, 고주파·제로평균 효과는 경쟁하지 않는다.**
// 넓은 영역의 평균을 바꾸는가로 갈린다. 비네트·조명 그라데이션·글로우 번짐은 앞쪽이고
// 주사선·그레인은 뒤쪽이다. 앞쪽은 `safe_rect` 안에서 끈다.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float curvature : hint_range(2.0, 24.0) = 14.0;
// 화면 세로에 몇 줄을 넣을 것인가. 실제 피치는 장치 픽셀 정수로 반올림된다.
uniform float scan_lines : hint_range(120.0, 400.0) = 240.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.30;
// 빔 굵기. 1.0은 sin 그대로(절반이 밝아진다), 크면 어두운 줄이 좁고 또렷해진다.
uniform float beam : hint_range(0.5, 4.0) = 1.8;
uniform float vignette : hint_range(0.0, 2.0) = 0.75;
// 이 반경 안쪽은 완전히 평평하다. 중앙부에 기울기가 없어야 단서가 안전하다.
uniform float vignette_inner : hint_range(0.0, 1.2) = 0.55;
uniform float tension : hint_range(0.0, 1.0) = 0.0;
// 보호 영역 (x, y, w, h), SCREEN_UV 기준. w가 0이면 보호하지 않는다.
uniform vec4 safe_rect = vec4(0.0, 0.0, 0.0, 0.0);
// 보호 영역 안에서 주사선을 얼마나 약하게 할 것인가.
//
// 주사선은 제로평균이라 **넓은 영역 평균**은 안 건드린다 — `tools/paper_probe.gd`가
// 그걸 확인한다. 그런데 사람이 종이 두 장을 비교하는 것은 평균 계산이 아니다.
// 또렷한 줄무늬가 얹히면 3.8% 차이를 눈으로 가려내기가 더 어려워진다.
// 계측은 통과하는데 사람은 못 보는 상태가 될 수 있고, 그건 검사가 못 잡는 종류의 실패다.
// 그래서 종이 위에서만 줄을 약하게 깐다. 화면 나머지는 온전한 CRT다.
uniform float safe_scanline : hint_range(0.0, 1.0) = 0.4;

vec2 curve_uv(vec2 uv, float amount) {
	uv = uv * 2.0 - 1.0;
	vec2 offset = abs(uv.yx) / amount;
	uv += uv * offset * offset;
	return uv * 0.5 + 0.5;
}

// 이 픽셀이 보호 영역 안인가. 0 = 바깥, 1 = 완전히 안쪽.
// 가장자리를 부드럽게 넘긴다 — 딱 끊으면 그 경계선 자체가 화면에 보인다.
// 그래서 `safe_rect`는 클립보드보다 조금 크게 넘겨야 한다. 전이 구간이 종이 위에 오면
// 그게 곧 기울기이고, 막으려던 문제가 그대로 돌아온다.
float protect(vec2 uv, vec4 r) {
	if (r.z <= 0.0) {
		return 0.0;
	}
	vec2 m = vec2(0.06);
	vec2 lo = smoothstep(r.xy - m, r.xy + m, uv);
	vec2 hi = 1.0 - smoothstep(r.xy + r.zw - m, r.xy + r.zw + m, uv);
	return lo.x * lo.y * hi.x * hi.y;
}

void fragment() {
	// 긴장이 오르면 관이 더 휜다.
	float bend = mix(curvature, curvature * 0.72, tension);
	vec2 uv = curve_uv(SCREEN_UV, bend);

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 col = texture(screen_texture, uv).rgb;
		float shield = protect(SCREEN_UV, safe_rect);

		// 주사선은 **장치 픽셀 정수 피치**로 고정한다.
		// UV 기준으로 잡으면 창 크기마다 굵기가 달라지고, 720p에서 주기가 2.32px —
		// Nyquist(2.0px) 바로 위라 무늬로 해상되지 않고 픽셀 격자와 맥놀이만 남는다.
		// 측정: 같은 자리 픽셀 행 사이 17.2% 변동. 무늬가 아니라 잡음이었다.
		// 위상은 **왜곡 전** 좌표에서 뽑는다 — 곡률이 피치를 흔들어 맥놀이를 되살리지 않게.
		float pitch = max(2.0, round((1.0 / SCREEN_PIXEL_SIZE.y) / scan_lines));
		float line = pow(abs(sin(fract(FRAGCOORD.y / pitch) * PI)), beam);
		float strength = scanline_strength * (0.8 + tension * 0.4)
			* mix(1.0, safe_scanline, shield);
		col *= 1.0 - strength * (1.0 - line);
		// 깎아낸 평균을 되돌린다. 안 되돌리면 화면 전체가 어두워지는데,
		// 어두운 화면에서는 3.8% 차이가 공짜로 더 안 보이게 된다.
		col *= 1.0 + strength * 0.42;

		// 비네트: 종횡비를 보정하고, 중앙은 평평하게, 클립보드는 비켜간다.
		vec2 p = (uv - 0.5) * vec2(1.0, SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y);
		float d = length(p) / 0.5;
		float falloff = smoothstep(vignette_inner, 1.20, d);
		col *= 1.0 - vignette * falloff * falloff * (1.0 - shield) * (1.0 + tension * 0.35);

		COLOR = vec4(col, 1.0);
	}
}
