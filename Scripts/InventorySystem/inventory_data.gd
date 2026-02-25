extends Resource
class_name InventoryData

signal inventory_update(inventory_data: InventoryData)
signal inventory_interact(inventory_data: InventoryData, index: int, button: int)

@export var inv_name: String
@export var slot_datas: Array[SlotData]

func find_item_index(item_name: String) -> int:
	for slot_index in range(len(slot_datas)):
		var slot_data = slot_datas[slot_index]
		if slot_data:
			if slot_data.item_data.name == item_name:
				return slot_index
	return -1

func find_slot_data(item_name: String) -> SlotData:
	for slot_index in range(len(slot_datas)):
		var slot_data = slot_datas[slot_index]
		if slot_data:
			if slot_data.item_data.name == item_name:
				return slot_data
	return null

func find_empty_slot() -> int:
	for slot_index in range(len(slot_datas)):
		if not(slot_datas[slot_index]): return slot_index
	return -1

func transportation_slot_data(index: int, inventory_data: InventoryData) -> void:
	var slot_data = slot_datas[index]
	if slot_data:
		var slot_index: int = inventory_data.find_item_index(slot_data.item_data.name)
		if slot_index != -1:
			inventory_data.drop_slot_data(grab_slot_data(index), slot_index)
		else:
			slot_index = inventory_data.find_empty_slot()
			if slot_index != -1:
				inventory_data.drop_slot_data(grab_slot_data(index), slot_index)

func grab_slot_data(index: int) -> SlotData:
	var slot_data = slot_datas[index]
	if slot_data:
		slot_datas[index] = null
		inventory_update.emit(self)
	return slot_data

func grab_hafl_slot_data(index: int) -> SlotData:
	var slot_data = slot_datas[index]
	var return_slot_data: SlotData
	
	if slot_data:
		return_slot_data = slot_data.duplicate()
		return_slot_data.quantity = ceili(float(return_slot_data.quantity)/2)
		slot_data.quantity = floori(float(slot_data.quantity)/2)
		if slot_data.quantity == 0:
			slot_data = null
		slot_datas[index] = slot_data
		inventory_update.emit(self)
	return return_slot_data

func drop_slot_data(grabbed_slot_data: SlotData, index: int) -> SlotData:
	var slot_data = slot_datas[index]
	var return_slot_data: SlotData
	if slot_data and slot_data.can_fully_merge_with(grabbed_slot_data):
		slot_data.fully_merge_with(grabbed_slot_data)
	elif slot_data and slot_data.can_fully_merge_with_return(grabbed_slot_data):
		return_slot_data = slot_data.fully_merge_with_return(grabbed_slot_data)
	else:
		slot_datas[index] = grabbed_slot_data
		return_slot_data = slot_data
	
	inventory_update.emit(self)
	return return_slot_data
	
func drop_single_slot_data(grabbed_slot_data: SlotData, index: int) -> SlotData:
	var slot_data = slot_datas[index]
	
	if not slot_data:
		slot_datas[index] = grabbed_slot_data.create_single_slot_data()
	elif slot_data.can_merge_with(grabbed_slot_data):
		slot_data.fully_merge_with(grabbed_slot_data.create_single_slot_data())
	
	inventory_update.emit(self)
	if grabbed_slot_data.quantity > 0: return grabbed_slot_data
	else: return null

func on_slot_clicked(index: int, button: int) -> void:
	inventory_interact.emit(self, index, button)
