extends CharacterBody3D

@export var mouse_sensitivity := 0.2
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 5.0
@export var gravity := 15.0
@export var fly_speed := 10.0

@onready var camera := $head/Camera3D
@onready var head := $head
@onready var default_head_pos: float = head.position.y

@onready var chunk_manager = ChunkManager.instance

var is_in_water := false

var current_speed := walk_speed
@export var head_bob_time := 0.0
@export var head_bob_intensity := 0.05
@export var head_bob_speed := 14.0

var noclip := false:
	set(value):
		noclip = value
		if noclip:
			gravity = 0
			collision_mask = 0
			collision_layer = 0
		else:
			gravity = 15.0
			collision_mask = 1
			collision_layer = 1

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		camera.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if event.is_action_pressed("toggle_noclip"):
		noclip = !noclip
		print("Noclip: ", "ON" if noclip else "OFF")

func _physics_process(delta):
	# Handle speed changes
	handle_water()
	if Input.is_action_pressed("sprint"):
		current_speed = sprint_speed if !noclip else fly_speed * 2
	else:
		current_speed = walk_speed if !noclip else fly_speed
	
	# Get input
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if noclip:
		# Fly movement - full 3D control
		var fly_dir := Vector3.ZERO
		fly_dir += transform.basis.x * input_dir.x
		fly_dir += transform.basis.z * input_dir.y
		
		# Add vertical movement in fly mode
		if Input.is_action_pressed("jump"):
			fly_dir += Vector3.UP
		if Input.is_action_pressed("crouch"):
			fly_dir += Vector3.DOWN
			
		if fly_dir.length() > 0:
			fly_dir = fly_dir.normalized()
		
		velocity = fly_dir * current_speed
		
		# No head bobbing in fly mode
		head.position.y = default_head_pos
		
	else:
		# Normal ground movement
		# Apply gravity
		if not is_on_floor():
			velocity.y -= gravity * delta
		
		# Handle jump
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity
		
		# Ground movement
		if direction:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
			
			# Head bobbing when moving on ground
			if is_on_floor():
				head_bob_time += delta * head_bob_speed
				head.position.y = default_head_pos + sin(head_bob_time * 2.0) * head_bob_intensity
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)
			velocity.z = move_toward(velocity.z, 0, current_speed)
			# Reset head position when not moving
			head.position.y = lerp(head.position.y, default_head_pos, delta * 10.0)
			head_bob_time = 0.0
	move_and_slide()
	
func handle_water():
	var in_water = false
	var depth = 0

	# Check how submerged the player is
	var block = ChunkManager.instance.get_block_at_world_position(global_position + Vector3(0, -1.5, 0))
	if block and block.is_liquid:
		in_water = true
		depth += 1

	if in_water:
		velocity.x *= 0.6
		velocity.z *= 0.6
		if Input.is_action_pressed("jump") or Input.is_action_pressed("move_forward"):
			velocity.y += 0.2
		else:
			if depth >= 2:
				velocity.y -= 0.05
		velocity.y = clamp(velocity.y, -2.0, 3.0)
