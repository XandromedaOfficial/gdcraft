@tool
extends Node
class_name ChunkManager

# ─────────────────────────────
# CONFIGURABLE EXPORTS
# ─────────────────────────────
@export var chunk_scene: PackedScene
@export var player_path: NodePath
@export var render_distance := 2  # how many chunks in each direction

# ─────────────────────────────
# RUNTIME DATA
# ─────────────────────────────
static var instance: ChunkManager

var _player: Node3D
var _last_player_chunk := Vector2i.ZERO

# Chunks in use and available
var _chunk_to_position: Dictionary = {}
var _position_to_chunk: Dictionary = {}
var _chunk_pool: Array[Chunk] = []

func _ready():
	if Engine.is_editor_hint():
		return

	instance = self

	if chunk_scene == null:
		push_error("🚫 'chunk_scene' is not assigned!")
		return

	if has_node(player_path):
		_player = get_node(player_path)
	else:
		push_error("🚫 Player path not set or found.")
		return

	# Delay generation until the scene is fully ready
	call_deferred("_generate_after_ready")
	
func _generate_after_ready():
	# Optional: disable player input while generating
	if "set_process_input" in _player:
		_player.set_process_input(false)
		_player.set_physics_process(false)

	_last_player_chunk = get_player_chunk()
	await generate_initial_chunks()

	if "set_process_input" in _player:
		_player.set_process_input(true)
		_player.set_physics_process(true)

func generate_initial_chunks():
	var player_chunk = get_player_chunk()
	for x in range(player_chunk.x - render_distance, player_chunk.x + render_distance + 1):
		for z in range(player_chunk.y - render_distance, player_chunk.y + render_distance + 1):
			var pos = Vector2i(x, z)
			if not _position_to_chunk.has(pos):
				var chunk: Chunk = get_chunk_from_pool()
				get_parent().call_deferred("add_child", chunk)
				# Update chunk dictionaries immediately
				_position_to_chunk[pos] = chunk
				_chunk_to_position[chunk] = pos
				# Positioning can also be deferred to avoid "not in tree" issues
				chunk.call_deferred("set_chunk_position", pos)

				await get_tree().process_frame  # Optional: smoother load
				
func _process(_delta):
	if not is_instance_valid(_player):
		return

	var current_chunk = get_player_chunk()
	if current_chunk != _last_player_chunk:
		_last_player_chunk = current_chunk
		update_chunks_around_player()

func get_player_chunk() -> Vector2i:
	if not is_instance_valid(_player):
		return Vector2i.ZERO
	var pos = _player.global_position
	return Vector2i(
		int(floor(pos.x / Chunk.dimensions.x)),
		int(floor(pos.z / Chunk.dimensions.z))
	)
	
func get_chunk(pos: Vector2i) -> Chunk:
	if _position_to_chunk.has(pos):
		return _position_to_chunk[pos]
	return null

func get_block_at_world_position(world_pos: Vector3) -> Block:
	var dims = Chunk.dimensions
	var chunk_x = int(floor(world_pos.x / float(dims.x)))
	var chunk_z = int(floor(world_pos.z / float(dims.z)))
	var chunk_pos = Vector2i(chunk_x, chunk_z)
	var chunk = get_chunk(chunk_pos)

	if not chunk:
		return null

	var local_x = int(world_pos.x) % dims.x
	if local_x < 0: local_x += dims.x

	var local_y = clamp(int(world_pos.y), 0, dims.y - 1)

	var local_z = int(world_pos.z) % dims.z
	if local_z < 0: local_z += dims.z
	
	var block = chunk._blocks[local_x][local_y][local_z]
	$"../GUI/Debug".text = "Block at " + str(world_pos) + " → local: (" + str(local_x) + ", " + str(local_y) + ", " + str(local_z) + ") is " + str(block.is_liquid)

	return chunk._blocks[local_x][local_y][local_z]

func update_chunks_around_player():
	var player_chunk = _last_player_chunk
	var new_visible := {}

	for x in range(player_chunk.x - render_distance, player_chunk.x + render_distance + 1):
		for z in range(player_chunk.y - render_distance, player_chunk.y + render_distance + 1):
			var pos = Vector2i(x, z)
			new_visible[pos] = true

			if not _position_to_chunk.has(pos):
				var chunk: Chunk = get_chunk_from_pool()
				get_parent().call_deferred("add_child", chunk)

				# Update dictionaries before calling set_chunk_position
				_position_to_chunk[pos] = chunk
				_chunk_to_position[chunk] = pos

				chunk.call_deferred("set_chunk_position", pos)
				await get_tree().create_timer(0.01).timeout

	# Unload chunks outside of render range
	var to_remove := []
	for pos in _position_to_chunk:
		if not new_visible.has(pos):
			var chunk = _position_to_chunk[pos]
			if is_instance_valid(chunk):
				chunk.visible = false
				chunk.set_process(false)
				get_parent().remove_child(chunk)
				_chunk_pool.append(chunk)
			to_remove.append(pos)

	for pos in to_remove:
		var chunk = _position_to_chunk[pos]
		_position_to_chunk.erase(pos)
		if _chunk_to_position.has(chunk):
			_chunk_to_position.erase(chunk)

func get_chunk_from_pool() -> Chunk:
	if _chunk_pool.size() > 0:
		var chunk = _chunk_pool.pop_back()
		chunk.visible = true
		chunk.set_process(true)
		return chunk

	if chunk_scene:
		return chunk_scene.instantiate()

	push_error("❗ Could not create chunk: chunk_scene is null")
	return null

func update_chunk_position(chunk: Chunk, current: Vector2i, previous: Vector2i):
	if _position_to_chunk.has(previous) and _position_to_chunk[previous] == chunk:
		_position_to_chunk.erase(previous)
	_chunk_to_position[chunk] = current
	_position_to_chunk[current] = chunk
