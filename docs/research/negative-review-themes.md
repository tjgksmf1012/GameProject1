# 부정 리뷰 분석 — 이 장르에서 사람들이 무엇에 화를 내는가

`01-user-research.md` C-1의 산출물. 조사일 2026-08.

> **방법론 고지**: 이 문서는 리뷰 요약·평론·커뮤니티 스레드를 종합한 **2차 조사**다.
> C-1이 요구한 "부정 리뷰 각 50개 정독"은 아직 하지 않았다. 표본이 아니라 **반복되는 주제**로 읽어야 한다.
> 개발 착수 전 Steam에서 직접 부정 리뷰를 훑어 이 목록을 보정할 것.

긍정 리뷰보다 부정 리뷰의 정보량이 많다. 우리가 어디서 죽을지를 남들이 이미 겪었기 때문이다.

---

# 반복되는 불만 5개

## 🔴 1. "일처럼 느껴진다" — Papers, Please

가장 자주 나오는 불만이다.

> 서류를 대조하는 일이 지루하고, 실수에 대한 공포가 실제 직장 스트레스처럼 느껴진다.
> *"지루한 직업에 대한 지루한 시뮬레이션"* 이라는 평가가 반복된다.

**NIGHTSHIFT에 그대로 적용되는 위험이다.** 우리도 문서를 대조해서 판정한다. 구조가 같다.

### 우리가 다른 점 (그리고 그게 충분한지)

| | Papers, Please | NIGHTSHIFT |
|---|---|---|
| 분량 | 6시간+ | 1박 8~12분 |
| 플레이어의 일 | 규정과 서류를 **대조**한다 | 규정 자체를 **의심**한다 |
| 실수의 의미 | 벌금·가족 아사 | 죽음 |

거짓 수칙이 "작업"을 "추리"로 바꿔준다는 게 우리 가설이다. **하지만 이건 가설이지 보장이 아니다.**
M0 플레이테스트에서 테스터가 *"이거 그냥 체크리스트 대조인데"* 라고 말하면 H1이 죽은 것이다.

> **관찰 항목 추가**: 테스터가 수칙을 **읽는지** 아니면 **훑고 넘기는지** 본다.
> 훑고 넘기기 시작하면 그 순간부터 이 게임은 작업이다.

## 🔴 2. 시행착오로 배우는 죽음은 공포를 파괴한다

이번 조사에서 **가장 중요한 발견**이다. 우리 코어 훅이 정확히 이 지뢰밭 위에 서 있다.

Frictional Games(Amnesia 개발사)의 주장이 특히 직접적이다:

> 반복 실패는 위험을 **예측 가능하게** 만든다. 그 결과는 공포가 아니라 짜증이다.
> 시행착오 루프에 갇히면 긴장이 전부 빠져나간다.

그리고 반복되는 관찰:

> 죽는 순간 몰입이 깨지고, 플레이어는 자기가 게임을 하고 있다는 걸 자각한다.

**거짓 수칙은 정의상 시행착오로 배우는 장치다.** 한 번 속아봐야 "수칙이 거짓말할 수 있다"를 안다.
이게 H1이 실패하는 가장 그럴듯한 경로다.

### 이 조사가 뒷받침하는 우리 설계

| 장치 | 이 조사가 주는 근거 |
|---|---|
| **3초 리플레이** (F-07, 불변식 3) | 죽음을 "예측 불가능한 사고"에서 "놓친 단서"로 바꾼다 |
| **`grace_on_first_trap`** (M0에서 추가) | 문법을 배우기 전의 첫 죽음을 없앤다 |
| **공정성 불변식 2** (거짓 수칙은 반증 단서를 남긴다) | 시행착오가 아니라 **관찰**로 알아낼 수 있게 한다 |

> 세 장치의 목적은 하나다 — **시행착오로 배우지 않아도 되게 만드는 것.**
> 이게 성립하면 이 장르의 가장 흔한 사망 원인을 피한다. 성립 안 하면 H1이 죽는다.

## 🟠 3. Exit 8의 불공정 구조 — 우리가 이미 막아둔 것

The Exit 8의 부정 리뷰에서 나온 구체적인 불만이다. 읽어볼 가치가 있다.

> 플레이할수록 **인위적으로 어려워진다.** 명백한 이상 징후는 이미 찾아버렸고,
> 리셋되면 미묘한 것만 남는다. 결국 거의 찾을 수 없는 것들만 남는 상황에 도달한다.
> 일부 이상은 너무 미묘해서, 나오는 순간 그 런은 무조건 죽는다.
> **세이브 데이터를 지워야 공정하게 클리어할 수 있었다.**

마지막 문장이 특히 아프다. 플레이어가 게임을 고쳐 쓰게 만든 것이다.

**우리는 이걸 이미 막아뒀다:**

| 불변식 | 막는 것 |
|---|---|
| 1. 모든 단서는 판정 시점에 화면에 존재 | "찾을 수 없는 단서" 자체가 불가능 |
| 4. 개별 판정은 결정론적 | "운이 나빠서 죽는" 경우가 없음 |

`tests/test_fairness.gd`가 자동 검증 중이다. **`05-prioritization.md` §4가 이 둘을 "절대 자르지 않는 항목"으로
지정한 게 옳았다** — 이 조사가 그 근거를 실증으로 채워준다.

## 🟠 4. 판정 인터페이스가 직관적이지 않다

Papers, Please와 Chilla's Art 양쪽에서 반복된다.

> 불일치를 찾아내는 방식이 직관적이지 않고 투박하다. (Papers, Please)
> 퍼즐이 직관적이지 않아 뭘 해야 할지 몰라 한참 헤맸다. (Chilla's Art)

이건 N1(첫 30초 안에 코어 루프가 자명해야 한다)의 **실증적 근거**다. 우리가 만든 요구사항이 아니라
이 장르가 실제로 반복해서 실패하는 지점이다.

> M0 플레이테스트에서 **절대 설명하지 않는다**는 규칙(C-2)을 반드시 지킬 것.
> 설명하는 순간 이 항목을 측정할 기회가 영영 사라진다.

## 🟡 5. 짧은 분량 — 다만 우리 문제는 반대다

The Exit 8은 **1시간**인데도 "짧고 리플레이성이 없다"고 비판받았다.
그런데도 상업적으로 성공했다. 짧다는 비판이 판매를 막지는 않았다.

**우리 문제는 짧은 게 아니라 애매한 것이다.** 2~3시간은:
- Exit 8처럼 "짧아서 좋다"는 포지션도 아니고
- Papers, Please처럼 "분량이 있다"는 포지션도 아니다

게다가 규칙 게임은 정답이 유출되면 가치가 급락하는데, 3시간은 유출 노출 시간이 3배다.

→ `docs/market/NIGHTSHIFT_REVIEW.md` §4-2의 미결 사항과 같은 결론이다. **분량 포지션을 확정해야 한다.**

---

# 보너스 — Chilla's Art의 약점은 우리의 기회다

`00-competitive-analysis.md`가 The Convenience Store를 "가장 위험한 비교 대상"으로 지목했다.
그 게임의 부정 리뷰를 보면 오히려 기회가 보인다. (전체 평가는 긍정 83%)

| 그들의 약점 | 우리의 대응 |
|---|---|
| **무섭지 않다** — 분위기는 좋은데 공포가 약하다 | 우리 공포는 분위기가 아니라 **판정의 무게**에서 온다. 틀리면 죽는다 |
| **설명이 없다** — 무슨 일이 벌어지는지 알려주지 않는다 | 우리는 수칙이 명시적이다. 문제는 그게 거짓일 수 있다는 것 |
| **퍼즐이 직관적이지 않다** | 불변식 1이 구조적으로 막는다 |
| **엔딩이 허무하다** | (미결. `03-PRD.md` §8 엔딩 분기 결정 시 반영할 것) |

같은 소재(편의점 야간 근무)를 쓰면서 **정반대 방향**으로 간다는 근거가 하나 더 생겼다.
그들은 서사와 분위기, 우리는 시스템과 판정이다.

---

# 이 조사가 남긴 액션

| # | 항목 | 반영처 |
|---|---|---|
| 1 | 플레이테스트에서 **"수칙을 읽는가, 훑는가"** 를 관찰 항목에 추가 | `playtest-template.md` |
| 2 | 시행착오 방어 3종(리플레이·유예·반증 단서)의 근거 확보 | 이 문서 §2 |
| 3 | 불변식 1·4를 절대 자르지 않는 근거 실증으로 보강 | `05-prioritization.md` §4 |
| 4 | 분량 포지션 확정 필요 (미결) | `03-PRD.md` §8 |
| 5 | 엔딩 설계 시 "허무하다"를 피할 것 | `03-PRD.md` §8 |

## 아직 안 한 것

- [ ] Steam 부정 리뷰 **직접 50개씩 정독** (Papers, Please / The Exit 8 / Chilla's Art)
- [ ] r/horrorgaming, 루리웹·인벤 "규칙 호러" 스레드 반응 수집
- [ ] 유튜브 실황 3편씩 시청 → **시청자 채팅이 터지는 지점** 타임스탬프 기록

세 번째가 특히 중요하다. P2(스트리머)가 우리의 유일한 현실적 마케팅 채널인데,
채팅이 터지는 지점을 모르면 그걸 설계할 수 없다.

---

## 출처

- [Papers, Please is a bad game and I don't get the appeal — NeoGAF](https://www.neogaf.com/threads/papers-please-is-a-bad-game-and-i-dont-get-the-appeal.741472/)
- [Papers, Please — Critical Miss #11](https://atomicbobomb.home.blog/2019/12/28/papers-please-critical-miss-11-working-for-the-clampdown/)
- [Why Trial and Error will Doom Games — Frictional Games](https://frictionalgames.com/2010-04-why-trial-and-error-will-doom-games/)
- [Why Trial and Error will Doom Games — Game Developer](https://www.gamedeveloper.com/design/why-trial-and-error-will-doom-games)
- [Don't Fear the Reaper: How Horror Games Can Get Smarter About Player Death — Dread Central](https://www.dreadcentral.com/editorials/486106/dont-fear-the-reaper-how-horror-games-can-get-smarter-about-player-death/)
- [The Exit 8 — Steam 부정 리뷰](https://steamcommunity.com/app/2653790/negativereviews/?l=english)
- [The Exit 8 Reviews — Metacritic](https://www.metacritic.com/game/the-exit-8/)
- [The Exit 8 and its clones: how do we call this new genre? — ResetEra](https://www.resetera.com/threads/the-exit-8-and-its-clones-how-do-we-call-this-new-genre.1095741/)
- [The Convenience Store | 夜勤事件 — Steam](https://store.steampowered.com/app/1228520/Chillas_Art_The_Convenience_Store/)
- [The Convenience Store Reviews — Metacritic](https://www.metacritic.com/game/the-convenience-store/)
