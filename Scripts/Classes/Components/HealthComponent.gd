extends RangeComponent
class_name HealthComponent

signal damaged(dmg: float, to_target: Dictionary, from_target: Dictionary)
signal died(reason: String)

@rpc("any_peer", "reliable", "call_local")
func set_value(new_value: float, reason: String) -> void:
	super.set_value(new_value, reason)
	#if get_multiplayer_authority() != multiplayer.get_unique_id():
		#rpc_id(get_multiplayer_authority(), 'set_health', new_value, reason)
	if value <= 0:
		die(reason)

@rpc("any_peer", "reliable", "call_local")
func damage(from: Dictionary, dmg: float) -> void:
	#if get_multiplayer_authority() != multiplayer.get_unique_id():
		#rpc_id(get_multiplayer_authority(), 'take_damage', from, dmg)
	var reason: String = 'damage'
	var old_value: float = value
	value -= dmg
	emit_signal("damaged", dmg, get_parent().get_parent().save_data(), from)
	emit_signal("changed_value", old_value, value, reason)
	if value <= 0:
		die(reason)

@rpc("any_peer", "reliable", "call_local")
func die(reason: String) -> void:
	#if get_multiplayer_authority() != multiplayer.get_unique_id():
		#rpc_id(get_multiplayer_authority(), 'die', reason)
	emit_signal("died", reason)
	
