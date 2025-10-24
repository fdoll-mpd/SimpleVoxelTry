extends Node3D

@export var default_place_block_id: int = 1
@export var max_place_distance: float = 64.0
@onready var terrain: VoxelTerrain = $VoxelTerrain

var _vt: VoxelTool = null
var _hud: Label


func _get_tool() -> VoxelTool:
	# Cache the tool — getting it every time is a little slower.
	if _vt == null:
		_vt = terrain.get_voxel_tool()
	return _vt

func world_to_voxel(world_pos: Vector3) -> Vector3i:
	var local := terrain.to_local(world_pos)  # world -> terrain local
	return Vector3i(floor(local.x), floor(local.y), floor(local.z))

# Convert voxel coords (terrain-local) to world space.
func voxel_to_world(voxel_pos: Vector3) -> Vector3:
	return terrain.to_global(voxel_pos)       # terrain local -> world
# =========================
# BLOCKY (VoxelMesherBlocky)
# =========================
# Places a solid rectangular cuboid of a given block ID.
# begin/end are INCLUSIVE (e.g., size = end - begin + 1)
func place_blocky_box(begin: Vector3i, end: Vector3i, voxel_id: int) -> void:
	var vt := _get_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE
	vt.mode = VoxelTool.MODE_SET
	vt.value = voxel_id
	vt.set_voxel(begin, 1)
	vt.set_voxel(end, 1)
	vt.do_box(begin, end) # inclusive on blocky terrains

# Convenience: place a cube by center+edge length
func place_blocky_cube(center: Vector3i, edge: int, voxel_id: int) -> void:
	var half := edge / 2
	var begin := Vector3i(center.x - half, center.y - half, center.z - half)
	var end   := Vector3i(center.x + (edge - 1 - half), center.y + (edge - 1 - half), center.z + (edge - 1 - half))
	place_blocky_box(begin, end, voxel_id)

# Places a filled blocky sphere of a given block ID (approximate sphere).
func place_blocky_sphere(center: Vector3, radius: float, voxel_id: int) -> void:
	var vt := _get_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE
	vt.mode = VoxelTool.MODE_SET
	vt.value = voxel_id
	vt.do_sphere(center, radius)


# =========================
# SMOOTH / SDF (Transvoxel)
# =========================
# Adds or removes SDF "matter" in a rectangular region.
# begin/end are HALF-OPEN: end is EXCLUSIVE (API requirement for SDF)
func place_sdf_box(begin: Vector3i, end_exclusive: Vector3i, add: bool = true) -> void:
	var vt := _get_tool()
	vt.channel = VoxelBuffer.CHANNEL_SDF
	#vt.mode = add ? VoxelTool.MODE_ADD : VoxelTool.MODE_REMOVE
	if add:
		vt.mode = VoxelTool.MODE_ADD
	else:
		vt.mode = VoxelTool.MODE_REMOVE
	vt.do_box(begin, end_exclusive) # end is exclusive for SDF

# Adds/removes a smooth SDF sphere (perfect for round blobs or carving holes).
func place_sdf_sphere(center: Vector3, radius: float, add: bool = true) -> void:
	var vt := _get_tool()
	vt.channel = VoxelBuffer.CHANNEL_SDF
	#vt.mode = add ? VoxelTool.MODE_ADD : VoxelTool.MODE_REMOVE
	if add:
		vt.mode = VoxelTool.MODE_ADD
	else:
		vt.mode = VoxelTool.MODE_REMOVE
	vt.do_sphere(center, radius)


# =========================
# EXAMPLES
# =========================
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	terrain.scale = Vector3(0.1, 0.1, 0.1)
	

	# Example blocky placements (IDs depend on your VoxelLibrary setup):
	# 1) Cube: 8x8x8 of voxel_id=1 centered at (0, 8, 0)
	place_blocky_cube(Vector3i(0, 8, 0), 8, 1)

	# 2) Rectangle (e.g., 12 x 4 x 6) with voxel_id=2, starting at (-6, 2, -3)
	place_blocky_box(Vector3i(-6, 2, -3), Vector3i(5, 5, 2), 2) # inclusive end

	# 3) Sphere: radius 6 of voxel_id=3 at (16, 10, 0)
	place_blocky_sphere(Vector3(16, 10, 0), 6.0, 3)

	# Example smooth/SDF placements (uncomment if using Transvoxel/Marching):
	# Adds a smooth box "blob"
	# place_sdf_box(Vector3i(-8, 4, -8), Vector3i(8, 12, 8), true)
	# Carves a smooth spherical hole
	# place_sdf_sphere(Vector3(0, 6, 16), 5.5, false)
	_setup_limits_hud()
	_make_debug_ground_plane()


func _setup_limits_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	_hud = Label.new()
	_hud.name = "VoxelLimitsHUD"
	_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud.size_flags_vertical = Control.SIZE_FILL
	_hud.position = Vector2(8, 8)
	_hud.add_theme_color_override("font_color", Color(1,1,1,1))
	_hud.add_theme_font_size_override("font_size", 14)
	#cl.add_child(_hud)
	terrain.debug_set_draw_flag(VoxelTerrain.DEBUG_DRAW_VOLUME_BOUNDS, true)
		
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _make_debug_ground_plane(
		size := 512.0,
		plane_color := Color(0.10, 0.45, 0.85, 1.0),   # nice blue
		outline_color := Color(1.0, 1.0, 1.0, 1.0)
	) -> void:
	var plane_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane_mi.mesh = plane
	#plane_mi.rotate_x(-PI / 2.0)
	plane_mi.position = Vector3(0, 0, 0)
	plane_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = plane_color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED            # <— draw both sides
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED  # <— force opaque
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	plane_mi.material_override = m
	add_child(plane_mi)

	# --- Outline as a thin line loop slightly above the plane ---
	# We'll build a simple line strip rectangle using SurfaceTool.
	var half := size * 0.5
	var y := 0.02  # small offset to prevent z-fighting with the plane
	var corners := [
		Vector3(-half, y, -half),
		Vector3( half, y, -half),
		Vector3( half, y,  half),
		Vector3(-half, y,  half),
		Vector3(-half, y, -half) # close the loop
	]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	st.set_color(outline_color)
	for c in corners:
		st.add_vertex(c)
	var outline_mesh := st.commit()

	var outline_mi := MeshInstance3D.new()
	outline_mi.mesh = outline_mesh
	outline_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Unshaded material for crisp lines
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = outline_color
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	outline_mi.material_override = lm

	add_child(outline_mi)

	# --- Static collider so physics bodies can land on it ---
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 0.2, size)
	col.shape = box
	sb.add_child(col)
	add_child(sb)


func draw_local_grid(cell: int = 1, half_extent: int = 16) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for x in range(-half_extent, half_extent + 1, cell):
		for z in [-half_extent, half_extent]:
			st.add_vertex(terrain.to_global(Vector3(x, 0, -half_extent)))
			st.add_vertex(terrain.to_global(Vector3(x, 0,  half_extent)))
	for z in range(-half_extent, half_extent + 1, cell):
		for x in [-half_extent, half_extent]:
			st.add_vertex(terrain.to_global(Vector3(-half_extent, 0, z)))
			st.add_vertex(terrain.to_global(Vector3( half_extent, 0, z)))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _process(_dt: float) -> void:
	_update_limits_hud()

func _update_limits_hud() -> void:
	var vt := _get_tool()

	# 1) Terrain bounds (terrain-local)
	var b := terrain.bounds
	var b_min := b.position
	var b_max := b.position + b.size

	# 2) Find all viewers
	var viewers: Array = []
	for n in get_tree().get_nodes_in_group("VoxelViewers"):
		if n is VoxelViewer:
			viewers.append(n)
	# Fallback: if you didn’t group them, search the whole tree (costly but fine for debug)
	if viewers.is_empty():
		for n in get_tree().get_nodes_in_group("**"):
			if n is VoxelViewer:
				viewers.append(n)

	# 3) Build text
	var sb := ""
	sb += "=== VoxelTool / Terrain Limits (terrain-local units) ===\n"
	sb += "Terrain.bounds:\n"
	sb += "  min: (%.1f, %.1f, %.1f)\n" % [b_min.x, b_min.y, b_min.z]
	sb += "  max: (%.1f, %.1f, %.1f)\n" % [b_max.x, b_max.y, b_max.z]
	sb += "  size: (%.1f, %.1f, %.1f)\n" % [b.size.x, b.size.y, b.size.z]

	# 4) Viewers and their load AABBs (terrain-local)
	for v in viewers:
		var center_local := terrain.to_local(v.global_transform.origin)
		var h := float(v.view_distance)
		var vr := float(v.view_distance_vertical_ratio)
		var v_rad := h * vr
		var v_aabb := AABB(
			center_local - Vector3(h, v_rad, h),
			Vector3(h*2.0, v_rad*2.0, h*2.0)
		)

		# Intersection of viewer AABB and terrain bounds (approx editable region)
		var i_min := v_aabb.position.max(b.position)   # component-wise max
		var i_max := (v_aabb.position + v_aabb.size).min(b.position + b.size)
		var i_size := (i_max - i_min).max(Vector3(0,0,0)) # clamp negatives to 0
		var has_intersection := i_size.x > 0.0 and i_size.y > 0.0 and i_size.z > 0.0

		sb += "\nViewer @ %s\n" % str(v.name)
		sb += "  center_local: (%.1f, %.1f, %.1f)\n" % [center_local.x, center_local.y, center_local.z]
		sb += "  view_distance: %d  vertical_ratio: %.2f\n" % [v.view_distance, v.view_distance_vertical_ratio]
		sb += "  load AABB:\n"
		sb += "    min: (%.1f, %.1f, %.1f)\n" % [v_aabb.position.x, v_aabb.position.y, v_aabb.position.z]
		sb += "    max: (%.1f, %.1f, %.1f)\n" % [(v_aabb.position+v_aabb.size).x, (v_aabb.position+v_aabb.size).y, (v_aabb.position+v_aabb.size).z]
		if has_intersection:
			sb += "  intersect bounds: %s\n" % ("YES")
		else:
			sb += "  intersect bounds: %s\n" % ("NO")
		if has_intersection:
			sb += "    i.min: (%.1f, %.1f, %.1f)\n" % [i_min.x, i_min.y, i_min.z]
			sb += "    i.max: (%.1f, %.1f, %.1f)\n" % [i_max.x, i_max.y, i_max.z]
			sb += "    i.size: (%.1f, %.1f, %.1f)\n" % [i_size.x, i_size.y, i_size.z]

	# 5) Live “is this area editable?” probe around origin (10×10×10)
	var probe := AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	var editable := vt.is_area_editable(probe)
	if editable:
		sb += "\nProbe is_area_editable([-5..5]^3 around origin): %s\n" % ("true")
	else:
		sb += "\nProbe is_area_editable([-5..5]^3 around origin): %s\n" % ("false")
	#sb += "\nProbe is_area_editable([-5..5]^3 around origin): %s\n" % (editable ? "true" : "false")

	_hud.text = sb
	
func place_one_block_from_ray(world_origin: Vector3, world_dir: Vector3, block_id: int = -1, max_dist: float = -1.0) -> bool:
	var vt := _get_tool()
	if vt == null:
		print("Could not get voxel tool")
		return false

	if block_id < 0:
		block_id = default_place_block_id
	if max_dist <= 0.0:
		max_dist = max_place_distance

	vt.set_raycast_normal_enabled(true)

	# 1) Try voxel raycast first (world space)
	var dir := world_dir.normalized()
	var hit := vt.raycast(world_origin, dir, max_dist)
	if hit != null:
		var target := Vector3i(hit.position) + Vector3i(hit.normal)
		if not vt.is_area_editable(AABB(Vector3(target), Vector3.ONE)):
			print("Got a hit but failed area editable check")
			return false
		vt.channel = VoxelBuffer.CHANNEL_TYPE
		vt.mode = VoxelTool.MODE_SET
		vt.value = block_id
		vt.do_point(target)
		return true

	# 2) Fallback: treat plane x = 1 as a hit if we cross it within max_dist
	# Solve world_origin.x + dir.x * t = 1  =>  t = (1 - origin.x) / dir.x
	var dir_local: Vector3 = terrain.global_transform.basis.inverse() * dir
	var origin_local: Vector3 = terrain.to_local(world_origin)

	# Solve origin_local.x + dir_local.x * t = 1
	if abs(dir_local.x) < 1e-5:
		return false
	var t := (1.0 - origin_local.x) / dir_local.x
	if t < 0.0 or t > max_dist:
		return false
	var p_local: Vector3 = origin_local + dir_local * t
	var p_world: Vector3 = terrain.to_global(p_local)
	#var p_local := terrain.to_local(p_world)

	# Base voxel at (floored) local position
	var base := Vector3i(floor(p_local.x), floor(p_local.y), floor(p_local.z))

	# Use the ray direction in TERRAIN-LOCAL space to choose the face normal
	#var dir_local := terrain.global_transform.basis.inverse() * dir
	var normal := Vector3i(1, 0, 0)
	if dir_local.x < 0.0:
		normal.x = -1

	var target := base + normal

	# Editable check (prevents "Area not editable")
	if not vt.is_area_editable(AABB(Vector3(target), Vector3.ONE)):
		print("Failed area editable check")
		return false

	# Place one block
	vt.channel = VoxelBuffer.CHANNEL_TYPE
	vt.mode = VoxelTool.MODE_SET
	vt.value = block_id
	vt.do_point(target)
	return true



# Convenience: place/replace exactly the voxel you hit (no +normal)
func paint_hit_block_from_ray(world_origin: Vector3, world_dir: Vector3, block_id: int = -1, max_dist: float = -1.0) -> bool:
	var vt := _get_tool()
	if vt == null:
		return false
	if block_id < 0:
		block_id = default_place_block_id
	if max_dist <= 0.0:
		max_dist = max_place_distance

	vt.set_raycast_normal_enabled(false) # we don't need the face here
	var hit := vt.raycast(world_origin, world_dir.normalized(), max_dist)
	if hit == null:
		return false

	var target: Vector3i = hit.position

	var editable := vt.is_area_editable(AABB(Vector3(target), Vector3.ONE))
	if not editable:
		return false

	vt.channel = VoxelBuffer.CHANNEL_TYPE
	vt.mode = VoxelTool.MODE_SET
	vt.value = block_id
	vt.do_point(target)
	return true
