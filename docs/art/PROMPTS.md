# 이미지 프롬프트 — Steam 스토어 에셋

> 쓰는 법: `GPT-BRIEF.md` 전문 + `reference/` PNG 5장을 먼저 주고,
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

---

# 2차 — 1차 결과를 보고 고친 것

1차에서 배운 것 셋:
- **그림자는 비교 대상이 있어야 읽힌다.** 실루엣에만 그림자를 없애면 「그림자가 없다」가
  아니라 「어두워서 안 보인다」가 된다. 선반과 계산대의 그림자를 **먼저 뚜렷하게** 만들어야
  그 옆의 빈 바닥이 이상해진다.
- **굵은 검은 막대는 먹칠로 읽힌다.** 이 게임은 정보를 가리지 않는다 — 다 보이는데 일부가
  거짓말을 한다. 손글씨는 **가늘고 흘려 쓴 선**이어야 한다.
- **다 따뜻하면 종이가 안 특별하다.** 차가운 빛과 따뜻한 종이의 대비가 이미지의 전부다.

## 1-2차. 메인 캡슐 (1232 × 706) — 그림자와 밝기

```
Same scene as before: a Korean convenience store at 4 AM seen from behind the
checkout counter. Clipboard with cream paper in the lower-left foreground, a
taped-on slip of slightly different paper among the handwritten lines. A
featureless matte-black human silhouette stands in the aisle. Rain-streaked
glass door with one amber sodium streetlamp outside.

CHANGE 1 — shadows must be legible. The overhead fluorescent panel casts CLEAR,
visible shadows: the shelving units throw hard dark shadows across the floor,
the counter throws a shadow, the floor tiles show the light pattern. But the
standing human figure casts NO shadow at all — the floor beneath and behind it
is unbroken. Everything else anchors to the floor; the figure does not. Make the
surrounding shadows strong enough that the missing one is noticeable on a second
look.

CHANGE 2 — lift the midtones. The image is currently too dark to read as a
thumbnail. Keep it night-time and desaturated, but raise the fluorescent light
on the shelves and floor so the space is legible at small size. The paper should
still be the brightest thing in frame.

Palette: cool teal-black, green-white fluorescent, one amber streetlamp, warm
cream paper. Analog horror: film grain, faint scanlines, vignette.
NO readable text, no logos, no faces, no blood. Keep the upper-right third dark
and simple for a title.
```

## 2-2차. 헤더 캡슐 (460 × 215) — 대비와 실루엣

```
Extreme close-up of a clipboard on a dark counter under COLD green-white
fluorescent light. Cream paper (#d8d2c4) fills the left two-thirds — it is the
only warm-toned object in the frame and it should look noticeably warmer than
everything around it. Fine, thin, cursive handwritten lines run across it,
unreadable. One line sits on a separate slip of slightly whiter paper taped over
the original, written in cooler bluish-black ink by a different hand.

The right third is dark, out of focus, and COLD — and a featureless black human
silhouette stands there, rim-lit just enough by the fluorescent light to be
clearly separable from the background. It must survive being scaled to 460x215.

Critical: cold light everywhere, warm paper only. Do not warm the overall image.
Shallow depth of field, paper sharp. Film grain, faint scanlines, vignette.
NO readable text, no logos, no faces. Keep the right third simple for a logo.
```

## 3-2차. 소형 캡슐 (231 × 87) — 먹칠이 아니라 손글씨

```
Tiny horizontal banner. A single sheet of warm cream paper (#d8d2c4) fills most
of the frame at a slight angle on near-black (#0d0f10).

The writing must look like a human wrote it with a ballpoint pen: THIN, cursive,
slightly uneven lines with varying pressure — NOT thick uniform bars, NOT
redaction blocks, NOT censorship marks. The words are unreadable because the
script is small and loose, not because anything is covering them.

One of the lines has a single thin pen stroke drawn through it — a strike-through
by the same hand, clearly a person crossing something out. That struck line is
the focal point.

Faint film grain, soft vignette. Must read as "a handwritten list with one line
crossed out" at 231x87 pixels. No text, no logo, no figures.
```

**체크**: 먹칠처럼 보이는가 손글씨처럼 보이는가. 굵은 막대가 하나라도 있으면 다시.

---

# 2차 결과 — 다섯 장 전부 채택 (`store/`)

정확한 스팀 규격으로 `docs/art/store/`에 넣었다. 원본은 `store/source/`.
**비율이 다섯 장 모두 목표와 0.23% 이내로 맞아서 크롭 없이 리사이즈만 했다.**

| 에셋 | 원본 | 목표 비율과 차이 |
|---|---|---|
| 메인 | 1657 × 949 | 0.06% |
| 헤더 | 1834 × 858 | 0.09% |
| 소형 | 2000 × 755 | 0.23% |
| 라이브러리 | 1024 × 1536 | 0.00% |
| 배경 | 1670 × 941 | 0.03% |

## 눈이 아니라 숫자로 확인한 것

「차갑고 종이만 따뜻하다」는 인상으로 판단하면 안 된다. 영역별 평균 RGB를 재봤다.

| 이미지 | 종이 | 주변 | 판정 |
|---|---|---|---|
| 메인 | R104 G94 B76 · 밝기 95 | 선반 밝기 17, 형광등 R65 G82 B77 (차가움) | 종이만 따뜻 ✅ |
| 헤더 | R112 G107 B91 | 우측 어둠 R8 G16 B15 (차가움) | ✅ |
| 소형 | 밝기 157 | 배경 밝기 6 | 231px에서 안 죽는다 ✅ |
| 라이브러리 | 밝기 89 | 상단 1/4 밝기 **1.8** | 제목 자리 확보 ✅ |
| 배경 | — | 전체 밝기 **6.0**, 중앙 6.8 | 글자 얹어도 읽힌다 ✅ |

**헤더의 덧댄 쪽지가 채도 5.2%로 나왔다** — 바탕 종이(18.2%, 따뜻)보다 차갑고 무채색이다.
브리프에 적은 「점장 잉크 `#23201c` / 남의 필체 `#2b2a33`」의 차이가 그대로 나왔다.
말로 시킨 것이 아니라 **수치로 확인된** 유일한 항목이고, 이 게임의 핵심 단서다.

## 남은 하나 — 그리고 왜 3차를 안 하는가

**메인 캡슐에서 실루엣의 발이 계산대에 가려 안 보인다.** 그래서 「그림자가 없다」를
읽을 수가 없다. 게다가 바닥 통로 밝기가 16.5로 선반(17.3)과 같아서, 발이 보였어도
그림자가 대비되지 않는다. 2차 프롬프트의 CHANGE 1은 절반만 먹혔다.

**그런데 이걸로 3차를 돌리지 않는다.** 물어야 할 것은 「완벽한가」가 아니라
**「이걸로 통과하는가」**다 (`CLAUDE.md` 3-6). 캡슐이 해야 할 일은
썸네일에서 살아남고 위시리스트를 만드는 것이고, 그건 지금 된다 —
그림자 없음은 스토어에서 아무도 안 보는 2회독 보상이다.
**게임의 훅은 헤더가 이미 더 잘 나르고 있다**: 덧댄 쪽지는 기제 그 자체이고
460px에서 또렷하다. 그림자 한 번 더 도는 값보다 이쪽이 크다.

## 엔진 차단

`docs/.gdignore`를 넣었다. 이 PNG들은 **고돗이 임포트조차 하지 않는다.**
`export_presets.cfg`의 `exclude_filter`가 이미 `res://docs/*`를 빼고 있지만,
그건 빌드에서 빼는 것이고 에디터는 여전히 텍스처로 임포트한다.
`CLAUDE.md` 1.1의 경계를 **파일 시스템 수준에서** 못박아 둔다.

## 아직 남은 것

- [ ] 제목은 게임 폰트로 나중에 얹는다 (지금 다섯 장 모두 글자 0개 — 확인함)
- [ ] **Steamworks AI 공시** — 이 캡슐을 쓰기로 확정하면 제출 전 최신 문서 확인,
      판단 근거를 `docs/licenses/`에 남길 것 (`CLAUDE.md` 7)
- [ ] 스크린샷 5장은 게임에서 직접 뽑는다 (GPT 아님)
