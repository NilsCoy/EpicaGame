extends Component
class_name ComponentContainer

var components: Dictionary[String, Node]

func _ready() -> void:
	for child: Variant in get_children():
		if is_component(child):
			components[child.name] = child

func is_component(node: Variant) -> bool:
	var component_name: String = node.name
	if 'Component' in component_name: return true
	else: return false

func has_component(component_name: String) -> bool:
	if get_component(component_name) != null:
		return true
	return false

func get_component(component_name: String) -> Node:
	if component_name in components.keys():
		return components[component_name]
	return null
