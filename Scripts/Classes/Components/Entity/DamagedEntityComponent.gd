extends EntityComponent
class_name DamagedEntityComponent

@export var data_entity_component: DataEntityComponent

static func get_component_type() -> String:
	return "DamagedEntityComponent"

func damaged(dmg: float, to_target: Dictionary, from_target: Dictionary) -> void:
	var entity: CharacterBody3D = data_entity_component.entity
	if not(entity.animation.is_block()):
		var damage: float = data_entity_component.calculate_damage(dmg)
		data_entity_component.health_component.damage(from_target, damage)
