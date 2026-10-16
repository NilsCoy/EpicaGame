extends Node

var thread: Thread = Thread.new()
var _stdin_running: bool = true
var _stdin_mutex: Mutex = Mutex.new()

func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		print(r"""
 ███▀█▄  ███ █▄  ▄██▀█▄  ███     ▄██▀▄▀█▄       ███▀█▄                              
▀███▄▄   ███ ██  ███ ██ ▀███     ███ █ ██      ▀███▄▄  ▄█▀█▄ ▄█▀▀▄ ██ ▄▄ ▄█▀█▄ ▄█▀▀▄
 ▄▄▄ ██ ▀███▀█▄ ▀███▀██  ███ ▄▄ ▀███   ██       ▄▄▄ ██ ██▀▀  ██    ▐█ █▌ ██▀▀  ██   
 ▀▀▀▀▀▀  ▀▀▀ ▀▀  ▀▀▀ ▀▀   ▀▀▀▀▀  ▀▀▀    ▀       ▀▀▀▀▀▀  ▀▀▀  ▀▀     ▀▀▀   ▀▀▀  ▀▀                                                  
""")
		print("Console ready. Type commands in terminal.")
		thread.start(_stdin_thread)

func _stdin_thread() -> void:
	while true:
		# Проверяем флаг под защитой мьютекса
		_stdin_mutex.lock()
		if not _stdin_running:
			_stdin_mutex.unlock()
			return
		_stdin_mutex.unlock()
		
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

#func _command_stop() -> void:
	#print('Server is stopping')
	#get_tree().root.get_node("Main/Map").save()
	#print('Map saved')
	#print('Server is stoped')
	#OS.kill(OS.get_process_id())
func _command_stop() -> void:
	print('Server is stopping')
	get_tree().root.get_node("Main/Map").save()
	print('Map saved')
	
	# Даём потоку команду завершиться
	# (нужно добавить флаг или использовать Mutex)
	# ... ваш механизм остановки ...
	
	# Сигнализируем потоку, что пора завершаться
	_stdin_mutex.lock()
	_stdin_running = false
	_stdin_mutex.unlock()
	
	# Дожидаемся завершения потока (это критично!)
	if thread.is_started():
		thread.wait_to_finish()
	
	print('Server is stopped')
	#get_tree().quit()
	OS.kill(OS.get_process_id())
