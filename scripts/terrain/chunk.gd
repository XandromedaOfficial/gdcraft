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

	for x in dimensions.x:
		for y in dimensions.y:
			for z in dimensions.z:
				create_block_mesh(Vector3i(x, y, z))

	_surface_tool.set_material(BlockManager.instance.chunk_material)
	var mesh = _surface_tool.commit()

	mesh_instance.mesh = mesh
	collision_shape.shape = mesh.create_trimesh_shape()

func create_block_mesh(pos: Vector3i):
	var block = _blocks[pos.x][pos.y][pos.z]
	if block == BlockManager.instance.air:
		return

	if check_transparent(pos + Vector3i.UP):
		create_face(_top, pos, block.top_texture if block.top_texture else block.texture)
	if check_transparent(pos + Vector3i.DOWN):
		create_face(_bottom, pos, block.bottom_texture if block.bottom_texture else block.texture)
	if check_transparent(pos + Vector3i.LEFT):
		create_face(_left, pos, block.texture)
	if check_transparent(pos + Vector3i.RIGHT):
		create_face(_right, pos, block.texture)
	if check_transparent(pos + Vector3i.FORWARD):
		create_face(_front, pos, block.texture)
	if check_transparent(pos + Vector3i.BACK):
		create_face(_back, pos, block.texture)

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
	if pos.x < 0 or pos.x >= dimensions.x: return true
	if pos.y < 0 or pos.y >= dimensions.y: return true
	if pos.z < 0 or pos.z >= dimensions.z: return true

	var b = _blocks[pos.x][pos.y][pos.z]
	return b == BlockManager.instance.air or (b and b.is_transparent)

func set_block(pos: Vector3i, block: Block):
	_blocks[pos.x][pos.y][pos.z] = block
	update_chunk()
