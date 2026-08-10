# 이미지 프롬프트 — Steam 스토어 에셋

> 쓰는 법: `GPT-BRIEF.md` 전문 + `reference/` PNG 4장을 먼저 주고,
> 그 다음 아래 프롬프트를 하나씩 준다. **브리프 없이 프롬프트만 주면 톤이 안 맞는다.**
>
> 규격은 Steamworks 문서 기준이며 **업로드 직전에 반드시 재확인할 것** — 밸브가 바꾼다.

---

## 우선순위

| 순위 | 에셋 | 규격 | 왜 필요한가 |
|---|---|---|---|
| 1 | **메인 캡슐** | 1232 × 706 | 스토어 첫인상. 이거 하나가 위시리스트를 만든다 |
| 2 | **헤더 캡슐** | 460 × 215 | 검색·추천에 뜨는 작은 카드 |
| 3 | 소형 캡슐 | 231 × 87 | 목록. 글자가 읽혀야 한다 |
| 4 | 라이브러리 세로 | 600 × 900 | 구매자 라이브러리 |
| 5 | 페이지 배경 | 1438 × 810 | 스토어 페이지 뒷배경. 어두워야 한다 |

> 스크린샷은 **GPT로 만들지 않는다.** 게임에서 직접 뽑는다:
> `xvfb-run -a godot --script res://tools/shoot_states.gd -- --out=... --verdict=none --night=N --index=K`

---

## 1. 메인 캡슐 (1232 × 706)

```
A still, quiet horror key art for a Korean late-night convenience store game.

Composition: viewed from BEHIND the checkout counter, first person, hands not
visible. In the foreground lower-left, a clipboard rests on the counter — cream
paper (#d8d2c4), the only warm object in the frame, with several handwritten
lines of text. One line is written in visibly different, cooler ink and on a
slightly different slip of paper taped over the original. Middle ground: a
featureless matte-black human silhouette stands on the customer side, backlit by
the store's fluorescent glow. It has no face. Background: shelves receding into
green-tinted fluorescent darkness, and a rain-streaked glass door where a single
sodium streetlamp glows amber outside.

Critical detail: the silhouette casts NO shadow on the floor, while the shelves
and counter do. This must be subtle but findable.

Palette: near-black cool teal (#0d0f10), panel grey (#16191b), warm cream paper
(#d8d2c4), one amber accent (#e8a33d) from the streetlamp only. Desaturated.
Cold light, warm paper — that contrast is the whole image.

Treatment: analog horror. Heavy film grain, faint CRT scanlines, slight chromatic
aberration at the edges, vignette. Looks like a photograph of a security monitor.

Mood: silent, 4 AM, something is wrong but nothing is moving.

NO: blood, gore, monsters, jump-scare imagery, glowing eyes, neon, cyberpunk,
text overlays, logos, readable words, UI elements, visible faces.
Leave the upper-right third relatively empty for the title to be placed later.
```

**체크**: 실루엣에 그림자가 없는가 · 종이가 유일하게 따뜻한가 · 글자가 안 읽히는가
(읽히면 현지화가 깨진다 — 제목은 나중에 따로 얹는다)

---

## 2. 헤더 캡슐 (460 × 215)

작아서 **한 가지만** 보여야 한다. 클립보드를 주인공으로.

```
Extreme close-up, horizontal composition. A clipboard on a dark counter under
cold fluorescent light. Cream paper (#d8d2c4) fills the left two-thirds,
handwritten rule lines running across it. One line is on a slightly whiter slip
of paper taped over the original, written in cooler, bluer ink — clearly added
by a different hand. In the dark right third, out of focus, a featureless black
human silhouette waits.

Palette: near-black cool teal, warm cream paper, one small amber highlight.
Analog horror treatment: film grain, faint scanlines, vignette.
Shallow depth of field — the paper is sharp, everything else is not.

NO readable text, no logos, no faces, no blood. Keep the right third dark and
simple so a logo can sit there.
```

---

## 3. 소형 캡슐 (231 × 87)

```
Tiny horizontal banner, extremely simple and high-contrast. A single sheet of
cream paper (#d8d2c4) at a slight angle on near-black (#0d0f10), with a few
handwritten ink lines suggested but not readable. One line is struck through
with a single pen stroke. Faint film grain and a soft vignette.
Minimal. Must read clearly at 231x87 pixels. No text, no logo, no figures.
```

**체크**: 231×87로 줄여서 봤을 때 **종이인 줄 알아볼 수 있는가.** 아니면 다시.

---

## 4. 라이브러리 세로 (600 × 900)

```
Vertical poster composition. Bottom half: a clipboard held at chest height, seen
from the holder's point of view, cream paper (#d8d2c4) with handwritten lines,
one line struck through with pen. Top half: darkness, a fluorescent ceiling
fixture casting green-white light downward, and far back a featureless black
human silhouette standing motionless in a convenience store aisle.

The composition should feel like the paper is holding back the dark.

Palette: near-black cool teal, panel grey, warm cream paper, one amber accent.
Analog horror: heavy grain, scanlines, chromatic aberration, vignette.
NO readable text, no faces, no blood, no monsters.
Leave the top quarter clear for a title.
```

---

## 5. 페이지 배경 (1438 × 810)

```
Very dark, low-contrast atmospheric background. An empty Korean convenience
store interior at 4 AM seen from the checkout counter: shelves receding into
green-tinted fluorescent darkness, a rain-streaked glass door, a single amber
sodium lamp outside. NO people, NO paper, NO focal point — this sits behind
other content and must never compete with it.

Palette: near-black cool teal (#0d0f10) dominant, faint green fluorescent, one
distant amber. Extremely desaturated. Heavy grain and vignette.
Darken the center so text placed over it stays readable.
```

---

## 받은 뒤 할 일

1. **글자가 들어갔으면 지운다.** 이 게임은 한/영(+중국어 예정)이고 캡슐에 글자가
   박히면 로케일마다 다시 만들어야 한다. 제목은 게임 폰트로 따로 얹는다.
2. **소형 캡슐은 실제 크기로 줄여서 본다.** 큰 화면에서 좋아 보이는 것이 231px에서
   죽는 경우가 대부분이다.
3. **Steam AI 공시.** 생성 이미지를 쓰면 Steamworks 제출 시 공시 대상이다.
   지금 이 게임은 코드 생성만이라 면제인데, 캡슐을 넣는 순간 그 상태가 바뀐다.
   **넣기 전에 Steamworks 최신 문서를 확인하고 `docs/licenses/`에 판단 근거를 남길 것.**
4. **게임 안으로 들여오지 않는다.** `CLAUDE.md` 1.1. 이 파일들은 스토어 전용이고
   `res://` 아래로 들어가면 안 된다.
