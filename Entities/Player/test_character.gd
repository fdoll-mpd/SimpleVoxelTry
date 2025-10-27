extends CharacterBody3D

@export var mouse_sensitivity: float = 0.01
@onready var head: Node3D = $Head
@onready var eye_camera: Camera3D = $Head/EyeCamera

@export var voxel_terrain_path: NodePath 
@export var place_block_id: int = 1
@export var max_place_distance: float = 64.0
@export var world_builder_path: NodePath
@onready var world_builder = (get_node(world_builder_path) if not world_builder_path.is_empty() else null)

@export var click_block_id: int = 1
@export var click_max_distance: float = 64.0


const SPEED := 5.0
const RUN_MULT := 2.0
const JUMP_VELOCITY := 4.5
const AIR_BRAKE := 10.0

var flying: bool = true
var move_faster: bool = false

# --- Debug HUD ---
var _hud_label: Label
var _last_toggles: String = ""

# --- Ray Debug Info ---
var _last_ray_origin: Vector3 = Vector3.ZERO
var _last_ray_hit: Vector3 = Vector3.ZERO
var _last_ray_direction: Vector3 = Vector3.ZERO
var _last_ray_success: bool = false
var _last_ray_pitch: float = 0.0
var _last_ray_yaw: float = 0.0
var _last_action: String = ""

var _terrain: VoxelTerrain
var _vt: VoxelTool


class Crosshair:
	extends Control
	var arm_len: float = 10.0
	var gap: float = 4.0
	var thickness: float = 2.0
	var color: Color = Color(1, 1, 1, 0.9)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		resized.connect(_on_resized)
		queue_redraw()

	func _on_resized() -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5

		# Horizontal arms
		draw_line(
			Vector2(c.x - gap - arm_len, c.y),
			Vector2(c.x - gap, c.y),
			color, thickness, true
		)
		draw_line(
			Vector2(c.x + gap, c.y),
			Vector2(c.x + gap + arm_len, c.y),
			color, thickness, true
		)

		# Vertical arms
		draw_line(
			Vector2(c.x, c.y - gap - arm_len),
			Vector2(c.x, c.y - gap),
			color, thickness, true
		)
		draw_line(
			Vector2(c.x, c.y + gap),
			Vector2(c.x, c.y + gap + arm_len),
			color, thickness, true
		)
		
		
		
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_create_debug_hud()
	
	var layer := CanvasLayer.new()
	add_child(layer)

	var cross := Crosshair.new()
	layer.add_child(cross)
	
	_terrain = get_node(voxel_terrain_path) as VoxelTerrain
	_vt = _terrain.get_voxel_tool()
	_vt.set_raycast_normal_enabled(true)

func _physics_process(delta: float) -> void:

		
	if not is_on_floor():
		if flying:
			velocity = Vector3.ZERO
		else:
			velocity += get_gravity() * delta
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	if Input.is_action_just_pressed("is_flying"):
		flying = !flying
		_last_toggles = "is_flying toggled -> %s" % (str(flying))

	if Input.is_action_just_pressed("is_moving_faster"):
		move_faster = !move_faster
		_last_toggles = "is_moving_faster toggled -> %s" % (str(move_faster))
		
	var speed := SPEED * (RUN_MULT if move_faster else 1.0)
	var vertical := (
		Input.get_action_strength("fly_up")
		- Input.get_action_strength("fly_down")
	)
	var input2 := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var input3 := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (eye_camera.global_transform.basis *  Vector3(input3.x, (vertical if flying else 0), input3.y)).normalized()
		


	if direction:
		if flying:
			velocity = direction * speed
		else:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	_update_debug_hud(delta)

func _unhandled_input(event: InputEvent) -> void:
	# Look
	if event is InputEventMouseMotion:
		var relative = event.relative * mouse_sensitivity
		head.rotate_y(-relative.x)
		eye_camera.rotate_x(-relative.y)
		eye_camera.rotation.x = clamp(eye_camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# Place single block
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if world_builder != null and world_builder.has_method("place_one_block_from_ray"):
			var origin: Vector3 = eye_camera.global_transform.origin
			var dir: Vector3 = -eye_camera.global_transform.basis.z
			
			# Capture ray info for debug display
			_last_ray_origin = origin
			_last_ray_direction = dir.normalized()
			
			# Calculate pitch and yaw from direction vector
			_last_ray_pitch = rad_to_deg(asin(-dir.normalized().y))
			var horizontal_dir = Vector2(dir.x, dir.z).normalized()
			_last_ray_yaw = rad_to_deg(atan2(horizontal_dir.x, horizontal_dir.y))
			
			var ok: bool = world_builder.place_one_block_from_ray(origin, dir, click_block_id, click_max_distance)
			
			if ok:
				# Get the actual hit point for feedback
				var hit = _vt.raycast(origin, dir.normalized(), click_max_distance)
				if hit != null:
					_last_ray_hit = Vector3(hit.position)
					_last_ray_success = true
					_last_action = "Single block placed"
				else:
					_last_ray_hit = Vector3.ZERO
					_last_ray_success = false
					_last_action = "Block placement failed"
			else:
				_last_ray_success = false
				_last_ray_hit = Vector3.ZERO
				_last_action = "No valid surface hit"

	# Hotkey structure placement
	if event is InputEventKey and event.pressed:
		var structure_type = ""
		var structure_name = ""
		
		if event.keycode == KEY_C:
			structure_type = "cube_3x3x3"
			structure_name = "3x3x3 Cube"
		elif event.keycode == KEY_R:
			structure_type = "box_4x4x8"
			structure_name = "4x4x8 Rectangular Prism"
		elif event.keycode == KEY_G:
			structure_type = "sphere_r4"
			structure_name = "Sphere (radius 4)"
		
		if structure_type != "" and world_builder != null and world_builder.has_method("place_structure_from_ray"):
			var origin: Vector3 = eye_camera.global_transform.origin
			var dir: Vector3 = -eye_camera.global_transform.basis.z
			
			# Capture ray info for debug display
			_last_ray_origin = origin
			_last_ray_direction = dir.normalized()
			
			# Calculate pitch and yaw
			_last_ray_pitch = rad_to_deg(asin(-dir.normalized().y))
			var horizontal_dir = Vector2(dir.x, dir.z).normalized()
			_last_ray_yaw = rad_to_deg(atan2(horizontal_dir.x, horizontal_dir.y))
			
			var ok: bool = world_builder.place_structure_from_ray(origin, dir, structure_type, click_block_id, click_max_distance)
			
			if ok:
				var hit = _vt.raycast(origin, dir.normalized(), click_max_distance)
				if hit != null:
					_last_ray_hit = Vector3(hit.position)
					_last_ray_success = true
					_last_action = structure_name + " placed"
					_last_toggles = "Placed " + structure_name
				else:
					_last_ray_hit = Vector3.ZERO
					_last_ray_success = true
					_last_action = structure_name + " placed"
					_last_toggles = "Placed " + structure_name
			else:
				_last_ray_success = false
				_last_ray_hit = Vector3.ZERO
				_last_action = "Failed to place " + structure_name
				_last_toggles = "Failed: " + structure_name
	
func _create_debug_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	_hud_label = Label.new()
	_hud_label.name = "DebugHUD"
	_hud_label.top_level = true
	_hud_label.position = Vector2(12, 12)
	_hud_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_hud_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hud_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_label.size = Vector2(680, 600)
	_hud_label.theme_type_variation = &"Label"
	_hud_label.add_theme_font_size_override("font_size", 14)
	_hud_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	canvas.add_child(_hud_label)

func _update_debug_hud(_delta: float) -> void:
	# Positions & rotations
	var pos := global_transform.origin
	var vel := velocity
	var speed := vel.length()

	var yaw_deg   := rad_to_deg(head.rotation.y)
	var pitch_deg := rad_to_deg(eye_camera.rotation.x)

	# Live inputs
	var fly_up_s   := Input.get_action_strength("fly_up")
	var fly_dn_s   := Input.get_action_strength("fly_down")
	var accept_s   := Input.get_action_strength("ui_accept")

	var fly_up_on  := Input.is_action_pressed("fly_up")
	var fly_dn_on  := Input.is_action_pressed("fly_down")
	var isfly_on   := Input.is_action_pressed("is_flying")
	var fast_on    := Input.is_action_pressed("is_moving_faster")

	_hud_label.text = ""
	_hud_label.text += "[STATE]\n"
	_hud_label.text += "  flying: %s    move_faster: %s\n" % [str(flying), str(move_faster)]
	_hud_label.text += "  gravity: %s   \n" % str(get_gravity())
	_hud_label.text += "  pos: (%.2f, %.2f, %.2f)\n" % [pos.x, pos.y, pos.z]
	_hud_label.text += "  vel: (%.2f, %.2f, %.2f) |speed=%.2f|\n" % [velocity.x, velocity.y, velocity.z, speed]
	_hud_label.text += "  camera yaw: %.1f°   pitch: %.1f°\n" % [yaw_deg, pitch_deg]
	_hud_label.text += "  camera pos: (%.2f, %.2f, %.2f)\n" % [eye_camera.global_transform.origin.x, eye_camera.global_transform.origin.y, eye_camera.global_transform.origin.z]
	_hud_label.text += "  head pos: (%.2f, %.2f, %.2f)\n" % [head.global_transform.origin.x, head.global_transform.origin.y, head.global_transform.origin.z]
	
	_hud_label.text += "\n[RAYCAST DEBUG]\n"
	if _last_ray_success:
		_hud_label.text += "  Status: HIT\n"
		_hud_label.text += "  Origin: (%.2f, %.2f, %.2f)\n" % [_last_ray_origin.x, _last_ray_origin.y, _last_ray_origin.z]
		_hud_label.text += "  Hit Point: (%.2f, %.2f, %.2f)\n" % [_last_ray_hit.x, _last_ray_hit.y, _last_ray_hit.z]
		var distance = _last_ray_origin.distance_to(_last_ray_hit)
		_hud_label.text += "  Distance: %.2f\n" % distance
		_hud_label.text += "  Direction: (%.3f, %.3f, %.3f)\n" % [_last_ray_direction.x, _last_ray_direction.y, _last_ray_direction.z]
		_hud_label.text += "  Ray Pitch: %.1f°   Ray Yaw: %.1f°\n" % [_last_ray_pitch, _last_ray_yaw]
	elif _last_ray_origin != Vector3.ZERO:
		_hud_label.text += "  Status: MISS\n"
		_hud_label.text += "  Origin: (%.2f, %.2f, %.2f)\n" % [_last_ray_origin.x, _last_ray_origin.y, _last_ray_origin.z]
		_hud_label.text += "  Direction: (%.3f, %.3f, %.3f)\n" % [_last_ray_direction.x, _last_ray_direction.y, _last_ray_direction.z]
		_hud_label.text += "  Ray Pitch: %.1f°   Ray Yaw: %.1f°\n" % [_last_ray_pitch, _last_ray_yaw]
	else:
		_hud_label.text += "  No raycast fired yet\n"
	
	_hud_label.text += "\n[INPUT]\n"
	_hud_label.text += "  fly_up: %.2f (%s)   fly_down: %.2f (%s)\n" % [
		fly_up_s, str(fly_up_on), fly_dn_s, str(fly_dn_on)
	]
	_hud_label.text += "  ui_accept: %.2f (%s)\n" % [accept_s, str(Input.is_action_pressed("ui_accept"))]
	_hud_label.text += "  is_flying (pressed now?): %s   is_moving_faster (pressed now?): %s\n" % [
		str(isfly_on), str(fast_on)
	]
	if _last_toggles != "":
		_hud_label.text += "  last toggle: %s\n" % _last_toggles
