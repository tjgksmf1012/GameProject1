shader_type canvas_item;

// 방. 패널 **뒤**에 깔리는 빛이다.
//
// 배경이 단색 `#0d0f10`이던 때, 화면은 어두운 게 아니라 **비어 있어 보였다.**
// 빈 자리가 "아직 안 만든 곳"으로 읽혔다. 광원이 하나 있으면 같은 빈 자리가 깊이가 된다.
//
// 색은 역할이 아니라 **광원**으로 나눈다. 그게 밤 장면이 밤으로 읽히는 이유다:
//   천장 형광등  — 초록 섞인 청록. 싸구려 관은 546nm에서 튄다
//   창밖 가로등  — 나트륨 주황. 한쪽 가장자리에만
//   카운터 상판  — 아래쪽에서 값이 한 번 꺾인다
//
// **여기에 클립보드를 밝히는 빛은 넣지 않는다.** 종이는 불투명해서 이 셰이더가 닿지 않고,
// 닿게 만들면 그 순간 매끄러운 휘도 기울기가 단서 위에 얹힌다 — `crt.gdshader` 주석 참고.
// 종이가 따뜻해 보이는 것은 **주변을 차갑게 해서** 얻는다(동시대비). 종이는 안 건드린다.

uniform vec3 ceiling : source_color = vec3(0.101, 0.133, 0.141);
uniform vec3 floor_tone : source_color = vec3(0.031, 0.039, 0.043);
// 창밖 나트륨등. 글자 위에 얹히지 않도록 가장자리에만, 약하게.
uniform vec3 sodium : source_color = vec3(0.784, 0.459, 0.165);
uniform float sodium_strength : hint_range(0.0, 0.4) = 0.13;
// 카운터 상판이 뒷벽과 만나는 높이.
uniform float counter_line : hint_range(0.4, 0.95) = 0.68;
uniform float counter_lift : hint_range(0.0, 0.2) = 0.035;
uniform float tension : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// 천장에서 바닥으로. 형광등은 위에 달려 있다.
	float drop = smoothstep(0.0, 1.0, UV.y);
	vec3 col = mix(ceiling, floor_tone, drop);

	// 카운터 상판. 값이 한 번 꺾이면 바닥과 벽이 갈라져 보인다.
	col += counter_lift * smoothstep(counter_line - 0.02, counter_line + 0.02, UV.y);

	// 창밖 가로등은 오른쪽 가장자리에서만 스며든다. 손님이 서 있는 쪽이다.
	float edge = smoothstep(0.72, 1.0, UV.x) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	col = mix(col, sodium, edge * sodium_strength);

	// 긴장이 오르면 실내가 더 초록으로 간다. 형광등이 죽어갈 때의 색이고,
	// 아무도 이걸 멋있다고 읽지 않는다 — 그게 목적이다.
	col *= mix(vec3(1.0), vec3(0.90, 1.03, 0.99), tension);

	COLOR = vec4(col, 1.0);
}
