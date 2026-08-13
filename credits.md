# 크레딧

## 폰트

이 프로젝트가 쓰는 **유일한 외부 에셋 종류 두 가지 중 하나**다 (CLAUDE.md §1.1).
세 역할 파일을 동봉해 Proton/Linux에서도 OS 글꼴에 기대지 않고 한글을 표시한다.

**한 서체가 세 목소리를 다 내면 안 된다.** 점장의 수칙은 명조, 기계의 영수증과
벽시계는 등폭 고딕, 나머지 UI는 고딕으로 분리했다.

| 파일 | 쓰이는 곳 | 서체 · 출처 | 라이선스 · 받은 날 | 상태 |
|---|---|---|---|---|
| `fonts/rules.ttf` | 클립보드 수칙 | Nanum Myeongjo Regular · Google Fonts | OFL 1.1 · 2026-08-13 | ☑ 동봉 |
| `fonts/machine.ttf` | 영수증 · CCTV · 시계 | Nanum Gothic Coding Regular · Google Fonts | OFL 1.1 · 2026-08-13 | ☑ 동봉 |
| `fonts/ui.ttf` | 나머지 전부 | Nanum Gothic Regular · Google Fonts | OFL 1.1 · 2026-08-13 | ☑ 동봉 |

역할 파일이 없으면 `ui`로, 그것도 없으면 OS 폰트로 물러서는 안전장치는 유지한다
(`ui/theme_factory.gd`의 `font(role)`). 받은 시점의 원문은 `docs/licenses/Nanum*-OFL.txt`에,
출시 PCK에 동봉되는 고지는 `licenses/*-OFL-1.1.txt`에 있다.

`fontTools 4.59.1`의 실제 cmap으로 세 파일 모두 한글 완성형 11,172자와 ASCII 95자를
전부 확인했다. SHA-256은 `rules` `7ED9E8653A8ED04285D51DC343FFEA6EB3D9C73AFC27383EA8929EE4FFD03205`,
`machine` `787EFFD7EFED2ABCA88ADE231FAA8191F4E9FCF85B1805A13EE1DC3724B72089`,
`ui` `76F45EF4A6BCFF344C837C95A7DCC26E017E38B5846D5AE0CDCB5B86BE2E2D31`이다.

> ⚠ **수칙 본문을 손글씨로 바꾸는 것은 신중해야 한다.** 수칙 문구가 곧 퍼즐이고,
> 획이 얇은 손글씨는 점장 잉크와 나중 잉크의 대비(F-05 단서)를 줄인다.
> 먼저 **번호만**(「하나.」「둘.」) 손글씨로 바꿔 보고, `tools/paper_probe.gd`로
> 단서 대비가 3% 아래로 안 떨어지는지 확인한 뒤에 본문으로 넓혀라.

> ⚠ **비트맵 서체(갈무리)는 정확한 배수 크기에서만 깨끗하다.** 11/22/33 같은 값에
> `antialiasing = NONE`, `subpixel_positioning = DISABLED`로 임포트해야 한다.
> 어중간한 크기에서는 뭉갠다.

`FontVariation`을 쓰면 파일 하나로 굵기·기울기·자간을 만들어낸다
(`Palette.machine_font(tracking)`). 동봉 파일을 1~2벌로 유지하면서 위계를 얻는
유일한 공짜 수단이다.

### 넣을 때 지켜야 하는 것

1. **라이선스는 OFL 1.1 또는 CC0만.** CC-BY-SA · GPL · NC는 금지 (CLAUDE.md §7).
2. 다운로드 **시점의 라이선스 원문**을 `docs/licenses/<서체이름>-OFL.txt`로 그대로 저장한다.
   링크만 적어두면 나중에 페이지가 바뀌었을 때 무엇에 동의했는지 증명할 수 없다.
3. 이 표에 서체 이름·버전·받은 곳·받은 날짜를 적는다.
4. 파일 이름은 위 표대로 고정한다 — 코드가 `res://fonts/<역할>.ttf`(또는 `.otf`)를 찾는다
   (`ui/theme_factory.gd`의 `ROLE_*`). 이름을 바꾸려면 거기도 바꾼다.

### 규격

- **한글 완성형 11,172자 전부** 있어야 한다. 부분 커버리지는 조용히 깨진다.
- 라틴 문자와 숫자도 있어야 한다 (영어 로케일이 같은 파일을 쓴다).
- 정적 웨이트 1~2개. 가변 폰트는 Godot에서 웨이트 지정이 번거롭다.
- 출시에 중국어 간체가 들어오면 커버리지를 다시 본다 (F-10).

넣은 뒤 확인:

```bash
godot --headless -- --selftest      # 「폰트: 동봉분을 쓴다 — 역할 [...]」에 넣은 역할이 다 떠야 한다
xvfb-run -a godot --script res://tools/paper_probe.gd   # 단서 대비가 3% 아래로 안 떨어지는지
xvfb-run -a godot --script res://tools/screenshot.gd -- --out=/tmp/s.png
```

## 오디오

| 파일 | 출처 | 라이선스 | 원문 보관 |
|---|---|---|---|
| (없음 — 현재 환경음은 전부 절차 생성) | — | — | — |
