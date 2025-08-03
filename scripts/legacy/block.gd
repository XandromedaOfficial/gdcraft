@icon("res://icon.svg")
@tool
extends Resource
class_name Block

# Exported textures for block faces
@export var texture: Texture2D
@export var top_texture: Texture2D
@export var bottom_texture: Texture2D

@export var is_transparent: bool = false
@export var is_liquid: bool = false
@export var is_air: bool = false 
@export var flow_speed: float = 1.0  # How fast water spreads (optional)

# Computed array of all non-null textures
func get_textures():
	return [texture, top_texture, bottom_texture].filter(func(t): return t != null)
