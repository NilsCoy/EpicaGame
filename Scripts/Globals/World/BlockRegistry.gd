extends Node

const ERROR_TEXTURE_PATH: String = "res://Assets/Textures/error.png"
const ERROR_BLOCK: Dictionary = {
	"type": "block",
	"textures": {
		"top": ERROR_TEXTURE_PATH,
		"bottom": ERROR_TEXTURE_PATH,
		"side": ERROR_TEXTURE_PATH,
	},
	"is_rotate": false
}

var blocks: Dictionary
#var blocks: Dictionary = {
	#"grass_block": {
		#"type": "block",
		#"textures": {
			#"top": "res://Assets/Blocks/grass_block_tint.png",
			#"bottom": "res://Assets/Blocks/dirt.png",
			#"side": "res://Assets/Blocks/grass_block_side.png",
		#},
		#"is_rotate": false
	#},
	#"dirt": {
		#"type": "block",
		#"textures": {
			#"top": "res://Assets/Blocks/dirt.png",
			#"bottom": "res://Assets/Blocks/dirt.png",
			#"side": "res://Assets/Blocks/dirt.png",
		#},
		#"is_rotate": false
	#},
	#"stone": {
		#"type": "block",
		#"textures": {
			#"top": "res://Assets/Blocks/stone.png",
			#"bottom": "res://Assets/Blocks/stone.png",
			#"side": "res://Assets/Blocks/stone.png",
		#},
		#"is_rotate": false
	#},
	#"cobblestone": {
		#"type": "block",
		#"textures": {
			#"top": "res://Assets/Blocks/cobblestone.png",
			#"bottom": "res://Assets/Blocks/cobblestone.png",
			#"side": "res://Assets/Blocks/cobblestone.png",
		#},
		#"is_rotate": false
	#},
	#"stone_stairs": {
		#"type": "model",
		#"asset": "res://Assets/Blocks/stairs.gltf",
		#"is_rotate": true
	#},
#}

var atlas_texture: Texture2D
var block_uv_map: Dictionary = {}

var ATLAS_SIZE: int = 0
var TILE_SIZE: float = 0.0

var texture_uv_lookup: Dictionary = {}

func _ready() -> void:
	blocks = get_blocks()
	
	#if OS.has_feature("dedicated_server"):
		#return
	generate_texture_atlas()

func get_blocks() -> Dictionary:
	var result: Dictionary = {}
	var files: Array = FileManager.get_files_in_directory(FileManager.get_file_path('Resources/Blocks/Data/', true))
	if files != []:
		for file: String in files:
			var block: Dictionary = FileManager.read_json(FileManager.get_file_path('Resources/Blocks/Data/'+file, true))
			result[file.split(".")[0]] = block
	result['error_block'] = ERROR_BLOCK
	return result

func generate_texture_atlas() -> void:
	var unique_paths: Array = []

	for block_id: String in blocks:
		if blocks[block_id]['type'] == 'block':
			for face: String in blocks[block_id]['textures']:
				var path: String = blocks[block_id]['textures'][face]
				if not unique_paths.has(path):
					unique_paths.append(path)

	var texture_count: int = unique_paths.size()
	var first_tex: Texture2D = load(unique_paths[0])
	var tile_px_size: int = first_tex.get_width() if first_tex != null else 16

	ATLAS_SIZE = int(ceil(sqrt(texture_count)))
	TILE_SIZE = 1.0 / ATLAS_SIZE

	var atlas_px_size: int = ATLAS_SIZE * tile_px_size
	var atlas_image: Image = Image.create(atlas_px_size, atlas_px_size, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color(0,0,0,0))

	for i: int in texture_count:
		var tex: Texture2D = load(unique_paths[i])
		var img: Image = tex.get_image() if tex != null else null

		var x: int = i % ATLAS_SIZE
		var y: int = i / ATLAS_SIZE
		texture_uv_lookup[unique_paths[i]] = Vector2i(x, y)

		# На выделенном сервере картинок текстур нет: UV нужны для меша и коллизии,
		# а сам атлас не рисуется
		if img == null:
			continue

		if img.is_compressed():
			img.decompress()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)

		atlas_image.blit_rect(
			img,
			Rect2i(0, 0, tile_px_size, tile_px_size),
			Vector2i(x * tile_px_size, y * tile_px_size)
		)

	# Теперь собираем UV для блоков
	for block_id: String in blocks:
		if blocks[block_id]["type"] == "block":
			block_uv_map[block_id] = { 
				"top": texture_uv_lookup[blocks[block_id]['textures']["top"]],
				"bottom": texture_uv_lookup[blocks[block_id]['textures']["bottom"]],
				"side": texture_uv_lookup[blocks[block_id]['textures']["side"]]
			}

	atlas_texture = ImageTexture.create_from_image(atlas_image)

## Возвращает данные блока или fallback error_block
func get_block(block_id: String) -> Dictionary:
	return blocks.get(block_id, ERROR_BLOCK)

## Проверяет существование блока
func has_block(block_id: String) -> bool:
	return blocks.has(block_id) and block_id != "air"

## Безопасный UV: если блока нет или у грани нет UV — отдаём UV error-текстуры
func get_uv(block_id: String, face: String) -> Vector2i:
	if block_uv_map.has(block_id) and block_uv_map[block_id].has(face):
		return block_uv_map[block_id][face]
	# fallback на UV error-текстуры (см. прошлый ответ)
	return block_uv_map.get("error_block", {}).get(face, Vector2i.ZERO)

## Тип блока ("block"/"model"), либо "error" для неизвестного
func get_type(block_id: String) -> String:
	return get_block(block_id).get("type", "error")
