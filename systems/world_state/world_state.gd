
extends Node

signal state_changed

var _flags: Dictionary = {}
var _counters: Dictionary = {}
var _outcomes: Dictionary = {}


func _ready() -> void:
	SaveManager.register_section(
		"world_state",
		Callable(self, "create_snapshot"),
		Callable(self, "validate_snapshot"),
		Callable(self, "restore_snapshot")
	)


# 참/거짓 기록: 중요한 정보 발견, 사건 발생 등
func set_flag(id: String, value: bool) -> void:
	_flags[id] = value
	state_changed.emit()


func get_flag(id: String) -> bool:
	return bool(_flags.get(id, false))


# 누적 기록: 전체 처치 수, 지역별 처치 수 등
func add_counter(id: String, amount: int = 1) -> void:
	_counters[id] = get_counter(id) + amount
	state_changed.emit()


func get_counter(id: String) -> int:
	return int(_counters.get(id, 0))


# 중요한 조우·사건의 결과 기록
func set_outcome(id: String, result: String) -> void:
	_outcomes[id] = result
	state_changed.emit()


func get_outcome(id: String) -> String:
	return str(_outcomes.get(id, ""))


func create_snapshot() -> Dictionary:
	return {
		"flags": _flags.duplicate(true),
		"counters": _counters.duplicate(true),
		"outcomes": _outcomes.duplicate(true)
	}


func validate_snapshot(data: Variant) -> bool:
	if not data is Dictionary:
		return false

	var flags: Variant = data.get("flags", {})
	var counters: Variant = data.get("counters", {})
	var outcomes: Variant = data.get("outcomes", {})

	if not flags is Dictionary:
		return false
	if not counters is Dictionary:
		return false
	if not outcomes is Dictionary:
		return false

	for value in flags.values():
		if not value is bool:
			return false

	for value in counters.values():
		if not (value is int or value is float):
			return false
		if not is_finite(float(value)):
			return false
		if float(value) != floor(float(value)):
			return false

	for value in outcomes.values():
		if not value is String:
			return false

	return true


func restore_snapshot(data: Dictionary) -> void:
	var flags: Dictionary = data.get("flags", {})
	var counters: Dictionary = data.get("counters", {})
	var outcomes: Dictionary = data.get("outcomes", {})

	_flags = flags.duplicate(true)
	_counters.clear()

	for id in counters:
		_counters[id] = int(counters[id])

	_outcomes = outcomes.duplicate(true)
	state_changed.emit()
