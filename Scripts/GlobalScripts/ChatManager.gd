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
		"help": _command_help(from, command)
		"say": _command_say(from, command)
		"summon": _command_summon(from, command)
		"damage": _command_damage(from, command)
		"gamemode": _command_gamemode(from, command)
		"spawnpoint": _command_spawnpoint(from, command)
		"setspawn": _command_setspawn(from, command)
		"save": _command_save(from, command)
		"restart": _command_restart(from, command)
		"test": _command_test(from, command)
		_:
			send_message(from, 'Неправильная команда!')
			send_message(from, 'Список команд: /help')


func _command_test(from: Node, command: Array) -> void:
	MultiplayerManager.send_message("Hello server!")

func _command_setspawn(from: Node, command: Array) -> void:
	if command.size() == 1:
		send_message(from, 'Точка мирового спавна переопределена на координаты игрока')
		Settings.world['settings']['spawn_position'] = from.position
		Settings.world['settings']['spawn_rotation'] = from.model.model.rotation

func _command_restart(from: Node, command: Array) -> void:
	if command.size() == 2:
		match command[1]:
			'game':
				get_tree().reload_current_scene()
			'server':
				pass
			_:
				send_message(from, 'Неправильная команда!')
				send_message(from, 'Используй: /restart <game/server>')
	else:
		send_message(from, 'Неправильная команда!')
		send_message(from, 'Используй: /restart <game/server>')

func _command_save(from: Node, command: Array) -> void:
	send_message(from, 'Мир сохранен!')
	FileManager.call_save_on_all_nodes(get_tree().root)

func _command_spawnpoint(from: Node, command: Array) -> void:
	if command.size() == 1:
		send_message(from, 'Точка спавна переопределена на координаты игрока')
		from.spawn_position = from.position
		from.spawn_rotation = from.model.model.rotation
	elif command.size() == 4:
		send_message(from, 'Точка спавна переопределена на координаты: {x}, {y}, {z}'.format(
			{'x':command[1], 'y':command[2], 'z':command[3]}
			))
		from.spawn_position = Vector3(float(command[1]), float(command[2]), float(command[3]))
		from.spawn_rotation = Vector3.ZERO
	elif command.size() == 7:
		send_message(from, 'Точка спавна переопределена на координаты: {x}, {y}, {z} | {nx}, {ny}, {nz}'.format(
		{'x':command[1], 'y':command[2], 'z':command[3], 'nx':command[4], 'ny':command[5], 'nz':command[6]}
		))
		from.spawn_position = Vector3(float(command[1]), float(command[2]), float(command[3]))
		from.spawn_rotation = Vector3(float(command[4]), float(command[5]), float(command[6]))

func _command_gamemode(from: Node, command: Array) -> void:
	if command.size() == 2:
		if int(command[1]) >= 0 and int(command[1]) <= 2:
			from.switch_gamemode(int(command[1]))
			match command[1]:
				"0": send_message(from, "Ваш режим сменен на survival")
				"1": send_message(from, "Ваш режим сменен на creative")
				"2": send_message(from, "Ваш режим сменен на spectator")
		else:
			send_message(from, 'Неправильная команда!')
			send_message(from, 'Используй: /gamemode <number>')
			send_message(from, '0: survival')
			send_message(from, '1: creative')
			send_message(from, '2: spectator')
	else:
		send_message(from, 'Неправильная команда!')
		send_message(from, 'Используй: /gamemode <number>')
		send_message(from, '0: survival')
		send_message(from, '1: creative')
		send_message(from, '2: spectator')

func _command_help(from: Node, command: Array) -> void:
	send_message(from, "")

func _command_say(from: Node, command: Array) -> void:
	if command.size() == 2:
		send_message(from, "Server: " + command[1])
	else:
		send_message(from, 'Неправильная команда!')
		send_message(from, 'Используй: /say <message>')

func _command_damage(from: Node, command: Array) -> void:
	if command.size() == 2:
		var component: Node = from.components.get_component('HealthComponent')
		if component != null:
			component.take_damage(null, float(command[1]))
			send_message(from, 'Вам нанесен урон: '+str(command[1]))
		else:
			send_message(from, 'Не найден компонент здоровья!')
	else:
		send_message(from, 'Неправильная команда!')
		send_message(from, 'Используй: /damage <amount>')

func _command_summon(from: Node, command: Array) -> void:
	if command.size() == 3:
		for i: int in range(int(command[2])):
			var path: String = "res://Scenes/Entities/" + command[1] + ".tscn"
			var entity_res: Resource = load(path)
			var entity: CharacterBody3D = entity_res.instantiate()
			entity.position = from.position
			entity.rotation = from.model.model.rotation
			get_tree().root.get_node("Main/Map").entities.add_child(entity)
	else:
		send_message(from, 'Неправильная команда!')
		send_message(from, 'Используй: /summon <type> <amount>')
