@tool
extends Node
class_name BlockManager

# Exported block resources
@export var air: Block
@export var stone: Block
@export var dirt: Block
@export var grass: Block
@export var water: Block

# Block texture size in pixels
@export var block_texture_size: Vector2i = Vector2i(16, 16)
@export var grid_width := 3  # Customize texture atlas grid width

# Read-only dictionary to store texture atlas positions
var _atlas_lookup: Dictionary = {}

# Read-only material and texture atlas size
var chunk_material: StandardMaterial3D
var texture_atlas_size: Vector2

# Singleton instance
static var instance: BlockManager = null

func remove_duplicates(arr: Array) -> Array:
	var seen := {}
	var result := []
	for item in arr:
		if not seen.has(item):
			seen[item] = true
			result.append(item)
	return result

func _ready():
	instance = self

	var blocks = [air, stone, dirt, grass, water]
	var block_textures := []

	for block in blocks:
		if block:
			block_textures += block.get_textures()

	# Remove duplicates
	block_textures = block_textures.duplicate()
	block_textures = block_textures.filter(func(tex): return tex != null)
	block_textures = remove_duplicates(block_textures)

	# Populate atlas lookup
	for i in block_textures.size():
		var pos = Vector2i(i % grid_width, floor(i / grid_width))
		_atlas_lookup[block_textures[i]] = pos

	var grid_height = ceil(block_textures.size() / float(grid_width))

	# Create and populate the image atlas
	var image_width = grid_width * block_texture_size.x
	var image_height = grid_height * block_texture_size.y
	var atlas_image = Image.create(image_width, image_height, false, Image.FORMAT_RGBA8)

	for i in block_textures.size():
		var tex: Texture2D = block_textures[i]
		var image = tex.get_image()
		image.convert(Image.FORMAT_RGBA8)

		var pos = _atlas_lookup[tex] * block_texture_size
		atlas_image.blit_rect(image, Rect2i(Vector2i.ZERO, block_texture_size), pos)

	var atlas_texture = ImageTexture.create_from_image(atlas_image)

	# Create material
	chunk_material = StandardMaterial3D.new()
	chunk_material.albedo_texture = atlas_texture
	chunk_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	texture_atlas_size = Vector2(grid_width, grid_height)

	print("Done loading %d images to make %d x %d atlas" % [block_textures.size(), grid_width, grid_height])

func get_texture_atlas_position(texture: Texture2D) -> Vector2i:
	if not texture or not _atlas_lookup.has(texture):
		return Vector2i.ZERO
	return _atlas_lookup[texture]
