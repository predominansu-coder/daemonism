# DAEMONISM — Step 03 설치 및 실행 확인 안내

이 문서는 **파일 적용용 절차**이며, `docs`에 넣는 것만으로 전투 코드가 설치되는 것은 아닙니다. 2026-10-15에 제공한 Step 03 개별 `.gd`, `.tscn`, `.tres`를 대상으로 작성했습니다.

## 추가하는 실행 파일
- `res://systems/combat/combat_timing.gd`
- `res://systems/combat/attack_phase_gate.gd`
- `res://systems/combat/combat_director.gd`
- `res://data/combat/dev_combat_timing.tres`

## 기존 파일 교체
- `res://systems/encounters/encounter_definition.gd`
- `res://data/encounters/dev_patrol.tres`
- `res://scenes/combat/combat_scene.gd`
- `res://scenes/combat/combat_scene.tscn`

**교체하지 않는 것:** `project.godot`, `core/game_root.gd`, 필드/플레이어/순찰 적 파일, `WorldState`, `SaveManager`, Autoload와 방향키 입력 설정.

## 적용 순서
1. Godot 실행을 중지(`F8`)하고 열린 씬·스크립트를 저장(`Ctrl+S`).
2. Godot 편집기를 닫고 프로젝트 폴더를 독립된 위치에 백업.
3. 파일 탐색기에서 `project.godot`이 들어 있는 폴더를 연다.
4. 필요한 경우 `systems/combat`, `data/combat` 폴더를 만든다.
5. Step 03에서 제공된 8개 실행 파일을 경로대로 복사한다. 위에 명시된 4개만 기존 파일을 교체한다.
6. Godot을 재실행한다. 파일 임포트 후 빨간 스크립트 오류가 있다면 오류의 파일명·줄 번호를 확인하고 먼저 수정한다.
7. `data/encounters/dev_patrol.tres`를 열어 인스펙터의 `Combat Timing`이 `dev_combat_timing.tres`를 참조하는지 확인.
8. `F5` → 게임 시작 → 방향키로 순찰 적과 조우.
9. 개발용 예시로 공격 단계 약 3.5초 뒤 공동 행동 단계 약 6초가 반복되고, 행동 단계에서 상단 게이지가 줄어드는지 확인.
10. `개발용 복귀 (전투 결과 없음)` 버튼으로 필드 복귀가 가능한지, 물리 콜백 오류가 재발하지 않는지 확인.

## 검증 범위
이 확인은 **공격/공동 행동 단계 전환과 타이머 UI**까지만 검증한다. 실제 공격 판정·Q/E·사망·체크포인트·전투 결과 저장을 검증하지 않는다.

이전에 이미 Step 03 파일을 모두 적용했다면 다시 복사하지 않아도 된다. 문서 4개만 `docs`에 추가할 수 있다.
