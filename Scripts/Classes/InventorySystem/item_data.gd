extends Resource
class_name ItemData

## Тип предмета
@export var type: String = ""
## Категория предмета
@export_enum('head', 'chest', 'weapon', 'consumable', 'material', 'coin') var category: String = "material"
## Название предмета
@export var item_name: String = ""
## Описание предмета
@export_multiline var discription: String = ""
## Максимум предметов в слоте
@export_range(1, 99, 1) var max_stack: int = 1
## Размер предмета в milti-slots
@export var size: Vector2i = Vector2i(1, 1)
## Текстура предмета
@export var texture: AtlasTexture
## Поворот текстуры предмета
@export_range(-360, 360, 0.1, "radians_as_degrees") var texture_rotate: float = 0
## Размер текстуры предмета
@export var texture_scale: float = 1
## Список компонентов предмета
@export var components: Array[ItemComponent] = []

func get_component(component_class: Script) -> ItemComponent:
	for component: ItemComponent in components:
		if component.get_script() == component_class:
			return component
	return null

func has_component(component_class: Script) -> bool:
	return get_component(component_class) != null

func get_all_components() -> Array[ItemComponent]:
	return components.duplicate()

func get_properties() -> Dictionary:
	var properties: Dictionary
	for component: ItemComponent in components:
		properties.merge(component.get_properties())
	return properties

func find_item(type: String) -> ItemData:
	var files: Array = FileManager.get_files_in_directory(
		FileManager.get_file_path("Resources/Items/Data", true)
	)
	
	for file: String in files:
		if file.split(".")[0] == type:
			return load(FileManager.get_file_path(
				"Resources/Items/Data/" + file,
				true
			))
	return null
