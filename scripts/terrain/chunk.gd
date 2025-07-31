@tool
extends StaticBody3D
class_name Chunk

@export var collision_shape: CollisionShape3D
@export var mesh_instance: MeshInstance3D
@export var terrain_noise: FastNoiseLite
@export var cave_noise: FastNoiseLite

static var dimensions: Vector3i = Vector3i(8, 32, 8)

var chunk_position: Vector2i
var _blocks: Array = []
var _surface_tool := SurfaceTool.new()

const _vertices := [
	Vector3i(0, 0, 0), Vector3i(1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(1, 1, 0),
	Vector3i(0, 0, 1), Vector3i(1, 0, 1),
	Vector3i(0, 1, 1), Vector3i(1, 1, 1)
]

const _top := [2, 3, 7, 6]
const _bottom := [0, 4, 5, 1]
const _left := [6, 4, 0, 2]
const _right := [3, 1, 5, 7]
const _back := [7, 5, 4, 6]
const _front := [2, 0, 1, 3]

func _init():
	_blocks.resize(dimensions.x)
	for x in _blocks.size():
		_blocks[x] = []
		for y in dimensions.y:
			_blocks[x].append([])
			for z in dimensions.z:
				_blocks[x][y].append(null)

func set_chunk_position(position: Vector2i):
	if ChunkManager.instance:
		ChunkManager.instance.update_chunk_position(self, position, chunk_position)

	chunk_position = position
	set_global_position(Vector3(chunk_position.x * dimensions.x, 0, chunk_position.y * dimensions.z))

	generate()
	update_chunk()

func generate():
	for x in dimensions.x:
		for y in dimensions.y:
			for z in dimensions.z:
				var global_x = chunk_position.x * dimensions.x + x
				var global_y = y
				var global_z = chunk_position.y * dimensions.z + z

				var surface_height = int(dimensions.y * ((terrain_noise.get_noise_2d(global_x, global_z) + 1.0) / 2.0))
				var cave_val = cave_noise.get_noise_3d(global_x, global_y, global_z)
				var block: Block
				if global_y > surface_height:
					if global_y < 14:
						block = BlockManager.instance.water  # Water level
					else:
						block = BlockManager.instance.air
				elif global_y < 10 and cave_val > 0.3 and global_y < surface_height - 2:
					block = BlockManager.instance.air  # Caves
				elif global_y == surface_height:
					block = BlockManager.instance.grass
				elif global_y >= surface_height - 3:
					block = BlockManager.instance.dirt
				else:
					block = BlockManager.instance.stone

				_blocks[x][y][z] = block

func update_chunk():
	_surface_tool.clear()
	_surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var collision_tool := SurfaceTool.new()
	collision_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for x in dimensions.x:
		for y in dimensions.y:
			for z in dimensions.z:
				var pos := Vector3i(x, y, z)
				var block: Block = _blocks[x][y][z]
				if block == BlockManager.instance.air:
					continue

				# Create visual mesh
				create_block_mesh(pos)

				# Create collision mesh ONLY if not water
				if block != BlockManager.instance.water:
					create_block_mesh_custom_tool(pos, collision_tool)

	_surface_tool.set_material(BlockManager.instance.chunk_material)
	var mesh = _surface_tool.commit()
	var collision_mesh = collision_tool.commit()

	mesh_instance.mesh = mesh

	if collision_mesh and collision_mesh.get_surface_count() > 0:
		collision_shape.shape = collision_mesh.create_trimesh_shape()
	else:
		collision_shape.shape = null

func create_block_mesh_custom_tool(pos: Vector3i, tool: SurfaceTool):
	var block = _blocks[pos.x][pos.y][pos.z]
	if block == BlockManager.instance.air:
		return

	if check_transparent(pos + Vector3i.UP):
		create_face_with_tool(_top, pos, block.top_texture if block.top_texture else block.texture, tool)
	if check_transparent(pos + Vector3i.DOWN):
		create_face_with_tool(_bottom, pos, block.bottom_texture if block.bottom_texture else block.texture, tool)
	if check_transparent(pos + Vector3i.LEFT):
		create_face_with_tool(_left, pos, block.texture, tool)
	if check_transparent(pos + Vector3i.RIGHT):
		create_face_with_tool(_right, pos, block.texture, tool)
	if check_transparent(pos + Vector3i.FORWARD):
		create_face_with_tool(_front, pos, block.texture, tool)
	if check_transparent(pos + Vector3i.BACK):
		create_face_with_tool(_back, pos, block.texture, tool)

func create_face_with_tool(face: Array, pos: Vector3i, texture: Texture2D, tool: SurfaceTool):
	var tex_pos = BlockManager.instance.get_texture_atlas_position(texture)
	var atlas_size = BlockManager.instance.texture_atlas_size

	var uv_offset = Vector2(tex_pos) / atlas_size
	var uv_size = Vector2(1.0 / atlas_size.x, 1.0 / atlas_size.y)

	var uvs = [
		uv_offset,
		uv_offset + Vector2(0, uv_size.y),
		uv_offset + uv_size,
		uv_offset + Vector2(uv_size.x, 0)
	]

	var verts = [
		_vertices[face[0]] + pos,
		_vertices[face[1]] + pos,
		_vertices[face[2]] + pos,
		_vertices[face[3]] + pos
	]

	var normal = (Vector3(verts[2]) - Vector3(verts[0])).cross(Vector3(verts[1]) - Vector3(verts[0])).normalized()
	var normals = [normal, normal, normal]

	tool.add_triangle_fan([verts[0], verts[1], verts[2]], [uvs[0], uvs[1], uvs[2]], normals)
	tool.add_triangle_fan([verts[0], verts[2], verts[3]], [uvs[0], uvs[2], uvs[3]], normals)


func create_block_mesh(pos: Vector3i):
	var block = _blocks[pos.x][pos.y][pos.z]
	if block == BlockManager.instance.air:
		return

	var is_water = (block == BlockManager.instance.water)

	for direction in [
		{face = _top,     offset = Vector3i.UP},
		{face = _bottom,  offset = Vector3i.DOWN},
		{face = _left,    offset = Vector3i.LEFT},
		{face = _right,   offset = Vector3i.RIGHT},
		{face = _front,   offset = Vector3i.FORWARD},
		{face = _back,    offset = Vector3i.BACK}
	]:
		var neighbor_pos = pos + direction.offset
		var neighbor = get_block_or_null(neighbor_pos)

		if is_water:
			# Only render water faces if neighbor is NOT water
			if neighbor != BlockManager.instance.water:
				create_face(direction.face, pos, block.texture)
		else:
			if neighbor == null or neighbor == BlockManager.instance.air or (neighbor and neighbor.is_transparent):
				var tex = block.texture
				if direction.face == _top and block.top_texture:
					tex = block.top_texture
				elif direction.face == _bottom and block.bottom_texture:
					tex = block.bottom_texture

				create_face(direction.face, pos, tex)
				
func get_block_or_null(pos: Vector3i) -> Block:
	if pos.x >= 0 and pos.x < dimensions.x and pos.y >= 0 and pos.y < dimensions.y and pos.z >= 0 and pos.z < dimensions.z:
		return _blocks[pos.x][pos.y][pos.z]
	# Check other chunks
	var world_pos = Vector3i(
		chunk_position.x * dimensions.x + pos.x,
		pos.y,
		chunk_position.y * dimensions.z + pos.z
	)
	return ChunkManager.instance.get_block_at_world_position(world_pos)


func create_face(face: Array, pos: Vector3i, texture: Texture2D):
	var tex_pos = BlockManager.instance.get_texture_atlas_position(texture)
	var atlas_size = BlockManager.instance.texture_atlas_size

	var uv_offset = Vector2(tex_pos) / atlas_size
	var uv_size = Vector2(1.0 / atlas_size.x, 1.0 / atlas_size.y)

	var uvs = [
		uv_offset,
		uv_offset + Vector2(0, uv_size.y),
		uv_offset + uv_size,
		uv_offset + Vector2(uv_size.x, 0)
	]

	var verts = [
		_vertices[face[0]] + pos,
		_vertices[face[1]] + pos,
		_vertices[face[2]] + pos,
		_vertices[face[3]] + pos
	]

	var normal = (Vector3(verts[2]) - Vector3(verts[0])).cross(Vector3(verts[1]) - Vector3(verts[0])).normalized()
	var normals = [normal, normal, normal]

	_surface_tool.add_triangle_fan([verts[0], verts[1], verts[2]], [uvs[0], uvs[1], uvs[2]], normals)
	_surface_tool.add_triangle_fan([verts[0], verts[2], verts[3]], [uvs[0], uvs[2], uvs[3]], normals)

func check_transparent(pos: Vector3i) -> bool:
	var b = get_block_or_null(pos)
	return b == null or b == BlockManager.instance.air or (b and b.is_transparent)

func set_block(pos: Vector3i, block: Block):
	_blocks[pos.x][pos.y][pos.z] = block
	update_chunk()
