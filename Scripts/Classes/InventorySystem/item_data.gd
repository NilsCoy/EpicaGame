extends Resource
class_name ItemData

## Тип предмета
@export var type: String = ""
## Категория предмета
@export_enum('head', 'chest', 'weapon', 'consumable', 'material', 'coin', 'block') var category: String = 'material'
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

## Данные предмета в виде словаря (для RPC и сохранения): тип и данные всех компонентов.
## Сам ресурс ItemData (и его компоненты) по RPC не передается
func save_data() -> Dictionary:
	var components_data: Array = []
	for component: ItemComponent in components:
		if component != null:
			components_data.append(component.save_data())
	return {
		'type': type,
		'category': category,
		'item_name': item_name,
		'components': components_data,
	}

## Загрузка предмета из словаря save_data().
## Остальные поля (текстура, размер и т.д.) берутся из ресурса предмета в ItemRegistry
func load_data(data: Dictionary) -> void:
	type = str(data.get('type', type))
	var registry_item: ItemData = ItemRegistry.get_item(type) if type != '' else null
	if registry_item != null:
		max_stack = registry_item.max_stack
		size = registry_item.size
		texture = registry_item.texture
		texture_rotate = registry_item.texture_rotate
		texture_scale = registry_item.texture_scale
		discription = registry_item.discription
	category = str(data.get('category', category))
	item_name = str(data.get('item_name', item_name))

	var components_data: Variant = data.get('components', [])
	if components_data is Array:
		components = []
		for component_data: Variant in components_data:
			if component_data is Dictionary:
				components.append(ItemComponent.create_from_data(component_data))

## Создает предмет из словаря save_data()
static func create_from_data(data: Dictionary) -> ItemData:
	var item: ItemData = ItemData.new()
	item.load_data(data)
	return item

## Поиск предмета по типу (через кэш ItemRegistry, без сканирования директории)
func find_item(type: String) -> ItemData:
	return ItemRegistry.get_item(type)
