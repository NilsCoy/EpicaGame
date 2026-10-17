extends EntityComponent
class_name DataEntityComponent

@export_group('Connect Nodes')
## Основная сущность
@export var enity: CharacterBody3D
## Компонент здоровья
@export var health_component: HealthEntityComponent
## Компонент энергии
@export var energy_component: EnergyEntityComponent
## Компонент инвентаря
@export var inventory_component: InventoryEntityComponent

@export_group('Base Attribures')
@export_subgroup('Armor')
## Защита брони
@export_range(0, 100, 0.1, "suffix:%") var base_defense: float = 0
## Защита от жары
@export_range(0, 100, 0.1, "suffix:%") var base_heat_defense: float = 0
## Защита от холода
@export_range(0, 100, 0.1, "suffix:%") var base_cold_defense: float = 0
## Вес брони
@export var base_weight: int = 1

@export_subgroup('Weapon')
## Урон
@export_range(0, 200, 0.1, "suffix:hp") var base_damage: float = 1
## Колющий урон
@export_range(0, 100, 0.1, "suffix:%") var base_stabbing_damage: float = 50
## Вертикальный урон
@export_range(0, 100, 0.1, "suffix:%") var base_vertical_damage: float = 50
## Горизонтальный урон
@export_range(0, 100, 0.1, "suffix:%") var base_horisontal_damage: float = 50
## Скорость атаки
@export var base_attack_speed: float = 1.0
## Шанс крита
@export_range(0, 100, 0.1, "suffix:%") var base_critical_chance: float = 25
## Множитель крита
@export var base_critical_multiplier: float = 1.5

static func get_component_type() -> String:
	return "DataEntityComponent"

func calculate_damage(dmg: float) -> float:
	var items_properties: Dictionary = inventory_component.get_equip_properties()
	
	var defence: float = base_defense
	
	for item: String in items_properties.keys():
		if items_properties[item].has('defense'): defence += items_properties[item].get('defense')
	
	var health: float = health_component.value
	dmg -= (dmg*(defence/100))
	
	return dmg

func calculate_attack(weapon_type: String, attack_type: String) -> float:
	var items_properties: Dictionary = inventory_component.get_equip_properties()
	
	var damage: float = 0
	var stabbing_damage: float = 0
	var vertical_damage: float = 0
	var horisontal_damage: float = 0
	var critical_chance: float = 0
	var critical_multiplier: float = 0
	
	var foot_damage: float = 0.1
	var guard_damage: float = 0.1
	
	var item: Dictionary = items_properties[weapon_type]
	if item.has('damage'): damage += item.get('damage')
	if item.has('stabbing_damage'): stabbing_damage += item.get('stabbing_damage')
	if item.has('vertical_damage'): vertical_damage += item.get('vertical_damage')
	if item.has('horisontal_damage'): horisontal_damage += item.get('horisontal_damage')
	if item.has('critical_chance'): critical_chance += item.get('critical_chance')
	if item.has('critical_multiplier'): critical_multiplier += item.get('critical_multiplier')
	
	match attack_type:
		'stabbing':
			damage += damage*(stabbing_damage/100)
		'vertical':
			damage += damage*(vertical_damage/100)
		'horisontal':
			damage += damage*(horisontal_damage/100)
		'foot':
			damage += damage*(foot_damage/100)
		'guard':
			damage += damage*(guard_damage/100)
	
	var random: float = randf_range(0, 1)
	print(random, ' ', critical_chance/100)
	if critical_chance/100 > random:
		damage += damage*critical_multiplier
	
	return damage
