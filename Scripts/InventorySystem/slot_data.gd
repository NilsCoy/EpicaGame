extends Resource
class_name SlotData

@export var item_data: ItemData
@export_range(1, 99) var quantity: int = 1: set = set_quantity

func can_merge_with(other_slot_data: SlotData) -> bool:
	return item_data == other_slot_data.item_data \
			and item_data.max_stack > 1 \
			and quantity < item_data.max_stack

func can_fully_merge_with(other_slot_data: SlotData) -> bool:
	return item_data == other_slot_data.item_data \
			and item_data.max_stack > 1 \
			and quantity + other_slot_data.quantity < item_data.max_stack

func can_fully_merge_with_return(other_slot_data: SlotData) -> bool:
	return item_data == other_slot_data.item_data \
			and item_data.max_stack > 1 \
			and quantity + other_slot_data.quantity >= item_data.max_stack \
			and quantity < item_data.max_stack \
			and other_slot_data.quantity < item_data.max_stack

func fully_merge_with(other_slot_data: SlotData) -> void:
	quantity += other_slot_data.quantity

func fully_merge_with_return(other_slot_data: SlotData) -> SlotData:
	var temp_quantity: int = quantity + other_slot_data.quantity
	quantity = item_data.max_stack
	other_slot_data.quantity = (item_data.max_stack - temp_quantity)
	if other_slot_data.quantity != 0:
		other_slot_data.quantity *= -1
	else: other_slot_data = null
	return other_slot_data

func create_single_slot_data() -> SlotData:
	var new_slot_data: SlotData = duplicate()
	new_slot_data.quantity = 1
	quantity -= 1
	return new_slot_data

func set_quantity(value: int) -> void:
	quantity = value
	if quantity > 1 and item_data.max_stack == 1:
		quantity = 1
		push_error("%s is not stackable, max_stack == 1" % item_data.name)
