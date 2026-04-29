extends Node

func has_flag(flag: String) -> bool:
	return flag in OS.get_cmdline_args()

func create_collision(target: Variant, layers: Array[int], masks: Array[int]) -> void:
	var tree: Array = []
	tree = target.get_children()
	while len(tree) > 0:
		var temp_tree: Array = []
		for i: int in range(len(tree)):
			if tree[i].get_children() != []:
				for child: Node in tree[i].get_children():
					temp_tree.append(child)
			else:
				if str(tree[i].get_class()) == 'MeshInstance3D':
					tree[i].create_trimesh_collision()
					tree[i].get_child(0).set_collision_layer_value(1, false)
					for layer: int in layers:
						tree[i].get_child(0).set_collision_layer_value(layer, true)
					tree[i].get_child(0).set_collision_mask_value(1, false)
					for mask: int in masks:
						tree[i].get_child(0).set_collision_mask_value(mask, true)
		tree = temp_tree

func replace_to_static(node_from: Variant) -> StaticBody3D:
	var new_node: StaticBody3D = StaticBody3D.new()
	new_node.name = node_from.name
	new_node.transform = node_from.transform
	new_node.owner = node_from.owner

	for child: Node in node_from.get_children():
		node_from.remove_child(child)
		new_node.add_child(child)

	return new_node

func generate_uuid_v4() -> String:
	var crypto: Crypto = Crypto.new()
	var b: PackedByteArray = crypto.generate_random_bytes(16)
	# UUID v4 правки битов
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		b[0], b[1], b[2], b[3],
		b[4], b[5],
		b[6], b[7],
		b[8], b[9],
		b[10], b[11], b[12], b[13], b[14], b[15]
	]
