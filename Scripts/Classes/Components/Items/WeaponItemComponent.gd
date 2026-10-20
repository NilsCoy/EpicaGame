extends ItemComponent
class_name WeaponItemComponent

@export_group('Use property')
## Урон
@export_range(0, 200, 0.1, "suffix:hp") var damage: float = 10
## Колющий урон
@export_range(0, 100, 0.1, "suffix:%") var stabbing_damage: float = 50
## Вертикальный урон
@export_range(0, 100, 0.1, "suffix:%") var vertical_damage: float = 50
## Горизонтальный урон
@export_range(0, 100, 0.1, "suffix:%") var horisontal_damage: float = 50
## Скорость атаки
@export var attack_speed: float = 1.0
## Шанс крита
@export_range(0, 100, 0.1, "suffix:%") var critical_chance: float = 25
## Множитель крита
@export var critical_multiplier: float = 1.5
## Число получаемых урон целей
@export var count_targets: int = 1
## Тип оружия
@export_enum('one_hand', 'two_hand') var weapon_type: String = 'one_hand'

@export_group('Model property')
## Смещение объекта
@export var pivot: Vector2 = Vector2(8.0, 20.0)

## Размер бокса колизии
@export var collision_size: Vector3 = Vector3(0.3, 0.8, 0.3)
## Смещение бокса колизии
@export var collision_offset: Vector3 = Vector3(0, 0.6, 0)

## Время начала атаки (начало хитскана)
@export var start_attack: float = 0.5
## Время конца атаки (длина хитскана)
@export var end_attack: float = 0.5

func get_component_type() -> String:
	return "WeaponItemComponent"

func get_properties() -> Dictionary:
	var properties: Dictionary = super.get_properties()
	properties.merge(get_use_property())
	properties.merge(get_model_property())
	return properties

func get_use_property() -> Dictionary:
	return {
		'damage': damage,
		'stabbing_damage': stabbing_damage,
		'vertical_damage': vertical_damage,
		'horisontal_damage': horisontal_damage,
		'attack_speed': attack_speed,
		'critical_chance': critical_chance,
		'critical_multiplier': critical_multiplier,
		'count_targets': count_targets,
		'weapon_type': weapon_type,
	}

func get_model_property() -> Dictionary:
	return {
		'pivot': pivot,
		'collision_size': collision_size,
		'collision_offset': collision_offset,
		'start_attack': start_attack,
		'end_attack': end_attack,
	}

func save_data() -> Dictionary:
	var data: Dictionary = super.save_data()
	data.merge(get_use_property())
	data.merge({
		'pivot': vector2_to_array(pivot),
		'collision_size': vector3_to_array(collision_size),
		'collision_offset': vector3_to_array(collision_offset),
		'start_attack': start_attack,
		'end_attack': end_attack,
	})
	return data

func load_data(data: Dictionary) -> void:
	super.load_data(data)
	damage = float(data.get('damage', damage))
	stabbing_damage = float(data.get('stabbing_damage', stabbing_damage))
	vertical_damage = float(data.get('vertical_damage', vertical_damage))
	horisontal_damage = float(data.get('horisontal_damage', horisontal_damage))
	attack_speed = float(data.get('attack_speed', attack_speed))
	critical_chance = float(data.get('critical_chance', critical_chance))
	critical_multiplier = float(data.get('critical_multiplier', critical_multiplier))
	count_targets = int(data.get('count_targets', count_targets))
	weapon_type = str(data.get('weapon_type', weapon_type))
	pivot = array_to_vector2(data.get('pivot'), pivot)
	collision_size = array_to_vector3(data.get('collision_size'), collision_size)
	collision_offset = array_to_vector3(data.get('collision_offset'), collision_offset)
	start_attack = float(data.get('start_attack', start_attack))
	end_attack = float(data.get('end_attack', end_attack))
