extends Resource
class_name InventoryData

## Сигнал обновления инвентаря
signal inventory_update(inventory_data: InventoryData)
## Сигнал взаимодействия с инвентарем
signal inventory_interact(inventory_data: InventoryData, index: int, button: int)

@export var inv_name: String
@export var grid_size: Vector2i = Vector2i(5, 5)

# true  = 1 слот = 1 предмет
# false = предмет может занимать несколько клеток
@export var single_slots: bool = false

@export var slot_datas: Array[SlotData]

## Стабильный идентификатор инвентаря (player:<player_id>:inventory, chest:<chest_id> и т.д.)
## Тип инвентаря определяется по префиксу идентификатора, а не по классу
var inventory_id: String = ""


## Инициализация инвентаря
func init_inventory() -> void:
	while slot_datas.size() < size():
		slot_datas.append(SlotData.new())

	# Если массив оказался больше размера инвентаря
	while slot_datas.size() > size():
		slot_datas.pop_back()

	# В шаблонах сцен у предмета может быть не указано количество, считаем его за 1
	for slot_data: SlotData in slot_datas:
		if slot_data.item_data != null and slot_data.quantity <= 0:
			slot_data.quantity = 1

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

		if not slot_accepts(slot_datas[target_index], grabbed_slot_data):
			return grabbed_slot_data

		# Меняем только содержимое, чтобы слот сохранил свой item_category
		var old_slot_data: SlotData = target_slot_data.duplicate()

		slot_datas[target_index].item_data = grabbed_slot_data.item_data
		slot_datas[target_index].quantity = grabbed_slot_data.quantity

		inventory_update.emit(self)

		return old_slot_data


	# -----------------------------------------
	# MULTI SLOTS
	# -----------------------------------------

	# Временно убираем старый предмет

	var old_slot_data: SlotData = target_slot_data.duplicate()

	slot_datas[target_index].item_data = null
	slot_datas[target_index].quantity = 0


	# Новый предмет ставим на место,
	# где был старый предмет

	if can_place_item(
		grabbed_slot_data,
		target_index
	):

		slot_datas[target_index].item_data = grabbed_slot_data.item_data
		slot_datas[target_index].quantity = grabbed_slot_data.quantity

		inventory_update.emit(self)

		return old_slot_data


	# Не получилось поставить.
	# Возвращаем старый предмет.

	slot_datas[target_index].item_data = old_slot_data.item_data
	slot_datas[target_index].quantity = old_slot_data.quantity

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

			slot_datas[index].item_data = new_item.item_data
			slot_datas[index].quantity = new_item.quantity

		else:
			grabbed_slot_data.quantity += new_item.quantity
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

		grabbed_slot_data.quantity += new_item.quantity
		return grabbed_slot_data


	inventory_update.emit(self)


	if grabbed_slot_data.quantity > 0:
		return grabbed_slot_data


	return SlotData.new()

## Кладет предмет в другой инвентарь.
## Сначала добивает стаки такого же предмета, остаток кладет в свободное место.
## Возвращает true, если хоть что-то переместилось
func transfer_slot_data(
	index: int,
	target_inventory: InventoryData
) -> bool:

	var slot_data: SlotData = get_item_at_index(index)

	if slot_data.item_data == null:
		return false

	var start_index: int = slot_datas.find(slot_data)

	if start_index == -1:
		return false

	var moved: bool = false


	# Добиваем стаки такого же предмета
	for target_index: int in range(target_inventory.slot_datas.size()):

		if slot_data.quantity <= 0:
			break

		var target_slot_data: SlotData = target_inventory.slot_datas[target_index]

		if target_slot_data.item_data == null or target_slot_data == slot_data:
			continue

		if not target_slot_data.can_merge_with(slot_data):
			continue

		var amount: int = mini(
			slot_data.item_data.max_stack - target_slot_data.quantity,
			slot_data.quantity
		)

		target_slot_data.quantity += amount
		slot_data.quantity -= amount
		moved = true


	# Остаток кладем в свободное место
	if slot_data.quantity > 0:

		var target_index: int = \
			target_inventory.find_empty_slot(slot_data)

		if target_index != -1:

			var grabbed_data: SlotData = grab_slot_data(index)

			target_inventory.place_item(
				grabbed_data,
				target_index
			)

			moved = true

	else:
		slot_datas[start_index].item_data = null
		slot_datas[start_index].quantity = 0


	if moved:
		inventory_update.emit(self)
		target_inventory.inventory_update.emit(target_inventory)

	return moved

## Кладет предмет в другой инвентарь (оставлено для совместимости, работает как transfer_slot_data)
func transportation_slot_data(
	index: int,
	inventory_data: InventoryData
) -> void:
	transfer_slot_data(index, inventory_data)


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

## Проверка, подходит ли предмет под категорию слота
func slot_accepts(slot_data: SlotData, item_slot_data: SlotData) -> bool:
	if item_slot_data.item_data == null:
		return true
	if slot_data.item_category == 'all':
		return true
	return slot_data.item_category == item_slot_data.item_data.category


# =====================================================
# СЕРИАЛИЗАЦИЯ
# =====================================================

## Сериализация всего инвентаря.
func to_dict() -> Dictionary:
	var slots: Array[Dictionary] = []
	for slot_data: SlotData in slot_datas:
		slots.append(slot_data.to_dict())

	return {
		"inventory_id": inventory_id,
		"inv_name": inv_name,
		"grid_size": {"x": grid_size.x, "y": grid_size.y},
		"single_slots": single_slots,
		"slots": slots
	}

## Восстановление инвентаря из словаря.
static func from_dict(data: Dictionary) -> InventoryData:
	var inventory_data: InventoryData = InventoryData.new()
	inventory_data.apply_dict(data)
	return inventory_data

## Применяет словарь к текущему инвентарю, не пересоздавая объект (сигналы и UI остаются подключенными).
## keep_layout = true: применяются только предметы, размер и категории слотов остаются как в шаблоне
## (используется при загрузке сохранения)
func apply_dict(data: Dictionary, keep_layout: bool = false) -> void:
	if not keep_layout:
		inventory_id = str(data.get("inventory_id", inventory_id))
		inv_name = str(data.get("inv_name", inv_name))
		single_slots = bool(data.get("single_slots", single_slots))

		var size_data: Variant = data.get("grid_size", {})
		if size_data is Dictionary:
			grid_size = Vector2i(
				maxi(int(size_data.get("x", grid_size.x)), 1),
				maxi(int(size_data.get("y", grid_size.y)), 1)
			)

	init_inventory()

	var slots: Variant = data.get("slots", [])
	if not(slots is Array):
		push_warning("InventoryData.apply_dict: нет массива slots в '%s'" % inventory_id)
		slots = []

	for index: int in range(size()):
		var new_slot: SlotData = SlotData.new()
		if index < slots.size() and slots[index] is Dictionary:
			new_slot = SlotData.from_dict(slots[index])

		slot_datas[index].item_data = new_slot.item_data
		slot_datas[index].quantity = new_slot.quantity
		if not keep_layout:
			slot_datas[index].item_category = new_slot.item_category

	inventory_update.emit(self)


# =====================================================
# ПРОВЕРКИ И ОТКАТ (используются сервером)
# =====================================================

## Проверяет целостность инвентаря: количество, стаки, категории, занимаемая область.
## Возвращает текст ошибки или пустую строку, если все верно
func get_state_error() -> String:
	if slot_datas.size() != size():
		return "размер массива слотов %d не совпадает с grid_size %d" % [slot_datas.size(), size()]

	var occupied: Array[bool] = []
	occupied.resize(size())
	occupied.fill(false)

	for index: int in range(slot_datas.size()):
		var slot_data: SlotData = slot_datas[index]

		if slot_data.item_data == null:
			if slot_data.quantity != 0:
				slot_data.quantity = 0
			continue

		if slot_data.quantity <= 0:
			return "слот %d: количество %d <= 0" % [index, slot_data.quantity]

		if slot_data.quantity > slot_data.item_data.max_stack:
			return "слот %d: переполнение стака %d > %d" % [index, slot_data.quantity, slot_data.item_data.max_stack]

		if not slot_accepts(slot_data, slot_data):
			return "слот %d: категория '%s' не подходит слоту '%s'" % [index, slot_data.item_data.category, slot_data.item_category]

		var item_size: Vector2i = get_item_size(slot_data)
		var start_pos: Vector2i = index_to_pos(index)

		if start_pos.x + item_size.x > grid_size.x or start_pos.y + item_size.y > grid_size.y:
			return "слот %d: предмет выходит за границы инвентаря" % index

		for y: int in range(item_size.y):
			for x: int in range(item_size.x):
				var cell: int = pos_to_index(start_pos + Vector2i(x, y))
				if occupied[cell]:
					return "слот %d: предмет пересекается с другим предметом" % index
				occupied[cell] = true

	return ""

## Количество предметов по типам (для проверки, что операция не создала и не удалила предметы)
func count_items() -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {}
	for slot_data: SlotData in slot_datas:
		if slot_data.item_data != null and slot_data.quantity > 0:
			result[slot_data.item_data.type] = result.get(slot_data.item_data.type, 0) + slot_data.quantity
	return result

## Снимок состояния для отката операции
func create_backup() -> Dictionary:
	var slots: Array = []
	for slot_data: SlotData in slot_datas:
		slots.append([slot_data, slot_data.item_data, slot_data.quantity, slot_data.item_category])
	return {"grid_size": grid_size, "slots": slots}

## Откат к снимку состояния, созданному create_backup()
func restore_backup(backup: Dictionary) -> void:
	grid_size = backup["grid_size"]
	var slots: Array = backup["slots"]

	# Восстанавливаем на месте, не подменяя сам массив slot_datas
	if slot_datas.size() != slots.size():
		slot_datas.resize(slots.size())

	for index: int in range(slots.size()):
		var slot: Array = slots[index]
		var slot_data: SlotData = slot[0]
		slot_data.item_data = slot[1]
		slot_data.quantity = slot[2]
		slot_data.item_category = slot[3]
		if slot_datas[index] != slot_data:
			slot_datas[index] = slot_data

	inventory_update.emit(self)

## Сравнение текущего состояния со снимком (было ли изменение)
func equals_backup(backup: Dictionary) -> bool:
	if grid_size != backup["grid_size"] or slot_datas.size() != backup["slots"].size():
		return false
	for index: int in range(slot_datas.size()):
		var slot: Array = backup["slots"][index]
		var slot_data: SlotData = slot_datas[index]
		if slot_data != slot[0] or slot_data.item_data != slot[1] or slot_data.quantity != slot[2]:
			return false
	return true

## Копия инвентаря с независимыми слотами (ItemData остаются общими ресурсами)
func duplicate_inventory() -> InventoryData:
	var copy: InventoryData = duplicate()
	var slots: Array[SlotData] = []
	for slot_data: SlotData in slot_datas:
		slots.append(slot_data.duplicate())
	copy.slot_datas = slots
	copy.inventory_id = inventory_id
	return copy
