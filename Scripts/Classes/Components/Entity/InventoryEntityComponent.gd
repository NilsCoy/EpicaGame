extends EntityComponent
class_name InventoryEntityComponent

## Интерфейс с инвентарем
@export var node_inventory: Node

## Слот шлема
@export var head: BoneAttachment3D
## Слот брони
@export var body: MeshInstance3D
## Слот основного оружия
@export var right_equip: Node3D
## Слот дополнительного оружия
@export var left_equip: Node3D

## Инвентарь игрока
var player_inventory: InventoryData:
	get:
		return node_inventory.player_inventory.inventory_data
## Экипировка игрока
var equip_inventory: InventoryData:
	get:
		return node_inventory.player_inventory.equip_data

var equiped: Array[ItemData] = [
	null, null,
	null, null,
	null, null,
	null,
]

func get_component_type() -> String:
	return "InventoryEntityComponent"

func _ready() -> void:
	equip_inventory.inventory_update.connect(_on_equip_inventory_update)

## Собираем все характеристики экипировки в один массив
func get_equip_properties() -> Dictionary:
	var properties: Dictionary
	for i: int in range(equip_inventory.slot_datas.size()):
		var item: ItemData = equip_inventory.slot_datas[i].item_data
		if item != null:
			properties[item.type] = item.get_properties()
	return properties

## Вызывается при обновлении инвентаря, обновляет одетую экипировку
func _on_equip_inventory_update(inventory_data: InventoryData) -> void:
	for i: int in range(inventory_data.slot_datas.size()):
		var item: ItemData = equip_inventory.slot_datas[i].item_data
		if item != null and equiped[i] != item:
			equiped[i] = item
		if item == null:
			equiped[i] = null
		_equip_item(i)

func _equip_item(index: int) -> void:
	var item: ItemData = equiped[index]
	match index:
		0:
			if item != null:
				var armor_component: ArmorItemComponent = item.get_component(ArmorItemComponent)
				if armor_component != null:
					var helmet: MeshInstance3D = load(armor_component.model_path).instantiate()
					head.add_child(helmet)
			else:
				for child: Node in head.get_children():
					child.queue_free()
		1:
			if item != null:
				var armor_component: ArmorItemComponent = item.get_component(ArmorItemComponent)
				if armor_component != null:
					var chest: MeshInstance3D = load(armor_component.model_path).instantiate()
					chest.skeleton = body.get_parent().get_path()
					body.add_child(chest)
			else:
				for child: Node in body.get_children():
					child.queue_free()
		2:
			if item != null:
				var weapon_component: WeaponItemComponent = item.get_component(WeaponItemComponent)
				if weapon_component != null:
					right_equip.texture = item.texture
					right_equip.pivot = weapon_component.pivot
					right_equip.collision_size = weapon_component.collision_size
					right_equip.collision_offset = weapon_component.collision_offset
					right_equip.start_attack = weapon_component.start_attack
					right_equip.end_attack = weapon_component.end_attack
					right_equip.show()
					right_equip.rebuild()
			else:
				right_equip.hide()
		3:
			if item != null:
				var weapon_component: WeaponItemComponent = item.get_component(WeaponItemComponent)
				if weapon_component != null:
					left_equip.texture = item.texture
					left_equip.pivot = weapon_component.pivot
					left_equip.collision_size = weapon_component.collision_size
					left_equip.collision_offset = weapon_component.collision_offset
					left_equip.start_attack = weapon_component.start_attack
					left_equip.end_attack = weapon_component.end_attack
					left_equip.show()
					right_equip.rebuild()
			else:
				left_equip.hide()
