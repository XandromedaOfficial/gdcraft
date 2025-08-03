extends VoxelGenerator

var noise := FastNoiseLite.new()

func _ready():
	noise.seed = randi()
	noise.octaves = 4
	noise.period = 64.0
	noise.persistence = 0.5

func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE

func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int):
	var size = out_buffer.get_size()

	for x in size.x:
		for y in size.y:
			for z in size.z:
				var world_x = origin.x + x
				var world_y = origin.y + y
				var world_z = origin.z + z

				var height := int(noise.get_noise_2d(world_x, world_z) * 10.0 + 32.0)

				var voxel_id := 0  # Air
				if world_y < height - 3:
					voxel_id = 1  # Stone
				elif world_y < height - 1:
					voxel_id = 2  # Dirt
				elif world_y == height:
					voxel_id = 3  # Grass

				out_buffer.set_voxel(voxel_id, x, y, z, VoxelBuffer.CHANNEL_TYPE)
