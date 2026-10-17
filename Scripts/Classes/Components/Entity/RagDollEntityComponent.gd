extends EntityComponent
class_name RagDollEntityComponent

@export var model: Node3D

func generate_ragdoll() -> Node3D:
	var ragdoll: Node3D = model.duplicate()
	for child: Node3D in ragdoll.get_child(0).get_children():
		if child.is_class("PhysicalBoneSimulator3D"):
			child.active = true
			for child2: Node3D in child.get_children():
				if child2.get_child(0).is_class("CollisionShape3D"):
					child2.get_child(0).disabled = false
			break
	ragdoll.position = get_parent().get_parent().position
	var timer: Timer = Timer.new()
	timer.autostart = true
	timer.one_shot = true
	timer.wait_time = 10
	timer.timeout.connect(func() -> void: 
		ragdoll.queue_free()
	)
	ragdoll.add_child(timer)
	return ragdoll

@rpc("any_peer", "unreliable", "call_local")
func spawn_ragdoll() -> void:
	var ragdoll: Node3D = generate_ragdoll()
	get_tree().root.get_node('Main/Map').entities.add_child(ragdoll)
	await get_tree().create_timer(0.05, false).timeout
	for child: Node3D in ragdoll.get_child(0).get_children():
		if child.is_class("PhysicalBoneSimulator3D"):
			child.physical_bones_start_simulation()
			break

static func get_component_type() -> String:
	return "RagDollEntityComponent"
