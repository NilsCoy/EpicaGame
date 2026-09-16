extends Node
## Менеджер сетевой синхронизации инвентарей
## Сервер — единственный источник истины
## Клиент отправляет действие → сервер изменяет InventoryData → сервер отправляет snapshot → клиент обновляется

signal inventory_snapshot_received(inventory_name: String, data: Dictionary)

## Сериализация SlotData в Dictionary
func serialize_slot_data(slot_data: SlotData) -> Dictionary:
	if slot_data == null or slot_data.item_data == null:
		return {
			"has_item": false,
			"item_category": slot_data.item_category if slot_data else "all"
		}
	
	return {
		"has_item": true,
		"item_type": slot_data.item_data.type,
		"quantity": slot_data.quantity,
		"item_category": slot_data.item_category
	}

## Десериализация Dictionary в SlotData
func deserialize_slot_data(data: Dictionary, inventory_data: InventoryData) -> SlotData:
	var slot := SlotData.new()
	slot.item_category = data.get("item_category", "all")
	
	if data.get("has_item", false):
		var item_type: String = data.get("item_type", "")
		slot.item_data = ItemData.new().find_item(item_type)
		slot.quantity = data.get("quantity", 1)
	
	return slot

## Сериализация InventoryData в Dictionary
func serialize_inventory_data(inventory_data: InventoryData) -> Dictionary:
	var slots_data: Array = []
	for slot_data in inventory_data.slot_datas:
		slots_data.append(serialize_slot_data(slot_data))
	
	return {
		"inv_name": inventory_data.inv_name,
		"grid_size": {"x": inventory_data.grid_size.x, "y": inventory_data.grid_size.y},
		"single_slots": inventory_data.single_slots,
		"slots": slots_data
	}

## Десериализация Dictionary в InventoryData
func deserialize_inventory_data(data: Dictionary, inventory_data: InventoryData) -> void:
	inventory_data.inv_name = data.get("inv_name", inventory_data.inv_name)
	
	var grid_size_data: Dictionary = data.get("grid_size", {})
	if grid_size_data.has("x") and grid_size_data.has("y"):
		inventory_data.grid_size = Vector2i(grid_size_data.x, grid_size_data.y)
	
	inventory_data.single_slots = data.get("single_slots", false)
	
	var slots_data: Array = data.get("slots", [])
	inventory_data.slot_datas.clear()
	
	for slot_dict in slots_data:
		inventory_data.slot_datas.append(deserialize_slot_data(slot_dict, inventory_data))
	
	inventory_data.init_inventory()
	inventory_data.inventory_update.emit(inventory_data)

## [Клиент] Отправляет действие с инвентарем на сервер
func send_inventory_action_to_server(
	inventory_name: String,
	action: String,
	index: int,
	target_index: int = -1,
	item_type: String = "",
	quantity: int = 0
) -> void:
	if not multiplayer.is_server():
		_rpc_send_inventory_action_to_server.rpc_id(
			1,
			inventory_name,
			action,
			index,
			target_index,
			item_type,
			quantity
		)

## [Сервер] Получает действие от клиента и обрабатывает его
@rpc("any_peer", "reliable", "call_local")
func _rpc_send_inventory_action_to_server(
	player_id: int,
	inventory_name: String,
	action: String,
	index: int,
	target_index: int,
	item_type: String,
	quantity: int
) -> void:
	if not multiplayer.is_server():
		return
	
	var sender_id := multiplayer.get_remote_sender_id()
	var player := _get_player_by_id(sender_id)
	
	if player == null or not player.has_node("Inventory"):
		return
	
	var inventory_component := player.get_node("Inventory") as InventoryEntityComponent
	if inventory_component == null:
		return
	
	var inventory_data: InventoryData = _get_inventory_by_name(inventory_component, inventory_name)
	if inventory_data == null:
		return
	
	# Обрабатываем действие на сервере
	_process_inventory_action_on_server(inventory_data, action, index, target_index, item_type, quantity)
	
	# Отправляем snapshot всем клиентам
	_broadcast_inventory_snapshot(inventory_name, serialize_inventory_data(inventory_data))

## Обработка действия на сервере
func _process_inventory_action_on_server(
	inventory_data: InventoryData,
	action: String,
	index: int,
	target_index: int,
	item_type: String,
	quantity: int
) -> void:
	match action:
		"grab":
			inventory_data.grab_slot_data(index)
		"grab_half":
			inventory_data.grab_hafl_slot_data(index)
		"drop":
			# Для drop нужен grabbed_slot_data, который должен быть передан
			pass # Обработка требует дополнительного контекста
		"transfer":
			if target_index >= 0:
				inventory_data.transfer_slot_data(index, inventory_data)

## Получение инвентаря по имени из компонента
func _get_inventory_by_name(inventory_component: InventoryEntityComponent, inv_name: String) -> InventoryData:
	if inv_name == "PlayerInventory":
		return inventory_component.player_inventory
	elif inv_name == "EquipInventory":
		return inventory_component.equip_inventory
	return null

## Получение игрока по ID
func _get_player_by_id(player_id: int) -> Node:
	var players_node := get_tree().root.get_node("Main/Map/Players")
	if players_node == null:
		return null
	
	for player in players_node.get_children():
		if player.player_id == player_id:
			return player
	return null

## [Сервер] Отправляет snapshot инвентаря всем клиентам
func _broadcast_inventory_snapshot(inventory_name: String, data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_rpc_receive_inventory_snapshot.rpc(inventory_name, data)

## [Клиент] Получает snapshot инвентаря от сервера
@rpc("authority", "reliable", "call_local")
func _rpc_receive_inventory_snapshot(inventory_name: String, data: Dictionary) -> void:
	inventory_snapshot_received.emit(inventory_name, data)

## [Клиент] Запрашивает инвентарь у сервера при подключении
func request_inventory_from_server(nickname: String) -> void:
	if not multiplayer.is_server():
		_rpc_request_inventory_from_server.rpc_id(1, nickname)

## [Сервер] Отправляет инвентарь игроку по запросу
@rpc("any_peer", "reliable", "call_local")
func _rpc_request_inventory_from_server(requester_id: int, nickname: String) -> void:
	if not multiplayer.is_server():
		return
	
	var sender_id := multiplayer.get_remote_sender_id()
	var player := _get_player_by_id(sender_id)
	
	if player == null:
		return
	
	# Загружаем инвентарь из сохранения
	var inventories := load_player_inventories(nickname)
	
	# Отправляем каждый инвентарь
	for inv_name in inventories:
		_rpc_receive_inventory_snapshot.rpc_id(sender_id, inv_name, inventories[inv_name])

## Сохранение инвентаря игрока на сервере
func save_player_inventories(nickname: String, player_inventory: InventoryData, equip_inventory: InventoryData) -> void:
	if not multiplayer.is_server():
		return
	
	var save_data := {
		"nickname": nickname,
		"PlayerInventory": serialize_inventory_data(player_inventory),
		"EquipInventory": serialize_inventory_data(equip_inventory)
	}
	
	var dir_path := FileManager.get_file_path("user://saves/inventories/", false)
	DirAccess.make_dir_recursive_absolute(dir_path)
	
	var file_path := dir_path + nickname + ".json"
	FileManager.save_json(file_path, save_data)

## Загрузка инвентаря игрока с сервера
func load_player_inventories(nickname: String) -> Dictionary:
	var dir_path := FileManager.get_file_path("user://saves/inventories/", false)
	var file_path := dir_path + nickname + ".json"
	
	var data := FileManager.read_json(file_path)
	if data.is_empty():
		# Возвращаем пустые инвентари если файл не найден
		return {}
	
	return {
		"PlayerInventory": data.get("PlayerInventory", {}),
		"EquipInventory": data.get("EquipInventory", {})
	}

## [Сервер] Сохраняет инвентари при выходе игрока
func on_player_disconnect(player_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	var player := _get_player_by_id(player_id)
	if player == null or not player.has_node("Inventory"):
		return
	
	var inventory_component := player.get_node("Inventory") as InventoryEntityComponent
	save_player_inventories(
		player.nickname,
		inventory_component.player_inventory,
		inventory_component.equip_inventory
	)
