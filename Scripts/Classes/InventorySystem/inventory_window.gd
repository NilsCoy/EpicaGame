extends Control
class_name InventoryWindow

# Inventory
## Предмет в руке игрока (слот серверного курсора, обновляется снапшотом)
var grabbed_slot_data: SlotData = SlotData.new()
@export var grabbed_slot_container: Control
var grabbed_slot_offset: Vector2 = Vector2.ZERO
var grabbed_slot_last_id: int = -1
var grabbed_inv_last_data: InventoryData
## Серверный курсор игрока (однослотовый инвентарь player:<player_id>:cursor)
var cursor_data: InventoryData
## Инвентари, зарегистрированные этим окном
var _bound_inventory_ids: Array[String] = []

func init_inventory() -> void:
	grabbed_slot_container.hide()

func _exit_tree() -> void:
	for inventory_id: String in _bound_inventory_ids:
		InventoryNetwork.unregister_inventory(inventory_id)
	_bound_inventory_ids.clear()

func _physics_process(delta: float) -> void:
	if grabbed_slot_container.visible:
		grabbed_slot_container.global_position = get_global_mouse_position() + Vector2(5, 5)
	if visible == false or Input.is_action_just_pressed('esc'):
		if grabbed_slot_last_id != -1 and grabbed_inv_last_data != null:
				if not is_networked(grabbed_inv_last_data):
					grabbed_slot_data = grabbed_inv_last_data.drop_slot_data(grabbed_slot_data, grabbed_slot_last_id)
				elif grabbed_slot_data.item_data != null:
					request_drop(grabbed_inv_last_data, grabbed_slot_last_id, "all")
				grabbed_slot_last_id = -1
				grabbed_inv_last_data = null
				update_grabbed_slot()

	#if grabbed_slot_container.visible:
		#grabbed_slot_container.global_position = \
			#get_global_mouse_position() \
			#- grabbed_slot_offset \
			#+ Vector2(5, 5)

## Игрок, которому принадлежит окно (Player -> UI -> окно)
func get_owner_player() -> Node:
	return get_parent().get_parent()

## Копирует шаблон инвентаря из сцены (ресурсы сцены общие для всех игроков)
## и регистрирует его в сетевом слое под идентификатором игрока
func bind_inventory(inventory_data: InventoryData, kind: String) -> InventoryData:
	return register_inventory(inventory_data.duplicate_inventory(), kind)

## Регистрирует уже подготовленный инвентарь в сетевом слое
func register_inventory(inventory_data: InventoryData, kind: String) -> InventoryData:
	inventory_data = InventoryNetwork.register_player_inventory(get_owner_player(), kind, inventory_data)
	if inventory_data.inventory_id != "" and InventoryNetwork.get_inventory(inventory_data.inventory_id) == inventory_data:
		_bound_inventory_ids.append(inventory_data.inventory_id)
	return inventory_data

## Подключает серверный курсор игрока
func bind_cursor() -> void:
	cursor_data = InventoryNetwork.get_player_cursor(get_owner_player())
	if InventoryNetwork.get_inventory(cursor_data.inventory_id) == cursor_data \
	and not _bound_inventory_ids.has(cursor_data.inventory_id):
		_bound_inventory_ids.append(cursor_data.inventory_id)
	if not cursor_data.inventory_update.is_connected(_on_cursor_update):
		cursor_data.inventory_update.connect(_on_cursor_update)
	_on_cursor_update(cursor_data)

func _on_cursor_update(inventory_data: InventoryData) -> void:
	grabbed_slot_data = inventory_data.slot_datas[0]
	if grabbed_slot_data.item_data == null:
		grabbed_slot_last_id = -1
		grabbed_inv_last_data = null
	if grabbed_slot_container != null and not OS.has_feature("dedicated_server"):
		update_grabbed_slot()

## Инвентарь синхронизируется с сервером (зарегистрирован в InventoryNetwork).
## Незарегистрированные инвентари (например, креативный) работают локально, как раньше
func is_networked(inv_data: InventoryData) -> bool:
	return cursor_data != null \
		and inv_data.inventory_id != "" \
		and InventoryNetwork.get_inventory(inv_data.inventory_id) == inv_data

func on_inventory_interact(inv_data: InventoryData, index: int, button: int) -> void:
	var debug: bool = false
	if debug:
		print("[Inventory] Клик: '%s' слот %d, кнопка %d, в руке: %s" % [
			inv_data.inventory_id if inv_data.inventory_id != "" else inv_data.inv_name, index, button,
			grabbed_slot_data.item_data.type if grabbed_slot_data.item_data != null else "-"
		])
	if not is_networked(inv_data):
		_local_inventory_interact(inv_data, index, button)
		return
	if not(Input.is_action_pressed("shift")):
		match [grabbed_slot_data.item_data, button]:
			[null, MOUSE_BUTTON_LEFT]:
				get_grab_offset(inv_data, index)
				grabbed_slot_last_id = inv_data.get_start_index(index)
				grabbed_inv_last_data = inv_data
				request_grab(inv_data, index, "all")
			[_, MOUSE_BUTTON_LEFT]:
				request_drop(inv_data, index, "all")
				grabbed_slot_last_id = -1
				grabbed_inv_last_data = null
			[null, MOUSE_BUTTON_RIGHT]:
				get_grab_offset(inv_data, index)
				grabbed_slot_last_id = inv_data.get_start_index(index)
				grabbed_inv_last_data = inv_data
				request_grab(inv_data, index, "half")
			[_, MOUSE_BUTTON_RIGHT]:
				request_drop(inv_data, index, "one")
				grabbed_slot_last_id = -1
				grabbed_inv_last_data = null
	update_grabbed_slot()

## Локальная работа с инвентарем без сервера (прежнее поведение)
func _local_inventory_interact(inv_data: InventoryData, index: int, button: int) -> void:
	if not(Input.is_action_pressed("shift")):
		match [grabbed_slot_data.item_data, button]:
			[null, MOUSE_BUTTON_LEFT]:
				get_grab_offset(inv_data, index)
				grabbed_slot_last_id = inv_data.get_start_index(index)
				grabbed_slot_data = inv_data.grab_slot_data(index)
				grabbed_inv_last_data = inv_data
			[_, MOUSE_BUTTON_LEFT]:
				grabbed_slot_data = inv_data.drop_slot_data(grabbed_slot_data, index)
				grabbed_slot_last_id = -1
				grabbed_inv_last_data = null
			[null, MOUSE_BUTTON_RIGHT]:
				get_grab_offset(inv_data, index)
				grabbed_slot_last_id = inv_data.get_start_index(index)
				grabbed_slot_data = inv_data.grab_hafl_slot_data(index)
				grabbed_inv_last_data = inv_data
			[_, MOUSE_BUTTON_RIGHT]:
				grabbed_slot_data = inv_data.drop_single_slot_data(grabbed_slot_data, index)
				grabbed_slot_last_id = -1
				grabbed_inv_last_data = null
	update_grabbed_slot()

## Запрос: взять предмет из слота в руку (mode: all | half | one | custom)
func request_grab(inv_data: InventoryData, index: int, mode: String, amount: int = 0) -> void:
	var payload: Dictionary = {
		"action": "grab",
		"source_inventory_id": inv_data.inventory_id,
		"source_slot": index,
		"mode": mode
	}
	if mode == "custom":
		payload["amount"] = amount
	InventoryNetwork.request_action(payload)

## Запрос: положить предмет из руки в слот (mode: all | one | half | custom)
func request_drop(inv_data: InventoryData, index: int, mode: String, amount: int = 0) -> void:
	var payload: Dictionary = {
		"action": "drop",
		"target_inventory_id": inv_data.inventory_id,
		"target_slot": index,
		"mode": mode
	}
	if mode == "custom":
		payload["amount"] = amount
	InventoryNetwork.request_action(payload)

## Запрос: переложить предмет из слота в другой инвентарь (shift + клик)
func request_transfer(inv_data: InventoryData, index: int, target_inv_data: InventoryData) -> void:
	InventoryNetwork.request_action({
		"action": "transfer",
		"source_inventory_id": inv_data.inventory_id,
		"source_slot": index,
		"target_inventory_id": target_inv_data.inventory_id,
		"mode": "all"
	})

func update_grabbed_slot() -> void:
	if grabbed_slot_data.item_data:
		grabbed_slot_container.set_slot_data(grabbed_slot_data)

		var item_size: Vector2i = grabbed_slot_data.item_data.size
		grabbed_slot_container.size = item_size * 64

		grabbed_slot_container.show()
	else:
		grabbed_slot_container.hide()

func get_grab_offset(inventory_data: InventoryData, index: int) -> void:
	var slot_data: SlotData = inventory_data.get_item_at_index(index)

	if slot_data.item_data == null:
		return

	var item_index: int = inventory_data.slot_datas.find(slot_data)

	var item_pos: Vector2i = inventory_data.index_to_pos(item_index)
	var click_pos: Vector2i= inventory_data.index_to_pos(index)

	var cell_offset: Vector2 = click_pos - item_pos

	grabbed_slot_offset = Vector2(cell_offset) * 64.0
