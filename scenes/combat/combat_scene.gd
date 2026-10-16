extends Node2D

# Development-only return. This is not victory, E resolution or escape.
signal development_exit_requested

var _encounter: EncounterRequest

@onready var director: CombatDirector = $CombatDirector
@onready var encounter_label: Label = $HUD/UIRoot/CenterContainer/VBoxContainer/EncounterLabel
@onready var phase_label: Label = $HUD/UIRoot/CenterContainer/VBoxContainer/PhaseLabel
@onready var exit_button: Button = $HUD/UIRoot/CenterContainer/VBoxContainer/DevelopmentExitButton
@onready var action_window_hud: Control = $HUD/UIRoot/ActionWindowHUD
@onready var time_label: Label = $HUD/UIRoot/ActionWindowHUD/TimingContent/TimeLabel
@onready var time_bar: ProgressBar = $HUD/UIRoot/ActionWindowHUD/TimingContent/TimeBar


func _ready() -> void:
	exit_button.pressed.connect(_on_exit_pressed)
	director.phase_changed.connect(_on_phase_changed)
	director.action_time_changed.connect(_on_action_time_changed)
	director.action_window_expired.connect(_on_action_window_expired)
	action_window_hud.hide()
	_update_encounter_label()


# GameRoot calls this after the scene enters the tree.
func set_encounter(request: EncounterRequest) -> void:
	_encounter = request
	_update_encounter_label()

	if _encounter == null or _encounter.definition == null \
	or not _encounter.definition.is_configured():
		phase_label.text = "조우 설정 오류: 전투를 시작할 수 없습니다."
		push_error("전투 장면에 유효하지 않은 조우가 전달되었습니다.")
		return

	director.begin(_encounter.definition.combat_timing)


func _update_encounter_label() -> void:
	if _encounter == null or _encounter.definition == null:
		encounter_label.text = "조우 정보 준비 중"
		return

	var enemy_text := ", ".join(_encounter.definition.enemy_ids)
	encounter_label.text = "조우: %s\n적 ID: %s" % [
		str(_encounter.definition.encounter_id), enemy_text
	]


func _on_phase_changed(next_phase: int) -> void:
	match next_phase:
		CombatDirector.Phase.ENEMY_ATTACK:
			action_window_hud.hide()
			phase_label.text = "적 공격 단계\n(공격 패턴·피격 판정은 아직 미구현)"
		CombatDirector.Phase.PLAYER_ACTION:
			action_window_hud.show()
			phase_label.text = "공동 행동 단계\n(Q/E 행동 처리 연결 전)"
		CombatDirector.Phase.FINISHED:
			action_window_hud.hide()
			phase_label.text = "전투 종료"
		_:
			action_window_hud.hide()
			phase_label.text = "전투 준비 중"


func _on_action_time_changed(remaining: float, total: float) -> void:
	time_bar.max_value = total
	time_bar.value = remaining
	time_label.text = "행동 가능 시간  %.1f초" % remaining


func _on_action_window_expired() -> void:
	print("공동 행동 단계 시간 만료: 다음 공격 단계")


func _on_exit_pressed() -> void:
	director.stop()
	development_exit_requested.emit()
