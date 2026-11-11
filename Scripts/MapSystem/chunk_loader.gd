extends Node
## Загрузчик чанков вокруг игрока.
## Клиент: следит за чанком игрока, запрашивает колонки X/Z в радиусе (ближние первыми) и выгружает чанки за его пределами.
## Клиент: сообщает карте, когда начальные чанки вокруг спавна распакованы и построены.
## Сервер: отправляет чанки вокруг спавна при входе, хранит центры игроков и рассылает клиентам изменённые чанки (флаг dirty).
## Пул из WORKER_COUNT потоков выполняет задачи: распаковку пакета и построение меша чанка.
## Ноды создаются и удаляются только в главном потоке.
## Метод rebuild_chunks принимает чанки от WorldEdit и ставит их перестроение в пул.

## Сигнал: начальные чанки вокруг спавна получены, распакованы и построены (клиент).
signal initial_chunks_ready

## Количество потоков в пуле.
const WORKER_COUNT: int = 4
## Радиус загрузки в чанках по X/Z.
const LOAD_RADIUS: int = 10
## Сцена чанка.
const CHUNK_SCENE: PackedScene = preload("res://Scenes/MapSystem/chunk.tscn")

## Размер чанка в блоках (берётся из WorldEdit).
var chunk_size: int = WorldEdit.CHUNK_SIZE

## Колонки X/Z, которые клиент уже запросил и держит в радиусе.
var _requested: Dictionary = {}
## Текущий центр загрузки клиента (X/Z чанка).
var _center: Vector2i = Vector2i.ZERO
## Известен ли центр загрузки клиента.
var _has_center: bool = false
## Центры игроков на сервере: peer_id -> Vector2i.
var _peer_centers: Dictionary = {}

## Чанки, у которых сейчас строится меш в потоке: имя -> Node3D (только главный поток).
var _busy: Dictionary = {}
## Данные, пришедшие, пока чанк был занят потоком: имя -> Dictionary.
var _pending: Dictionary = {}
## Чанки, которые нужно удалить, когда поток закончит работу: имя -> true.
var _unload_pending: Dictionary = {}
## Чанки, которые изменились, пока поток строил их меш: имя -> Node3D. Перестроятся повторно после потока.
var _rebuild_again: Dictionary = {}

## Сколько пакетов чанков распаковано с момента подключения (клиент).
var _decoded_count: int = 0
## Сколько начальных чанков ожидается от сервера, -1 если ожидание не активно (клиент).
var _initial_target: int = -1

## Очередь задач для потоков.
var _queue: Array[Callable] = []
## Мьютекс очереди задач.
var _queue_mutex: Mutex = Mutex.new()
## Семафор: сколько задач ждёт в очереди.
var _queue_semaphore: Semaphore = Semaphore.new()
## Флаг остановки потоков.
var _stopping: bool = false
## Потоки пула.
var _workers: Array[Thread] = []

## Запускает потоки пула.
func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	for i: int in WORKER_COUNT:
		var worker: Thread = Thread.new()
		worker.start(_worker_loop)
		_workers.append(worker)

## Останавливает потоки пула.
func _exit_tree() -> void:
	_queue_mutex.lock()
	_stopping = true
	_queue_mutex.unlock()
	for i: int in WORKER_COUNT:
		_queue_semaphore.post()
	for worker: Thread in _workers:
		worker.wait_to_finish()
	_workers.clear()

## Клиент обновляет центр загрузки, сервер рассылает изменённые чанки.
func _process(_delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		_broadcast_dirty_chunks()
	else:
		_update_center()

# ============================================================
#  ПЕРЕСТРОЕНИЕ ИЗ WORLDEDIT
# ============================================================

## Главный поток: ставит перестроение мешей чанков в пул. Вызывается из WorldEdit после изменения блоков.
## Чанк, который уже строится, помечается на повторное перестроение, чтобы не потерять последние изменения.
func rebuild_chunks(chunks: Array) -> void:
	for chunk: Node3D in chunks:
		if not is_instance_valid(chunk) or chunk.is_queued_for_deletion():
			continue
		var chunk_name: String = chunk.name
		if _busy.has(chunk_name):
			_rebuild_again[chunk_name] = chunk
			continue
		_start_mesh(chunk)

## Главный поток: очищает старые ModelBlock-ноды и отправляет чанк в пул на построение меша.
func _start_mesh(chunk: Node3D) -> void:
	var chunk_name: String = chunk.name
	_clear_model_blocks(chunk)
	_busy[chunk_name] = chunk
	_enqueue(_mesh_job.bind(chunk, chunk_name))

# ============================================================
#  КЛИЕНТ
# ============================================================

## Клиент: получает от сервера центр спавна и количество начальных чанков.
## Колонки вокруг спавна помечаются как запрошенные, чтобы не запрашивать их повторно.
func begin_initial_load(expected: int, center: Vector2i) -> void:
	_center = center
	_has_center = true
	for x: int in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for z: int in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			_requested[center + Vector2i(x, z)] = true
	_initial_target = expected
	_check_initial_ready()

## Пересчитывает центр игрока. При смене чанка выгружает лишнее и запрашивает недостающее.
func _update_center() -> void:
	var player: Node3D = _get_local_player()
	if player == null:
		return
	var center: Vector2i = Vector2i(
		floori(player.global_position.x / chunk_size),
		floori(player.global_position.z / chunk_size)
	)
	if _has_center and center == _center:
		return
	_center = center
	_has_center = true
	_unload_outside_radius()

	var missing: Array[Vector2i] = []
	for x: int in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for z: int in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var column: Vector2i = _center + Vector2i(x, z)
			if not _requested.has(column):
				_requested[column] = true
				missing.append(column)
	# Ближние колонки запрашиваем первыми
	missing.sort_custom(_sort_by_distance)
	rpc_id(1, "request_chunks", _center, missing)

## Сортирует колонки по расстоянию до текущего центра.
func _sort_by_distance(a: Vector2i, b: Vector2i) -> bool:
	return (a - _center).length_squared() < (b - _center).length_squared()

## Удаляет чанки и запросы колонок, которые вышли за радиус.
func _unload_outside_radius() -> void:
	for column: Vector2i in _requested.keys():
		if not _is_in_radius(column, _center):
			_requested.erase(column)
	for chunk: Node in get_parent().chunks.get_children():
		var column: Vector2i = _column_from_position((chunk as Node3D).position)
		if _is_in_radius(column, _center):
			continue
		var chunk_name: String = chunk.name
		_pending.erase(chunk_name)
		_rebuild_again.erase(chunk_name)
		if _busy.has(chunk_name):
			# Поток ещё читает blocks: удалим чанк, когда он закончит
			_unload_pending[chunk_name] = true
		else:
			chunk.queue_free()

## Главный поток: получает распакованные данные и считает их для ожидания начальной загрузки.
func _on_chunk_decoded(data: Dictionary) -> void:
	_decoded_count += 1
	_route_decoded(data)
	_check_initial_ready()

## Главный поток: направляет данные чанка в создание/обновление или откладывает, если чанк занят.
func _route_decoded(data: Dictionary) -> void:
	var chunk_pos: Vector3 = data.position
	var column: Vector2i = _column_from_position(chunk_pos)
	if _has_center and not _is_in_radius(column, _center):
		return
	var chunk_name: String = data.name
	if _busy.has(chunk_name):
		# Меш этого чанка строится прямо сейчас: применим данные после него
		_unload_pending.erase(chunk_name)
		_rebuild_again.erase(chunk_name)
		_pending[chunk_name] = data
		return
	_apply_chunk(data)

## Записывает блоки в чанк (создаёт его при необходимости) и отправляет построение меша в пул.
func _apply_chunk(data: Dictionary) -> void:
	var chunk_name: String = data.name
	var chunks: Node = get_parent().chunks
	var chunk: Node3D = chunks.get_node_or_null(chunk_name) as Node3D
	if chunk != null and chunk.is_queued_for_deletion():
		# Чанк удаляется (например, пустой): освобождаем имя для нового
		chunk.name = chunk_name + "_removed"
		chunk = null
	if chunk == null:
		chunk = CHUNK_SCENE.instantiate()
		chunk.name = chunk_name
		chunk.position = data.position
		# blocks заданы до add_child: _ready чанка не будет генерировать воздух и строить меш сам
		chunk.blocks = data.blocks
		chunk.loaded_chunk = false
		chunks.add_child(chunk)
		_busy[chunk_name] = chunk
		_enqueue(_mesh_job.bind(chunk, chunk_name))
	else:
		chunk.blocks = data.blocks
		_start_mesh(chunk)

## Главный поток: удаляет старые ModelBlock-ноды чанка перед перестроением.
## Встроенный скрипт chunk.tscn не имеет метода clear_model_blocks, поэтому очистка делается здесь.
func _clear_model_blocks(chunk: Node3D) -> void:
	for child: Node in chunk.get_children():
		if "ModelBlock" in child.name:
			chunk.remove_child(child)
			child.queue_free()

## Главный поток: поток закончил строить меш чанка.
## Порядок: удаление > новые данные из сети > повторное перестроение после изменений.
func _on_mesh_done(chunk_name: String) -> void:
	_busy.erase(chunk_name)
	if _unload_pending.has(chunk_name):
		_unload_pending.erase(chunk_name)
		_rebuild_again.erase(chunk_name)
		var old_chunk: Node = get_parent().chunks.get_node_or_null(chunk_name)
		if old_chunk != null:
			old_chunk.queue_free()
	elif _pending.has(chunk_name):
		var data: Dictionary = _pending[chunk_name]
		_pending.erase(chunk_name)
		_rebuild_again.erase(chunk_name)
		_route_decoded(data)
	elif _rebuild_again.has(chunk_name):
		var again: Node3D = _rebuild_again[chunk_name]
		_rebuild_again.erase(chunk_name)
		if is_instance_valid(again) and not again.is_queued_for_deletion():
			_start_mesh(again)
	_check_initial_ready()

## Клиент: проверяет, получены ли все начальные чанки и построены ли их меши.
func _check_initial_ready() -> void:
	if _initial_target < 0:
		return
	if _decoded_count < _initial_target or not _busy.is_empty():
		return
	_initial_target = -1
	initial_chunks_ready.emit()

## Клиент: получает сжатый чанк от сервера и ставит его в очередь распаковки.
@rpc("authority", "reliable")
func receive_chunk(pocket: Array) -> void:
	var packet: PackedByteArray = pocket[0]
	_enqueue(_decode_job.bind(packet))

# ============================================================
#  СЕРВЕР
# ============================================================

## Сервер: возвращает колонку X/Z, где находится спавн карты.
func get_spawn_column() -> Vector2i:
	return _column_from_position(get_parent().spawn.position)

## Сервер: отправляет клиенту чанки в радиусе вокруг спавна и запоминает его центр.
## Возвращает количество отправленных чанков.
func send_spawn_chunks(peer_id: int, center: Vector2i) -> int:
	_peer_centers[peer_id] = center
	var sent: int = 0
	for chunk: Node in get_parent().chunks.get_children():
		var column: Vector2i = _column_from_position((chunk as Node3D).position)
		if not _is_in_radius(column, center):
			continue
		rpc_id(peer_id, "receive_chunk", [chunk.serialize()])
		sent += 1
	return sent

## Сервер: принимает колонки клиента, запоминает его центр и отправляет существующие чанки.
## Порядок отправки совпадает с порядком колонок (ближние первыми).
@rpc("any_peer", "reliable")
func request_chunks(center: Vector2i, columns: Array) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	_peer_centers[sender] = center
	var by_column: Dictionary = {}
	for chunk: Node in get_parent().chunks.get_children():
		var column: Vector2i = _column_from_position((chunk as Node3D).position)
		if not by_column.has(column):
			by_column[column] = []
		by_column[column].append(chunk)
	for column: Vector2i in columns:
		if not by_column.has(column):
			continue
		for chunk: Node in by_column[column]:
			rpc_id(sender, "receive_chunk", [chunk.serialize()])

## Сервер: отправляет изменённые чанки всем клиентам, у которых они попадают в радиус.
func _broadcast_dirty_chunks() -> void:
	if _peer_centers.is_empty():
		return
	for chunk: Node in get_parent().chunks.get_children():
		if not chunk.dirty:
			continue
		chunk.dirty = false
		var column: Vector2i = _column_from_position((chunk as Node3D).position)
		var pocket: Array = [chunk.serialize()]
		for peer_id: int in _peer_centers.keys():
			if _is_in_radius(column, _peer_centers[peer_id]):
				rpc_id(peer_id, "receive_chunk", pocket)

## Сервер: забывает центр отключившегося игрока.
func _on_peer_disconnected(peer_id: int) -> void:
	_peer_centers.erase(peer_id)

# ============================================================
#  ПОТОКИ
# ============================================================

## Добавляет задачу в очередь пула.
func _enqueue(job: Callable) -> void:
	_queue_mutex.lock()
	_queue.append(job)
	_queue_mutex.unlock()
	_queue_semaphore.post()

## Тело потока: берёт задачу из очереди и выполняет её.
func _worker_loop() -> void:
	while true:
		_queue_semaphore.wait()
		_queue_mutex.lock()
		if _stopping:
			_queue_mutex.unlock()
			return
		var job: Callable = _queue.pop_front()
		_queue_mutex.unlock()
		job.call()

## Задача потока: распаковывает пакет и передаёт данные в главный поток.
func _decode_job(packet: PackedByteArray) -> void:
	var decompressed: PackedByteArray = packet.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var data: Dictionary = bytes_to_var(decompressed)
	call_deferred("_on_chunk_decoded", data)

## Задача потока: строит меш чанка. Нода гарантированно жива, пока имя есть в _busy.
func _mesh_job(chunk: Node3D, chunk_name: String) -> void:
	chunk._rebuild()
	call_deferred("_on_mesh_done", chunk_name)

# ============================================================
#  ХЕЛПЕРЫ
# ============================================================

## Возвращает игрока, которым управляет это клиентское приложение.
func _get_local_player() -> Node3D:
	for player: Node in get_parent().players.get_children():
		if player is Node3D and player.is_multiplayer_authority():
			return player as Node3D
	return null

## Переводит мировую позицию чанка в колонку X/Z (Vector2i.y здесь означает мировой Z).
func _column_from_position(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / chunk_size), floori(pos.z / chunk_size))

## Проверяет, входит ли колонка в квадратный радиус вокруг центра.
func _is_in_radius(column: Vector2i, center: Vector2i) -> bool:
	return absi(column.x - center.x) <= LOAD_RADIUS and absi(column.y - center.y) <= LOAD_RADIUS
