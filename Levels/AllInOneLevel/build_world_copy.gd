extends Node3D

@onready var terrain: Node = $VoxelTerrain # adjust path if needed
@onready var player: Node3D = $"res://Entities/Player/TestCharacter.tscn" 
# "Material" index to write into the blocky terrain (1 = solid cube per your library)
const SOLID := 1

# Voxel sizes (in voxels)
const VOX_SPHERE_RADIUS := 6
const VOX_CUBE_HALF := Vector3i(5, 5, 5)
const VOX_RECT_HALF := Vector3i(8, 3, 4)

# Where to place the two sets (in voxels / world units)
const STATIC_BASE := Vector3i(-20, 12, 0)  # voxel shapes (float in air)
const DYNAMIC_BASE := Vector3( 20, 12, 0)  # physics bodies (fall)

# Size of the ground plate
const GROUND_HALF := Vector3i(128, 1, 128)

var _vt: VoxelTool

func _ready() -> void:
	if !terrain:
		push_error("Terrain node not found. Place a VoxelTerrain named 'Terrain' beside this node.")
		return
	_ensure_viewer_covering_edits()

	# Defer edits to give the terrain one frame to register the viewer
	call_deferred("_do_all_edits")
	#_build_ground()
	#_stamp_static_voxel_shapes()
	#_spawn_dynamic_falling_shapes()

func _do_all_edits() -> void:
	_vt = terrain.get_voxel_tool()
	_vt.mode = VoxelTool.MODE_SET
	_vt.channel = VoxelBuffer.CHANNEL_TYPE
	_vt.value = SOLID

	await _build_ground_safe()
	await _stamp_static_voxel_shapes_safe()
	_spawn_dynamic_falling_shapes() # this is regular Godot physics; no waiting needed

func _wait_area_editable(a_min: Vector3i, a_max: Vector3i, timeout_frames := 180) -> bool:
	var size_i := a_max - a_min
	var box: AABB = AABB(Vector3(a_min), Vector3(size_i))  # use AABB instead of Box3i

	var frames := 0
	while frames < timeout_frames and not _vt.is_area_editable(box):
		await get_tree().process_frame
		frames += 1
	return _vt.is_area_editable(box)

func _do_box_safe(a_min: Vector3i, a_max: Vector3i) -> void:
	if await _wait_area_editable(a_min, a_max):
		_vt.do_box(a_min, a_max)
	else:
		push_warning("Box edit skipped: area not editable after waiting. Increase viewer view_distance or move edits closer.")

func _do_sphere_safe(center: Vector3i, radius: int) -> void:
	# Build an AABB that bounds the sphere for the editability test
	var r := Vector3i(radius, radius, radius)
	var a_min := center - r
	var a_max := center + r
	if await _wait_area_editable(a_min, a_max):
		_vt.do_sphere(center, radius)
	else:
		push_warning("Sphere edit skipped: area not editable after waiting. Increase viewer view_distance or move edits closer.")

func _ensure_viewer_covering_edits() -> void:
	# Find or create a VoxelViewer
	var viewer := terrain.get_node_or_null("../VoxelViewer")
	if viewer == null:
		viewer = VoxelViewer.new()
		viewer.name = "VoxelViewer"
		# attach near the player if present, else under terrain's parent
		if player:
			player.add_child(viewer)
		else:
			terrain.get_parent().add_child(viewer)
	# Place the viewer between your static/dynamic sets and above the ground
	viewer.global_position = Vector3(0, 12, 0)

	# Make sure the view distance is large enough to *cover your edit AABBs*
	# This value is in world units for loading priority; bigger = more blocks get loaded.
	# Try 200–300; increase if you still see "Area not editable".
	if not viewer.has_method("set_view_distance") and "view_distance" in viewer:
		# Older builds expose it as a property
		viewer.view_distance = 300
	else:
		viewer.view_distance = 300
		
func _build_ground_safe() -> void:
	var a := Vector3i(-GROUND_HALF.x, -1, -GROUND_HALF.z)
	var b := Vector3i(GROUND_HALF.x, 0, GROUND_HALF.z)
	await _do_box_safe(a, b)

func _stamp_static_voxel_shapes_safe() -> void:
	await _do_sphere_safe(STATIC_BASE + Vector3i(-12, 0, 0), VOX_SPHERE_RADIUS)

	var c_center := STATIC_BASE + Vector3i(0, 0, 0)
	await _do_box_safe(c_center - VOX_CUBE_HALF, c_center + VOX_CUBE_HALF)

	var r_center := STATIC_BASE + Vector3i(12, 0, 0)
	await _do_box_safe(r_center - VOX_RECT_HALF, r_center + VOX_RECT_HALF)
	
func _get_tool():
	var vt = terrain.get_voxel_tool()
	# we’re editing TYPE indices for blocky voxels
	vt.mode = VoxelTool.MODE_SET
	vt.channel = VoxelBuffer.CHANNEL_TYPE
	vt.value = SOLID
	return vt

func _build_ground() -> void:
	# Big, thin box centered around y = 0
	var vt = _get_tool()
	var a := Vector3i(-GROUND_HALF.x, -1, -GROUND_HALF.z)
	var b := Vector3i( GROUND_HALF.x,  0,  GROUND_HALF.z)
	vt.do_box(a, b)

func _stamp_static_voxel_shapes() -> void:
	var vt = _get_tool()

	# Sphere
	vt.do_sphere(STATIC_BASE + Vector3i(-12, 0, 0), VOX_SPHERE_RADIUS)

	# Cube
	var c_center := STATIC_BASE + Vector3i(0, 0, 0)
	vt.do_box(c_center - VOX_CUBE_HALF, c_center + VOX_CUBE_HALF)

	# Rectangular prism
	var r_center := STATIC_BASE + Vector3i(12, 0, 0)
	vt.do_box(r_center - VOX_RECT_HALF, r_center + VOX_RECT_HALF)

func _spawn_dynamic_falling_shapes() -> void:
	# Sizes in *world units*. If you scaled your Terrain down to get micro-voxels,
	# leave these shapes unscaled so they look like “chunky voxel props” that fall.
	_spawn_box(DYNAMIC_BASE + Vector3(-12, 0, 0), Vector3.ONE * (VOX_SPHERE_RADIUS * 2.0)) # cube-ish match
	_spawn_sphere(DYNAMIC_BASE + Vector3(  0, 0, 0), float(VOX_SPHERE_RADIUS))
	_spawn_box(DYNAMIC_BASE + Vector3( 12, 0, 0), Vector3(VOX_RECT_HALF.x*2.0, VOX_RECT_HALF.y*2.0, VOX_RECT_HALF.z*2.0))

func _spawn_box(pos: Vector3, size: Vector3) -> void:
	var body := RigidBody3D.new()
	body.transform.origin = pos

	# Physics material lives on the body (or on shapes)
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 0.0
	body.physics_material_override = pm
	add_child(body)

	# Visual
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	body.add_child(mesh)

	# Collision
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)


func _spawn_sphere(pos: Vector3, radius: float) -> void:
	var body := RigidBody3D.new()
	body.transform.origin = pos

	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 0.0
	body.physics_material_override = pm
	add_child(body)

	# Visual
	var mesh := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius            # (no "height" on SphereMesh)
	mesh.mesh = s
	body.add_child(mesh)

	# Collision
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	col.shape = shape
	body.add_child(col)
