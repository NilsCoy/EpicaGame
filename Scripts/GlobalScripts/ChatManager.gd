extends Node

func send(from: Node, message: String) -> void:
	if from != null:
		if message[0] == "/":
			send_command(from, message.substr(1).split(" "))
		else:
			send_message(from, from.name + ": " + message)

func send_message(from: Node, message: String) -> void:
	from.chat.text = from.chat.text + message + "\n"

func send_command(from: Node, command: Array) -> void:
	match command[0]:
		"test":
			var entity_res: Resource = preload("res://Scenes/Entities/traning_dummy.tscn")
			var entity: CharacterBody3D = entity_res.instantiate()
			entity.position = from.position
			entity.rotation = from.model.model.rotation
			get_tree().root.get_node("Main/Map").entities.add_child(entity)
