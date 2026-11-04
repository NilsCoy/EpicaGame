extends PanelContainer
class_name ToolPanel

@export var tool_type: String = 'sphere'

func get_tool() -> Dictionary:
	var tool_data: Dictionary
	
	tool_data['tool_type'] = tool_type
	
	return tool_data
