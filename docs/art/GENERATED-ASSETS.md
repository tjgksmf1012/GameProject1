# 런타임 생성 원화 기록

> 2026-08-19~2026-08-21 · OpenAI 내장 `imagegen` · 사전 생성 래스터 원화
>
> 이 파일은 Steam Pre-Generated AI 콘텐츠 공시와 저장소 추적을 위한 기록이다.
> 모든 인물은 가상의 성인이며 실존 브랜드·상표·저작권 캐릭터·특정 작가 이름을
> 프롬프트에 사용하지 않았다.

## 공통 미술 방향

- 한국 심야 편의점의 차가운 청록 형광등과 바깥의 약한 나트륨등을 한 조명 언어로 쓴다.
- 배경은 손그림 래스터 반사실주의, 캐릭터는 과슈·카본·모노타이프의 영수증 누아르다.
- 벡터·SVG·플랫 셀 셰이딩·애니메이션풍·광택 3D·아동화풍을 피한다.
- 손님 외형은 정답을 암시하지 않는다. 가방과 후드는 공개 특성만 시각화한다.
- `has_shadow`는 CCTV 코드 오버레이에만 존재하고 인물 원화에는 굽지 않는다.

## 파일 목록

| 런타임 파일 | 용도 | 원본 생성 파일 |
|---|---|---|
| `assets/art/title-storefront.png` | 16:9 제목 점포 | `exec-66fedc7d-f883-4aad-a825-99af486efa28.png` |
| `assets/art/cctv-atlas.png` | 계산대·매대·창고·출입구 2×2 아틀라스 | `exec-9c4a3673-1afc-4e17-96c6-54cb022f9f8a.png` |
| `assets/art/performers/bus-driver.png` | 버스 기사 4단계 연기 시트 | `exec-3b8e11b7-1c2d-4f6c-a9ff-5fb71d868515.png` |
| `assets/art/performers/night-florist.png` | 야간 꽃집 주인 4단계 연기 시트 | `exec-433fa04c-e5d7-4c2e-91d3-8ad8f1793a2a.png` |
| `assets/art/performers/lab-technician.png` | 검사 기사 4단계 연기 시트 | `exec-51dd7d65-2941-4366-a02d-933648dcef3a.png` |
| `assets/art/performers/night-office-worker.png` | 야근자 4단계 연기 시트 | `exec-c04a4dd8-9847-4b4c-906a-119045900ae0.png` |
| `assets/art/performers/delivery-rider.png` | 배달 기사 4단계 연기 시트 | `exec-51d14ca1-c299-456f-ba5f-a938c274e993.png` |
| `assets/art/performers/portrait-retoucher.png` | 영정사진 보정사 4단계 연기 시트 | `exec-ebe94ef1-f10f-49d4-a666-723afb39a4be.png` |
| `assets/art/performers/printmaking-student.png` | 판화과 학생 4단계 연기 시트 | `exec-0421ebec-1d96-4ef1-be91-9ad1e8f15973.png` |
| `assets/art/performers/amateur-boxer.png` | 아마추어 복서 4단계 연기 시트 | `exec-9e4d8033-702e-477b-9803-6e3a1d59be3f.png` |
| `assets/art/performers/fish-auctioneer.png` | 어시장 경매인 4단계 연기 시트 | `exec-0d944975-65e2-4927-a8b1-4c5c6c0c82a8.png` |
| `assets/art/performers/laundry-collector.png` | 세탁물 수거원 4단계 연기 시트 | `exec-ce595588-2081-4e9a-9c2c-caedd425134c.png` |

## 최종 프롬프트 세트

캐릭터 8종의 공통 프롬프트, 배역별 프롬프트, 2×2 연기 칸 규약과 편집 이력은
`docs/art/CHARACTER-PERFORMANCE-ASSETS.md`에 기록한다. 아래 정적 초상 프롬프트는
2026-08-19 1차 원화의 역사 기록이며, 해당 파일은 2026-08-21 런타임에서 폐기했다.

### 제목 점포

```text
Use case: stylized-concept
Asset type: 16:9 runtime title-screen background
Primary request: a believable small independent Korean convenience store exterior at 2 a.m.
in heavy summer rain, viewed straight-on from across a wet narrow street; warm fluorescent
interior visible through fogged glass, stocked shelves and checkout counter readable, one
distant ordinary human silhouette just inside the sliding door.
Style/medium: premium hand-painted raster background, grounded semi-realism, textured
gouache/digital paint, subtle PS2-era survival-horror grime.
Composition: wide centered storefront, blank sign fascia and uncluttered title area.
Constraints: no text, logos, trademarks, chain branding, watermark, monster, blood, or
supernatural clue.
```

### CCTV 아틀라스

```text
Use case: stylized-concept
Asset type: square 2-by-2 runtime CCTV environment atlas
Primary request: four equal surveillance scenes — checkout floor, stocked aisle and
refrigerators, back storage with cartons and metal shelves, rain-streaked sliding entrance.
Style/medium: hand-painted raster surveillance environments, grounded realism, cold
green-gray analog CCTV exposure and textured gouache/digital paint.
Composition: exact equal 2x2 grid with thin black gutters; high corner cameras; top-left has
clear floor for a runtime shadow overlay.
Constraints: no people, human-shaped shadows, text, labels, timestamps, logos, brands,
watermark, monsters, blood, or supernatural clue.
```

### 얼굴 공개·가방 없음 3종

```text
Use case: stylized-concept
Asset type: runtime customer portrait
Primary request: an ordinary fictional Korean adult at a late-night convenience-store
checkout — tired office worker / university student / older neighborhood resident.
Subject: waist-up, uncovered readable face, believable anatomy and natural hands empty on
the counter, no bag, strap, umbrella, or held product; neutral restrained expression.
Style/medium: premium hand-painted raster semi-realism, textured gouache/digital paint,
subtle survival-horror grime.
Lighting: cold cyan-green fluorescent rim and faint warm sodium bounce.
Constraints: dark vignette backdrop; no text, logo, trademark, watermark, mutation, blood,
or supernatural clue; appearance must not imply verdict.
```

사무직 초상은 첫 생성본의 가방끈과 캔이 공개 특성과 충돌해 아래 편집으로 교정했다.

```text
Use case: precise-object-edit
Primary request: remove only the black shoulder-bag strap, buckle, and gold beverage can;
reconstruct the jacket and place both empty hands naturally on the checkout counter.
Constraints: preserve identity, face, hair, expression, proportions, windbreaker, shirt,
loose tie, background, painterly texture, lighting, crop, palette, and counter.
```

### 얼굴 공개·가방 있음 2종

```text
Use case: stylized-concept
Asset type: runtime customer portrait
Primary request: a clearly new ordinary fictional Korean adult — middle-aged woman with a
folded black umbrella / building maintenance worker — carrying a clearly visible worn
cross-body canvas bag.
Subject: waist-up, uncovered face, realistic anatomy, natural empty hands, bag strap and
bag edge unmistakable, neutral expression.
Style/medium: same premium hand-painted raster semi-realism and textured gouache/digital
paint, dark vignette, cold fluorescent rim and weak sodium bounce.
Constraints: no held product, text, logo, trademark, watermark, mutation, blood, or
supernatural clue; appearance must not imply verdict.
```

### 얼굴 가림·가방 없음 2종

```text
Use case: stylized-concept
Asset type: runtime customer portrait
Primary request: an ordinary fictional Korean adult in a rain-darkened hooded jacket or
poncho at the checkout.
Subject: waist-up, realistic anatomy, empty hands on counter, no bag or strap; wet hood
casts a deep natural shadow hiding the eyes while nose and mouth remain subtly human.
Style/medium: premium hand-painted raster semi-realism, textured gouache/digital paint,
restrained survival-horror grime.
Constraints: no monster, skull, glowing eyes, held product, text, logo, trademark,
watermark, mutation, blood, or supernatural clue; appearance must not imply verdict.
```

### 얼굴 가림·가방 있음 1종

```text
Use case: stylized-concept
Asset type: runtime customer portrait
Primary request: an ordinary fictional older Korean man in a wet hooded coat carrying a
clearly visible worn cross-body grocery satchel.
Subject: waist-up, hood naturally hides eyes, nose and lined mouth remain human, realistic
hands empty on counter, strap and bag edge clearly readable.
Style/medium: same premium hand-painted raster semi-realism, dark vignette, cold fluorescent
rim and weak sodium bounce.
Constraints: no held product, text, logo, trademark, watermark, mutation, blood, glowing
eyes, monster, or supernatural clue; appearance must not imply verdict.
```

## 런타임 선택·연기 규칙

`ui/art/customer_figure.gd`는 `has_bag`과 `hides_face`로 호환되는 그룹을 고른 뒤
고객 ID와 세션 솔트로 그룹 안 연기 시트를 분산한다. 같은 플레이에서는 일관되고 새 게임에는
다시 섞여 외형 암기를 막는다. `is_wet`은 모든 고객에게 같은 방식의
빗물 오버레이만 더한다. 대사 공개 중에는 말하기 칸, 공통 인내 단계가 오르면 초조와 압박
칸으로 바뀐다. 정답·이상 여부·그림자 값은 이 코드에 전달되지 않는다.
