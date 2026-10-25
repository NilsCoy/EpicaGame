extends EntityComponent
class_name DataEntityComponent

## Характеристики пересчитаны (на сервере) или получены от сервера (на клиенте)
signal stats_updated(stats: Dictionary)

const SERVER_PEER: int = 1

@export_group('Connect Nodes')
## Основная сущность
@export var entity: CharacterBody3D
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

## Итоговые характеристики (база + экипировка). Считает сервер, клиент получает по RPC
var stats: Dictionary = {}
## Данные надетых предметов: индекс слота экипировки -> ItemData.save_data()
var equip_items: Dictionary = {}
## Владелец уже запросил характеристики, значит узел игрока у него создан (только на сервере)
var _owner_ready: bool = false

static func get_component_type() -> String:
	return "DataEntityComponent"

func _ready() -> void:
	stats = get_base_stats()
	if multiplayer.is_server():
		inventory_component.equipment_changed.connect(_on_equipment_changed)
		update_stats()
	elif is_multiplayer_authority():
		# Характеристики нужны только владельцу; запрос идет после появления узла у клиента
		_request_stats.rpc_id(SERVER_PEER)

# =====================================================
# СИНХРОНИЗАЦИЯ (сервер -> игрок)
# =====================================================

func _on_equipment_changed(_equiped: Array[String]) -> void:
	update_stats()

## Сервер: пересчет характеристик по экипировке и отправка владельцу
func update_stats() -> void:
	if not multiplayer.is_server():
		return
	equip_items = _collect_equip_items()
	stats = calculate_stats(equip_items)
	stats_updated.emit(stats)
	_send_stats()

## Клиент-владелец: запрос характеристик у сервера
@rpc("any_peer", "call_remote", "reliable")
func _request_stats() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	_owner_ready = true
	_send_stats()

func _send_stats() -> void:
	var peer: int = get_multiplayer_authority()
	if not _owner_ready or not multiplayer.get_peers().has(peer):
		return
	_sync_stats.rpc_id(peer, stats, equip_items)

## Сервер -> игрок. Передаются только словари (save_data предметов и компонентов),
## потому что RPC не умеет передавать объекты (ItemData, ItemComponent) целиком
@rpc("any_peer", "call_remote", "reliable")
func _sync_stats(new_stats: Dictionary, new_equip_items: Dictionary) -> void:
	var debug: bool = false
	if multiplayer.get_remote_sender_id() != SERVER_PEER:
		return
	stats = new_stats
	equip_items = new_equip_items
	if debug:
		print("[Stats] %s: %s" % [entity.name, stats])
	stats_updated.emit(stats)

## Надетые предметы в виде словарей: индекс слота -> ItemData.save_data()
func _collect_equip_items() -> Dictionary:
	var items: Dictionary = {}
	var equip_inventory: InventoryData = inventory_component.equip_inventory
	for i: int in range(equip_inventory.slot_datas.size()):
		var item: ItemData = equip_inventory.slot_datas[i].item_data
		if item != null:
			items[i] = item.save_data()
	return items

## Восстановление предмета, полученного по RPC (компоненты создаются из словарей)
func get_equip_item(index: int) -> ItemData:
	if not equip_items.has(index):
		return null
	return ItemData.create_from_data(equip_items[index])

# =====================================================
# РАСЧЕТ ХАРАКТЕРИСТИК
# =====================================================

func get_base_stats() -> Dictionary:
	return {
		'defense': base_defense,
		'heat_defense': base_heat_defense,
		'cold_defense': base_cold_defense,
		'weight': base_weight,
		'damage': base_damage,
		'stabbing_damage': base_stabbing_damage,
		'vertical_damage': base_vertical_damage,
		'horisontal_damage': base_horisontal_damage,
		'attack_speed': base_attack_speed,
		'critical_chance': base_critical_chance,
		'critical_multiplier': base_critical_multiplier,
	}

## Итоговые характеристики по словарям надетых предметов (индекс слота -> ItemData.save_data()).
## Защита и вес складываются со всей брони, атака берется с оружия в основной руке (слот 2)
func calculate_stats(items: Dictionary) -> Dictionary:
	var result: Dictionary = get_base_stats()

	for index: Variant in items:
		for component: Dictionary in _get_components(items[index], 'ArmorItemComponent'):
			for key: String in ['defense', 'heat_defense', 'cold_defense', 'weight']:
				result[key] += component.get(key, 0)

	if items.has(2):
		var weapons: Array[Dictionary] = _get_components(items[2], 'WeaponItemComponent')
		if not weapons.is_empty():
			for key: String in [
				'damage', 'stabbing_damage', 'vertical_damage', 'horisontal_damage',
				'attack_speed', 'critical_chance', 'critical_multiplier'
			]:
				result[key] = weapons[0].get(key, result[key])

	return result

## Данные компонентов нужного типа из ItemData.save_data()
func _get_components(item_data: Dictionary, component_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for component: Variant in item_data.get('components', []):
		if component is Dictionary and component.get('component_type', '') == component_type:
			result.append(component)
	return result

func calculate_damage(dmg: float) -> float:
	var defence: float = clampf(float(stats.get('defense', base_defense)), 0, 100)
	dmg -= (dmg*(defence/100))
	return dmg

## weapon_type — тип предмета оружия (item.type), без оружия считается по базовым характеристикам
func calculate_attack(weapon_type: String, attack_type: String) -> float:
	var debug: bool = false
	var weapon: Dictionary = get_base_stats()
	for index: Variant in equip_items:
		if equip_items[index].get('type', '') == weapon_type:
			var weapons: Array[Dictionary] = _get_components(equip_items[index], 'WeaponItemComponent')
			if not weapons.is_empty():
				weapon = weapons[0]
			break

	var damage: float = float(weapon.get('damage', base_damage))
	var stabbing_damage: float = float(weapon.get('stabbing_damage', base_stabbing_damage))
	var vertical_damage: float = float(weapon.get('vertical_damage', base_vertical_damage))
	var horisontal_damage: float = float(weapon.get('horisontal_damage', base_horisontal_damage))
	var critical_chance: float = float(weapon.get('critical_chance', base_critical_chance))
	var critical_multiplier: float = float(weapon.get('critical_multiplier', base_critical_multiplier))

	var foot_damage: float = 0.1
	var guard_damage: float = 0.1

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
	if debug:
		print("[Stats] crit roll: ", random, ' ', critical_chance/100)
	if critical_chance/100 > random:
		damage += damage*critical_multiplier

	return damage
