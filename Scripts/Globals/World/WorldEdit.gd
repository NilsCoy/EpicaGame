extends Node
## Глобальный world-edit менеджер.
## Принимает RPC и считает фигуры в отдельных потоках (только данные, без нод).
## В главном потоке применяет готовые операции к чанкам и отправляет изменённые чанки на перестроение в ChunkLoader.
##
## Чанки лежат НЕ рядом с этим узлом, а в отдельном контейнере
## (по умолчанию "../Map/Chunks"). Путь можно задать явно через chunks_container.
##
## Требования к чанку:
##   - CHUNK_SIZE, blocks, generate_blocks(), rebuild(), _rebuild();
##   - чанк.tscn лежит по пути CHUNK_SCENE_PATH;
##   - загрузчик чанков (сосед контейнера) имеет метод rebuild_chunks(chunks: Array).

const CHUNK_SIZE: int = 16
const CHUNK_SCENE_PATH: String = "res://Scenes/MapSystem/chunk.tscn"
const DEFAULT_CHUNKS_PATH: String = "../Map/Chunks"  # относительно WorldEdit, если он в Main
const MAX_BLOCKS: int = 2_000_000                     # предохранитель от гигантских операций
const MAX_COORD: int = 1_000_000                      # защита от переполнения при округлении
## Имя метода загрузчика чанков, который ставит меши в пул потоков.
const REBUILD_METHOD: String = "rebuild_chunks"

var block_1: Vector3i
var block_2: Vector3i

var overlay: Node

## Контейнер, в котором лежат чанки (узел Chunks). Если не задан — ищется по пути.
@export var chunks_container: Node = null

## Потоки, которые сейчас считают фигуры (только главный поток).
var _compute_threads: Array[Thread] = []

func _ready() -> void:
	if not(OS.has_feature("dedicated_server")):
		overlay = load("res://Scenes/Utilites/block_overlay.tscn").instantiate()
		add_child(overlay)

## Дожидается потоков расчёта перед выходом из дерева.
func _exit_tree() -> void:
	for thread: Thread in _compute_threads:
		thread.wait_to_finish()
	_compute_threads.clear()

# ============================================================
#  ПУБЛИЧНОЕ API (вызывается с клиента/сервера)
# ============================================================

## Ставит один блок по мировым координатам. Отправляет один RPC на сервер.
## world_pos — мировые координаты блока (Vector3i или Vector3, дробная часть отбрасывается),
## block_id — id блока, rotation — поворот (для model-блоков; для обычных ZERO -> UP).
func set_block(world_pos: Vector3i, block_id: String = "stone",
		rotation: Vector3 = Vector3.ZERO) -> void:
	_set_block_rpc.rpc(world_pos, block_id, rotation)

## Заполненная или полая сфера. Отправляет один RPC на сервер.
## center — мировые координаты центра, radius — радиус в блоках,
## hollow — полая ли, thickness — толщина стенки в блоках.
func sphere(center: Vector3, radius: float, block_id: String = "stone",
		hollow: bool = false, thickness: int = 1, rotation: Vector3 = Vector3.ZERO) -> void:
	_sphere_rpc.rpc(center, radius, block_id, hollow, thickness, rotation)

## Заполненный или полый вертикальный цилиндр (ось Y).
## center — центр нижнего основания, height — высота в блоках.
func cylinder(center: Vector3, radius: float, height: int, block_id: String = "stone",
		hollow: bool = false, thickness: int = 1, rotation: Vector3 = Vector3.ZERO) -> void:
	_cylinder_rpc.rpc(center, radius, height, block_id, hollow, thickness, rotation)

## Заполненный или полый куб по двум противоположным углам (мировые координаты).
func cube(point_a: Vector3, point_b: Vector3, block_id: String = "stone",
		hollow: bool = false, thickness: int = 1, rotation: Vector3 = Vector3.ZERO) -> void:
	_cube_rpc.rpc(point_a, point_b, block_id, hollow, thickness, rotation)

## Куб по радиусу (X/Z) и высоте (Y).
## center — центр нижнего основания, radius — радиус в блоках, height — высота в блоках.
func cube_radius_height(center: Vector3, radius: float, height: int,
		block_id: String = "stone", hollow: bool = false, thickness: int = 1,
		rotation: Vector3 = Vector3.ZERO) -> void:
	if radius <= 0.0 or height <= 0:
		return
	# radius = 1 -> 1 блок по X/Z, radius = 2 -> 3 блока и т.д.
	var half: float = maxf(radius - 1.0, 0.0)
	var point_a: Vector3 = Vector3(center.x - half, center.y, center.z - half)
	var point_b: Vector3 = Vector3(center.x + half, center.y + float(height - 1), center.z + half)
	cube(point_a, point_b, block_id, hollow, thickness, rotation)

## Сглаживание внутри вертикального цилиндра (ось Y).
## strength — число проходов, radius_neighbors — радиус окна соседей (1 = 3x3x3).
func smooth_cylinder(center: Vector3, radius: float, height: int,
		strength: int = 1, radius_neighbors: int = 1) -> void:
	_smooth_cylinder_rpc.rpc(center, radius, height, strength, radius_neighbors)

# ============================================================
#  RPC-обёртки (сервер выполняет)
# ============================================================

## RPC установки одного блока. Выполняется только на сервере.
@rpc("any_peer", "call_local", "reliable")
func _set_block_rpc(world_pos: Vector3i, block_id: String, rotation: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_dispatch(_ops_set_block.bind(world_pos, block_id, rotation))

## RPC сферы. Расчёт идёт в потоке.
@rpc("any_peer", "call_local", "reliable")
func _sphere_rpc(center: Vector3, radius: float, block_id: String,
		hollow: bool, thickness: int, rotation: Vector3) -> void:
	_dispatch(_ops_sphere.bind(center, radius, block_id, hollow, thickness, rotation))

## RPC цилиндра. Расчёт идёт в потоке.
@rpc("any_peer", "call_local", "reliable")
func _cylinder_rpc(center: Vector3, radius: float, height: int, block_id: String,
		hollow: bool, thickness: int, rotation: Vector3) -> void:
	_dispatch(_ops_cylinder.bind(center, radius, height, block_id, hollow, thickness, rotation))

## RPC куба. Расчёт идёт в потоке.
@rpc("any_peer", "call_local", "reliable")
func _cube_rpc(point_a: Vector3, point_b: Vector3, block_id: String,
		hollow: bool, thickness: int, rotation: Vector3) -> void:
	_dispatch(_ops_cube.bind(point_a, point_b, block_id, hollow, thickness, rotation))

## RPC сглаживания по цилиндру. Снимок соседей собирается в главном потоке, расчёт — в потоке.
@rpc("any_peer", "call_local", "reliable")
func _smooth_cylinder_rpc(center: Vector3, radius: float, height: int,
		strength: int, radius_neighbors: int) -> void:
	_prepare_smooth(center, radius, height, strength, radius_neighbors)

# ============================================================
#  ПОТОКИ РАСЧЁТА
# ============================================================

## Главный поток: запускает расчёт операций в отдельном потоке.
## compute должен возвращать Array словарей {"pos": Vector3i, "id": String, "rot": Vector3}.
func _dispatch(compute: Callable) -> void:
	var thread: Thread = Thread.new()
	_compute_threads.append(thread)
	thread.start(_compute_worker.bind(thread, compute))

## Тело потока: считает операции и возвращает их в главный поток.
func _compute_worker(thread: Thread, compute: Callable) -> void:
	var ops: Array = compute.call()
	call_deferred("_on_compute_done", thread, ops)

## Главный поток: применяет операции к чанкам и отправляет изменённые чанки на перестроение.
## Сервер только пишет блоки (перестроение у клиентов).
func _on_compute_done(thread: Thread, ops: Array) -> void:
	thread.wait_to_finish()
	_compute_threads.erase(thread)
	var cache: Dictionary = {}
	for op: Dictionary in ops:
		_set_block_world(cache, op["pos"], str(op["id"]), op["rot"])
	if not multiplayer.is_server():
		_rebuild_all(cache)

## Формирует одну операцию записи блока.
func _make_op(pos: Vector3i, block_id: String, rotation: Vector3) -> Dictionary:
	return {"pos": pos, "id": block_id, "rot": rotation}

# ============================================================
#  РАСЧЁТ ФИГУР (чистые данные, без нод; выполняется в потоках)
# ============================================================

## Операция для одного блока.
func _ops_set_block(world_pos: Vector3i, block_id: String, rotation: Vector3) -> Array:
	return [_make_op(world_pos, block_id, rotation)]

## Операции для сферы: куб вокруг центра, оставляем блоки внутри радиуса,
## при hollow отсекаем внутренность радиусом (r - thickness).
func _ops_sphere(center: Vector3, radius: float, block_id: String,
		hollow: bool, thickness: int, rotation: Vector3) -> Array:
	var ops: Array = []
	if radius <= 0.0:
		return ops

	var r: int = int(ceil(radius))
	var r2: float = radius * radius
	var inner_r: int = max(r - thickness, 0)
	var inner2: float = float(inner_r * inner_r)

	var cx: int = int(round(center.x))
	var cy: int = int(round(center.y))
	var cz: int = int(round(center.z))

	var volume: float = (4.0 / 3.0) * PI * pow(radius + 1.0, 3.0)
	if volume > float(MAX_BLOCKS):
		push_warning("world_edit.sphere: too many blocks (~%d), abort" % int(volume))
		return ops

	for dx: int in range(-r, r + 1):
		var dx2: int = dx * dx
		for dy: int in range(-r, r + 1):
			var dy2: int = dy * dy
			for dz: int in range(-r, r + 1):
				var d2: float = float(dx2 + dy2 + dz * dz)
				if d2 > r2:
					continue
				if hollow and d2 < inner2:
					continue
				ops.append(_make_op(Vector3i(cx + dx, cy + dy, cz + dz), block_id, rotation))
	return ops

## Операции для вертикального цилиндра: круг в плоскости XZ, столбец по Y.
## При hollow оставляем только кольцо толщиной thickness.
func _ops_cylinder(center: Vector3, radius: float, height: int, block_id: String,
		hollow: bool, thickness: int, rotation: Vector3) -> Array:
	var ops: Array = []
	if radius <= 0.0 or height <= 0:
		return ops

	var r: int = int(ceil(radius))
	var r2: float = radius * radius
	var inner_r: int = max(r - thickness, 0)
	var inner2: float = float(inner_r * inner_r)

	var cx: int = int(round(center.x))
	var base_y: int = int(round(center.y))
	var cz: int = int(round(center.z))

	var volume: float = PI * pow(radius + 1.0, 2.0) * float(height + 1)
	if volume > float(MAX_BLOCKS):
		push_warning("world_edit.cylinder: too many blocks (~%d), abort" % int(volume))
		return ops

	for dx: int in range(-r, r + 1):
		var dx2: int = dx * dx
		for dz: int in range(-r, r + 1):
			var d2: float = float(dx2 + dz * dz)
			if d2 > r2:
				continue
			if hollow and d2 < inner2:
				continue
			for dy: int in range(height):
				ops.append(_make_op(Vector3i(cx + dx, base_y + dy, cz + dz), block_id, rotation))
	return ops

## Операции для куба по двум углам. Нормализует min/max через floor.
## При hollow отсекаем блоки, отступающие от всех стенок на thickness.
func _ops_cube(point_a: Vector3, point_b: Vector3, block_id: String,
		hollow: bool, thickness: int, rotation: Vector3) -> Array:
	var ops: Array = []
	var min_x: int = int(floor(min(point_a.x, point_b.x)))
	var min_y: int = int(floor(min(point_a.y, point_b.y)))
	var min_z: int = int(floor(min(point_a.z, point_b.z)))
	var max_x: int = int(floor(max(point_a.x, point_b.x)))
	var max_y: int = int(floor(max(point_a.y, point_b.y)))
	var max_z: int = int(floor(max(point_a.z, point_b.z)))

	var volume: int = (max_x - min_x + 1) * (max_y - min_y + 1) * (max_z - min_z + 1)
	if volume > MAX_BLOCKS:
		push_warning("world_edit.cube: too many blocks (~%d), abort" % volume)
		return ops

	for x: int in range(min_x, max_x + 1):
		for y: int in range(min_y, max_y + 1):
			for z: int in range(min_z, max_z + 1):
				if hollow:
					var inside: bool = (
						x >= min_x + thickness and x <= max_x - thickness and
						y >= min_y + thickness and y <= max_y - thickness and
						z >= min_z + thickness and z <= max_z - thickness
					)
					if inside:
						continue
				ops.append(_make_op(Vector3i(x, y, z), block_id, rotation))
	return ops

## Главный поток: собирает список ячеек цилиндра и снимок id блоков (с окном соседей),
## затем запускает сглаживание в потоке. Чтение нод только здесь.
func _prepare_smooth(center: Vector3, radius: float, height: int,
		strength: int, radius_neighbors: int) -> void:
	if radius <= 0.0 or height <= 0 or strength <= 0:
		return

	var r: int = int(ceil(radius))
	var r2: float = radius * radius
	var nb: int = maxi(radius_neighbors, 1)

	var cx: int = int(round(center.x))
	var base_y: int = int(round(center.y))
	var cz: int = int(round(center.z))

	# предохранитель от гигантских операций (окно соседей тоже считаем)
	var volume: float = PI * pow(radius + 1.0, 2.0) * float(height + 1)
	if volume > float(MAX_BLOCKS):
		push_warning("world_edit.smooth_cylinder: too many blocks (~%d), abort" % int(volume))
		return

	# список блоков цилиндра считаем один раз
	var cells: Array = []
	for dx: int in range(-r, r + 1):
		var dx2: int = dx * dx
		for dz: int in range(-r, r + 1):
			var d2: float = float(dx2 + dz * dz)
			if d2 > r2:
				continue
			for dy: int in range(height):
				cells.append(Vector3i(cx + dx, base_y + dy, cz + dz))

	# снимок id блоков вокруг цилиндра, включая окно соседей
	var snapshot: Dictionary = {}
	for pos: Vector3i in cells:
		for ox: int in range(-nb, nb + 1):
			for oy: int in range(-nb, nb + 1):
				for oz: int in range(-nb, nb + 1):
					var np: Vector3i = pos + Vector3i(ox, oy, oz)
					if not snapshot.has(np):
						snapshot[np] = _get_block_id_at(np)

	_dispatch(_ops_smooth.bind(cells, snapshot, strength, nb))

## Операции сглаживания: каждой ячейке ставим самый частый id из окружения.
## Проходы работают по копии снимка, поэтому результат не зависит от порядка обхода.
func _ops_smooth(cells: Array, snapshot: Dictionary, strength: int, nb: int) -> Array:
	var current: Dictionary = snapshot.duplicate()
	for _pass: int in range(strength):
		var before: Dictionary = current.duplicate()
		for pos: Vector3i in cells:
			var counts: Dictionary = {}
			for ox: int in range(-nb, nb + 1):
				for oy: int in range(-nb, nb + 1):
					for oz: int in range(-nb, nb + 1):
						var np: Vector3i = pos + Vector3i(ox, oy, oz)
						var nid: String = str(before.get(np, ""))
						if nid == "":
							continue
						counts[nid] = int(counts.get(nid, 0)) + 1
			if counts.is_empty():
				continue
			# самый частый id; при равенстве — стабильно по имени
			var best_id: String = ""
			var best_count: int = -1
			for key: String in counts.keys():
				var c: int = int(counts[key])
				if c > best_count or (c == best_count and key < best_id):
					best_count = c
					best_id = key
			if best_id != "":
				current[pos] = best_id

	var ops: Array = []
	for pos: Vector3i in cells:
		var id: String = str(current.get(pos, ""))
		if id != "":
			ops.append(_make_op(pos, id, Vector3.ZERO))
	return ops

# ============================================================
#  РАБОТА С ЧАНКАМИ (только главный поток)
# ============================================================

## Возвращает id блока по мировым координатам или "", если блока/чанка нет.
func _get_block_id_at(world_block: Vector3i) -> String:
	if abs(world_block.x) > MAX_COORD or abs(world_block.y) > MAX_COORD or abs(world_block.z) > MAX_COORD:
		return ""

	var container: Node = _get_chunks_container()
	if container == null:
		return ""

	var cc: Vector3i = _chunk_coord_of(world_block, CHUNK_SIZE)
	var chunk: Node = container.get_node_or_null(_chunk_name(cc))
	if chunk == null:
		return ""

	var lx: int = world_block.x - cc.x * CHUNK_SIZE
	var ly: int = world_block.y - cc.y * CHUNK_SIZE
	var lz: int = world_block.z - cc.z * CHUNK_SIZE
	if lx < 0 or ly < 0 or lz < 0 or lx >= CHUNK_SIZE or ly >= CHUNK_SIZE or lz >= CHUNK_SIZE:
		return ""

	var data: Variant = chunk.blocks[lx][ly][lz]
	if data == null:
		return ""
	if typeof(data) == TYPE_DICTIONARY:
		return str(data.get("id", ""))
	return str(data)

## Возвращает узел-контейнер чанков. Если ссылка не задана в инспекторе,
## ищет её по DEFAULT_CHUNKS_PATH, а затем по имени "Chunks" в текущей сцене.
func _get_chunks_container() -> Node:
	if chunks_container != null:
		return chunks_container

	# 1) путь относительно WorldEdit (напр. WorldEdit лежит в Main)
	var by_path: Node = get_node_or_null(DEFAULT_CHUNKS_PATH)
	if by_path != null:
		chunks_container = by_path
		return by_path

	# 2) ищем любой узел с именем "Chunks" в текущей сцене
	var scene: Node = get_tree().current_scene
	if scene != null:
		var found: Node = scene.find_child("Chunks", true, false)
		if found != null:
			chunks_container = found
			return found

	push_error("WorldEdit: не найден контейнер чанков (Chunks). Задай chunks_container в инспекторе.")
	return null

## Возвращает загрузчик чанков: сосед контейнера, у которого есть метод REBUILD_METHOD.
func _get_chunk_loader() -> Node:
	var container: Node = _get_chunks_container()
	if container == null or container.get_parent() == null:
		return null
	for child: Node in container.get_parent().get_children():
		if child.has_method(REBUILD_METHOD):
			return child
	return null

## Мировые координаты блока -> координаты чанка. floor-деление,
## поэтому корректно работает и для отрицательных координат.
func _chunk_coord_of(world_block: Vector3i, chunk_size: int) -> Vector3i:
	return Vector3i(
		int(floor(float(world_block.x) / float(chunk_size))),
		int(floor(float(world_block.y) / float(chunk_size))),
		int(floor(float(world_block.z) / float(chunk_size)))
	)

## Формирует имя узла чанка из его координат ("chunk_X_Y_Z").
func _chunk_name(c: Vector3i) -> String:
	return "chunk_" + str(c.x) + "_" + str(c.y) + "_" + str(c.z)

## Возвращает чанк по координатам, а если его нет — инстанцирует из сцены,
## добавляет в контейнер чанков и заполняет дефолтными блоками.
func _get_or_create_chunk(c: Vector3i) -> Node:
	var container: Node = _get_chunks_container()
	if container == null:
		return null

	var cname: String = _chunk_name(c)
	var chunk: Node = container.get_node_or_null(cname)
	if chunk != null:
		return chunk

	chunk = load(CHUNK_SCENE_PATH).instantiate()
	chunk.position = Vector3(c.x, c.y, c.z) * CHUNK_SIZE
	chunk.name = cname
	container.add_child(chunk)
	chunk.generate_blocks()
	return chunk

## Записывает один блок по мировым координатам в нужный чанк (без rebuild).
## Кеш cache: Vector3i -> Node, чтобы не искать чанк на каждый блок.
func _set_block_world(cache: Dictionary, world_block: Vector3i,
		block_id: String, rotation: Vector3) -> void:
	if abs(world_block.x) > MAX_COORD or abs(world_block.y) > MAX_COORD or abs(world_block.z) > MAX_COORD:
		return

	var cc: Vector3i = _chunk_coord_of(world_block, CHUNK_SIZE)

	var chunk: Node
	if cache.has(cc):
		chunk = cache[cc]
	else:
		chunk = _get_or_create_chunk(cc)
		if chunk == null:
			return
		cache[cc] = chunk

	var lx: int = world_block.x - cc.x * CHUNK_SIZE
	var ly: int = world_block.y - cc.y * CHUNK_SIZE
	var lz: int = world_block.z - cc.z * CHUNK_SIZE
	if lx < 0 or ly < 0 or lz < 0 or lx >= CHUNK_SIZE or ly >= CHUNK_SIZE or lz >= CHUNK_SIZE:
		return

	var rot: Vector3 = rotation
	if block_id == "air":
		rot = Vector3.UP
	elif BlockRegistry.blocks[block_id]["type"] != "model" and rot == Vector3.ZERO:
		rot = Vector3.UP
	chunk.blocks[lx][ly][lz] = {"id": block_id, "rotation": rot}
	chunk.dirty = true

## Отправляет затронутые чанки загрузчику на перестроение мешей в пуле потоков.
## Если загрузчика нет — перестраивает чанки сразу (запасной вариант).
func _rebuild_all(cache: Dictionary) -> void:
	var chunks: Array = []
	for cc: Vector3i in cache.keys():
		var chunk: Node = cache[cc]
		if chunk != null and chunk.has_method("rebuild"):
			chunks.append(chunk)
	if chunks.is_empty():
		return

	var loader: Node = _get_chunk_loader()
	if loader == null:
		for chunk: Node in chunks:
			chunk.rebuild()
		return
	loader.rebuild_chunks(chunks)
