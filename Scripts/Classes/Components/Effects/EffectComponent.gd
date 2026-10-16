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
