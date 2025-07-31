@tool
extends MeshInstance3D

@export var cube_size: float = 1.0
@export var width: int = 32
@export var height: int = 32
@export var depth: int = 32
@export var seed: int = -1  # If -1, randomize

@export var regenerate := false:
	set(value):
		if value:
			_ready()
			regenerate = false

var cube_mesh: ArrayMesh
var voxels = []
var noise: FastNoiseLite

var default_uvs = [
	Vector2(0, 0),
	Vector2(1, 0),
	Vector2(1, 1),
	Vector2(0, 1)
]

func _ready() -> void:
	if seed == -1:
		seed = randi()
		print("Random seed used: ", seed)

	# Initialize noise generator
	noise = FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05

	# Generate voxels and mesh
	voxels = generate_voxels()
	generate_mesh(voxels)
	seed = -1


# Generate terrain using Perlin noise heightmap
func generate_voxels() -> Array:
	var array = []
	array.resize(width)

	for x in range(width):
		array[x] = []
		for y in range(height):
			array[x].append([])
			for z in range(depth):
				array[x][y].append(0)  # Start empty

	for x in range(width):
		for z in range(depth):
			var height_sample = noise.get_noise_2d(x, z)
			var terrain_height = int(remap(height_sample, -1.0, 1.0, height / 4, height * 0.75))

			for y in range(height):
				if y == 0:
					array[x][y][z] = 4  # Bedrock
				elif y < terrain_height - 4:
					array[x][y][z] = 3  # Stone
				elif y < terrain_height - 1:
					array[x][y][z] = 2  # Dirt
				elif y == terrain_height:
					array[x][y][z] = 1  # Grass
				elif y < terrain_height:
					array[x][y][z] = 2  # Dirt fill
				else:
					array[x][y][z] = 0  # Air

	return array


# Generate visible mesh from voxels
func generate_mesh(voxels):
	var faces = []

	for x in range(voxels.size()):
		for y in range(voxels[x].size()):
			for z in range(voxels[x][y].size()):
				if voxels[x][y][z] != 0:
					var position = Vector3(x, y, z) * cube_size

					if x == 0 or voxels[x - 1][y][z] == 0:
						faces.append(create_face(Vector3.LEFT, position, default_uvs))
					if x == voxels.size() - 1 or voxels[x + 1][y][z] == 0:
						faces.append(create_face(Vector3.RIGHT, position, default_uvs))
					if y == 0 or voxels[x][y - 1][z] == 0:
						faces.append(create_face(Vector3.DOWN, position, default_uvs))
					if y == voxels[x].size() - 1 or voxels[x][y + 1][z] == 0:
						faces.append(create_face(Vector3.UP, position, default_uvs))
					if z == 0 or voxels[x][y][z - 1] == 0:
						faces.append(create_face(Vector3.FORWARD, position, default_uvs))
					if z == voxels[x][y].size() - 1 or voxels[x][y][z + 1] == 0:
						faces.append(create_face(Vector3.BACK, position, default_uvs))

	var vertices = []
	var normals = []
	var uvs = []

	for face in faces:
		vertices += face["vertices"]
		normals += face["normals"]
		uvs += face["uvs"]

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uvs)

	cube_mesh = ArrayMesh.new()
	cube_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	self.mesh = cube_mesh

# Create a single quad face
func create_face(direction: Vector3, position: Vector3, uv_coords: Array) -> Dictionary:
	var vertices = []
	var normals = []
	var uvs = []

	normals.resize(4)
	match direction:
		Vector3.UP:
			vertices = [
				position + Vector3(-0.5, 0.5, -0.5) * cube_size,
				position + Vector3(0.5, 0.5, -0.5) * cube_size,
				position + Vector3(0.5, 0.5, 0.5) * cube_size,
				position + Vector3(-0.5, 0.5, 0.5) * cube_size
			]
			normals.fill(Vector3.UP)
		Vector3.DOWN:
			vertices = [
				position + Vector3(-0.5, -0.5, 0.5) * cube_size,
				position + Vector3(0.5, -0.5, 0.5) * cube_size,
				position + Vector3(0.5, -0.5, -0.5) * cube_size,
				position + Vector3(-0.5, -0.5, -0.5) * cube_size
			]
			normals.fill(Vector3.DOWN)
		Vector3.LEFT:
			vertices = [
				position + Vector3(-0.5, -0.5, -0.5) * cube_size,
				position + Vector3(-0.5, 0.5, -0.5) * cube_size,
				position + Vector3(-0.5, 0.5, 0.5) * cube_size,
				position + Vector3(-0.5, -0.5, 0.5) * cube_size
			]
			normals.fill(Vector3.LEFT)
		Vector3.RIGHT:
			vertices = [
				position + Vector3(0.5, -0.5, 0.5) * cube_size,
				position + Vector3(0.5, 0.5, 0.5) * cube_size,
				position + Vector3(0.5, 0.5, -0.5) * cube_size,
				position + Vector3(0.5, -0.5, -0.5) * cube_size
			]
			normals.fill(Vector3.RIGHT)
		Vector3.FORWARD:
			vertices = [
				position + Vector3(-0.5, -0.5, -0.5) * cube_size,
				position + Vector3(0.5, -0.5, -0.5) * cube_size,
				position + Vector3(0.5, 0.5, -0.5) * cube_size,
				position + Vector3(-0.5, 0.5, -0.5) * cube_size
			]
			normals.fill(Vector3.FORWARD)
		Vector3.BACK:
			vertices = [
				position + Vector3(-0.5, 0.5, 0.5) * cube_size,
				position + Vector3(0.5, 0.5, 0.5) * cube_size,
				position + Vector3(0.5, -0.5, 0.5) * cube_size,
				position + Vector3(-0.5,-0.5, 0.5) * cube_size
			]
			normals.fill(Vector3.BACK)

	uvs = uv_coords

	return {
		"vertices" : [
			vertices[0], vertices[1], vertices[2],
			vertices[2], vertices[3], vertices[0]
		],
		"normals" : [
			normals[0], normals[1], normals[2],
			normals[2], normals[3], normals[0]
		],
		"uvs" : [
			uvs[0], uvs[1], uvs[2],
			uvs[2], uvs[3], uvs[0]
		]
}
