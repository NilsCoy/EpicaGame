extends EntityComponent
class_name EntityComponentContainer

#var components: Dictionary[String, Node]
@export var components: Array[EntityComponent]

func _ready() -> void:
	for child: Variant in get_children():
		if is_component(child):
			#components[child.name] = child
			components.append(child)

func is_component(node: Variant) -> bool:
	var component_name: String = node.name
	if 'Component' in component_name: return true
	else: return false

func has_component(component_class: Script) -> bool:
	if get_component(component_class) != null:
		return true
	return false

#func get_component(component_name: String) -> Node:
	#if component_name in components:
		#return components[component_name]
	#return null

func get_component(component_class: Script) -> EntityComponent:
	for component: EntityComponent in components:
		if component.get_script() == component_class:
			return component
	return null

func get_all_components() -> Array[EntityComponent]:
	return components.duplicate()

func get_component_type() -> String:
	return "EntityComponentContainer"
