extends Node

@export var starting_scene: PackedScene
@export var field_scene: PackedScene
@export var combat_scene: PackedScene

@onready var scene_host: Node = $SceneHost

var active_scene: Node = null
var _suspended_field: Node = null
var _active_request: EncounterRequest = null
var _encounter_transition_pending: bool = false


func _ready() -> void:
	if starting_scene == null:
		push_error("시작 장면이 지정되지 않았습니다.")
		return

	var title: Node = starting_scene.instantiate()
	if not title.has_signal("start_requested"):
		push_error("타이틀 시작 신호가 없습니다.")
		title.queue_free()
		return

	title.connect("start_requested", Callable(self, "_on_start_requested"))
	_replace_active_scene(title)


func _replace_active_scene(next_scene: Node) -> void:
	if is_instance_valid(active_scene):
		scene_host.remove_child(active_scene)
		active_scene.queue_free()

	active_scene = next_scene
	scene_host.add_child(active_scene)


func _on_start_requested() -> void:
	if field_scene == null:
		push_error("필드 장면이 지정되지 않았습니다.")
		return

	var field: Node = field_scene.instantiate()
	if not field.has_signal("encounter_requested"):
		push_error("필드 조우 신호가 없습니다.")
		field.queue_free()
		return

	field.connect("encounter_requested", Callable(self, "_on_encounter_requested"))
	_replace_active_scene(field)


func _on_encounter_requested(request: EncounterRequest) -> void:
	if _suspended_field != null or _encounter_transition_pending:
		return

	if request == null or request.definition == null \
	or not request.definition.is_configured():
		push_error("유효하지 않은 조우 요청입니다.")
		return

	# Area2D.body_entered runs within a physics callback.
	# Never detach the field (with CollisionObjects) during that callback.
	_encounter_transition_pending = true
	_begin_encounter.call_deferred(request)


func _begin_encounter(request: EncounterRequest) -> void:
	_encounter_transition_pending = false

	if _suspended_field != null or not is_instance_valid(active_scene):
		return

	if active_scene.get_parent() != scene_host:
		return

	if combat_scene == null:
		push_error("전투 장면이 지정되지 않았습니다.")
		return

	var combat: Node = combat_scene.instantiate()
	if not combat.has_signal("development_exit_requested") \
	or not combat.has_method("set_encounter"):
		push_error("전투 장면 인터페이스가 일치하지 않습니다.")
		combat.queue_free()
		return

	combat.connect("development_exit_requested", Callable(self, "_on_development_exit_requested"))

	# This now runs after the physics callback, in deferred idle time.
	# Keep the field instance so it can be restored unchanged.
	_suspended_field = active_scene
	scene_host.remove_child(active_scene)
	active_scene = null
	_active_request = request

	_replace_active_scene(combat)
	combat.call("set_encounter", request)

	print("조우 연결: ", request.definition.encounter_id,
		" / 지역: ", request.region_id,
		" / 배치: ", request.spawn_id)


func _on_development_exit_requested() -> void:
	if not is_instance_valid(_suspended_field):
		push_error("복귀할 필드 장면이 없습니다.")
		return

	var previous_field: Node = _suspended_field
	_suspended_field = null
	_active_request = null

	# This is NOT an encounter outcome. No WorldState mutations.
	_replace_active_scene(previous_field)
