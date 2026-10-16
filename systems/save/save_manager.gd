
extends Node

const SAVE_DIRECTORY := "user://saves"
const SAVE_VERSION := 1

var _providers: Dictionary = {}
var _unclaimed_sections: Dictionary = {}


func register_section(
	section_id: String,
	snapshot_function: Callable,
	validate_function: Callable,
	restore_function: Callable
) -> void:
	if _providers.has(section_id):
		push_error("중복된 저장 섹션: " + section_id)
		return

	_providers[section_id] = {
		"snapshot": snapshot_function,
		"validate": validate_function,
		"restore": restore_function
	}


func _slot_path(slot_id: int) -> String:
	return SAVE_DIRECTORY + "/slot_%d.json" % slot_id


func save_slot(slot_id: int) -> bool:
	if slot_id < 1:
		push_error("잘못된 저장 슬롯 번호입니다.")
		return false

	var sections: Dictionary = _unclaimed_sections.duplicate(true)

	for section_id in _providers:
		var provider: Dictionary = _providers[section_id]
		var section_data: Variant = provider["snapshot"].call()

		if not provider["validate"].call(section_data):
			push_error("저장 데이터 검증 실패: " + section_id)
			return false

		sections[section_id] = section_data

	var document := {
		"version": SAVE_VERSION,
		"sections": sections
	}

	var directory_path := ProjectSettings.globalize_path(
		SAVE_DIRECTORY
	)

	if DirAccess.make_dir_recursive_absolute(directory_path) != OK:
		push_error("저장 폴더 생성 실패")
		return false

	var target_path := ProjectSettings.globalize_path(
		_slot_path(slot_id)
	)

	var temp_path := target_path + ".tmp"
	var backup_path := target_path + ".bak"

	var file := FileAccess.open(
		temp_path,
		FileAccess.WRITE
	)

	if file == null:
		push_error("임시 저장 파일 생성 실패")
		return false

	file.store_string(
	JSON.stringify(document, "\t")
)

	file.flush()
	var write_error := file.get_error()
	file.close()

	if write_error != OK:
		push_error("저장 데이터 쓰기 실패")
		return false

	if FileAccess.file_exists(target_path):
		if FileAccess.file_exists(backup_path):
			if DirAccess.remove_absolute(backup_path) != OK:
				push_error("이전 백업 파일 정리 실패")
				return false

		if DirAccess.rename_absolute(
			target_path, backup_path
		) != OK:
			push_error("기존 저장 파일 백업 실패")
			return false

	if DirAccess.rename_absolute(
		temp_path, target_path
	) != OK:
		push_error("새 저장 파일 확정 실패")

		if FileAccess.file_exists(backup_path) \
		and not FileAccess.file_exists(target_path):
			DirAccess.rename_absolute(
				backup_path, target_path
			)

		return false

	print("저장 성공: 슬롯 ", slot_id)
	return true


func load_slot(slot_id: int) -> bool:
	if slot_id < 1:
		return false

	var path := _slot_path(slot_id)

	if not FileAccess.file_exists(path):
		push_warning("저장 파일이 없습니다: " + path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("저장 파일을 열 수 없습니다.")
		return false

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		push_error("저장 파일 JSON 해석 실패")
		return false

	var document: Variant = json.data

	if not document is Dictionary:
		return false

	if document.get("version", -1) != SAVE_VERSION:
		push_error("지원하지 않는 저장 파일 버전")
		return false

	var sections: Variant = document.get("sections")

	if not sections is Dictionary:
		return false

	# 모든 등록 시스템을 검사한 뒤에만 데이터를 반영합니다.
	for section_id in _providers:
		var provider: Dictionary = _providers[section_id]
		var section_data: Variant = sections.get(
			section_id, {}
		)

		if not provider["validate"].call(section_data):
			push_error("불러오기 검증 실패: " + section_id)
			return false

	var preserved: Dictionary = sections.duplicate(true)

	for section_id in _providers:
		preserved.erase(section_id)

	for section_id in _providers:
		var provider: Dictionary = _providers[section_id]
		provider["restore"].call(
			sections.get(section_id, {})
		)

	_unclaimed_sections = preserved

	print("불러오기 성공: 슬롯 ", slot_id)
	return true
