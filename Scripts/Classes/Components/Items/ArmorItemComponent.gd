extends ItemComponent
class_name ArmorItemComponent

@export_group('Use property')
## Защита брони
@export_range(0, 100, 0.1, "suffix:%") var defense: float = 10
## Защита от жары
@export_range(0, 100, 0.1, "suffix:%") var heat_defense: float = 10
## Защита от холода
@export_range(0, 100, 0.1, "suffix:%") var cold_defense: float = 10
## Вес брони
@export var weight: int = 5

@export_group('Model property')
## Модель брони
@export_file_path() var model_path: String

func get_component_type() -> String:
	return "ArmorItemComponent"

func get_properties() -> Dictionary:
	var properties: Dictionary = super.get_properties()
	properties.merge(get_use_property())
	properties.merge(get_model_property())
	return properties

func get_use_property() -> Dictionary:
	return {
		'defense': defense,
		'heat_defense': heat_defense,
		'cold_defense': cold_defense,
		'weight': weight,
	}

func get_model_property() -> Dictionary:
	return {
		'model_path': model_path,
	}
