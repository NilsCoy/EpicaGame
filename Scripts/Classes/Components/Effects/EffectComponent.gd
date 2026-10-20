extends Resource
class_name EffectComponent

@export_enum(
	'heal',
	'regeneration',
	'damage',
	'poison',
) var effect_name: String

## Базовый класс для всех компонентов
func get_component_type() -> String:
	return "EffectComponent"

## Данные эффекта в виде словаря (для RPC и сохранения)
func save_data() -> Dictionary:
	return {
		'component_type': get_component_type(),
		'effect_name': effect_name,
	}

func load_data(data: Dictionary) -> void:
	effect_name = str(data.get('effect_name', effect_name))
