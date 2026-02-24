extends Resource
class_name ItemData

@export var name: String = ""
@export_multiline var discription: String = ""
@export_range(1, 99, 1) var max_stack: int = 1
@export var texture: AtlasTexture
