extends Node

func send(from: Node, message: String) -> void:
	if from != null:
		if message[0] == "/":
			send_command(from.player_id, message.substr(1).split(" "))
		else:
			send_broadcast(from.name + ": " + message)
			MultiplayerManager.rpc_id(1, "send_log", from.name + ": " + message)

func send_message(to: int , message: String) -> void:
	rpc_id(1, "_send_message_to_server", to, message)

@rpc("any_peer", "reliable")
func _send_message_to_server(to: int, message: String) -> void:
	if multiplayer.is_server():
		for player: CharacterBody3D in get_tree().get_nodes_in_group("Players"):
			if player.player_id == to:
				rpc_id(player.player_id, "_message", message)

@rpc("authority", "reliable")
func _message(message: String) -> void:
	for player: CharacterBody3D in get_tree().get_nodes_in_group("Players"):
		if player.player_id == multiplayer.get_unique_id():
			player.chat.text += message + "\n"

func send_broadcast(message: String) -> void:
	rpc_id(1, "_send_broadcast_to_server", message)

@rpc("any_peer", "reliable")
func _send_broadcast_to_server(message: String) -> void:
	if multiplayer.is_server():
		rpc("_broadcast", message)

@rpc("authority", "reliable")
func _broadcast(message: String) -> void:
	for player: CharacterBody3D in get_tree().get_nodes_in_group("Players"):
		player.chat.text += message + "\n"

func send_command(from: int, command: Array) -> void:
	rpc_id(1, "_send_command_to_server", from, command)
	
	#match command[0]:
		#"help": _command_help(from, command)
		#"say": _command_say(from, command)
		#"summon": _command_summon(from, command)
		#"damage": _command_damage(from, command)
		#"gamemode": _command_gamemode(from, command)
		#"spawnpoint": _command_spawnpoint(from, command)
		#"setspawn": _command_setspawn(from, command)
		#"save": _command_save(from, command)
		#"restart": _command_restart(from, command)
		#"test": _command_test(from, command)
		#_:
			#send_message(from, 'Неправильная команда!')
			#send_message(from, 'Список команд: /help')

@rpc("any_peer", "reliable")
func _send_command_to_server(from: int, command: Array) -> void:
	if multiplayer.is_server():
		for player: CharacterBody3D in get_tree().get_nodes_in_group("Players"):
			if player.player_id == from:
				MultiplayerManager.send_log(str(player.name, " -> ", command))
				match command[0]:
					"setspawn": _command_setspawn(player, command)
					"gamemode": _command_gamemode(player, command)
					_:
						#send_message(player.player_id, 'Неправильная команда!')
						#send_message(player.player_id, 'Список команд: /help')
						rpc_id(player.player_id, "_message", 'Неправильная команда!')
						rpc_id(player.player_id, "_message", 'Список команд: /help')

func _command_setspawn(from: Node, command: Array) -> void:
	if command.size() == 1:
		rpc_id(from.player_id, "_message", 'Точка мирового спавна переопределена на координаты игрока')
		Settings.world['settings']['spawn_position'] = [from.position.x, from.position.y, from.position.z]
		Settings.world['settings']['spawn_rotation'] = [from.model.model.rotation.x, from.model.model.rotation.y, from.model.model.rotation.z]
		Settings.save_world_settings()
		get_tree().root.get_node('Main/Map').update_spawn()

func _command_restart(from: Node, command: Array) -> void:
	if command.size() == 2:
		match command[1]:
			'game':
				get_tree().reload_current_scene()
			'server':
				pass
			_:
				send_message(from.player_id, 'Неправильная команда!')
				send_message(from.player_id, 'Используй: /restart <game/server>')
	else:
		send_message(from.player_id, 'Неправильная команда!')
		send_message(from.player_id, 'Используй: /restart <game/server>')

func _command_save(from: Node, command: Array) -> void:
	send_message(from.player_id, 'Мир сохранен!')
	FileManager.call_save_on_all_nodes(get_tree().root)

func _command_spawnpoint(from: Node, command: Array) -> void:
	if command.size() == 1:
		send_message(from.player_id, 'Точка спавна переопределена на координаты игрока')
		from.spawn_position = from.position
		from.spawn_rotation = from.model.model.rotation
	elif command.size() == 4:
		send_message(from.player_id, 'Точка спавна переопределена на координаты: {x}, {y}, {z}'.format(
			{'x':command[1], 'y':command[2], 'z':command[3]}
			))
		from.spawn_position = Vector3(float(command[1]), float(command[2]), float(command[3]))
		from.spawn_rotation = Vector3.ZERO
	elif command.size() == 7:
		send_message(from.player_id, 'Точка спавна переопределена на координаты: {x}, {y}, {z} | {nx}, {ny}, {nz}'.format(
		{'x':command[1], 'y':command[2], 'z':command[3], 'nx':command[4], 'ny':command[5], 'nz':command[6]}
		))
		from.spawn_position = Vector3(float(command[1]), float(command[2]), float(command[3]))
		from.spawn_rotation = Vector3(float(command[4]), float(command[5]), float(command[6]))

func _command_gamemode(from: Node, command: Array) -> void:
	if command.size() == 2:
		if int(command[1]) >= 0 and int(command[1]) <= 2:
			from.switch_gamemode(int(command[1]))
			from.rpc_id(from.player_id, 'switch_gamemode', int(command[1]))
			match command[1]:
				"0": rpc_id(from.player_id, '_message', 'Ваш режим сменен на survival')
				"1": rpc_id(from.player_id, '_message', 'Ваш режим сменен на creative')
				"2": rpc_id(from.player_id, '_message', 'Ваш режим сменен на spectator')
		else:
			rpc_id(from.player_id, '_message', 'Неправильная команда!')
			rpc_id(from.player_id, '_message', 'Используй: /gamemode <number>')
			rpc_id(from.player_id, '_message', '0: survival')
			rpc_id(from.player_id, '_message', '1: creative')
			rpc_id(from.player_id, '_message', '2: spectator')
	else:
		rpc_id(from.player_id, '_message', 'Неправильная команда!')
		rpc_id(from.player_id, '_message', 'Используй: /gamemode <number>')
		rpc_id(from.player_id, '_message', '0: survival')
		rpc_id(from.player_id, '_message', '1: creative')
		rpc_id(from.player_id, '_message', '2: spectator')

#func _command_gamemode(from: Node, command: Array) -> void:
	#if command.size() == 2:
		#if int(command[1]) >= 0 and int(command[1]) <= 2:
			#from.switch_gamemode(int(command[1]))
			#match command[1]:
				#"0": send_message(from.player_id, "Ваш режим сменен на survival")
				#"1": send_message(from.player_id, "Ваш режим сменен на creative")
				#"2": send_message(from.player_id, "Ваш режим сменен на spectator")
		#else:
			#send_message(from.player_id, 'Неправильная команда!')
			#send_message(from.player_id, 'Используй: /gamemode <number>')
			#send_message(from.player_id, '0: survival')
			#send_message(from.player_id, '1: creative')
			#send_message(from.player_id, '2: spectator')
	#else:
		#send_message(from.player_id, 'Неправильная команда!')
		#send_message(from.player_id, 'Используй: /gamemode <number>')
		#send_message(from.player_id, '0: survival')
		#send_message(from.player_id, '1: creative')
		#send_message(from.player_id, '2: spectator')

func _command_help(from: Node, command: Array) -> void:
	send_message(from.player_id, "")

func _command_say(from: Node, command: Array) -> void:
	if command.size() == 2:
		send_message(from.player_id, "Server: " + command[1])
	else:
		send_message(from.player_id, 'Неправильная команда!')
		send_message(from.player_id, 'Используй: /say <message>')

func _command_damage(from: Node, command: Array) -> void:
	if command.size() == 2:
		var component: Node = from.components.get_component('HealthComponent')
		if component != null:
			component.take_damage(null, float(command[1]))
			send_message(from.player_id, 'Вам нанесен урон: '+str(command[1]))
		else:
			send_message(from.player_id, 'Не найден компонент здоровья!')
	else:
		send_message(from.player_id, 'Неправильная команда!')
		send_message(from.player_id, 'Используй: /damage <amount>')

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
		send_message(from.player_id, 'Неправильная команда!')
		send_message(from.player_id, 'Используй: /summon <type> <amount>')
