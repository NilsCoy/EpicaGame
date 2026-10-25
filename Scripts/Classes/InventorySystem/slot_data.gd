extends Resource
class_name SlotData

## Вложенный предмет в слот
@export var item_data: ItemData
## Количество предметов в слоте
@export_range(0, 99) var quantity: int = 0: set = set_quantity
## Тип предмета доступный во вложение
@export_enum('all', 'head', 'chest', 'weapon', 'consumable') var item_category: String = 'all'

## Проверяет, может ли текущий слот объединиться с другим слотом
func can_merge_with(other_slot_data: SlotData) -> bool:
	return item_data == other_slot_data.item_data \
			and item_data.max_stack > 1 \
			and quantity < item_data.max_stack

## Проверяет, может ли текущий слот полностью объединиться с другим слотом
func can_fully_merge_with(other_slot_data: SlotData) -> bool:
	return item_data == other_slot_data.item_data \
			and item_data.max_stack > 1 \
			and quantity + other_slot_data.quantity < item_data.max_stack

## Проверяет, можно ли заполнить текущий слот до максимума и вернуть остаток
func can_fully_merge_with_return(other_slot_data: SlotData) -> bool:
	return item_data == other_slot_data.item_data \
			and item_data.max_stack > 1 \
			and quantity + other_slot_data.quantity >= item_data.max_stack \
			and quantity < item_data.max_stack \
			and other_slot_data.quantity < item_data.max_stack

## Полностью объединяет количество из other_slot_data в текущий слот
func fully_merge_with(other_slot_data: SlotData) -> void:
	quantity += other_slot_data.quantity

## Объединяет слоты с возвратом остатка
## Заполняет текущий слот до максимума, а остаток возвращает в other_slot_data
## Если остаток равен 0, возвращает null
func fully_merge_with_return(other_slot_data: SlotData) -> SlotData:
	var temp_quantity: int = quantity + other_slot_data.quantity
	quantity = item_data.max_stack
	other_slot_data.quantity = (item_data.max_stack - temp_quantity)
	if other_slot_data.quantity != 0:
		other_slot_data.quantity *= -1
	else: other_slot_data = SlotData.new()
	return other_slot_data

## Cоздает новый слот с одним предметом и уменьшает количество в текущем слоте на 1
## Используется для разделения стека предметов
func create_single_slot_data() -> SlotData:
	var new_slot_data: SlotData = duplicate()
	new_slot_data.quantity = 1
	quantity -= 1
	return new_slot_data

## Сеттер для quantity с проверкой стакабельности предмета
## Если предмет не стакабельный (max_stack == 1), сбрасывает количество на 1 и выводит ошибку
func set_quantity(value: int) -> void:
	quantity = value
	if item_data != null and quantity > 1 and item_data.max_stack == 1:
		quantity = 1
		push_error("%s is not stackable, max_stack == 1" % item_data.name)

## Сериализация слота в словарь.
## Передается только строковый идентификатор предмета (item_data.type), без ресурса
func to_dict() -> Dictionary:
	return {
		"item": item_data.type if item_data != null else "",
		"quantity": quantity if item_data != null else 0,
		"item_category": item_category
	}

## Восстановление слота из словаря.
## Неизвестный предмет не вызывает краш: слот остается пустым, выводится предупреждение
static func from_dict(data: Dictionary) -> SlotData:
	var slot_data: SlotData = SlotData.new()
	slot_data.item_category = str(data.get("item_category", "all"))

	var item_type: String = str(data.get("item", ""))
	if item_type == "":
		return slot_data

	var item: ItemData = ItemRegistry.get_item(item_type)
	if item == null:
		push_warning("SlotData.from_dict: неизвестный предмет '%s', слот очищен" % item_type)
		return slot_data

	var item_quantity: int = int(data.get("quantity", 0))
	if item_quantity <= 0:
		push_warning("SlotData.from_dict: неверное количество %d для '%s', слот очищен" % [item_quantity, item_type])
		return slot_data
	if item_quantity > item.max_stack:
		push_warning("SlotData.from_dict: количество %d для '%s' больше max_stack %d, обрезано" % [item_quantity, item_type, item.max_stack])
		item_quantity = item.max_stack

	slot_data.item_data = item
	slot_data.quantity = item_quantity
	return slot_data
