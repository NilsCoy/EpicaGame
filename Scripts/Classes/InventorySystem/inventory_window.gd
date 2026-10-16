extends Control
class_name InventoryWindow

# Inventory
var grabbed_slot_data: SlotData = SlotData.new()
@export var grabbed_slot_container: Control
var grabbed_slot_offset: Vector2 = Vector2.ZERO
var grabbed_slot_last_id: int = -1
var grabbed_inv_last_data: InventoryData

func init_inventory() -> void:
	grabbed_slot_container.hide()


func _physics_process(delta: float) -> void:
	if grabbed_slot_container.visible:
		grabbed_slot_container.global_position = get_global_mouse_position() + Vector2(5, 5)
	if visible == false or Input.is_action_just_pressed('esc'):
		if grabbed_slot_last_id != -1 and grabbed_inv_last_data != null:
				grabbed_slot_data = grabbed_inv_last_data.drop_slot_data(grabbed_slot_data, grabbed_slot_last_id)
				grabbed_slot_last_id = -1
				grabbed_inv_last_data = null
				update_grabbed_slot()

	#if grabbed_slot_container.visible:
		#grabbed_slot_container.global_position = \
			#get_global_mouse_position() \
			#- grabbed_slot_offset \
			#+ Vector2(5, 5)

func on_inventory_interact(inv_data: InventoryData, index: int, button: int) -> void:
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
