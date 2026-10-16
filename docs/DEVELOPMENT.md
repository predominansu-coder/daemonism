# DAEMONISM 개발·검증 방법

기준 엔진은 **Godot 4.7.2**입니다. 프로젝트는 Forward+이며 Windows 드라이버 설정은 `d3d12`입니다. Headless 검사는 화면 렌더링이나 Windows 내보내기 검사를 대신하지 않습니다.

## 클라우드 CLI

현재 클라우드에 설치된 검증용 실행 파일:

```text
/workspace/.daemonism-env/bin/Godot_v4.7.2-stable_linux.x86_64
```

시스템 `/usr/local/bin/godot`은 4.6.3일 수 있으므로 그대로 사용하지 않습니다. 활성화 스크립트는 PATH와 XDG 쓰기 경로를 설정합니다.

```bash
cd /workspace/daemonism
source /workspace/.daemonism-env/activate.sh
godot --version
export GODOT_BIN=/workspace/.daemonism-env/bin/Godot_v4.7.2-stable_linux.x86_64
"$GODOT_BIN" --headless --editor --path . --import
GODOT_BIN="$GODOT_BIN" bash tests/run_headless.sh
```

버전 출력은 `4.7.2.*`여야 합니다. 다른 머신에서는 `GODOT_BIN`을 설치된 Godot 4.7.2 실행 파일의 경로로 바꿉니다. runner는 `GODOT_BIN` → 위 클라우드 경로 → PATH의 `godot` 순서로 선택하고 버전이 맞지 않으면 중단합니다. Bash, `timeout`, `rg`가 필요하며 추가 Godot 플러그인은 필요하지 않습니다.

`tests/run_headless.sh`는 임포트, 메인 씬 30프레임 시작, 감독·이동·패턴·통합 검사, 별도 두 프로세스의 저장/불러오기를 순서대로 실행합니다. 임시 XDG 데이터/설정/캐시 경로에서 저장을 검사하고 종료 시 정리해 사용자 세이브와 분리합니다. 종료 코드 외에도 `SCRIPT ERROR:`/`ERROR:`와 각 suite의 완료 표시를 검사합니다.

특정 검사의 직접 실행 예:

```bash
"$GODOT_BIN" --headless --path . --script res://tests/combat_director_test.gd
"$GODOT_BIN" --headless --path . --script res://tests/combat_movement_test.gd
"$GODOT_BIN" --headless --path . --script res://tests/combat_patterns_test.gd
"$GODOT_BIN" --headless --path . --script res://tests/combat_integration_test.gd
```

직접 실행 시에는 runner의 격리 경로·오류 로그 검사 기능이 적용되지 않습니다. 저장 검사는 기본적으로 runner를 사용하세요.

화면을 사용할 수 있는 머신의 편집기/게임 시작 명령:

```bash
"$GODOT_BIN" --editor --path .
"$GODOT_BIN" --path .
```

현재 클라우드 검증은 headless입니다. 엔진 버전·결과 수·남은 검사는 [구현 현황](IMPLEMENTATION_STATUS.md)에 기록합니다.

## Windows에서 화면·조작 확인

1. **Godot 4.7.2** 프로젝트 관리자를 열고 `가져오기(Import)` → 저장소의 `project.godot` → `가져오기 및 편집`을 선택합니다. 처음 임포트가 끝날 때까지 기다립니다.
2. 프로젝트를 연 뒤 `F5`로 메인 프로젝트를 실행합니다. 임의의 전투 씬만 `F6`으로 실행하면 조우 문맥이 없어 정식 흐름을 확인할 수 없습니다.
3. 타이틀의 시작 버튼을 누릅니다. 방향키로 움직이고 필드 카메라가 따라오는지 확인합니다. 순찰 적은 처음 필드 플레이어 오른쪽 약 200 위치에서 위아래로 이동합니다.
4. 적에 접촉해 전투로 진입합니다. 하단에 조우 ID와 단계가, 중앙에 아레나·플레이어가 표시되는지 확인합니다. 디버거에 물리 콜백 중 충돌 노드 제거 오류가 없어야 합니다.
5. 방향키로 이동하고 대각선 이동·벽 방향 이동을 확인합니다. 플레이어가 아레나 밖으로 벗어나지 않고 카메라가 플레이어를 따라가지 않는지 봅니다. 창 크기를 바꿔 영역과 HUD를 확인합니다.
6. 방향키와 Space로 대쉬합니다. 연속 입력은 쿨타임에 제한되고, 벽에서 멈춰야 합니다. 입력 없이 Space를 누르면 마지막 방향으로 이동합니다. 필드에는 Space 대쉬가 없습니다.
7. 공격 단계에서 예고선이 먼저 보이고 투사체가 발사되는지 확인합니다. 예고가 시작된 뒤 이동해 발사 방향이 뒤늦게 따라오지 않는지 봅니다. 접촉 시 HP가 줄지 않는 것은 현재 미구현 범위입니다.
8. 기본 개발 조우는 약 3.5초 공격 후 6초 행동 단계로 넘어갑니다. 행동 단계에서 상단 게이지가 감소하고 0이 되면 다음 공격 단계로 가야 합니다. 행동 단계에 이전 투사체가 남아 있지 않은지 확인합니다. 시간 수치는 최종 밸런스가 아닙니다.
9. 현재 행동 단계에서도 이동·대쉬가 가능하며 이는 잠정 동작입니다. Q/E·타깃 선택·HP·승패를 기대하지 않습니다.
10. `개발용 복귀 (전투 결과 없음)`를 누릅니다. 이전 필드로 돌아가고, 적의 감지 영역에서 벗어났다가 다시 접촉하면 재조우가 가능해야 합니다. 이 버튼은 적 처치나 도주 기록을 만들지 않습니다.
11. `F8`로 실행을 종료합니다. 출력과 디버거의 오류, 시각적 문제 및 사용 엔진/OS를 기록합니다.

이 화면·실제 조작 검사는 아직 수행하지 않았습니다. 입력 지연·가독성·정식 회피 난이도·Forward+ 렌더링·Windows/Steam 내보내기도 별도 검증 대상입니다.

## 개발용 수치 편집

실행을 `F8`로 멈춘 뒤 Godot 왼쪽 **파일시스템(FileSystem)**에서 아래 Resource를 클릭합니다. 오른쪽 **인스펙터(Inspector)** 값을 바꾸고 `Ctrl+S`로 저장한 후 `F5`로 확인합니다. 값은 최종 기획으로 확정하지 않습니다.

| 파일 | 인스펙터 항목 | 영향 |
| --- | --- | --- |
| `data/combat/dev_player_motion.tres` | Move Speed, Dash Speed, Dash Duration Seconds, Dash Cooldown Seconds | 전투 전용 이동/대쉬 |
| `data/combat/dev_attack_pattern.tres` | Volley Count, Projectiles Per Volley, Telegraph Seconds, Volley Interval Seconds, Projectile Speed/Lifetime Seconds/Radius, Spread Degrees, Normalized Origin | 기본 예고 일제사격 |
| `data/combat/dev_combat_timing.tres` | Attack End Condition, Attack Duration Seconds, Action Duration Seconds | 공격 종료 방식과 행동시간 |
| `data/encounters/dev_patrol.tres` | Combat Timing, Attack Pattern | 해당 필드 조우가 사용할 데이터 참조 |

아레나 크기는 `scenes/combat/combat_arena.tscn`을 열고 씬 트리의 루트 `Arena`를 선택한 뒤 인스펙터의 **Bounds**에서 조정합니다. 카메라 확대율은 실행 시 영역/창 크기에 맞춰 계산됩니다.

시퀀스 방식을 확인할 때는 `dev_combat_timing.tres`의 **Attack End Condition**을 **Sequence Finished**로 설정하고 반드시 **Attack Pattern** 참조가 있는지 확인합니다. 패턴의 마지막 투사체가 퇴장해야 행동 단계로 전환합니다. 변경은 작업 브랜치에서 검토하고, 단순 확인을 위해 미정인 전투 규칙이나 공유 Resource의 실행 상태를 수정하지 않습니다.

개발용 키를 바꾸려면 **프로젝트(Project) → 프로젝트 설정(Project Settings) → 입력 맵(Input Map) → combat_dash**의 이벤트를 편집합니다. 현재 Space는 사용자의 이번 개발용 선택이며 최종 입력 규칙은 미정입니다.
