extends EntityComponent
class_name RangeEntityComponent

signal changed_value(old_value: float, new_value: float, reason: String)
signal changed_max_value(old_value: float, new_value: float, reason: String)

#var _max_value: float = 100.0
#var _value: float = 100.0

@export var max_value: float = 100.0:
	get:
		return max_value
	set(new_max_value):
		var old_max_value: float = max_value
		max_value = new_max_value
		emit_signal("changed_max_value", old_max_value, max_value, "variable has been changed")

@export var value: float = 100.0:
	get:
		return value
	set(new_value):
		var old_value: float = value
		value = new_value
		emit_signal("changed_value", old_value, value, "variable has been changed")

@rpc("any_peer", "reliable", "call_local")
func set_value(new_value: float, reason: String) -> void:
	var old_value: float = value
	value = new_value
	emit_signal("changed_value", old_value, value, reason)

@rpc("any_peer", "reliable", "call_local")
func set_max_value(new_value: float, reason: String) -> void:
	var old_max_value: float = max_value
	max_value = new_value
	emit_signal("changed_max_value", old_max_value, max_value, reason)

static func get_component_type() -> String:
	return "RangeEntityComponent"
