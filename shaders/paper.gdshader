shader_type canvas_item;

// 수칙 한 줄이 적힌 종이. **거짓 수칙의 시각 단서가 여기서 나온다** (04-functional-spec F-05).
//
// `tools/solver_audit.gd`가 판정한 대로, 논리적 모순만으로는 "둘 중 하나가 거짓"까지만 알 수 있다.
// 어느 쪽인지는 이 셰이더가 말해준다. 장식이 아니라 하중 구조물이다.
//
// 너무 명확하면 퍼즐이 죽고, 너무 미묘하면 불공정해진다. 스크린샷으로 조정한다.

uniform float paper_tone : hint_range(0.85, 1.15) = 1.0;
uniform float ink_bleed : hint_range(0.0, 1.0) = 0.0;
uniform float fiber_strength : hint_range(0.0, 0.4) = 0.10;
uniform float fiber_seed = 0.0;

// 오늘 밤 고쳐 쓴 줄인가. **이것만은 미묘하면 안 된다.**
// 어제 맞던 수칙이 오늘 틀리는데 바뀐 표시가 안 보이면 그건 퍼즐이 아니라 속임수다
// (공정성 불변식 2). 나머지 단서와 반대 방향으로 — 더 어둡지 않고 더 밝게 — 간다.
// 오래 덧쓴 줄은 낡아서 어둡고, 오늘 덧댄 종이는 새것이라 밝다.
uniform float rewritten : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.7, 289.1))) * 24634.6345);
}

void fragment() {
	// COLOR에는 스타일박스가 칠한 색이 이미 들어 있다. 거기서부터 종이를 만든다.
	vec3 col = COLOR.rgb * paper_tone;

	// 종이 섬유. 줄마다 seed가 달라 같은 종이가 두 장 나오지 않는다.
	vec2 grid = floor(UV * vec2(320.0, 90.0));
	float fiber = hash(grid + vec2(fiber_seed, fiber_seed * 0.61));
	col -= (fiber - 0.5) * fiber_strength * 0.12;

	// 나중에 덧쓴 줄은 잉크가 번져 종이가 미세하게 얼룩진다.
	col -= ink_bleed * 0.05 * hash(grid * 0.37 + vec2(fiber_seed * 2.1, 0.0));

	// 덧댄 쪽지. 가장자리로 갈수록 얇아지고, 지우고 쓴 자리라 결이 거칠다.
	float band = smoothstep(0.5, 0.24, abs(UV.y - 0.5));
	float scratch = hash(vec2(floor(UV.x * 210.0), floor(UV.y * 5.0) + fiber_seed * 3.3));
	col += rewritten * band * (0.085 - scratch * 0.10);

	COLOR = vec4(col, COLOR.a);
}
