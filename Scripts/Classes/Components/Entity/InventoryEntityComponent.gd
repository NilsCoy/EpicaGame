extends EntityComponent
class_name InventoryEntityComponent

## Экипировка изменилась (на сервере — после изменения инвентаря, на клиенте — после синхронизации)
signal equipment_changed(equiped: Array[String])

const SERVER_PEER: int = 1

## Интерфейс с инвентарем
@export var node_inventory: Node

## Слот шлема
@export var head: BoneAttachment3D
## Слот брони
@export var body: MeshInstance3D
## Слот основного оружия
@export var right_equip: Node3D
## Слот дополнительного оружия
@export var left_equip: Node3D

## Инвентарь игрока
var player_inventory: InventoryData:
	get:
		return node_inventory.player_inventory.inventory_data
## Экипировка игрока
var equip_inventory: InventoryData:
	get:
		return node_inventory.player_inventory.equip_data

## Типы надетых предметов по слотам экипировки.
## Источник — серверный equip_data, клиенты получают массив по RPC от сервера
var equiped: Array[String] = [
	'', '',
	'', '',
	'', '',
	'',
]
## Что сейчас отображается на модели по слотам (чтобы не пересоздавать модели без изменений)
var _shown: Array[String] = []
## Пиры, у которых уже создан этот игрок и которые ждут обновления экипировки (только на сервере)
var _listeners: Array[int] = []

static func get_component_type() -> String:
	return "InventoryEntityComponent"

func _ready() -> void:
	_shown.resize(equiped.size())
	_shown.fill('')
	if multiplayer.is_server():
		equip_inventory.inventory_update.connect(_on_equip_inventory_update)
		_on_equip_inventory_update(equip_inventory)
		# На хосте модель тоже нужно показать (на клиентах это делает _sync_equiped)
		_apply_equiped(equiped)
	else:
		# Клиент сам запрашивает экипировку: сервер не может слать RPC узлу,
		# которого у клиента еще нет (игрок создается через add_player позже)
		_request_equiped.rpc_id(SERVER_PEER)

## Собираем все характеристики экипировки в один массив
func get_equip_properties() -> Dictionary:
	var properties: Dictionary
	for i: int in range(equip_inventory.slot_datas.size()):
		var item: ItemData = equip_inventory.slot_datas[i].item_data
		if item != null:
			properties[item.type] = item.get_properties()
	return properties

## Надетые предметы: индекс слота -> ItemData (только непустые слоты).
## На сервере берется из equip_data, на клиенте — из ItemRegistry по синхронизированным типам
func get_equip_items() -> Dictionary[int, ItemData]:
	var items: Dictionary[int, ItemData] = {}
	for i: int in range(equiped.size()):
		if equiped[i] != '':
			var item: ItemData = ItemRegistry.get_item(equiped[i])
			if item != null:
				items[i] = item
	return items

## Вызывается при обновлении инвентаря на сервере, рассылает изменения экипировки
func _on_equip_inventory_update(inventory_data: InventoryData) -> void:
	var debug: bool = false
	if not multiplayer.is_server():
		return

	var new_equiped: Array[String] = []
	new_equiped.resize(equiped.size())
	new_equiped.fill('')
	for i: int in range(mini(inventory_data.slot_datas.size(), new_equiped.size())):
		var item: ItemData = inventory_data.slot_datas[i].item_data
		if item != null:
			new_equiped[i] = item.type

	if new_equiped == equiped:
		return

	if debug:
		print("[Equip] %s: %s -> %s" % [get_parent().get_parent().name, equiped, new_equiped])

	equiped = new_equiped
	_apply_equiped(equiped)
	equipment_changed.emit(equiped)

	for peer: int in _listeners.duplicate():
		_send_equiped(peer)

## Клиент: запрос текущей экипировки игрока (при появлении игрока у клиента)
@rpc("any_peer", "call_remote", "reliable")
func _request_equiped() -> void:
	if not multiplayer.is_server():
		return
	var peer: int = multiplayer.get_remote_sender_id()
	if not _listeners.has(peer):
		_listeners.append(peer)
	_send_equiped(peer)

func _send_equiped(peer: int) -> void:
	if not multiplayer.get_peers().has(peer):
		_listeners.erase(peer)
		return
	_sync_equiped.rpc_id(peer, PackedStringArray(equiped))

## Сервер -> клиент: актуальная экипировка. Передаются типы предметов (строки), а не ресурсы.
## Узлом игрока владеет клиент, поэтому "any_peer" + проверка, что прислал сервер
@rpc("any_peer", "call_remote", "reliable")
func _sync_equiped(types: PackedStringArray) -> void:
	var debug: bool = false
	if multiplayer.get_remote_sender_id() != SERVER_PEER:
		return

	var new_equiped: Array[String] = []
	new_equiped.resize(equiped.size())
	new_equiped.fill('')
	for i: int in range(mini(types.size(), new_equiped.size())):
		new_equiped[i] = types[i]

	if debug:
		print("[Equip] %s получил экипировку: %s" % [get_parent().get_parent().name, new_equiped])

	equiped = new_equiped
	_apply_equiped(equiped)
	equipment_changed.emit(equiped)

## Обновляет модель только в тех слотах, которые изменились
func _apply_equiped(types: Array[String]) -> void:
	for i: int in range(types.size()):
		if _shown[i] != types[i]:
			_equip_item(i, types[i])
			_shown[i] = types[i]

## Отображение предмета в слоте. Сначала слот всегда очищается,
## поэтому при смене предмета старая модель не остается
func _equip_item(index: int, item_type: String) -> void:
	var item: ItemData = ItemRegistry.get_item(item_type)
	match index:
		0:
			_clear_children(head)
			if item != null:
				var armor_component: ArmorItemComponent = item.get_component(ArmorItemComponent)
				if armor_component != null:
					var helmet: MeshInstance3D = load(armor_component.model_path).instantiate()
					head.add_child(helmet)
		1:
			_clear_children(body)
			if item != null:
				var armor_component: ArmorItemComponent = item.get_component(ArmorItemComponent)
				if armor_component != null:
					var chest: MeshInstance3D = load(armor_component.model_path).instantiate()
					chest.skeleton = body.get_parent().get_path()
					body.add_child(chest)
		2:
			_equip_weapon(right_equip, item)
		3:
			_equip_weapon(left_equip, item)

func _equip_weapon(equip: Node3D, item: ItemData) -> void:
	var weapon_component: WeaponItemComponent = item.get_component(WeaponItemComponent) if item != null else null
	if weapon_component == null:
		equip.hide()
		return
	equip.texture = item.texture
	equip.pivot = weapon_component.pivot
	equip.collision_size = weapon_component.collision_size
	equip.collision_offset = weapon_component.collision_offset
	equip.start_attack = weapon_component.start_attack
	equip.end_attack = weapon_component.end_attack
	equip.show()
	equip.rebuild()

## Удаляет модели сразу (remove_child), а не только в конце кадра,
## чтобы при быстрой смене предметов старая и новая модели не накладывались
func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
