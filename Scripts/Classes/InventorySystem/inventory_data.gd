extends Resource
class_name InventoryData

signal inventory_update(inventory_data: InventoryData)
signal inventory_interact(inventory_data: InventoryData, index: int, button: int)

@export var inv_name: String
@export var grid_size: Vector2i = Vector2i(5, 5)
@export var slot_datas: Array[SlotData]
@export var single_slots: bool = false

func init_inventory() -> void:
	while slot_datas.size() < size():
		slot_datas.append(null)

func size() -> int:
	return grid_size.x * grid_size.y

func get_item_at_index(index: int) -> SlotData:
	for i: int in range(len(slot_datas)):
		var slot_data: SlotData = slot_datas[i]

		if slot_data == null:
			continue

		var item_size: Vector2i = slot_data.item_data.size
		var start_pos: Vector2i = index_to_pos(i)
		var target_pos: Vector2i = index_to_pos(index)

		if target_pos.x >= start_pos.x \
		and target_pos.x < start_pos.x + item_size.x \
		and target_pos.y >= start_pos.y \
		and target_pos.y < start_pos.y + item_size.y:
			return slot_data

	return null

func place_item(slot_data: SlotData, start_index: int) -> bool:
	if not can_place_item(slot_data, start_index):
		return false

	slot_datas[start_index] = slot_data
	inventory_update.emit(self)

	return true

#func can_place_item(slot_data: SlotData, start_index: int) -> bool:
	#var start_pos: Vector2i = index_to_pos(start_index)
	#var item_size: Vector2i = slot_data.item_data.size
#
	## Проверяем, не выходит ли предмет за границы
	#if start_pos.x + item_size.x > grid_size.x:
		#return false
#
	#if start_pos.y + item_size.y > grid_size.y:
		#return false
#
	## Проверяем каждую клетку, которую займёт предмет
	#for y: int in range(item_size.y):
		#for x: int in range(item_size.x):
			#var check_pos: Vector2i = start_pos + Vector2i(x, y)
			#var check_index: int = pos_to_index(check_pos)
#
			#if slot_datas[check_index] != null:
				#return false
#
	#return true

func can_place_item(
	slot_data: SlotData,
	index: int,
	ignore_slot_data: SlotData = null
) -> bool:

	var start_pos: Vector2i = index_to_pos(index)
	var item_size: Vector2i = slot_data.item_data.size

	# Проверяем выход за границы
	if start_pos.x + item_size.x > grid_size.x:
		return false

	if start_pos.y + item_size.y > grid_size.y:
		return false

	# Проверяем каждую клетку
	for y: int in range(item_size.y):
		for x: int in range(item_size.x):

			var check_pos: Vector2i = start_pos + Vector2i(x, y)
			var check_index: int = pos_to_index(check_pos)

			var occupying_slot: SlotData = get_item_at_index(check_index)

			if occupying_slot != null and occupying_slot != ignore_slot_data:
				return false

	return true

func index_to_pos(index: int) -> Vector2i:
	return Vector2i(
		index % grid_size.x,
		index / grid_size.x
	)

func pos_to_index(pos: Vector2i) -> int:
	return pos.y * grid_size.x + pos.x

func find_item_index(item_name: String) -> int:
	for slot_index: int in range(len(slot_datas)):
		var slot_data: SlotData = slot_datas[slot_index]
		if slot_data:
			if slot_data.item_data.name == item_name:
				return slot_index
	return -1

func find_slot_data(item_name: String) -> SlotData:
	for slot_index: int in range(len(slot_datas)):
		var slot_data: SlotData = slot_datas[slot_index]
		if slot_data:
			if slot_data.item_data.name == item_name:
				return slot_data
	return null

#func find_empty_slot() -> int:
	#for slot_index: int in range(len(slot_datas)):
		#if not(slot_datas[slot_index]): return slot_index
	#return -1
func find_empty_slot(slot_data: SlotData) -> int:
	for slot_index: int in range(len(slot_datas)):
		if can_place_item(slot_data, slot_index):
			return slot_index

	return -1

func transportation_slot_data(index: int, inventory_data: InventoryData) -> void:
	var slot_data: SlotData = get_item_at_index(index)
	if slot_data:
		var slot_index: int = inventory_data.find_item_index(slot_data.item_data.name)
		if slot_index != -1:
			inventory_data.drop_slot_data(grab_slot_data(index), slot_index)
		else:
			slot_index = inventory_data.find_empty_slot(slot_data)
			if slot_index != -1:
				inventory_data.drop_slot_data(grab_slot_data(index), slot_index)

#func grab_slot_data(index: int) -> SlotData:
	#var slot_data: SlotData = slot_datas[index]
	#if slot_data:
		#slot_datas[index] = null
		#inventory_update.emit(self)
	#return slot_data
func grab_slot_data(index: int) -> SlotData:
	var slot_data: SlotData = get_item_at_index(index)

	if slot_data == null:
		return null

	var start_index: int = slot_datas.find(slot_data)

	if start_index != -1:
		slot_datas[start_index] = null

	inventory_update.emit(self)

	return slot_data

#func grab_hafl_slot_data(index: int) -> SlotData:
	#var slot_data: SlotData = get_item_at_index(index)
	#var return_slot_data: SlotData
	#
	#if slot_data:
		#return_slot_data = slot_data.duplicate()
		#return_slot_data.quantity = ceili(float(return_slot_data.quantity)/2)
		#slot_data.quantity = floori(float(slot_data.quantity)/2)
		#if slot_data.quantity == 0:
			#slot_data = null
		#slot_datas[index] = slot_data
		#inventory_update.emit(self)
	#return return_slot_data
func grab_hafl_slot_data(index: int) -> SlotData:
	var slot_data: SlotData = get_item_at_index(index)
	var return_slot_data: SlotData

	if slot_data:
		return_slot_data = slot_data.duplicate()
		return_slot_data.quantity = ceili(float(slot_data.quantity) / 2.0)
		slot_data.quantity = floori(float(slot_data.quantity) / 2.0)
		var item_index: int = slot_datas.find(slot_data)
		if slot_data.quantity == 0:
			slot_datas[item_index] = null
		inventory_update.emit(self)
	return return_slot_data

#func drop_slot_data(grabbed_slot_data: SlotData, index: int) -> SlotData:
	#var slot_data: SlotData = slot_datas[index]
	#var return_slot_data: SlotData
	#if slot_data and slot_data.can_fully_merge_with(grabbed_slot_data):
		#slot_data.fully_merge_with(grabbed_slot_data)
	#elif slot_data and slot_data.can_fully_merge_with_return(grabbed_slot_data):
		#return_slot_data = slot_data.fully_merge_with_return(grabbed_slot_data)
	#else:
		#slot_datas[index] = grabbed_slot_data
		#return_slot_data = slot_data
	#
	#inventory_update.emit(self)
	#return return_slot_data
#func drop_slot_data(grabbed_slot_data: SlotData, index: int) -> SlotData:
	#var slot_data: SlotData = get_item_at_index(index)
	#var return_slot_data: SlotData
#
	## 1. На клетке ничего нет
	#if slot_data == null:
		#if can_place_item(grabbed_slot_data, index):
			#slot_datas[index] = grabbed_slot_data
			#return_slot_data = null
		#else:
			#return_slot_data = grabbed_slot_data
#
	## 2. Такой же предмет — пытаемся объединить
	#elif slot_data.can_fully_merge_with(grabbed_slot_data):
		#slot_data.fully_merge_with(grabbed_slot_data)
#
	## 3. Можно объединить частично
	#elif slot_data.can_fully_merge_with_return(grabbed_slot_data):
		#return_slot_data = slot_data.fully_merge_with_return(grabbed_slot_data)
#
	## 4. Другой предмет — пытаемся поменять
	#else:
		#var old_item_index: int = slot_datas.find(slot_data)
#
		#if can_place_item(grabbed_slot_data, index):
			#slot_datas[old_item_index] = grabbed_slot_data
			#return_slot_data = slot_data
		#else:
			#return_slot_data = grabbed_slot_data
#
	#inventory_update.emit(self)
	#return return_slot_data

func drop_slot_data(grabbed_slot_data: SlotData, index: int) -> SlotData:
	var target_slot_data: SlotData = get_item_at_index(index)

	# Пустое место
	if target_slot_data == null:
		if can_place_item(grabbed_slot_data, index):
			slot_datas[index] = grabbed_slot_data
			inventory_update.emit(self)
			return null

		inventory_update.emit(self)
		return grabbed_slot_data


	# Если это тот же предмет — пытаемся объединить
	if target_slot_data.can_fully_merge_with(grabbed_slot_data):
		target_slot_data.fully_merge_with(grabbed_slot_data)
		inventory_update.emit(self)
		return null


	if target_slot_data.can_fully_merge_with_return(grabbed_slot_data):
		var return_slot_data: SlotData = \
			target_slot_data.fully_merge_with_return(grabbed_slot_data)

		inventory_update.emit(self)
		return return_slot_data


	# -------------------------
	# ОБМЕН ПРЕДМЕТОВ
	# -------------------------

	# Где реально лежит старый предмет
	var target_index: int = slot_datas.find(target_slot_data)

	# Убираем старый предмет временно
	slot_datas[target_index] = null

	# Проверяем, помещается ли новый предмет
	# на место клика
	if can_place_item(grabbed_slot_data, index, target_slot_data):

		slot_datas[index] = grabbed_slot_data

		inventory_update.emit(self)

		# Старый предмет теперь оказывается в руке
		return target_slot_data


	# Новый предмет не помещается.
	# Возвращаем всё как было.
	slot_datas[target_index] = target_slot_data

	inventory_update.emit(self)

	return grabbed_slot_data

#func drop_single_slot_data(grabbed_slot_data: SlotData, index: int) -> SlotData:
	#var slot_data: SlotData = slot_datas[index]
	#
	#if not slot_data:
		#slot_datas[index] = grabbed_slot_data.create_single_slot_data()
	#elif slot_data.can_merge_with(grabbed_slot_data):
		#slot_data.fully_merge_with(grabbed_slot_data.create_single_slot_data())
	#
	#inventory_update.emit(self)
	#if grabbed_slot_data.quantity > 0: return grabbed_slot_data
	#else: return null

func drop_single_slot_data(grabbed_slot_data: SlotData, index: int) -> SlotData:
	var slot_data: SlotData = get_item_at_index(index)
	var new_item: SlotData = grabbed_slot_data.duplicate()
	new_item = new_item.create_single_slot_data()

	if not slot_data:
		if can_place_item(new_item, index):
			slot_datas[index] = grabbed_slot_data.create_single_slot_data()
		else:
			return grabbed_slot_data

	elif slot_data.can_merge_with(grabbed_slot_data):
		slot_data.fully_merge_with(grabbed_slot_data.create_single_slot_data())
	else:
		return grabbed_slot_data

	inventory_update.emit(self)

	if grabbed_slot_data.quantity > 0:
		return grabbed_slot_data
	else:
		return null

func on_slot_clicked(index: int, button: int) -> void:
	inventory_interact.emit(self, index, button)
