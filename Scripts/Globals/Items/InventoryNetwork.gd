extends Node

## Сетевой слой инвентарей (server-authoritative).
## Клиент отправляет только действия, сервер проверяет их, выполняет атомарно
## и рассылает полный снапшот затронутых инвентарей подписанным клиентам.
##
## Идентификаторы инвентарей:
##   player:<player_id>:inventory | equipment | cursor (hotbar — на будущее)
##   chest:<chest_id>, container:<id>, trader:<id>, ... — любые другие префиксы
## Доступ к player:* есть только у владельца, к остальным — по подписке и дистанции.

## Отклонение действия сервером (на клиенте)
signal action_rejected(reason: String)

const PLAYER_PREFIX: String = "player"
## Виды инвентарей игрока, которые сохраняются на сервере
const SAVED_KINDS: Array[String] = ["inventory", "hotbar", "equipment", "cursor"]
## Максимальная дистанция до контейнера (сундука) для взаимодействия
const MAX_INTERACT_DISTANCE: float = 6.0
## Максимум запросов от одного клиента в секунду
const RATE_LIMIT_PER_SECOND: int = 20

const ACTIONS: Array[String] = ["grab", "drop", "transfer", "move", "merge", "split", "swap"]
const MODES: Array[String] = ["all", "one", "half", "custom"]
const PAYLOAD_KEYS: Array[String] = [
	"action", "source_inventory_id", "source_slot",
	"target_inventory_id", "target_slot", "amount", "mode"
]

## Зарегистрированные инвентари: inventory_id -> InventoryData
var _inventories: Dictionary[String, InventoryData] = {}
## Узлы мира контейнеров для проверки дистанции: inventory_id -> Node3D
var _world_nodes: Dictionary[String, Node3D] = {}
## Подписчики: inventory_id -> Array[int] (peer id)
var _subscribers: Dictionary[String, Array] = {}
## Снапшоты, пришедшие до регистрации инвентаря на клиенте
var _pending_snapshots: Dictionary[String, Dictionary] = {}
## Счетчик запросов для rate limit: peer id -> [начало окна в мс, количество]
var _rate: Dictionary[int, Array] = {}


# =====================================================
# ИДЕНТИФИКАТОРЫ И РЕГИСТРАЦИЯ
# =====================================================

## Идентификатор инвентаря игрока: player:<player_id>:<kind>
func make_player_inventory_id(player_id: String, kind: String) -> String:
	return "%s:%s:%s" % [PLAYER_PREFIX, player_id, kind]

## Регистрация инвентаря под стабильным идентификатором.
## world_node — узел в мире (сундук) для проверки дистанции, для инвентарей игрока не нужен
func register_inventory(inventory_data: InventoryData, inventory_id: String, world_node: Node3D = null) -> InventoryData:
	if inventory_id == "":
		push_error("InventoryNetwork: попытка зарегистрировать инвентарь без inventory_id")
		return inventory_data

	if _inventories.has(inventory_id) and _inventories[inventory_id] != inventory_data:
		push_warning("InventoryNetwork: инвентарь '%s' зарегистрирован повторно и будет заменен" % inventory_id)

	inventory_data.inventory_id = inventory_id
	inventory_data.init_inventory()
	_inventories[inventory_id] = inventory_data

	if world_node != null:
		_world_nodes[inventory_id] = world_node

	if not multiplayer.is_server() and _pending_snapshots.has(inventory_id):
		inventory_data.apply_dict(_pending_snapshots[inventory_id])
		_pending_snapshots.erase(inventory_id)

	return inventory_data

## Удаление инвентаря из реестра. На сервере несохраненные изменения игрока сохраняются заранее
func unregister_inventory(inventory_id: String) -> void:
	if not _inventories.has(inventory_id):
		return

	if multiplayer.is_server():
		var player_id: String = _get_player_id_from_inventory(inventory_id)
		if player_id != "" and SaveManager.is_dirty(player_id):
			SaveManager.save_player_id(player_id)

	_inventories.erase(inventory_id)
	_world_nodes.erase(inventory_id)
	_subscribers.erase(inventory_id)
	_pending_snapshots.erase(inventory_id)

## Получение инвентаря по идентификатору, null если не зарегистрирован
func get_inventory(inventory_id: String) -> InventoryData:
	return _inventories.get(inventory_id, null)

## Регистрация инвентаря игрока.
## Сервер регистрирует инвентари всех игроков, клиент — только свои и подписывается на них.
## Чужие инвентари на клиенте не регистрируются (сервер их не пришлет)
func register_player_inventory(player: Node, kind: String, inventory_data: InventoryData) -> InventoryData:
	var player_id: String = get_player_uuid(player)
	if player_id == "":
		return inventory_data

	var inventory_id: String = make_player_inventory_id(player_id, kind)

	if multiplayer.is_server():
		return register_inventory(inventory_data, inventory_id)

	if _is_local_player(player):
		register_inventory(inventory_data, inventory_id)
		subscribe(inventory_id)
	else:
		inventory_data.inventory_id = inventory_id

	return inventory_data

## Курсор игрока — однослотовый инвентарь с предметом, который игрок держит в руке
func get_player_cursor(player: Node) -> InventoryData:
	var player_id: String = get_player_uuid(player)
	if player_id != "":
		var inventory_id: String = make_player_inventory_id(player_id, "cursor")
		if _inventories.has(inventory_id):
			return _inventories[inventory_id]

	var cursor_data: InventoryData = InventoryData.new()
	cursor_data.inv_name = "Cursor"
	cursor_data.grid_size = Vector2i(1, 1)
	cursor_data.single_slots = true
	cursor_data.init_inventory()
	return register_player_inventory(player, "cursor", cursor_data)


# =====================================================
# КЛИЕНТСКИЙ API (одинаковый для клиента, хоста и одиночной игры)
# =====================================================

## Отправка действия с инвентарем. На сервере/хосте выполняется сразу, на клиенте уходит на сервер.
## Клиент не меняет инвентарь сам, а ждет снапшот от сервера
func request_action(payload: Dictionary) -> void:
	if multiplayer.is_server():
		_process_request(multiplayer.get_unique_id(), payload)
	else:
		request_inventory_action.rpc_id(1, payload)

## Подписка на инвентарь (например, при открытии сундука)
func subscribe(inventory_id: String) -> void:
	if multiplayer.is_server():
		_subscribe_peer(multiplayer.get_unique_id(), inventory_id)
	else:
		subscribe_inventory.rpc_id(1, inventory_id)

## Отписка от инвентаря (например, при закрытии сундука)
func unsubscribe(inventory_id: String) -> void:
	if multiplayer.is_server():
		_unsubscribe_peer(multiplayer.get_unique_id(), inventory_id)
	else:
		unsubscribe_inventory.rpc_id(1, inventory_id)


# =====================================================
# RPC: КЛИЕНТ -> СЕРВЕР
# =====================================================

## Запрос действия с инвентарем от клиента
@rpc("any_peer", "call_remote", "reliable")
func request_inventory_action(payload: Dictionary) -> void:
	if not multiplayer.is_server():
		push_error("InventoryNetwork: request_inventory_action вызван не на сервере")
		return
	_process_request(multiplayer.get_remote_sender_id(), payload)

## Запрос подписки на инвентарь от клиента
@rpc("any_peer", "call_remote", "reliable")
func subscribe_inventory(inventory_id: String) -> void:
	if not multiplayer.is_server():
		push_error("InventoryNetwork: subscribe_inventory вызван не на сервере")
		return
	var peer: int = multiplayer.get_remote_sender_id()
	if not _check_rate(peer):
		return
	_subscribe_peer(peer, inventory_id)

## Запрос отписки от инвентаря от клиента
@rpc("any_peer", "call_remote", "reliable")
func unsubscribe_inventory(inventory_id: String) -> void:
	if not multiplayer.is_server():
		push_error("InventoryNetwork: unsubscribe_inventory вызван не на сервере")
		return
	_unsubscribe_peer(multiplayer.get_remote_sender_id(), inventory_id)


# =====================================================
# RPC: СЕРВЕР -> КЛИЕНТ
# =====================================================

## Полный снапшот инвентаря от сервера
@rpc("authority", "call_remote", "reliable")
func sync_inventory_snapshot(inventory_id: String, snapshot: Dictionary) -> void:
	var debug: bool = false
	if debug:
		print("[Inventory] Снапшот '%s': %s" % [inventory_id, snapshot.get("slots", [])])
	var inventory_data: InventoryData = get_inventory(inventory_id)
	if inventory_data == null:
		_pending_snapshots[inventory_id] = snapshot
		return
	inventory_data.apply_dict(snapshot)

## Сервер отклонил действие
@rpc("authority", "call_remote", "reliable")
func reject_inventory_action(reason: String) -> void:
	var debug: bool = false
	if debug:
		print("[Inventory] Сервер отклонил действие: ", reason)
	action_rejected.emit(reason)


# =====================================================
# СЕРВЕР: ПОДПИСКИ
# =====================================================

func _subscribe_peer(peer: int, inventory_id: String) -> void:
	var error: String = _get_access_error(peer, inventory_id, false)
	if error != "":
		_reject(peer, "подписка на '%s': %s" % [inventory_id, error], [])
		return

	var peers: Array = _subscribers.get(inventory_id, [])
	if not peers.has(peer):
		peers.append(peer)
	_subscribers[inventory_id] = peers

	_send_snapshot(peer, inventory_id)

func _unsubscribe_peer(peer: int, inventory_id: String) -> void:
	if _subscribers.has(inventory_id):
		_subscribers[inventory_id].erase(peer)

## Отключение клиента: предмет из курсора возвращается в инвентарь, подписки удаляются
func on_peer_disconnected(peer: int) -> void:
	var player: Node = get_player_by_peer(peer)
	if player != null:
		_return_cursor(player)

	for inventory_id: String in _subscribers.keys():
		_subscribers[inventory_id].erase(peer)
	_rate.erase(peer)

## Возврат предмета из курсора в инвентарь или хотбар, если там есть место.
## Если места нет, предмет остается в курсоре и сохраняется вместе с ним
func _return_cursor(player: Node) -> void:
	var debug: bool = false
	var player_id: String = get_player_uuid(player)
	var cursor_data: InventoryData = get_inventory(make_player_inventory_id(player_id, "cursor"))
	if cursor_data == null or cursor_data.slot_datas[0].item_data == null:
		return

	for kind: String in ["inventory", "hotbar"]:
		var target: InventoryData = get_inventory(make_player_inventory_id(player_id, kind))
		if target == null:
			continue
		var affected: Array[InventoryData] = [cursor_data, target]
		_execute_atomic(affected, _transfer_cursor.bind(cursor_data, target))
		if cursor_data.slot_datas[0].item_data == null:
			break

	if debug and cursor_data.slot_datas[0].item_data != null:
		print("[Inventory] Нет места для предмета из курсора игрока %s, он сохранен в курсоре" % player_id)
	SaveManager.mark_dirty(player_id)

func _transfer_cursor(cursor_data: InventoryData, target: InventoryData) -> String:
	cursor_data.transfer_slot_data(0, target)
	return ""


# =====================================================
# СЕРВЕР: ОБРАБОТКА ЗАПРОСОВ
# =====================================================

func _process_request(peer: int, payload: Dictionary) -> void:
	var debug: bool = false
	if debug:
		print("[Inventory] Запрос от peer %d: %s" % [peer, payload])
	if not _check_rate(peer):
		return

	var error: String = _validate_payload(payload)
	if error != "":
		_reject(peer, error, [])
		return

	var player: Node = get_player_by_peer(peer)
	if player == null:
		_reject(peer, "игрок не найден или не авторизован", [])
		return

	var action: String = payload["action"]
	var mode: String = payload.get("mode", "all")
	var amount: int = int(payload.get("amount", 0))
	var player_id: String = get_player_uuid(player)
	var cursor_id: String = make_player_inventory_id(player_id, "cursor")

	# Курсор подставляется сервером, клиенту доверять нельзя
	var source_id: String = cursor_id if action == "drop" else str(payload.get("source_inventory_id", ""))
	var target_id: String = cursor_id if action == "grab" else str(payload.get("target_inventory_id", ""))
	var source_slot: int = 0 if action == "drop" else int(payload.get("source_slot", -1))
	var target_slot: int = 0 if action == "grab" else int(payload.get("target_slot", -1))

	var involved: Array[String] = [source_id]
	if not involved.has(target_id):
		involved.append(target_id)

	for inventory_id: String in involved:
		error = _get_access_error(peer, inventory_id, true)
		if error != "":
			_reject(peer, "'%s': %s" % [inventory_id, error], involved)
			return

	var source: InventoryData = get_inventory(source_id)
	var target: InventoryData = get_inventory(target_id)

	if source_slot < 0 or source_slot >= source.size():
		_reject(peer, "неверный слот источника %d" % source_slot, involved)
		return
	if action != "transfer" and (target_slot < 0 or target_slot >= target.size()):
		_reject(peer, "неверный слот назначения %d" % target_slot, involved)
		return

	var source_slot_data: SlotData = source.get_item_at_index(source_slot)
	if source_slot_data.item_data == null or source_slot_data.quantity <= 0:
		_reject(peer, "в руке нет предмета" if action == "drop" else "в слоте %d нет предмета" % source_slot, involved)
		return
	if mode == "custom" and (amount <= 0 or amount > source_slot_data.quantity):
		_reject(peer, "неверное количество %d (доступно %d)" % [amount, source_slot_data.quantity], involved)
		return

	var affected: Array[InventoryData] = [source]
	if target != source:
		affected.append(target)

	error = _execute_atomic(
		affected,
		_apply_action.bind(action, mode, amount, source, source_slot, target, target_slot)
	)

	if error != "":
		_reject(peer, error, involved)
		return

	for inventory_data: InventoryData in affected:
		_broadcast_snapshot(inventory_data.inventory_id)
		var owner_id: String = _get_player_id_from_inventory(inventory_data.inventory_id)
		if owner_id != "":
			SaveManager.mark_dirty(owner_id)

## Выполняет операцию атомарно: после выполнения проверяет целостность всех затронутых
## инвентарей и сохранение количества предметов. При любой ошибке — полный откат
func _execute_atomic(affected: Array[InventoryData], operation: Callable) -> String:
	var backups: Array[Dictionary] = []
	var counts_before: Dictionary[String, int] = _count_items(affected)
	for inventory_data: InventoryData in affected:
		backups.append(inventory_data.create_backup())

	var error: String = operation.call()

	if error == "":
		for inventory_data: InventoryData in affected:
			var state_error: String = inventory_data.get_state_error()
			if state_error != "":
				error = "%s: %s" % [inventory_data.inventory_id, state_error]
				break

	if error == "" and _count_items(affected) != counts_before:
		error = "операция изменила количество предметов"

	if error == "":
		var changed: bool = false
		for index: int in range(affected.size()):
			if not affected[index].equals_backup(backups[index]):
				changed = true
				break
		if not changed:
			error = "операция ничего не изменила"

	if error != "":
		for index: int in range(affected.size()):
			affected[index].restore_backup(backups[index])

	return error

## Выполнение действия над серверными InventoryData. Возвращает текст ошибки или пустую строку
func _apply_action(
	action: String,
	mode: String,
	amount: int,
	source: InventoryData,
	source_slot: int,
	target: InventoryData,
	target_slot: int
) -> String:
	match action:
		"grab":
			# Слот -> курсор (target — курсор игрока)
			var cursor_slot: SlotData = target.slot_datas[0]
			if cursor_slot.item_data != null:
				return "в руке уже есть предмет"
			var taken: SlotData = _take(source, source_slot, mode, amount)
			if taken.item_data == null:
				return "не удалось взять предмет"
			_set_slot(cursor_slot, taken)
			return ""

		"drop":
			# Курсор -> слот (source — курсор игрока)
			return _drop_from_cursor(source, target, target_slot, mode, amount)

		"transfer":
			# Слот -> любое подходящее место в другом инвентаре
			if source == target:
				return "нельзя переложить предмет в тот же инвентарь"
			if mode != "all":
				return "transfer поддерживает только mode = all"
			if not source.transfer_slot_data(source_slot, target):
				return "нет места в целевом инвентаре"
			return ""

		"move", "merge", "split", "swap":
			# Слот -> слот (обмен, объединение и разделение выполняет drop_slot_data)
			var source_start: int = source.slot_datas.find(source.get_item_at_index(source_slot))
			var taken: SlotData = _take(source, source_slot, "half" if action == "split" and mode == "all" else mode, amount)
			if taken.item_data == null:
				return "не удалось взять предмет"
			var rest: SlotData = target.drop_slot_data(taken, target_slot)
			if not _is_empty(rest):
				# Остаток или предмет после обмена возвращается на место источника
				var back: SlotData = source.drop_slot_data(rest, source_start)
				if not _is_empty(back):
					return "не удалось вернуть предмет на место"
			return ""

	return "неизвестное действие '%s'" % action

## Берет предметы из слота в зависимости от режима: all | half | one | custom
func _take(inventory_data: InventoryData, index: int, mode: String, amount: int) -> SlotData:
	var slot_data: SlotData = inventory_data.get_item_at_index(index)
	if slot_data.item_data == null:
		return SlotData.new()

	match mode:
		"all":
			return inventory_data.grab_slot_data(index)
		"half":
			return inventory_data.grab_hafl_slot_data(index)
		"one":
			amount = 1

	if amount <= 0 or amount > slot_data.quantity:
		return SlotData.new()
	if amount == slot_data.quantity:
		return inventory_data.grab_slot_data(index)

	var taken: SlotData = slot_data.duplicate()
	taken.quantity = amount
	slot_data.quantity -= amount
	inventory_data.inventory_update.emit(inventory_data)
	return taken

## Кладет предметы из курсора в слот: all | one | half | custom
func _drop_from_cursor(cursor_data: InventoryData, target: InventoryData, target_slot: int, mode: String, amount: int) -> String:
	var held: SlotData = cursor_data.slot_datas[0]
	var rest: SlotData

	match mode:
		"all":
			rest = target.drop_slot_data(held.duplicate(), target_slot)
		"one":
			rest = target.drop_single_slot_data(held.duplicate(), target_slot)
		_:
			var count: int = ceili(float(held.quantity) / 2.0) if mode == "half" else amount
			if count <= 0 or count > held.quantity:
				return "неверное количество %d (в руке %d)" % [count, held.quantity]
			var part: SlotData = held.duplicate()
			part.quantity = count
			var part_rest: SlotData = target.drop_slot_data(part, target_slot)
			rest = held.duplicate()
			rest.quantity = held.quantity - count
			if not _is_empty(part_rest):
				if part_rest.item_data != held.item_data:
					return "нельзя обменять часть стака на другой предмет"
				rest.quantity += part_rest.quantity

	_set_slot(held, rest)
	return ""

## Копирует содержимое слота (без item_category, ее хранит сам слот)
func _set_slot(slot_data: SlotData, from_slot_data: SlotData) -> void:
	if _is_empty(from_slot_data):
		slot_data.item_data = null
		slot_data.quantity = 0
		return
	slot_data.item_data = from_slot_data.item_data
	slot_data.quantity = from_slot_data.quantity

func _is_empty(slot_data: SlotData) -> bool:
	return slot_data == null or slot_data.item_data == null or slot_data.quantity <= 0

func _count_items(affected: Array[InventoryData]) -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {}
	for inventory_data: InventoryData in affected:
		var counts: Dictionary[String, int] = inventory_data.count_items()
		for item_type: String in counts:
			result[item_type] = result.get(item_type, 0) + counts[item_type]
	return result


# =====================================================
# СЕРВЕР: ПРОВЕРКИ
# =====================================================

## Проверка формы запроса. Клиент передает только действие; quantity, item и слоты не принимаются
func _validate_payload(payload: Dictionary) -> String:
	for key: Variant in payload.keys():
		if not(key is String) or not PAYLOAD_KEYS.has(key):
			return "недопустимое поле '%s' в запросе (клиент не может задавать состояние инвентаря)" % str(key)

	var action: Variant = payload.get("action")
	if not(action is String) or not ACTIONS.has(action):
		return "неизвестное действие '%s'" % str(action)

	var mode: Variant = payload.get("mode", "all")
	if not(mode is String) or not MODES.has(mode):
		return "неизвестный режим '%s'" % str(mode)

	for key: String in ["source_inventory_id", "target_inventory_id"]:
		if payload.has(key) and not(payload[key] is String):
			return "поле '%s' должно быть строкой" % key

	for key: String in ["source_slot", "target_slot", "amount"]:
		if payload.has(key) and not(payload[key] is int):
			return "поле '%s' должно быть целым числом" % key

	if payload.has("amount") and int(payload["amount"]) < 0:
		return "отрицательное количество"

	match action:
		"grab":
			if not payload.has("source_inventory_id") or not payload.has("source_slot"):
				return "grab: нужны source_inventory_id и source_slot"
		"drop":
			if not payload.has("target_inventory_id") or not payload.has("target_slot"):
				return "drop: нужны target_inventory_id и target_slot"
		"transfer":
			if not payload.has("source_inventory_id") or not payload.has("source_slot") \
			or not payload.has("target_inventory_id"):
				return "transfer: нужны source_inventory_id, source_slot и target_inventory_id"
		_:
			for key: String in ["source_inventory_id", "source_slot", "target_inventory_id", "target_slot"]:
				if not payload.has(key):
					return "%s: нет поля '%s'" % [action, key]

	return ""

## Проверка доступа игрока к инвентарю. Пустая строка — доступ есть.
## for_action = true — проверка для изменения (для контейнера нужна подписка),
## false — только для чтения снапшота
func _get_access_error(peer: int, inventory_id: String, for_action: bool) -> String:
	if not _inventories.has(inventory_id):
		return "инвентарь не найден"

	var player: Node = get_player_by_peer(peer)
	if player == null:
		return "игрок не найден или не авторизован"

	var parts: PackedStringArray = inventory_id.split(":")

	if parts[0] == PLAYER_PREFIX:
		if parts.size() != 3:
			return "неверный идентификатор инвентаря"
		if parts[1] != get_player_uuid(player):
			return "чужой инвентарь"
		return ""

	# Контейнеры (сундуки и т.п.)
	if for_action and not _subscribers.get(inventory_id, []).has(peer):
		return "нет подписки на контейнер"

	if _world_nodes.has(inventory_id):
		var world_node: Node3D = _world_nodes[inventory_id]
		if not is_instance_valid(world_node):
			return "контейнер больше не существует"
		if player is Node3D and (player as Node3D).global_position.distance_to(world_node.global_position) > MAX_INTERACT_DISTANCE:
			return "контейнер слишком далеко"

	return ""

## Rate limit: не больше RATE_LIMIT_PER_SECOND запросов в секунду от одного клиента
func _check_rate(peer: int) -> bool:
	var now: int = Time.get_ticks_msec()
	var state: Array = _rate.get(peer, [now, 0])
	if now - int(state[0]) >= 1000:
		state = [now, 0]
	state[1] = int(state[1]) + 1
	_rate[peer] = state

	if int(state[1]) == RATE_LIMIT_PER_SECOND + 1:
		_reject(peer, "слишком много запросов", [])
	return int(state[1]) <= RATE_LIMIT_PER_SECOND


# =====================================================
# СЕРВЕР: ОТПРАВКА
# =====================================================

## Отклонение действия: лог (debug), сообщение клиенту и актуальные снапшоты для синхронизации
func _reject(peer: int, reason: String, inventory_ids: Array[String]) -> void:
	var debug: bool = false
	if debug:
		print("[Inventory] Отклонено для peer %d: %s" % [peer, reason])

	if peer == multiplayer.get_unique_id():
		action_rejected.emit(reason)
		return

	if multiplayer.get_peers().has(peer):
		reject_inventory_action.rpc_id(peer, reason)
		for inventory_id: String in inventory_ids:
			if _get_access_error(peer, inventory_id, false) == "":
				_send_snapshot(peer, inventory_id)

func _send_snapshot(peer: int, inventory_id: String) -> void:
	var inventory_data: InventoryData = get_inventory(inventory_id)
	if inventory_data == null or peer == multiplayer.get_unique_id():
		return
	if not multiplayer.get_peers().has(peer):
		return
	sync_inventory_snapshot.rpc_id(peer, inventory_id, inventory_data.to_dict())

func _broadcast_snapshot(inventory_id: String) -> void:
	for peer: int in _subscribers.get(inventory_id, []):
		_send_snapshot(peer, inventory_id)


# =====================================================
# ВСПОМОГАТЕЛЬНОЕ
# =====================================================

## Поиск игрока по peer id
func get_player_by_peer(peer: int) -> Node:
	for player: Node in get_tree().get_nodes_in_group("Players"):
		if int(player.get("player_id")) == peer and get_player_uuid(player) != "":
			return player
	return null

## player_id владельца для инвентарей вида player:<player_id>:<kind>, иначе пустая строка
func _get_player_id_from_inventory(inventory_id: String) -> String:
	var parts: PackedStringArray = inventory_id.split(":")
	if parts.size() == 3 and parts[0] == PLAYER_PREFIX and SAVED_KINDS.has(parts[2]):
		return parts[1]
	return ""

## Постоянный идентификатор игрока (player_uuid), пустая строка если не назначен
func get_player_uuid(player: Node) -> String:
	var player_id: Variant = player.get("player_uuid")
	if player_id == null:
		return ""
	return str(player_id)

func _is_local_player(player: Node) -> bool:
	return int(player.get("player_id")) == multiplayer.get_unique_id()
