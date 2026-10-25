extends Resource
class_name ItemComponent

## Базовый класс для всех компонентов
func get_component_type() -> String:
	return "ItemComponent"

func get_properties() -> Dictionary:
	return {}

## Данные компонента в виде словаря (для RPC и сохранения).
## Ресурс целиком по RPC передать нельзя, поэтому передаются только простые типы:
## числа, строки, массивы. Векторы хранятся массивами, как в save_data() игрока
func save_data() -> Dictionary:
	return {
		'component_type': get_component_type(),
	}

## Загрузка данных компонента из словаря save_data()
func load_data(data: Dictionary) -> void:
	pass

## Создает компонент нужного класса по словарю save_data()
static func create_from_data(data: Dictionary) -> ItemComponent:
	var component: ItemComponent
	match str(data.get('component_type', '')):
		'ArmorItemComponent': component = ArmorItemComponent.new()
		'WeaponItemComponent': component = WeaponItemComponent.new()
		'ConsumableItemComponent': component = ConsumableItemComponent.new()
		_: component = ItemComponent.new()
	component.load_data(data)
	return component

static func vector2_to_array(vector: Vector2) -> Array:
	return [vector.x, vector.y]

static func vector3_to_array(vector: Vector3) -> Array:
	return [vector.x, vector.y, vector.z]

static func array_to_vector2(value: Variant, default: Vector2) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Vector2:
		return value
	return default

static func array_to_vector3(value: Variant, default: Vector3) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Vector3:
		return value
	return default
