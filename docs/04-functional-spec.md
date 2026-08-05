# 04. 기능 명세서

> Claude Code가 구현할 때 직접 참조하는 문서. 애매하면 구현하지 말고 물어볼 것.
> 상위 문서: `03-PRD.md` / 우선순위: `05-prioritization.md`

---

## F-01. 수칙 엔진 (Rule Engine) — 최우선

이 게임의 심장. `systems/rules/`. **Godot 노드를 상속하지 않는다.**

### 데이터 스키마 — `data/rules/*.json`
```json
{
  "id": "rule_no_hat_after_3am",
  "text_ko": "새벽 3시 이후, 모자를 쓴 손님에게는 물건을 팔지 마시오.",
  "text_en": "After 3 AM, do not sell to customers wearing hats.",
  "veracity": "true",
  "conditions": [
    { "field": "time", "op": "after", "value": "03:00" },
    { "field": "customer.has_hat", "op": "eq", "value": true }
  ],
  "required_verdict": "refuse",
  "introduced_night": 2,
  "conflicts_with": ["rule_always_serve_regulars"]
}
```

**필드 정의**
| 필드 | 설명 |
|---|---|
| `veracity` | `true` / `false` / `decaying` — 거짓 수칙은 지키면 페널티. `decaying`은 특정 밤부터 거짓으로 전환 |
| `conditions` | AND 결합. OR이 필요하면 수칙을 분리한다 |
| `required_verdict` | `serve` / `refuse` / `special:<id>` |
| `conflicts_with` | 명시적 모순 관계. UI에서 충돌 힌트 연출에 사용 |

### 핵심 API
```gdscript
class_name RuleEngine

# 현재 상황에서 적용 가능한 수칙 전부 반환
func applicable_rules(ctx: JudgeContext) -> Array[Rule]

# 수칙들이 요구하는 판정 (충돌 시 복수 반환)
func required_verdicts(ctx: JudgeContext) -> Array[Verdict]

# 플레이어 판정 평가 → 결과
func evaluate(ctx: JudgeContext, player_verdict: Verdict) -> JudgeResult
```

### 공정성 불변식 (⚠ 절대 위반 금지)
1. **판정에 필요한 모든 단서는 판정 시점에 화면에 존재해야 한다.** 숨겨진 스탯·주사위 금지
2. **거짓 수칙은 반드시 사전에 반증 가능한 단서를 남긴다.** (예: 필체가 다르다, 종이 재질이 다르다, 다른 수칙과 논리적으로 모순된다)
3. 실패 후 **3초 리플레이**로 놓친 단서를 반드시 보여준다
4. 무작위화는 **조합·순서**에만. 개별 판정의 정답은 결정론적

> `tests/test_rule_engine.gd`에서 위 4개를 자동 검증한다.

---

## F-02. 손님 시스템

`systems/customers/`

### 스키마 — `data/customers/*.json`
```json
{
  "id": "cust_salaryman_late",
  "silhouette": "tall_slouched",
  "traits": { "has_hat": false, "has_bag": true, "wet": true, "shadow_visible": true },
  "items": ["item_soju", "item_cup_ramen"],
  "dialogue_ko": ["...봉투 주세요.", "왜 그렇게 봐요?"],
  "patience_seconds": 45,
  "anomaly": null
}
```

- `anomaly`가 `null`이 아니면 이상 개체. 이상 징후는 **traits로 표현**되며 항상 관찰 가능해야 한다 (F-01 불변식 1)
- `silhouette`은 이미지가 아니라 **절차적 폴리곤 프리셋 ID**
- `patience_seconds` 경과 시 손님이 압박 대사 → 이후 자동 이탈(페널티)

### 생성 규칙
- 밤별 손님 풀에서 추출. 이상 개체 비율은 `data/balance.json`의 밤별 곡선을 따른다
- **연속 3명 이상 정상 손님 금지** (지루함), **연속 3명 이상 이상 개체 금지** (긴장 포화)

---

## F-03. POS 단말

`ui/pos/`

- 상품 스캔: 손님이 올린 아이템을 클릭 → 목록에 추가
- 결제: 현금 / 카드. 금액 계산은 자동 (계산 문제를 내는 게임이 아니다)
- 신분 확인: 주류·담배 품목 시 나이 확인 버튼 활성화
- **판정 버튼**: `판매` / `거부` / `특수 대응`(밤에 따라 해금)
- 모든 버튼에 트윈 + 클릭음 필수 (`CLAUDE.md` 5절)

---

## F-04. CCTV 모니터

`ui/cctv/`

- 2×2 = 4채널 동시 표시. **채널 전환 없음** (전환은 FNAF 문법이라 의도적으로 배제)
- 각 채널은 절차적 도형 + 노이즈 셰이더로 렌더
- 이상 징후는 **저확률로 짧게** 나타난다. 놓쳐도 다른 단서로 판정 가능해야 함 (F-01 불변식 1)
- 채널별 독립 그레인·롤링 셔터 파라미터

---

## F-05. 수칙 클립보드

`ui/clipboard/`

- 현재 유효 수칙 전체 표시. 스크롤 가능
- 밤 시작 시 **새 수칙 추가 연출** (종이가 끼워지는 애니메이션 + 사운드)
- 거짓 수칙은 **미묘한 시각 차이**를 가진다 (필체 굵기, 잉크 번짐, 종이 색조 — 전부 셰이더 파라미터)
  - ⚠ 너무 명확하면 퍼즐이 죽고, 너무 미묘하면 불공정해진다. 플레이테스트로 조정
- 플레이어가 수칙에 **직접 메모/취소선**을 그을 수 있다 (몰입 + 추론 보조)

---

## F-06. 밤 진행 · 시간

`systems/night/`

- 22:00 → 06:00. 시간은 **손님 처리 단위로 진행** (실시간 아님 — 압박은 `patience`가 담당)
- 밤 종료 정산: 처리 손님 수, 오판 수, 소지금 변화, 생존 여부
- 오판 3회 = 밤 실패. 실패 시 해당 밤 재시작 (진행 상실 없음)
- **자동 저장은 밤 단위.** 중간 저장 없음

---

## F-07. 판정 결과 · 사망 연출

- 즉시 피드백형: 판정 직후 결과 (대부분)
- 지연 피드백형: 밤 후반에 결과가 돌아옴 (긴장 유지용, 밤 4 이후)
- **사망 연출 3종 이상**, 각각 클립화 가능해야 함 (`02-user-needs.md` N5)
  - 공포 + 약간의 부조리. **플레이 중에는 절대 웃기지 않는다**
- 사망 후 **3초 리플레이**: 놓친 단서를 하이라이트

---

## F-08. 오디오

`audio/` — **외부 에셋이 허용되는 유일한 구역**

- UI SFX: 절차적 생성 우선 (jsfxr 계열 또는 Godot 내 신스 코드)
- 환경음: 냉장고 웅웅거림, 형광등, 빗소리, 문 종소리
- **모든 오디오 단서에 시각 대체 단서 필수** (`02-user-needs.md` N9 — 부스는 시끄럽다)
- 라이선스 원문을 `docs/licenses/`에 캡처 보관. CC-BY-SA / GPL / NC 사용 금지

---

## F-09. 셰이더 (= 이 게임의 아트)

`shaders/`

| 셰이더 | 용도 | 파라미터 |
|---|---|---|
| `crt.gdshader` | 전체 화면 곡률·스캔라인 | `curvature`, `scanline_strength` |
| `grain.gdshader` | 필름 그레인 | `intensity` ← **긴장도에 연동** |
| `chromatic.gdshader` | 색수차 | `offset` ← 이상 상황에서 증가 |
| `dither.gdshader` | 팔레트 제한 디더링 | `palette`, `levels` |
| `paper.gdshader` | 클립보드 종이 질감 | `age`, `ink_bleed` ← 거짓 수칙 단서 |

> **긴장도(tension) 단일 값이 여러 셰이더를 동시에 구동한다.** 이게 "돈 들인 것처럼 보이는" 핵심 트릭이다.

---

## F-10. 현지화

- 모든 표시 문자열은 `data/strings_<locale>.json`
- 출시: 한국어 + 영어. 이후 중국어 간체
- **하드코딩된 표시 문자열 0개** — CI 또는 테스트로 검증

---

## F-11. 텔레메트리 (데모 이후)

- 수집: 밤별 이탈 지점, 세션 길이, 오판 유형 분포
- **개인정보 수집 금지. 집계 수치만.** 옵트아웃 제공
- 목적: `01-user-research.md`의 H4~H6 검증

---

## 명세 작성 규칙

- 새 기능은 이 문서에 **F-번호를 받고 나서** 구현한다
- 각 기능은 `02-user-needs.md`의 N-번호 중 하나 이상을 참조해야 한다. 참조가 없으면 만들지 않는다
- 명세가 애매하면 코드를 쓰지 말고 질문한다
