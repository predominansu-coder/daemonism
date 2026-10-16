
extends Node

@export_enum("SAVE", "LOAD")
var test_action: String = "SAVE"

const TEST_SLOT := 99


func _ready() -> void:
	if test_action == "SAVE":
		WorldState.set_flag("test.found_secret", true)
		WorldState.add_counter("test.kills", 3)
		WorldState.set_outcome(
			"test.important_enemy", "resolved"
		)

		if SaveManager.save_slot(TEST_SLOT):
			print("PASS: 테스트 데이터 저장 성공")
		else:
			push_error("FAIL: 테스트 데이터 저장 실패")

	elif test_action == "LOAD":
		if not SaveManager.load_slot(TEST_SLOT):
			push_error("FAIL: 데이터 불러오기 실패")
			return

		var success: bool = (
			WorldState.get_flag("test.found_secret")
			and WorldState.get_counter("test.kills") == 3
			and WorldState.get_outcome(
                "test.important_enemy"
			) == "resolved"
		)

		if success:
			print("PASS: 저장 데이터 복원 검증 성공")
		else:
			push_error("FAIL: 저장 데이터가 일치하지 않음")
