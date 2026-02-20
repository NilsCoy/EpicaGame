extends Node

func create_collision(target,layers,masks):
	var tree = []
	tree = target.get_children()
	while len(tree) > 0:
		var temp_tree = []
		for i in range(len(tree)):
			if tree[i].get_children() != []:
				for child in tree[i].get_children():
					temp_tree.append(child)
			else:
				if str(tree[i].get_class()) == 'MeshInstance3D':
					tree[i].create_trimesh_collision()
					tree[i].get_child(0).set_collision_layer_value(1, false)
					for layer in layers:
						tree[i].get_child(0).set_collision_layer_value(layer, true)
					tree[i].get_child(0).set_collision_mask_value(1, false)
					for mask in masks:
						tree[i].get_child(0).set_collision_mask_value(mask, true)
		tree = temp_tree
	pass
