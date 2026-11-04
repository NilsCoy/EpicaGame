extends Node
## Глобальный world-edit менеджер.
## Принимает RPC, считает фигуру, раскладывает блоки по чанкам и делает rebuild.
##
## Чанки лежат НЕ рядом с этим узлом, а в отдельном контейнере
## (по умолчанию "./Main/Map/Chunks/"). Путь можно задать явно через chunks_container.
##
## Требования к чанку:
##   - CHUNK_SIZE, blocks, generate_blocks(), rebuild(), atlas_generator;
##   - чанк.tscn лежит по пути CHUNK_SCENE_PATH.

const CHUNK_SIZE: int = 16
const CHUNK_SCENE_PATH: String = "res://Scenes/MapSystem/chunk.tscn"
const DEFAULT_CHUNKS_PATH: String = "../Map/Chunks"  # относительно WorldEdit, если он в Main
const MAX_BLOCKS: int = 2_000_000                     # предохранитель от гигантских операций
const MAX_COORD: int = 1_000_000                      # защита от переполнения при округлении

var block_1: Vector3i
var block_2: Vector3i

## Контейнер, в котором лежат чанки (узел Chunks). Если не задан — ищется по пути.
@export var chunks_container: Node = null


# ============================================================
#  ПУБЛИЧНОЕ API (вызывается с клиента/сервера)
# ============================================================

## Ставит один блок по мировым координатам. Отправляет один RPC на сервер.
## world_pos — мировые координаты блока (Vector3i или Vector3, дробная часть отбрасывается),
## block_id — id блока, rotation — поворот (для model-блоков; для обычных ZERO -> UP).
func set_block(world_pos: Vector3i, block_id: String = "stone",
		rotation: Vector3 = Vector3.ZERO) -> void:
	_set_block_rpc(world_pos, block_id, rotation)
	_set_block_rpc.rpc(world_pos, block_id, rotation)

## Заполненная или полая сфера. Отправляет один RPC на сервер.
## center — мировые координаты центра, radius — радиус в блоках,
## hollow — полая ли, thickness — толщина стенки в блоках.
func sphere(center: Vector3, radius: float, block_id: String = "stone",
		hollow: bool = false, thickness: int = 1, rotation: Vector3 = Vector3.ZERO) -> void:
	_sphere_rpc(center, radius, block_id, hollow, thickness, rotation)
	_sphere_rpc.rpc(center, radius, block_id, hollow, thickness, rotation)


## Заполненный или полый вертикальный цилиндр (ось Y).
## center — центр нижнего основания, height — высота в блоках.
func cylinder(center: Vector3, radius: float, height: int, block_id: String = "stone",
		hollow: bool = false, thickness: int = 1, rotation: Vector3 = Vector3.ZERO) -> void:
	_cylinder_rpc(center, radius, height, block_id, hollow, thickness, rotation)
	_cylinder_rpc.rpc(center, radius, height, block_id, hollow, thickness, rotation)


## Заполненный или полый куб по двум противоположным углам (мировые координаты).
func cube(point_a: Vector3, point_b: Vector3, block_id: String = "stone",
		hollow: bool = false, thickness: int = 1, rotation: Vector3 = Vector3.ZERO) -> void:
	_cube_rpc(point_a, point_b, block_id, hollow, thickness, rotation)
	_cube_rpc.rpc(point_a, point_b, block_id, hollow, thickness, rotation)

## Куб по радиусу (X/Z) и высоте (Y).
## Внутри пересчитывает радиус/высоту в два угла и вызывает обычный cube по координатам,
## так что логика заполнения/полости остаётся в одном месте.
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
## center — центр нижнего основания, radius — радиус, height — высота в блоках,
## strength — число проходов, radius_neighbors — радиус окна соседей (1 = 3x3x3).
func smooth_cylinder(center: Vector3, radius: float, height: int,
		strength: int = 1, radius_neighbors: int = 1) -> void:
	_smooth_cylinder_rpc(center, radius, height, strength, radius_neighbors)
	_smooth_cylinder_rpc.rpc(center, radius, height, strength, radius_neighbors)

# ============================================================
#  RPC-обёртки (сервер выполняет)
# ============================================================

## RPC установки одного блока. Выполняется только на сервере.
@rpc("any_peer", "call_local", "reliable")
func _set_block_rpc(world_pos: Vector3i, block_id: String, rotation: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_do_set_block(world_pos, block_id, rotation)

## RPC сферы. Выполняется только на сервере, затем строит фигуру.
@rpc("any_peer", "call_local", "reliable")
func _sphere_rpc(center: Vector3, radius: float, block_id: String,
		hollow: bool, thickness: int, rotation: Vector3) -> void:
	#if not multiplayer.is_server():
		#return
	_do_sphere(center, radius, block_id, hollow, thickness, rotation)


## RPC цилиндра. Выполняется только на сервере.
@rpc("any_peer", "call_local", "reliable")
func _cylinder_rpc(center: Vector3, radius: float, height: int, block_id: String,
		hollow: bool, thickness: int, rotation: Vector3) -> void:
	#if not multiplayer.is_server():
		#return
	_do_cylinder(center, radius, height, block_id, hollow, thickness, rotation)


## RPC куба. Выполняется только на сервере.
@rpc("any_peer", "call_local", "reliable")
func _cube_rpc(point_a: Vector3, point_b: Vector3, block_id: String,
		hollow: bool, thickness: int, rotation: Vector3) -> void:
	#if not multiplayer.is_server():
		#return
	_do_cube(point_a, point_b, block_id, hollow, thickness, rotation)

## RPC сглаживания по цилиндру. Выполняется только на сервере.
@rpc("any_peer", "call_local", "reliable")
func _smooth_cylinder_rpc(center: Vector3, radius: float, height: int,
		strength: int, radius_neighbors: int) -> void:
	#if not multiplayer.is_server():
		#return
	_do_smooth_cylinder(center, radius, height, strength, radius_neighbors)

# ============================================================
#  РЕАЛИЗАЦИЯ ФИГУР (только на сервере)
# ============================================================

## Ставит один блок по мировым координатам: находит/создаёт чанк,
## пишет блок и делает rebuild этого чанка.
func _do_set_block(world_pos: Vector3i, block_id: String, rotation: Vector3) -> void:
	var cache: Dictionary = {}
	_set_block_world(cache, world_pos, block_id, rotation)
	if not(multiplayer.is_server()):
		_rebuild_all(cache)

## Строит сферу: перебирает куб вокруг центра, оставляет блоки внутри радиуса,
## при hollow отсекает внутренность радиусом (r - thickness). Один rebuild на чанк.
func _do_sphere(center: Vector3, radius: float, block_id: String,
		hollow: bool, thickness: int, rotation: Vector3) -> void:
	if radius <= 0.0:
		return

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
		return

	var cache: Dictionary = {}
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
				_set_block_world(cache, Vector3i(cx + dx, cy + dy, cz + dz), block_id, rotation)
	if not(multiplayer.is_server()):
		_rebuild_all(cache)


## Строит вертикальный цилиндр: перебирает круг в плоскости XZ, затем столбец по Y.
## При hollow оставляет только кольцо толщиной thickness.
func _do_cylinder(center: Vector3, radius: float, height: int, block_id: String,
		hollow: bool, thickness: int, rotation: Vector3) -> void:
	if radius <= 0.0 or height <= 0:
		return

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
		return

	var cache: Dictionary = {}
	for dx: int in range(-r, r + 1):
		var dx2: int = dx * dx
		for dz: int in range(-r, r + 1):
			var d2: float = float(dx2 + dz * dz)
			if d2 > r2:
				continue
			if hollow and d2 < inner2:
				continue
			for dy: int in range(height):
				_set_block_world(cache, Vector3i(cx + dx, base_y + dy, cz + dz), block_id, rotation)
	if not(multiplayer.is_server()):
		_rebuild_all(cache)


## Строит куб по двум углам. Внутри нормализует min/max через floor.
## При hollow отсекает блоки, отступающие от всех стенок на thickness.
func _do_cube(point_a: Vector3, point_b: Vector3, block_id: String,
		hollow: bool, thickness: int, rotation: Vector3) -> void:
	var min_x: int = int(floor(min(point_a.x, point_b.x)))
	var min_y: int = int(floor(min(point_a.y, point_b.y)))
	var min_z: int = int(floor(min(point_a.z, point_b.z)))
	var max_x: int = int(floor(max(point_a.x, point_b.x)))
	var max_y: int = int(floor(max(point_a.y, point_b.y)))
	var max_z: int = int(floor(max(point_a.z, point_b.z)))

	var volume: int = (max_x - min_x + 1) * (max_y - min_y + 1) * (max_z - min_z + 1)
	if volume > MAX_BLOCKS:
		push_warning("world_edit.cube: too many blocks (~%d), abort" % volume)
		return

	var cache: Dictionary = {}
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
				_set_block_world(cache, Vector3i(x, y, z), block_id, rotation)
	if not(multiplayer.is_server()):
		_rebuild_all(cache)


## Сглаживает блоки в цилиндре: каждому блоку ставит самый частый id из его окружения.
## strength — число проходов, radius_neighbors — радиус окна соседей.
## Каждый проход работает по снимку, чтобы результат не зависел от порядка обхода.
func _do_smooth_cylinder(center: Vector3, radius: float, height: int,
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
	var cells: Array[Vector3i] = []
	for dx: int in range(-r, r + 1):
		var dx2: int = dx * dx
		for dz: int in range(-r, r + 1):
			var d2: float = float(dx2 + dz * dz)
			if d2 > r2:
				continue
			for dy: int in range(height):
				cells.append(Vector3i(cx + dx, base_y + dy, cz + dz))

	var cache: Dictionary = {}
	for _pass: int in range(strength):
		# снимок id до прохода
		var snapshot: Dictionary = {}
		for pos: Vector3i in cells:
			snapshot[pos] = _get_block_id_at(pos)

		for pos: Vector3i in cells:
			var counts: Dictionary = {}
			for ox: int in range(-nb, nb + 1):
				for oy: int in range(-nb, nb + 1):
					for oz: int in range(-nb, nb + 1):
						var np: Vector3i = pos + Vector3i(ox, oy, oz)
						var nid: String = str(snapshot.get(np, _get_block_id_at(np)))
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
				_set_block_world(cache, pos, best_id, Vector3.ZERO)

	if not(multiplayer.is_server()):
		_rebuild_all(cache)


## Возвращает id блока по мировым координатам или "" , если блока/чанка нет.
## Нужно сглаживанию для чтения соседей (в т.ч. вне цилиндра).
func _get_block_id_at(world_block: Vector3i) -> String:
	if abs(world_block.x) > MAX_COORD or abs(world_block.y) > MAX_COORD or abs(world_block.z) > MAX_COORD:
		return ""

	var container: Node = _get_chunks_container()
	if container == null:
		return ""

	var chunk_size: int = _first_chunk_size({})
	var cc: Vector3i = _chunk_coord_of(world_block, chunk_size)
	var chunk: Node = container.get_node_or_null(_chunk_name(cc))
	if chunk == null:
		return ""

	var lx: int = world_block.x - cc.x * chunk_size
	var ly: int = world_block.y - cc.y * chunk_size
	var lz: int = world_block.z - cc.z * chunk_size
	if lx < 0 or ly < 0 or lz < 0 or lx >= chunk_size or ly >= chunk_size or lz >= chunk_size:
		return ""

	var data: Variant = chunk.blocks[lx][ly][lz]
	if data == null:
		return ""
	if typeof(data) == TYPE_DICTIONARY:
		return str(data.get("id", ""))
	return str(data)

# ============================================================
#  ЧАНКИ
# ============================================================

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
func _get_or_create_chunk(c: Vector3i, chunk_size: int) -> Node:
	var container: Node = _get_chunks_container()
	if container == null:
		return null

	var cname: String = _chunk_name(c)
	var chunk: Node = container.get_node_or_null(cname)
	if chunk != null:
		return chunk

	chunk = load(CHUNK_SCENE_PATH).instantiate()
	chunk.position = Vector3(c.x, c.y, c.z) * chunk_size
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

	# размер чанка берём у уже существующего (у нас он константный)
	var chunk_size: int = _first_chunk_size(cache)
	var cc: Vector3i = _chunk_coord_of(world_block, chunk_size)

	var chunk: Node
	if cache.has(cc):
		chunk = cache[cc]
	else:
		chunk = _get_or_create_chunk(cc, chunk_size)
		if chunk == null:
			return
		cache[cc] = chunk

	var lx: int = world_block.x - cc.x * chunk_size
	var ly: int = world_block.y - cc.y * chunk_size
	var lz: int = world_block.z - cc.z * chunk_size
	if lx < 0 or ly < 0 or lz < 0 or lx >= chunk_size or ly >= chunk_size or lz >= chunk_size:
		return

	var rot: Vector3 = rotation
	if block_id == 'air':
		rot = Vector3.UP
	elif chunk.atlas_generator.blocks[block_id]["type"] != "model" and rot == Vector3.ZERO:
		rot = Vector3.UP
	chunk.blocks[lx][ly][lz] = {"id": block_id, "rotation": rot}


## Возвращает размер чанка (CHUNK_SIZE): сначала из кеша, потом у любого
## существующего чанка в контейнере, иначе fallback 16.
func _first_chunk_size(cache: Dictionary) -> int:
	for cc: Vector3i in cache.keys():
		return cache[cc].CHUNK_SIZE

	var container: Node = _get_chunks_container()
	if container != null:
		for child: Node in container.get_children():
			if child.name.begins_with("chunk_") and "CHUNK_SIZE" in child:
				return child.CHUNK_SIZE
	return 16  # fallback; поменяй на свой CHUNK_SIZE, если он не 16


## Перестраивает (rebuild) все затронутые чанки из кеша — один раз на чанк.
func _rebuild_all(cache: Dictionary) -> void:
	for cc: Vector3i in cache.keys():
		var chunk: Node = cache[cc]
		if chunk != null and chunk.has_method("rebuild"):
			chunk.rebuild()
