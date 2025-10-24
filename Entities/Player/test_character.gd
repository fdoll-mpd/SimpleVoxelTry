extends CharacterBody3D

@export var mouse_sensitivity: float = 0.01
@onready var head: Node3D = $Head
@onready var eye_camera: Camera3D = $Head/EyeCamera

@export var voxel_terrain_path: NodePath 
@export var place_block_id: int = 1           # blocky ID to place on click
@export var max_place_distance: float = 64.0  # how far you can reach
@export var world_builder_path: NodePath
@onready var world_builder = (get_node(world_builder_path) if not world_builder_path.is_empty() else null)

# Which block ID to place when clicking (must exist in your VoxelBlockyLibrary)
@export var click_block_id: int = 1

# How far you can reach with clicks
@export var click_max_distance: float = 64.0


const SPEED := 5.0
const RUN_MULT := 2.0
const JUMP_VELOCITY := 4.5
const AIR_BRAKE := 10.0 # flight damping (units/sec^2)

var flying: bool = false
var move_faster: bool = false

# --- Debug HUD ---
var _hud_label: Label
var _last_toggles: String = ""

var _terrain: VoxelTerrain
var _vt: VoxelTool

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_create_debug_hud()
	_terrain = get_node(voxel_terrain_path) as VoxelTerrain
	_vt = _terrain.get_voxel_tool()
	_vt.set_raycast_normal_enabled(true) # we want the face normal from ray hits  :contentReference[oaicite:1]{index=1}
	for v in get_tree().get_nodes_in_group("VoxelViewers"):
		v.view_distance *= 10.0                 # keep same world-space load radius
		# if you set vertical ratio, you normally don't need to change it

	# Terrain-wide clamp so the viewer can ask for that distance:
	_terrain.max_view_distance *= 10

	# If you have a click/brush reach:
	#default_place_block_id = default_place_block_id  # unchanged
	max_place_distance *= 10.0          

	# If your player script has its own reach:
	click_max_distance *= 10.0

func _physics_process(delta: float) -> void:

		
	if not is_on_floor():
		if flying:
			velocity = Vector3.ZERO
		else:
			#print("Falling with velocity: (%.2f, %.2f, %.2f) " % [velocity.x, velocity.y, velocity.z])
			velocity += get_gravity() * delta
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	if Input.is_action_just_pressed("is_flying"):
		flying = !flying
		#print("Flying toggle")
		_last_toggles = "is_flying toggled -> %s" % (str(flying))

	if Input.is_action_just_pressed("is_moving_faster"):
		move_faster = !move_faster
		_last_toggles = "is_moving_faster toggled -> %s" % (str(move_faster))
		
	var speed := SPEED * (RUN_MULT if move_faster else 1.0)

	# Camera-relative planar axes (ignore tilt for ground move)
	#var cam_basis := eye_camera.global_transform.basis
	#var forward := -cam_basis.z; forward.y = 0.0; forward = forward.normalized()
	#var right :=  cam_basis.x; right.y   = 0.0; right   = right.normalized()

	var input2 := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (eye_camera.global_transform.basis *  Vector3(input2.x, 0, input2.y)).normalized()
		
		# DO NOT zero velocity every frame here — breaks hover diagnostics
		#var vertical := (
			#Input.get_action_strength("fly_up")
			#- Input.get_action_strength("fly_down")
		#)

		#var fly_dir := right * input2.x + forward * input2.y + Vector3.UP * vertical
		

		#if fly_dir.length() > 0.001:
			#var target := fly_dir.normalized() * speed
			#velocity = velocity.move_toward(target, AIR_BRAKE * delta)
		#else:
			#velocity = velocity.move_toward(Vector3.ZERO, AIR_BRAKE * delta)
	if direction:
		if flying:
			velocity = direction * speed
		else:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	#if flying:
		## DO NOT zero velocity every frame here — breaks hover diagnostics
		##var vertical := (
			##Input.get_action_strength("fly_up")
			##- Input.get_action_strength("fly_down")
		##)
#
		##var fly_dir := right * input2.x + forward * input2.y + Vector3.UP * vertical
		#
#
		##if fly_dir.length() > 0.001:
			##var target := fly_dir.normalized() * speed
			##velocity = velocity.move_toward(target, AIR_BRAKE * delta)
		##else:
			##velocity = velocity.move_toward(Vector3.ZERO, AIR_BRAKE * delta)
		#if direction:
			#velocity = direction * speed
		#else:
			#velocity.x = move_toward(velocity.x, 0.0, speed)
			#velocity.z = move_toward(velocity.z, 0.0, speed)
	#else:
#
#
		## Planar ground move
		##var dir2d := right * input2.x + forward * input2.y
		##if direction.length() > 0.001:
		#if direction:
			#velocity.x = direction.x * speed
			#velocity.z = direction.z * speed
		#else:
			#velocity.x = move_toward(velocity.x, 0.0, speed)
			#velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	_update_debug_hud(delta)

func _unhandled_input(event: InputEvent) -> void:
	# Look
	if event is InputEventMouseMotion:
		var relative = event.relative * mouse_sensitivity
		head.rotate_y(-relative.x)
		eye_camera.rotate_x(-relative.y)
		eye_camera.rotation.x = clamp(eye_camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	#if event is InputEventMouseButton and event.pressed and event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
		#_place_voxel_from_camera()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Left mouse button clicked ", world_builder, " and ", world_builder.has_method("place_one_block_from_ray"))
		if world_builder != null and world_builder.has_method("place_one_block_from_ray"):
			var origin: Vector3 = eye_camera.global_transform.origin
			var dir: Vector3 = -eye_camera.global_transform.basis.z
			var ok: bool = world_builder.place_one_block_from_ray(origin, dir, click_block_id, click_max_distance)
			print("Tried to place one block from ray ", ok)
			if not ok:
				# Optional: print something helpful to your HUD/log.
				# Common causes: area not loaded (no/too-small VoxelViewer), outside bounds, invalid block ID.
				_last_toggles = "place failed (not editable / out of range / no hit)"

	## Re-capture on click
	#if event is InputEventMouseButton and event.pressed:
		#if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
#
	#if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _place_voxel_from_camera() -> void:
	if _vt == null or _terrain == null:
		return

	# Ray in world space from the camera’s forward direction
	var origin: Vector3 = eye_camera.global_transform.origin
	var dir: Vector3 = -eye_camera.global_transform.basis.z.normalized()

	# Voxel-aware raycast (world-space), returns VoxelRaycastResult or null  :contentReference[oaicite:2]{index=2}
	var hit := _vt.raycast(origin, dir, max_place_distance)
	if hit == null:
		return

	# We clicked a voxel at `hit.position` (voxel coords), and which face via `hit.normal`.  :contentReference[oaicite:3]{index=3}
	var target: Vector3i = hit.position + Vector3i(hit.normal)

	# Optional: make sure the 1×1×1 area is actually editable (loaded & in bounds)  :contentReference[oaicite:4]{index=4}
	var editable := _vt.is_area_editable(AABB(Vector3(target), Vector3.ONE))
	if not editable:
		return

	# Write a single blocky voxel at `target`. Use do_point with MODE_SET & value (block ID).  :contentReference[oaicite:5]{index=5}
	_vt.channel = VoxelBuffer.CHANNEL_TYPE
	_vt.mode = VoxelTool.MODE_SET
	_vt.value = place_block_id
	_vt.do_point(target)
	
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
	_hud_label.size = Vector2(680, 500)
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
