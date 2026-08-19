# 런타임 생성 원화 기록

> 2026-08-19 · OpenAI 내장 `imagegen` · 사전 생성 래스터 원화
>
> 이 파일은 Steam Pre-Generated AI 콘텐츠 공시와 저장소 추적을 위한 기록이다.
> 모든 인물은 가상의 성인이며 실존 브랜드·상표·저작권 캐릭터·특정 작가 이름을
> 프롬프트에 사용하지 않았다.

## 공통 미술 방향

- 한국 심야 편의점의 차가운 청록 형광등과 바깥의 약한 나트륨등을 한 조명 언어로 쓴다.
- 프리미엄 손그림 래스터 반사실주의, 과슈·디지털 페인트 질감, 절제된 PS2 생존 공포의 때.
- 벡터·SVG·플랫 셀 셰이딩·애니메이션풍·광택 3D·아동화풍을 피한다.
- 손님 외형은 정답을 암시하지 않는다. 가방과 후드는 공개 특성만 시각화한다.
- `has_shadow`는 CCTV 코드 오버레이에만 존재하고 인물 원화에는 굽지 않는다.

## 파일 목록

| 런타임 파일 | 용도 | 원본 생성 파일 |
|---|---|---|
| `assets/art/title-storefront.png` | 16:9 제목 점포 | `exec-66fedc7d-f883-4aad-a825-99af486efa28.png` |
| `assets/art/cctv-atlas.png` | 계산대·매대·창고·출입구 2×2 아틀라스 | `exec-9c4a3673-1afc-4e17-96c6-54cb022f9f8a.png` |
| `assets/art/customers/office-worker.png` | 얼굴 공개·가방 없음 | `exec-b9790a97-378a-4f96-a20f-9e10cff7f162.png` |
| `assets/art/customers/student.png` | 얼굴 공개·가방 없음 | `exec-5ec7c389-ee17-4fe7-86e0-1798fadf0ddd.png` |
| `assets/art/customers/older-woman.png` | 얼굴 공개·가방 없음 | `exec-b555db84-7e25-4b81-b811-adf88a431ffa.png` |
| `assets/art/customers/bag-woman.png` | 얼굴 공개·가방 있음 | `exec-434a788e-8430-4ae8-997a-8103482860b5.png` |
| `assets/art/customers/bag-worker.png` | 얼굴 공개·가방 있음 | `exec-32bab67f-3463-4a07-a3c1-f8e611e62ebd.png` |
| `assets/art/customers/hood-no-bag.png` | 얼굴 가림·가방 없음 | `exec-20a7dc43-cc17-4319-b90d-9f39b62ad8fa.png` |
| `assets/art/customers/hood-woman.png` | 얼굴 가림·가방 없음 | `exec-9a79e0ef-b7c2-43e7-b893-f78fb8e99ded.png` |
| `assets/art/customers/hood-bag.png` | 얼굴 가림·가방 있음 | `exec-80072ecf-34c4-4700-aff7-1783394ffaaa.png` |

## 최종 프롬프트 세트

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

## 런타임 선택 규칙

`ui/art/customer_figure.gd`는 `has_bag`과 `hides_face`로 호환되는 그룹을 고른 뒤
고객 ID의 안정 해시로 그룹 안 초상을 분산한다. `is_wet`은 모든 고객에게 같은 방식의
빗물 오버레이만 더한다. 정답·이상 여부·그림자 값은 이 코드에 전달되지 않는다.
