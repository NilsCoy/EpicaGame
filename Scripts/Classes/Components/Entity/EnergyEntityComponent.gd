extends RangeEntityComponent
class_name EnergyEntityComponent

signal empty(reason: String)

@rpc("any_peer", "reliable", "call_local")
func set_value(new_value: float, reason: String) -> void:
	super.set_value(new_value, reason)
	if value <= 0:
		empty_value(reason)

@rpc("any_peer", "reliable", "call_local")
func empty_value(reason: String) -> void:
	emit_signal("empty", reason)

static func get_component_type() -> String:
	return "EnergyEntityComponent"
