# 캐릭터 퍼포먼스 원화 기록

> 생성일: 2026-08-21
>
> 생성 도구: OpenAI 내장 `imagegen`
>
> 모드: 새 래스터 이미지 생성 및 반복 편집

## 목표

기존의 서로 무관한 정적 반실사 초상 8장을 폐기하고, NIGHTSHIFT만의 인쇄물 같은
화풍과 실제 연기 상태를 가진 10명의 고정 출연진으로 교체한다. 모든 인물은 가상의
한국인 성인이며 실존 인물·브랜드·저작권 캐릭터·특정 작가 이름을 사용하지 않았다.

## 공통 아트 디렉션

- 매체: 불투명 과슈, 카본 연필, 모노타이프 잉크, 거친 붓자국, 영수증 종이 섬유.
- 인쇄 언어: 산화된 청록과 니코틴색 주황의 제한 팔레트, 드문 복사기 망점과 미세한
  오프레지스터. 광택 디지털 페인팅이나 매끈한 벡터 윤곽은 쓰지 않는다.
- 무대: 기름때 묻은 검은 계산대와 어두운 편의점. 청록 형광등 림과 바깥의 주황
  나트륨광을 모든 시트에 공유한다.
- 구도: 정확히 같은 크기의 2×2 칸. 같은 인물·의상·소품·카메라 높이를 유지한다.
- 연기: 좌상단 `도착/대기`, 우상단 `대사/반응`, 좌하단 `초조/재촉`, 우하단
  `압박/요구` 순서다. 눈썹과 입만 바꾸지 않고 손·무게중심·소품 사용까지 바꾼다.
- 금지: 글자, 로고, 워터마크, 초자연 단서, 유혈, 기형, 정답을 암시하는 조명.

## 현재 런타임 파일

| 파일 | 고정 배역과 식별 소품 | 원본 생성 파일 |
|---|---|---|
| `assets/art/performers/bus-driver.png` | 흉터 난 눈썹의 심야 버스 기사·황동 검표기 | `exec-3b8e11b7-1c2d-4f6c-a9ff-5fb71d868515.png` |
| `assets/art/performers/night-florist.png` | 은색 단발의 야간 꽃집 주인·꺾인 국화 | `exec-433fa04c-e5d7-4c2e-91d3-8ad8f1793a2a.png` |
| `assets/art/performers/lab-technician.png` | 수리한 안경의 검사 기사·보라색 장갑 | `exec-51dd7d65-2941-4366-a02d-933648dcef3a.png` |
| `assets/art/performers/night-office-worker.png` | 흰 머리 한 줄의 야근자·느슨한 넥타이 | `exec-c04a4dd8-9847-4b4c-906a-119045900ae0.png` |
| `assets/art/performers/delivery-rider.png` | 겨자색 우비의 배달 기사·보온 가방 | `exec-51d14ca1-c299-456f-ba5f-a938c274e993.png` |
| `assets/art/performers/portrait-retoucher.png` | 영정사진 보정사·포트폴리오와 왁스 연필 | `exec-ebe94ef1-f10f-49d4-a666-723afb39a4be.png` |
| `assets/art/performers/printmaking-student.png` | 판화과 학생·잉크 묻은 가방과 종이관 | `exec-0421ebec-1d96-4ef1-be91-9ad1e8f15973.png` |
| `assets/art/performers/amateur-boxer.png` | 후드를 쓴 아마추어 복서·테이핑과 황동 열쇠 | `exec-9e4d8033-702e-477b-9803-6e3a1d59be3f.png` |
| `assets/art/performers/fish-auctioneer.png` | 어시장 경매인·고무 앞치마와 집계 끈 | `exec-0d944975-65e2-4927-a8b1-4c5c6c0c82a8.png` |
| `assets/art/performers/laundry-collector.png` | 세탁물 수거원·천 자루와 황동 태그 | `exec-ce595588-2081-4e9a-9c2c-caedd425134c.png` |

모든 파일은 1536×1024 PNG이며 한 칸은 768×512다. Godot에서는 `AtlasTexture`로
필요한 칸만 잘라 표시한다.

## 최종 프롬프트 세트

각 인물 생성에는 아래 공통 프롬프트를 사용하고 `Character` 단락만 교체했다.

```text
Use case: game-production character performance sheet.
Create one exact 2x2 grid of four equal waist-up checkout-counter portraits of the same
fictional Korean adult. Keep identity, face, age, outfit, signature prop, camera height,
lighting and counter consistent in every panel.

Performance order: top-left arrival/neutral listening; top-right speaking/reacting with a
specific hand gesture; bottom-left urging/impatient using the signature prop or checking
time; bottom-right demanding/pressured, leaning into the counter. Change expression,
shoulder line, weight distribution, hands and prop action—not only the mouth.

Distinct visual language: opaque gouache, carbon pencil and monotype ink on oil-stained
charcoal receipt paper; visible bristle drag and paper fibre; sparse photocopy halftone;
slightly off-register oxidized teal and nicotine-amber screenprint accents. Uneven handmade
marks, tactile matte pigment, editorial printmaking rather than glossy digital concept art.
Cold teal convenience-store fluorescent rim, weak amber sodium spill, dark checkout.

No text, letters, numbers, logos, brands, watermark, extra panels, border captions,
supernatural clue, monster anatomy, blood, generic anime, vector/SVG look, plastic 3D,
airbrushed skin or smooth photoreal AI gloss. Believable hands and consistent fingers.
```

배역별 `Character` 단락:

```text
Bus driver — fictional Korean man, late 50s, scarred eyebrow, worn teal cardigan over a
rumpled uniform shirt, small brass ticket punch clipped to his chest.

Night florist — fictional Korean woman, early 60s, silver bob, burgundy knitted vest,
green rain sleeve, holding one bent chrysanthemum.

Lab technician — fictional Korean woman, late 30s, asymmetric undercut, repaired black
glasses, lab smock under a rain shell, violet nitrile gloves in her pocket.

Delivery rider — fictional Korean man, early 30s, mustard rain jacket, battered insulated
messenger bag and one riding glove.

Funeral portrait retoucher — fictional Korean woman, mid-40s, dark work coat, battered
portfolio case, red wax pencil and graphite-stained fingers.

Amateur boxer — fictional Korean woman, late 20s, rain-dark hood, taped hands and a brass
locker key; no bag or strap.

Fish-market auctioneer — fictional Korean man around 50, fisher hood and cap, rubber apron,
tally cord and one shortened fingertip; no bag or strap.

Laundromat collector — fictional Korean woman, early 50s, oversized hood and cloth mask,
patched rain poncho, canvas laundry sack and brass claim tags.

Night office worker — fictional Korean man, early 40s, prematurely white hair streak,
repaired rumpled shirt, unmistakable loose teal necktie and blank badge clip; no bag.

Printmaking student — fictional Korean university student, age 21, uneven bob with teal
lock, repaired glasses, patched rain shell, ink-stained messenger bag and blank paper tube.
```

야근자와 학생의 최종 정밀 편집에는 아래 프롬프트를 각 원본과 함께 사용했다.

```text
Use case: precise style and background edit of this exact 2x2 character performance sheet.
Preserve the same fictional character's identity, face, age, outfit, signature props, all
four expressions, poses, hands, camera height, counter, equal grid, and panel order exactly.
Replace the detailed store background in all four panels with near-black oil-stained
charcoal receipt paper and only abstract shelf blocks. Push the rendering into tactile
Korean editorial printmaking: opaque gouache, carbon pencil, monotype ink, visible bristle
drag and paper fibre, sparse coarse photocopy halftone, slightly misregistered oxidized
teal and nicotine-amber screenprint accents. Flatten smooth skin and digital depth; add
dry-brush scars and handmade plate noise while keeping face, hands and props readable at
small game UI size. No new objects, text, logo, watermark, photoreal gloss, anime,
fashion-model treatment, vector look, extra panels, or changed fingers.
```

버스 기사는 첫 생성 뒤 같은 시트를 유지한 채 인쇄 질감을 강화하고 배경을 다른 시트와
같은 어두운 영수증 종이로 맞추는 두 번의 정밀 편집을 거쳤다. 야근자와 학생도 첫 생성
뒤 인물과 네 동작을 보존하고 배경·망점·드라이브러시를 통일하는 정밀 편집을 한 번씩
거쳤다. 첫 생성 파일은 각각 `exec-120cf0e4-61ab-4cdb-a4de-3acab22bc952.png`,
`exec-6b472258-9655-440d-b249-a4ab43f03d57.png`이다.

## 런타임 연기와 공정성

`ui/art/customer_figure.gd`는 공개 특성 `has_bag`, `hides_face`, 고객 ID와 세션 솔트만으로
시트를 선택한다. 같은 플레이 안에서는 같은 ID가 같은 얼굴을 유지하지만 새 게임에서는
다시 섞여 “이 얼굴은 늘 정상”이라는 반복 플레이 치트를 막는다. 이름에 성별·역할이
명시된 손님은 공개 ID 표로 전용 시트를 고정한다.
칸 전환은 `ui/customer_view.gd`의 대사 타자 효과와 모든 고객에게 동일한
인내 단계만 받는다. `anomaly`, `verdict`, `has_shadow`는 선택 함수와 연기 함수에 전달하지
않는다. 말이 없는 대사는 입 연기를 하지 않는다. 따라서 플레이어가 외형이나 애니메이션
자체를 정답 치트로 사용할 수 없다.
