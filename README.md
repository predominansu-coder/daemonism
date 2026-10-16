# DAEMONISM

Windows PC / Steam 출시를 목표로 개발 중인 2D 탑다운 스토리 판타지 RPG입니다. 한 회차 약 30시간을 목표로 하며, 현재는 필드 조우와 독립 전투의 기반을 개발하는 단계입니다. 30시간 분량의 콘텐츠나 완성된 RPG 프레임워크가 구현된 상태는 아닙니다.

프로젝트 기준은 **Godot 4.7.2 / GDScript / Forward+**입니다. 실제 검증 범위는 [구현·검증 현황](docs/IMPLEMENTATION_STATUS.md)을 확인하세요.

## 실행

1. Godot 프로젝트 관리자에서 이 저장소의 `project.godot`을 가져옵니다.
2. 프로젝트를 열고 임포트가 끝나면 `F5`를 누릅니다.
3. 타이틀에서 게임을 시작하고 방향키로 이동해 순찰 적과 접촉합니다.
4. 전투에서는 방향키 이동과 **Space 대쉬**를 사용할 수 있습니다. Space는 사용자가 이번 개발용 키로 선택한 값이며 최종 키 배치는 미정입니다.
5. `개발용 복귀 (전투 결과 없음)` 버튼으로 필드로 돌아갑니다.

현재 전투는 경계·고정 카메라·이동·무적 없는 대쉬·예고 후 투사체 발사·공격/행동 단계 연결을 다룹니다. 투사체 접촉 신호는 있지만 피해·HP·Q/E·승패·체크포인트는 아직 구현하지 않았습니다. 행동 단계의 이동/대쉬도 개발 편의를 위한 잠정 동작입니다.

## 개발 문서

- [문서 안내 및 근거 우선순위](docs/README.md)
- [사용자 결정과 아키텍처 재검토](docs/ARCHITECTURE_BASELINE.md)
- [전투 책임과 확장 계약](docs/COMBAT_PHASE_BASELINE.md)
- [실행·설정·검증 방법](docs/DEVELOPMENT.md)
- [구현·검증 현황 및 다음 단계](docs/IMPLEMENTATION_STATUS.md)
- [작업 지침](AGENTS.md)

CLI 검증의 진입점은 `tests/run_headless.sh`입니다. Windows 화면·조작과 Forward+ 렌더링 확인은 자동 검증과 별도로 필요합니다.
