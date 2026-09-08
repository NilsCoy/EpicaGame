extends EntityComponent
class_name InventoryEntityComponent

@export var node_inventory: Node

var player_inventory: InventoryData:
	get:
		return node_inventory.player_inventory.inventory_data
var equip_inventory: InventoryData:
	get:
		return node_inventory.player_inventory.equip_data

func get_component_type() -> String:
	return "InventoryEntityComponent"

func get_equip_properties() -> Dictionary:
	var properties: Dictionary
	for i: int in range(equip_inventory.slot_datas.size()):
		var item: ItemData = equip_inventory.slot_datas[i].item_data
		if item != null:
			properties[item.type] = item.get_properties()
	return properties
