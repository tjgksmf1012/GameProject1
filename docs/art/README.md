# docs/art — 스토어 에셋 작업 폴더

**여기 있는 것은 게임에 들어가지 않는다.** `res://` 아래가 아니라 `docs/` 아래인 이유다.

| 파일 | 용도 |
|---|---|
| `GPT-BRIEF.md` | 이미지 모델에 먼저 주는 게임 설명. 톤·색·금기 |
| `PROMPTS.md` | 에셋별 프롬프트와 Steam 규격, 받은 뒤 확인할 것 |
| `reference/` | **게임에서 직접 뽑은 스크린샷.** 브리프와 같이 준다 |

## 왜 게임 안에는 안 넣는가

`CLAUDE.md` 1.1 — 화면에 보이는 모든 것은 코드로 만든다. 스프라이트도 텍스처도 없다.
`CLAUDE.md` 7 — 코드 생성은 Steam AI 공시 면제이고, 셰이더·벡터·절차적 비주얼은
디퓨전 이미지가 아니라 「AI 아트」 백래시 대상이 아니다.

**생성 이미지를 게임에 넣으면 둘 다 깨진다.** 스토어 캡슐은 게임 밖이라 1.1의 적용
대상이 아니지만, 공시 쪽은 여전히 걸린다 — 제출 전에 확인하고 근거를 남길 것.

## 스크린샷 다시 뽑기

```bash
xvfb-run -a godot --script res://tools/screenshot.gd -- \
  --scene=res://main/title_screen.tscn --out=docs/art/reference/01-title.png --frames=120
xvfb-run -a godot --script res://tools/shoot_states.gd -- \
  --out=docs/art/reference/03-counter-clean.png --verdict=none --night=4 --index=1 --step=40
```
`--verdict=none` 이 없으면 판정 뒤 화면만 찍힌다.
