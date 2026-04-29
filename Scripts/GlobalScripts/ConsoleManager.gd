extends Node

var thread: Thread = Thread.new()

func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		print(r"""
 _____      _             _____                          
|  ___|    (_)           /  ___|                         
| |__ _ __  _  ___ __ _  \ `--.  ___ _ ____   _____ _ __ 
|  __| '_ \| |/ __/ _` |  `--. \/ _ \ '__\ \ / / _ \ '__|
| |__| |_) | | (_| (_| | /\__/ /  __/ |   \ V /  __/ |   
\____/ .__/|_|\___\__,_| \____/ \___|_|    \_/ \___|_|   
     | |                                                 
     |_|                                                 
""")
		print("Console ready. Type commands in terminal.")
		thread.start(_stdin_thread)

func _stdin_thread() -> void:
	while true:
		var line: String = OS.read_string_from_stdin()
		if line != "":
			line = line.strip_edges()
			if line != "":
				call_deferred("execute", line)

func execute(line: String) -> void:
	var args: Array = line.split(" ")
	match args[0]:
		"stop": _command_stop()
		#"kick": print("Kick player:", args[1])
		"test": print("This is test message!")

func _command_stop() -> void:
	print('Server is stopping')
	get_tree().root.get_node("Main/Map").save()
	print('Map saved')
	print('Server is stoped')
	OS.kill(OS.get_process_id())
