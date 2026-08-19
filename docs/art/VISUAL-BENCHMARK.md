# 비주얼 벤치마크 — 왜 이 게임이 비교당하는가

> **2026-08-19 갱신:** 이 문서의 절차형 전용 해법은 1차 패스 기록이다. 사용자가
> 캐릭터와 미완성 공간의 상품성이 부족하다고 판정해 런타임 래스터 원화를 승인했다.
> 종이 대비·CCTV 그림자 공정성은 유지하되, 현행 자산 기준은 `GENERATED-ASSETS.md`다.

> 2026-08 조사. 손님 도형을 세 번 고치고도 「그림이 별로다」가 맞았다.
> 도형 하나의 문제가 아니었다. **이 문서는 그 진단이다.**

---

## 0. 한 줄 진단

**우리는 화면 전체를 지배하는 장치가 없다.**

지금 NIGHTSHIFT는 *깨끗한 벡터 도형* 위에 *CRT 필터*를 얹은 구조다. 그래서 CRT가
「세계」로 안 읽히고 **「UI에 씌운 필터」**로 읽힌다. 아래 네 게임은 전부 반대다 —
**모든 픽셀을 건드리는 장치 하나**를 정하고 거기서 물러서지 않는다.

| 게임 | 장치 | 이게 왜 싸게 먹히나 |
|---|---|---|
| Return of the Obra Dinn | **1비트 디더링** + 두꺼운 외곽선 | 색이 2개뿐이라 「잘 그렸나」를 물을 수가 없다. 형태만 남는다 |
| Papers, Please | 극단적으로 제한된 팔레트 + **촉감** (도장·서류 넘김·셔터) | 그림이 아니라 **손맛**이 품질로 읽힌다 |
| Beholder | 납작한 **검은 실루엣 + 크고 텅 빈 눈** | 얼굴을 안 그리는데 표정이 산다. 눈 두 개가 전부다 |
| Chilla's Art (夜勤事件) | 로우폴리 + **VHS 신호 결함** (인광 잔상·번짐·인터레이스·지터) | 저해상도가 결함이 아니라 매체가 된다 |

공통점: **장치가 협상 대상이 아니다.** 우리는 CRT를 「켜 두되 강도를 조절」하고 있고,
그 밑의 도형은 여전히 깔끔한 UI 고도에 있다. 그게 어긋남의 정체다.

---

## 1. 우리에게 없는 것 다섯

### ① 전역 장치가 없다
Obra Dinn은 **두 색**이다. 그래서 낮은 폴리곤이 결함이 아니라 양식이 된다.
우리는 색이 무제한이라 도형 하나하나가 「잘 그렸나」로 심판받는다. 진다.

> ⚠ **다만 1비트는 이 게임에서 못 쓴다.** 종이 두 종의 대비가 3.99%인데
> (`tools/paper_probe.gd`) 2색으로 뭉개면 **코어 훅이 죽는다.** 쓴다면
> 6~8단계 제한 팔레트 + 디더링이다. 아트 방향이 기제를 깨면 그건 방향이 아니다.

### ② 외곽선이 사실상 없다
Obra Dinn의 절반은 디더링이고 나머지 절반은 **가독성을 위한 두꺼운 외곽선**이다.
우리 도형의 외곽선은 `#0a0c0d` 1.1px — 배경과 구분이 거의 안 된다.
실루엣이 배경에 녹아서 「덩어리」로만 보이는 이유다.

### ③ 촉감이 없다
Papers, Please의 품질감은 그림이 아니라 **도장이 쿵 찍히는 느낌**에서 온다.
우리는 종이가 있는데 종이를 만지는 감각이 없다 —
취소선은 그어지지만 펜이 눌리는 느낌이 없고, 영수증은 뽑히지만 찢기지 않는다.

### ④ 시간축 결함이 없다
Chilla's Art의 VHS는 **움직인다** — 잔상, 번짐, 인터레이스, 지터.
우리 스캔라인과 그레인은 사실상 정적이다. 아날로그 호러가 무서운 건
신호가 **불안정**해서지 줄이 그어져 있어서가 아니다.

### ⑤ 손님이 캐릭터가 아니다
Beholder는 검은 실루엣에 **크고 텅 빈 눈 두 개**만 얹는다. 그것만으로 표정이 산다.
우리는 얼굴을 완전히 비웠고(의도적), 그래서 마네킹과 구분이 안 된다.

> 우리 규칙은 「얼굴이 보이면 판단이 아니라 인상이 된다」였다. Beholder의 눈은
> **표정이 아니라 시선**이다 — 어디를 보는지만 말한다. 규칙을 안 깨고 캐릭터를
> 얻는 길이 여기 있을 수 있다. 다만 이건 설계 판단이라 사람이 정해야 한다.

---

## 2. 순서 — 무엇부터 하면 가장 크게 달라지는가

싼 것부터. 위 세 개만 해도 화면이 달라진다.

| | 할 일 | 비용 | 기제 위험 |
|---|---|---|---|
| 1 | **제한 팔레트 + 디더링 셰이더**를 전역으로. 6~8단계 | 셰이더 1개 | ⚠ 종이 대비 3.99%가 살아남는지 `paper_probe`로 확인 필수 |
| 2 | **외곽선을 실제로 보이게.** 도형 외곽을 배경보다 밝게, 2px 이상 | 상수 몇 개 | 없음 |
| 3 | **시간축 결함.** 지터·잔상·인터레이스를 긴장도에 연동 | 셰이더 수정 | 없음 (강도 상한 필요 — 글씨가 흐려지면 안 된다) |
| 4 | **촉감.** 취소선에 펜 눌림, 영수증 찢김, 스캔에 물리적 반동 | 트윈 + 효과음 | 없음 |
| 5 | 손님에 **시선** (눈 두 개) | 도형 몇 줄 | ⚠ 설계 판단 — 캡슐 5장도 같이 바뀌어야 한다 |

---

## 3. 생성 이미지를 게임에 넣는 것에 대해

`CLAUDE.md` 1.1이 게임 안의 그림을 금지하고, 7절이 **그 덕분에** Steam AI 공시가
면제라고 적어놨다. 생성 이미지를 게임에 넣으면 둘 다 깨진다. 스토어 캡슐은 게임 밖이라
넣었지만, 게임 안은 다르다.

**그런데 위 네 게임 중 이미지 에셋 품질로 이긴 게임은 하나도 없다.**
Obra Dinn은 두 색이고, Beholder는 검은 덩어리고, Chilla's Art는 일부러 저해상도다.
전부 **장치**로 이겼다. 우리에게 없는 것은 그림이 아니라 장치다.

그러니 GPT에 시킬 것은 「이미지를 그려줘」가 아니라
**「이 장치를 셰이더/도형 코드로 짜줘」**여야 한다. 그건 §1.1도 §7도 안 건드린다.

---

## 출처

- [Lucas Pope and the rise of the 1-bit 'dither-punk' aesthetic — Game Developer](https://www.gamedeveloper.com/design/lucas-pope-and-the-rise-of-the-1-bit-dither-punk-aesthetic)
- [How Lucas Pope created the unique 1-bit art style of Return of the Obra Dinn — PlayStation.Blog](https://blog.playstation.com/archive/2019/10/17/lucas-pope-on-return-of-the-obra-dinns-art-style/)
- [Shader Showcase Saturday #11: Return of the Obra Dinn — Alan Zucconi](https://www.alanzucconi.com/2018/10/24/shader-showcase-saturday-11/)
- [Designing the bleak genius of Papers, Please — Game Developer](https://www.gamedeveloper.com/design/designing-the-bleak-genius-of-i-papers-please-i-)
- [8 Great Games With Silhouette Art (Beholder) — GameRant](https://gamerant.com/games-silhouette-art/)
- [The Convenience Store | 夜勤事件 — Chilla's Art](https://chillas-art.itch.io/the-convenience-store)
- [PSX-Style: How indie games with "bad graphics" breathed new life into horror — Medium](https://medium.com/@vasiliy.ovchinnikov/psx-style-how-indie-games-with-bad-graphics-breathed-new-life-into-the-horror-genre-a80241139f29)
- [The Cult of Good Enough: Art Direction in Indie Games — Wayline](https://www.wayline.io/blog/cult-of-good-enough-indie-game-art)
