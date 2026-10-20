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

func save_data() -> Dictionary:
	var data: Dictionary = super.save_data()
	var effects_data: Array = []
	for effect: EffectComponent in effects:
		if effect != null:
			effects_data.append(effect.save_data())
	data['effects'] = effects_data
	return data

func load_data(data: Dictionary) -> void:
	super.load_data(data)
	var effects_data: Variant = data.get('effects', [])
	if not(effects_data is Array):
		return
	effects.clear()
	for effect_data: Variant in effects_data:
		if effect_data is Dictionary:
			var effect: EffectComponent = EffectComponent.new()
			effect.load_data(effect_data)
			effects.append(effect)
