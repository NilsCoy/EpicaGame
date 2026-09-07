extends Resource
class_name ItemData

@export var type: String = ""
@export var name: String = ""
@export_multiline var discription: String = ""
@export_range(1, 99, 1) var max_stack: int = 1
@export var size: Vector2i = Vector2i(1, 1)
@export var texture: AtlasTexture
@export var attributes: Dictionary = {}
