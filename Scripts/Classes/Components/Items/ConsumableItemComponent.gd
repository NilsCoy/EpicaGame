extends ItemComponent
class_name ConsumableItemComponent

## Эффекты использования
@export var effects: Array[EffectComponent]

func get_component_type() -> String:
	return "ConsumableItemComponent"

func get_properties() -> Dictionary:
	var properties: Dictionary = super.get_properties()
	properties.merge(get_use_property())
	return properties

func get_use_property() -> Dictionary:
	return {
		'effects': effects,
	}
