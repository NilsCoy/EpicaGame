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
	else:
		other_slot_data = SlotData.new()
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
	if quantity > 1 and item_data.max_stack == 1:
		quantity = 1
		push_error("%s is not stackable, max_stack == 1" % item_data.name)
