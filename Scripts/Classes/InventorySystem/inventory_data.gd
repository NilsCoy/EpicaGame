extends Resource
class_name InventoryData

## Сигнал обновления инвентаря
signal inventory_update(inventory_data: InventoryData)
## Сигнал взаимодействия с инвентарем
signal inventory_interact(inventory_data: InventoryData, index: int, button: int)
## Сигнал для отправки действия на сервер (используется в сетевой игре)
signal send_action_to_server(inventory_name: String, action: String, index: int, target_index: int, item_type: String, quantity: int, grabbed_data: Dictionary)

@export var inv_name: String
@export var grid_size: Vector2i = Vector2i(5, 5)

# true  = 1 слот = 1 предмет
# false = предмет может занимать несколько клеток
@export var single_slots: bool = false

@export var slot_datas: Array[SlotData]

## Флаг авторитетности (сервер имеет право изменять данные напрямую)
var is_authoritative: bool = false

## Инициализация инвентаря
func init_inventory() -> void:
	while slot_datas.size() < size():
		slot_datas.append(SlotData.new())

	# Если массив оказался больше размера инвентаря
	while slot_datas.size() > size():
		slot_datas.pop_back()

## Получение размера инвентаря, как в Array.size()
func size() -> int:
	return grid_size.x * grid_size.y

func get_start_index(index: int) -> int:
	var slot_data: SlotData = get_item_at_index(index)
	for i: int in range(slot_datas.size()):
		if slot_datas[i].item_data != null and slot_data.item_data != null:
			if slot_data.item_data.type == slot_datas[i].item_data.type and slot_data.quantity == slot_datas[i].quantity:
				return i
	return -1

## Получение позиции по индексу
func index_to_pos(index: int) -> Vector2i:
	return Vector2i(
		index % grid_size.x,
		index / grid_size.x
	)

## Получение индекса по позиции
func pos_to_index(pos: Vector2i) -> int:
	return pos.y * grid_size.x + pos.x

## Получение размера предмета по слоту
func get_item_size(slot_data: SlotData) -> Vector2i:
	if slot_data.item_data == null:
		return Vector2i.ONE

	if single_slots:
		return Vector2i.ONE

	return slot_data.item_data.size

## Получение предмета по индексу
func get_item_at_index(index: int) -> SlotData:

	if index < 0 or index >= slot_datas.size():
		return SlotData.new()


	# -----------------------------------------
	# SINGLE SLOTS
	# -----------------------------------------

	if single_slots:
		return slot_datas[index]


	# -----------------------------------------
	# MULTI SLOTS
	# -----------------------------------------

	for i: int in range(slot_datas.size()):

		var slot_data: SlotData = slot_datas[i]

		if slot_data.item_data == null:
			continue

		var item_size: Vector2i = get_item_size(slot_data)

		var start_pos: Vector2i = index_to_pos(i)
		var target_pos: Vector2i = index_to_pos(index)

		if target_pos.x >= start_pos.x \
		and target_pos.x < start_pos.x + item_size.x \
		and target_pos.y >= start_pos.y \
		and target_pos.y < start_pos.y + item_size.y:

			return slot_data

	return SlotData.new()

## Проверка возможности поставить предмет в слот
func can_place_item(
	slot_data: SlotData,
	index: int,
	ignore_slot_data: SlotData = SlotData.new()
) -> bool:

	if slot_data.item_data == null:
		return false

	if index < 0 or index >= size():
		return false


	# -----------------------------------------
	# SINGLE SLOTS
	# -----------------------------------------
	if single_slots:


		var occupying_slot: SlotData = slot_datas[index]

		if occupying_slot.item_data == null:
			if occupying_slot.item_category == 'all':
				return true
			if occupying_slot.item_category == slot_data.item_data.category:
				return true
			return false

		if occupying_slot == ignore_slot_data:
			return true

		return false


	# -----------------------------------------
	# MULTI SLOTS
	# -----------------------------------------

	var start_pos: Vector2i = index_to_pos(index)
	var item_size: Vector2i = get_item_size(slot_data)


	# Не выходит ли предмет за границы

	if start_pos.x + item_size.x > grid_size.x:
		return false

	if start_pos.y + item_size.y > grid_size.y:
		return false


	# Проверяем все клетки

	for y: int in range(item_size.y):
		for x: int in range(item_size.x):

			var check_pos: Vector2i = \
				start_pos + Vector2i(x, y)

			var check_index: int = pos_to_index(check_pos)

			var occupying_slot: SlotData = \
				get_item_at_index(check_index)
			
			if occupying_slot.item_data != null \
			and occupying_slot != ignore_slot_data:
				return false
			
			if occupying_slot.item_category != 'all':
				if occupying_slot.item_category != slot_data.item_data.category:
					return false


	return true

## Ставит предмет в слот
func place_item(
	slot_data: SlotData,
	start_index: int
) -> bool:

	if not can_place_item(slot_data, start_index):
		return false

	slot_datas[start_index].item_data = slot_data.item_data
	slot_datas[start_index].quantity = slot_data.quantity

	inventory_update.emit(self)

	return true

## Ищет свободное место для установки предмета
func find_empty_slot(slot_data: SlotData) -> int:

	if slot_data.item_data == null:
		return -1


	for slot_index: int in range(size()):

		if can_place_item(slot_data, slot_index):
			return slot_index


	return -1

## Ищет индекс слота по типу предмета
func find_item_index(item_type: String) -> int:

	for slot_index: int in range(slot_datas.size()):

		var slot_data: SlotData = slot_datas[slot_index]

		if slot_data.item_data != null:
			if slot_data.item_data.type == item_type:
				return slot_index


	return -1

## Ищет слот по типу предмета
func find_slot_data(item_type: String) -> SlotData:

	for slot_index: int in range(slot_datas.size()):

		var slot_data: SlotData = slot_datas[slot_index]

		if slot_data.item_data != null:
			if slot_data.item_data.type == item_type:
				return slot_data


	return SlotData.new()

## Забирает предмет из слота, на его место возвращается null если есть предмет и наоброт
func grab_slot_data(index: int) -> SlotData:

	var slot_data: SlotData = get_item_at_index(index)
	var gap_slot_data: SlotData = get_item_at_index(index).duplicate()

	if slot_data.item_data == null:
		return SlotData.new()


	var start_index: int = slot_datas.find(slot_data)

	if start_index != -1:
		slot_datas[start_index].item_data = null
		slot_datas[start_index].quantity = 0


	inventory_update.emit(self)

	return gap_slot_data


## Забирает половину предметов в слоте
func grab_hafl_slot_data(index: int) -> SlotData:

	var slot_data: SlotData = get_item_at_index(index)

	if slot_data.item_data == null:
		return slot_data


	var return_slot_data: SlotData = slot_data.duplicate()


	# Берём половину

	return_slot_data.quantity = \
		ceili(float(slot_data.quantity) / 2.0)

	slot_data.quantity = \
		floori(float(slot_data.quantity) / 2.0)


	# Находим настоящее место предмета

	var item_index: int = slot_datas.find(slot_data)

	if item_index != -1:

		if slot_data.quantity <= 0:
			slot_datas[item_index].item_data = null


	inventory_update.emit(self)

	return return_slot_data

## Кладет предмет в слот, если есть пустое место или одинаковый предмет
func drop_slot_data(
	grabbed_slot_data: SlotData,
	index: int
) -> SlotData:
	if grabbed_slot_data.item_data == null:
		return SlotData.new()


	var target_slot_data: SlotData = get_item_at_index(index)


	# =====================================================
	# ПУСТОЕ МЕСТО
	# =====================================================

	if target_slot_data.item_data == null:

		if can_place_item(
			grabbed_slot_data,
			index
		):

			slot_datas[index].item_data = grabbed_slot_data.item_data
			slot_datas[index].quantity = grabbed_slot_data.quantity

			inventory_update.emit(self)

			return SlotData.new()


		inventory_update.emit(self)

		return grabbed_slot_data


	# =====================================================
	# ОБЪЕДИНЕНИЕ
	# =====================================================

	if target_slot_data.can_fully_merge_with(
		grabbed_slot_data
	):

		target_slot_data.fully_merge_with(
			grabbed_slot_data
		)

		inventory_update.emit(self)

		grabbed_slot_data.item_data = null
		return grabbed_slot_data


	# =====================================================
	# ЧАСТИЧНОЕ ОБЪЕДИНЕНИЕ
	# =====================================================

	if target_slot_data.can_fully_merge_with_return(
		grabbed_slot_data
	):

		var return_slot_data: SlotData = \
			target_slot_data.fully_merge_with_return(
				grabbed_slot_data
			)

		inventory_update.emit(self)

		return return_slot_data


	# =====================================================
	# ОБМЕН
	# =====================================================

	var target_index: int = \
		slot_datas.find(target_slot_data)


	if target_index == -1:

		push_error(
			"drop_slot_data: target_slot_data не найден"
		)

		return grabbed_slot_data


	# -----------------------------------------
	# SINGLE SLOTS
	# -----------------------------------------

	if single_slots:

		slot_datas[target_index] = grabbed_slot_data

		inventory_update.emit(self)

		return target_slot_data


	# -----------------------------------------
	# MULTI SLOTS
	# -----------------------------------------

	# Временно убираем старый предмет

	slot_datas[target_index] = SlotData.new()


	# Новый предмет ставим на место,
	# где был старый предмет

	if can_place_item(
		grabbed_slot_data,
		target_index,
		target_slot_data
	):

		slot_datas[target_index] = grabbed_slot_data

		inventory_update.emit(self)

		return target_slot_data


	# Не получилось поставить.
	# Возвращаем старый предмет.

	slot_datas[target_index] = target_slot_data

	inventory_update.emit(self)

	return grabbed_slot_data

# Кладет 1 предмет в слот, если есть место или одинаковый предмет
func drop_single_slot_data(
	grabbed_slot_data: SlotData,
	index: int
) -> SlotData:

	if grabbed_slot_data.item_data == null:
		return grabbed_slot_data


	var slot_data: SlotData = \
		get_item_at_index(index)


	var new_item: SlotData = \
		grabbed_slot_data.create_single_slot_data()


	# =====================================================
	# ПУСТОЙ СЛОТ
	# =====================================================

	if slot_data.item_data == null:

		if can_place_item(
			new_item,
			index
		):

			slot_datas[index] = new_item

		else:
			return grabbed_slot_data


	# =====================================================
	# ОБЪЕДИНЕНИЕ
	# =====================================================

	elif slot_data.can_merge_with(
		grabbed_slot_data
	):

		slot_data.fully_merge_with(
			new_item
		)


	else:

		return grabbed_slot_data


	inventory_update.emit(self)


	if grabbed_slot_data.quantity > 0:
		return grabbed_slot_data


	return SlotData.new()

## Кладет предмет в другой инвентарь
func transfer_slot_data(
	index: int,
	target_inventory: InventoryData
) -> void:

	var slot_data: SlotData = get_item_at_index(index)

	if slot_data.item_data == null:
		return


	# Ищем свободное место в целевом инвентаре
	var target_index: int = \
		target_inventory.find_empty_slot(slot_data)

	if target_index == -1:
		return


	# Забираем предмет из текущего инвентаря
	var grabbed_data: SlotData = grab_slot_data(index)

	if grabbed_data.item_data == null:
		return


	# Кладём его в другой инвентарь
	target_inventory.place_item(
		grabbed_data,
		target_index
	)

## WIP! Кладет предмет в другой инвентарь
func transportation_slot_data(
	index: int,
	inventory_data: InventoryData
) -> void:

	var slot_data: SlotData = \
		get_item_at_index(index)


	if slot_data.item_data == null:
		return

	if slot_data.item_data == null:
		return


	# Уже есть такой предмет
	var slot_index: int = \
		inventory_data.find_item_index(
			slot_data.item_data.type
		)


	if slot_index != -1:

		var grabbed_data: SlotData = \
			grab_slot_data(index)

		if grabbed_data:
			inventory_data.drop_slot_data(
				grabbed_data,
				slot_index
			)

		return


	# Ищем свободное место с учётом размера

	slot_index = \
		inventory_data.find_empty_slot(slot_data)


	if slot_index == -1:
		return


	var grabbed_data: SlotData = \
		grab_slot_data(index)


	if grabbed_data:

		inventory_data.drop_slot_data(
			grabbed_data,
			slot_index
		)


## Вызывает нажатие по слоту
func on_slot_clicked(
	index: int,
	button: int
) -> void:
	inventory_interact.emit(
		self,
		index,
		button
	)

## Применяет снапшот данных от сервера (для клиентов)
func apply_snapshot(data: Dictionary) -> void:
	if not InventoryNetworkManager:
		return
	
	InventoryNetworkManager.deserialize_inventory_data(data, self)

## Отправляет действие на сервер (для клиентов)
func _send_action_to_server(
	action: String,
	index: int,
	target_index: int = -1,
	item_type: String = "",
	quantity: int = 0,
	grabbed_data: SlotData = null
) -> void:
	if is_authoritative or not InventoryNetworkManager:
		return
	
	var grabbed_dict: Dictionary = {}
	if grabbed_data != null:
		grabbed_dict = InventoryNetworkManager.serialize_slot_data(grabbed_data)
	
	send_action_to_server.emit(
		inv_name,
		action,
		index,
		target_index,
		item_type,
		quantity,
		grabbed_dict
	)
