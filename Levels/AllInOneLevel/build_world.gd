extends Node3D

@export var default_place_block_id: int = 1
@export var max_place_distance: float = 64.0
@onready var terrain: VoxelTerrain = $VoxelTerrain
@onready var _characters_container : Node = $Players

@export var use_voxel_relative_distances: bool = true
@export var max_place_distance_voxels: int = 64

func world_to_voxel(world_pos: Vector3) -> Vector3i:
	var local := terrain.to_local(world_pos)
	return Vector3i(floor(local.x), floor(local.y), floor(local.z))

func voxel_to_world(voxel_pos: Vector3) -> Vector3:
	return terrain.to_global(voxel_pos)

# Size of one voxel in world units (assumes uniform scale).
func voxel_size_world() -> float:
	var s := terrain.global_transform.basis.get_scale().abs()
	if absf(s.x - s.y) > 0.0001 or absf(s.x - s.z) > 0.0001:
		push_warning("VoxelTerrain is non-uniformly scaled; using X component: %f" % s.x)
	return s.x
	
var _vt: VoxelTool = null
var _hud: Label
const CharacterScene = preload("res://Entities/Player/TestCharacter.tscn")

func _get_tool() -> VoxelTool:
	# Cache the tool – getting it every time is a little slower.
	if _vt == null:
		_vt = terrain.get_voxel_tool()
	return _vt

#func world_to_voxel(world_pos: Vector3) -> Vector3i:
	#var local := terrain.to_local(world_pos)  # world -> terrain local
	#return Vector3i(floor(local.x), floor(local.y), floor(local.z))
#
## Convert voxel coords (terrain-local) to world space.
#func voxel_to_world(voxel_pos: Vector3) -> Vector3:
	#return terrain.to_global(voxel_pos)

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
	if add:
		vt.mode = VoxelTool.MODE_ADD
	else:
		vt.mode = VoxelTool.MODE_REMOVE
	vt.do_box(begin, end_exclusive) # end is exclusive for SDF

# Adds/removes a smooth SDF sphere (perfect for round blobs or carving holes).
func place_sdf_sphere(center: Vector3, radius: float, add: bool = true) -> void:
	var vt := _get_tool()
	vt.channel = VoxelBuffer.CHANNEL_SDF
	if add:
		vt.mode = VoxelTool.MODE_ADD
	else:
		vt.mode = VoxelTool.MODE_REMOVE
	vt.do_sphere(center, radius)

func make_voxel_plane(corner: Vector3 = Vector3(-20, 3, -20), side: int=50, voxel_id: int = 2):
	var vt: VoxelTool = _get_tool()
	var corner_v := world_to_voxel(corner)
	for x_side in side:
		for z_side in side:
			var base := Vector3i(floor(corner.x + x_side), floor(corner.y), floor(corner.z + z_side))
			var target := base + Vector3i(0, 1, 0)

			# Editable check (prevents "Area not editable")
			if not vt.is_area_editable(AABB(Vector3(target), Vector3.ONE)):
				print("Failed make voxel plane editable check")
				return false
			
			vt.channel = VoxelBuffer.CHANNEL_TYPE
			vt.mode = VoxelTool.MODE_ADD
			vt.value = voxel_id
			vt.do_point(target)

# =========================
# EXAMPLES
# =========================
func _ready() -> void:
	print("Build World scale", terrain.global_transform.basis.get_scale().abs())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	make_voxel_plane(Vector3(-20, 3, -20), 50, 2)

	# Example blocky placements (IDs depend on your VoxelLibrary setup):
	# 1) Cube: 8x8x8 of voxel_id=1 centered at (0, 8, 0)
	#place_blocky_cube(Vector3i(0, 8, 0), 8, 1)
#
	## 2) Rectangle (e.g., 12 x 4 x 6) with voxel_id=2, starting at (-6, 2, -3)
	#place_blocky_box(Vector3i(-6, 2, -3), Vector3i(5, 5, 2), 2) # inclusive end
#
	## 3) Sphere: radius 6 of voxel_id=3 at (16, 10, 0)
	#place_blocky_sphere(Vector3(16, 10, 0), 6.0, 3)

	_setup_limits_hud()
	print("Bounds: ", terrain.bounds)
	#_make_debug_ground_plane()
	
func get_terrain() -> VoxelTerrain:
	return terrain
	
func _spawn_character(peer_id: int, pos: Vector3) -> Node3D:
	var node_name = str(peer_id)
	if _characters_container.has_node(node_name):
		#_logger.error(str("Character ", peer_id, " already created"))
		return null
	var character : Node3D = CharacterScene.instantiate()
	character.name = node_name
	character.position = pos
	character.voxel_terrain_path = get_terrain().get_path()
	_characters_container.add_child(character)
	return character

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
	plane_mi.position = Vector3(0, -1, 0)
	plane_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = plane_color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	plane_mi.material_override = m
	add_child(plane_mi)

	# --- Outline as a thin line loop slightly above the plane ---
	var half := size * 0.5
	var y := -1.02  # small offset to prevent z-fighting with the plane
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
	
	print_world_limits_summary(global_transform.origin, 200000, 2)



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

	# 3) Build text
	var sb := ""
	sb += "=== VoxelTool / Terrain Limits (terrain-local units) ===\n"
	sb += "Terrain.bounds:\n"
	sb += "  min: (%.1f, %.1f, %.1f)\n" % [b_min.x, b_min.y, b_min.z]
	sb += "  max: (%.1f, %.1f, %.1f)\n" % [b_max.x, b_max.y, b_max.z]
	sb += "  size: (%.1f, %.1f, %.1f)\n" % [b.size.x, b.size.y, b.size.z]


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
		var i_min := v_aabb.position.max(b.position)
		var i_max := (v_aabb.position + v_aabb.size).min(b.position + b.size)
		var i_size := (i_max - i_min).max(Vector3(0,0,0))
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

	# 5) Live "is this area editable?" probe around origin (10×10×10)
	var probe := AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	var editable := vt.is_area_editable(probe)
	if editable:
		sb += "\nProbe is_area_editable([-5..5]^3 around origin): %s\n" % ("true")
	else:
		sb += "\nProbe is_area_editable([-5..5]^3 around origin): %s\n" % ("false")

	_hud.text = sb

# =========================
# IMPROVED BLOCK PLACEMENT
# =========================

# Place a single block using proper raycast - NO FALLBACK
func place_one_block_from_ray(world_origin: Vector3, world_dir: Vector3, block_id: int = -1, max_dist: float = -1.0, placing: bool = true) -> bool:
	var vt := _get_tool()
	if vt == null:
		print("Could not get voxel tool")
		return false

	if block_id < 0:
		block_id = default_place_block_id
	if max_dist <= 0.0:
		#max_dist = max_place_distance
		var _vox_size := voxel_size_world()
		max_dist = (float(max_place_distance_voxels) * _vox_size if use_voxel_relative_distances else max_place_distance)
	
	vt.set_raycast_normal_enabled(true)

	# Raycast to find a voxel hit
	var dir := world_dir.normalized()
	var hit := vt.raycast(world_origin, dir, max_dist)
	
	if hit == null:
		# No hit - don't place anything
		return false
	
	# Place block adjacent to the hit surface (using the normal)
	#var target := Vector3i(hit.position) + Vector3i(hit.normal)
	#
	## Check if area is editable
	#if not vt.is_area_editable(AABB(Vector3(target), Vector3.ONE)):
		#print("Target position not editable")
		#return false
	#
	## Place the block
	#vt.channel = VoxelBuffer.CHANNEL_TYPE
	#vt.mode = VoxelTool.MODE_ADD
	#vt.value = block_id
	#vt.do_point(target)
	#return true
	var hit_pos: Vector3i = hit.position
	var n := hit.normal               # Vector3 (e.g. (-0.999, 0, 0))
	var step := Vector3i(
		_axis_step(n.x),
		_axis_step(n.y),
		_axis_step(n.z)
	)
	
	var place_pos: Vector3i = hit_pos + step

	# Debug info: which voxel, which face/normal, and where we’ll place
	print("HIT pos=", hit_pos, 
		  " face=", _face_name(n), 
		  " normal=", n, 
		  " step=", step, 
		  " PLACE pos=", place_pos)

	# (optional) bounds/editability check around the place position
	if not vt.is_area_editable(AABB(Vector3(place_pos), Vector3.ONE)):
		return false
	
	vt.mode = VoxelTool.MODE_SET
	vt.channel = VoxelBuffer.CHANNEL_TYPE
	if placing:
		vt.value = block_id
		vt.do_point(place_pos)
	else:
		vt.value = 0
		vt.do_point(hit_pos)
		
	return true

func _axis_step(n: float) -> int:
	if n > 0.05:
		return 1
	elif n < -0.05:
		return -1
	return 0

# Human-readable face name for debugging
func _face_name(n: Vector3) -> String:
	var ax := absf(n.x)
	var ay := absf(n.y)
	var az := absf(n.z)

	if ax > ay and ax > az:
		if n.x > 0.0:
			return "POS_X (+X/right)"
		else:
			return "NEG_X (-X/left)"
	elif ay > ax and ay > az:
		if n.y > 0.0:
			return "POS_Y (+Y/top)"
		else:
			return "NEG_Y (-Y/bottom)"
	else:
		if n.z > 0.0:
			return "POS_Z (+Z/front)"
		else:
			return "NEG_Z (-Z/back)"
			
# Place a structure (cube, box, or sphere) from raycast hit point
func place_structure_from_ray(world_origin: Vector3, world_dir: Vector3, structure_type: String, block_id: int = -1, max_dist: float = -1.0) -> bool:
	var vt := _get_tool()
	if vt == null:
		print("Could not get voxel tool")
		return false

	if block_id < 0:
		block_id = default_place_block_id
	if max_dist <= 0.0:
		#max_dist = max_place_distance
		var _vox_size := voxel_size_world()
		max_dist = (float(max_place_distance_voxels) * _vox_size if use_voxel_relative_distances else max_place_distance)

	
	vt.set_raycast_normal_enabled(true)

	# Raycast to find placement location
	var dir := world_dir.normalized()
	var hit := vt.raycast(world_origin, dir, max_dist)
	
	if hit == null:
		print("No hit for structure placement")
		return false
	
	# Calculate center point for structure (offset from hit surface)
	var hit_pos := Vector3i(hit.position)
	var normal := Vector3i(hit.normal)
	
	# Place structure based on type
	match structure_type:
		"cube_3x3x3":
			# Place a 3x3x3 cube
			var center := hit_pos + normal * 2  # Offset by 2 to clear the surface
			var half := 1  # 3/2 = 1 (integer division)
			var begin := Vector3i(center.x - half, center.y - half, center.z - half)
			var end := Vector3i(center.x + half, center.y + half, center.z + half)
			
			# Check if area is editable
			var check_size := Vector3(3, 3, 3)
			if not vt.is_area_editable(AABB(Vector3(begin), check_size)):
				print("Cube placement area not editable")
				return false
			
			place_blocky_box(begin, end, block_id)
			return true
			
		"box_4x4x8":
			# Place a 4x4x8 rectangular prism (tall)
			var center := hit_pos + normal * 4  # Offset by 4 to clear the surface
			var begin := Vector3i(center.x - 2, center.y - 2, center.z - 2)
			var end := Vector3i(center.x + 1, center.y + 5, center.z + 1)
			
			# Check if area is editable
			var check_size := Vector3(4, 8, 4)
			if not vt.is_area_editable(AABB(Vector3(begin), check_size)):
				print("Box placement area not editable")
				return false
			
			place_blocky_box(begin, end, block_id)
			return true
			
		"sphere_r4":
			# Place a sphere with radius 4
			var center := Vector3(hit_pos) + Vector3(normal) * 5.0  # Offset by 5 to clear the surface
			var radius := 4.0
			
			# Check if area is editable (approximate bounding box)
			var check_begin := center - Vector3.ONE * radius
			var check_size := Vector3.ONE * (radius * 2)
			if not vt.is_area_editable(AABB(check_begin, check_size)):
				print("Sphere placement area not editable")
				return false
			
			place_blocky_sphere(center, radius, block_id)
			return true
	
	print("Unknown structure type: ", structure_type)
	return false

# Place a structure at a specific world position (no raycast needed)
func place_structure_at_position(world_pos: Vector3, structure_type: String, block_id: int = -1, offset_up: float = 5.0) -> bool:
	var vt := _get_tool()
	if vt == null:
		print("Could not get voxel tool")
		return false

	if block_id < 0:
		block_id = default_place_block_id
	
	# Convert world position to terrain local space
	print("Trying to place at", world_pos)
	var local_pos := terrain.to_local(world_pos)
	var base_pos := Vector3i(floor(local_pos.x), floor(local_pos.y), floor(local_pos.z))
	
	# Apply upward offset
	var center := base_pos + Vector3i(0, int(offset_up), 0)
	
	# Place structure based on type
	match structure_type:
		"cube_3x3x3":
			var half := 1
			var begin := Vector3i(center.x - half, center.y - half, center.z - half)
			var end := Vector3i(center.x + half, center.y + half, center.z + half)
			
			var check_size := Vector3(3, 3, 3)
			if not vt.is_area_editable(AABB(Vector3(begin), check_size)):
				print("Cube placement area not editable")
				return false
			place_blocky_box(begin, end, block_id)
			print("Placed structure at ", begin, " to ", end)
			print_world_limits_summary(global_transform.origin, 200000, 2)

			return true
			
		"box_4x4x8":
			var begin := Vector3i(center.x - 2, center.y - 2, center.z - 2)
			var end := Vector3i(center.x + 1, center.y + 5, center.z + 1)
			
			var check_size := Vector3(4, 8, 4)
			if not vt.is_area_editable(AABB(Vector3(begin), check_size)):
				print("Box placement area not editable")
				return false
			place_blocky_box(begin, end, block_id)
			print("Placed structure at ", begin, " to ", end)
			print_world_limits_summary(global_transform.origin, 200000, 2)

			return true
			
		"sphere_r4":
			var radius := 4.0
			var sphere_center := Vector3(center)
			
			var check_begin := sphere_center - Vector3.ONE * radius
			var check_size := Vector3.ONE * (radius * 2)
			if not vt.is_area_editable(AABB(check_begin, check_size)):
				print("Sphere placement area not editable")
				return false
			
			
			place_blocky_sphere(sphere_center, radius, block_id)
			print("Placed structure at ", sphere_center, " with radius of ", radius)
			print_world_limits_summary(global_transform.origin, 200000, 2)

			return true
		
		"platform_10x10":
			# Create a flat 10x10 platform
			var half := 5
			var begin := Vector3i(center.x - half, center.y, center.z - half)
			var end := Vector3i(center.x + half - 1, center.y, center.z + half - 1)
			
			var check_size := Vector3(10, 1, 10)
			if not vt.is_area_editable(AABB(Vector3(begin), check_size)):
				print("Platform placement area not editable")
				return false
			
			print("Placed structure at ", begin, " to ", end)
			place_blocky_box(begin, end, block_id)
			print_world_limits_summary(global_transform.origin, 200000, 2)

			return true
	
	print("Unknown structure type: ", structure_type)
	return false

# Convenience: paint/replace exactly the voxel you hit (no +normal)
func paint_hit_block_from_ray(world_origin: Vector3, world_dir: Vector3, block_id: int = -1, max_dist: float = -1.0) -> bool:
	var vt := _get_tool()
	if vt == null:
		return false
	if block_id < 0:
		block_id = default_place_block_id
	if max_dist <= 0.0:
		#max_dist = max_place_distance
		var _vox_size := voxel_size_world()
		max_dist = (float(max_place_distance_voxels) * _vox_size if use_voxel_relative_distances else max_place_distance)


	vt.set_raycast_normal_enabled(false)
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


func try_place_then_air(p: Vector3i, block_id: int = 2) -> bool:
	var vt: VoxelTool = _get_tool()
	if not is_voxel_editable(p):
		return false
	vt.channel = VoxelBuffer.CHANNEL_TYPE
	vt.mode = VoxelTool.MODE_ADD
	vt.value = block_id
	vt.do_point(p)
	vt.value = 0
	vt.do_point(p)
	return true
		

func is_voxel_editable(p: Vector3i) -> bool:
	var vt: VoxelTool = _get_tool()
	return vt.is_area_editable(AABB(Vector3(p), Vector3.ONE))

func probe_limit_along_axis(start_v: Vector3i, axis: Vector3i, max_steps: int = 100000, test_block_id: int = 2) -> Dictionary:
	var vt: VoxelTool = _get_tool()
	var last_ok := start_v
	var steps := 0
	var p := start_v
	while steps < max_steps:
		p += axis
		if not vt.is_area_editable(AABB(Vector3(p), Vector3.ONE)):
			break
		# write + revert (verifies we can actually touch the voxel)
		vt.channel = VoxelBuffer.CHANNEL_TYPE
		vt.mode = VoxelTool.MODE_ADD
		vt.value = test_block_id
		vt.do_point(p)
		vt.value = 0
		vt.do_point(p)
		last_ok = p
		steps += 1
	var reason := "non_editable" if steps < max_steps else "max_steps"
	return {"last_ok": last_ok, "steps": steps, "reason": reason}

func test_world_limits(start_world: Vector3 = Vector3.ZERO, max_steps: int = 100000, test_block_id: int = 2) -> Dictionary:
	var start_v := world_to_voxel(start_world)
	var results := {
		"+X": probe_limit_along_axis(start_v, Vector3i(1, 0, 0), max_steps, test_block_id),
		"-X": probe_limit_along_axis(start_v, Vector3i(-1, 0, 0), max_steps, test_block_id),
		"+Y": probe_limit_along_axis(start_v, Vector3i(0, 1, 0), max_steps, test_block_id),
		"-Y": probe_limit_along_axis(start_v, Vector3i(0, -1, 0), max_steps, test_block_id),
		"+Z": probe_limit_along_axis(start_v, Vector3i(0, 0, 1), max_steps, test_block_id),
		"-Z": probe_limit_along_axis(start_v, Vector3i(0, 0, -1), max_steps, test_block_id),
	}
	if has_method("voxel_to_world"):
		for k in results.keys():
			var v: Vector3i = results[k]["last_ok"]
			results[k]["last_ok_world"] = voxel_to_world(v)
	return results

func print_world_limits_summary(start_world: Vector3 = Vector3.ZERO, max_steps: int = 100000, test_block_id: int = 2) -> void:
	var r := test_world_limits(start_world, max_steps, test_block_id)
	print("--- World Limits from ", start_world, " ---")
	for k in ["+X","-X","+Y","-Y","+Z","-Z"]:
		var e = r[k]
		var v = e["last_ok"]
		var w = (e["last_ok_world"] if e.has("last_ok_world") else null)
		print("%s  steps=%d  last_ok_voxel=%s%s  reason=%s" % [
			k, int(e["steps"]), str(v),
			("  last_ok_world=%s" % str(w) if w != null else ""),
			str(e["reason"]),
		])
	#draw_world_border_box()
#
#const _WORLD_BORDER_NODE_NAME := "WorldBorderViz"
#
## Remove existing border viz node (if any)
#func _clear_world_border_viz() -> void:
	#var old := get_node_or_null(_WORLD_BORDER_NODE_NAME)
	#if old:
		#old.queue_free()
#
## Build a transparent fill box material
#func _make_transparent_fill_material(color: Color = Color(0.2, 0.6, 1.0, 0.12)) -> StandardMaterial3D:
	#var m := StandardMaterial3D.new()
	#m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	#m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	#m.albedo_color = color
	#m.cull_mode = BaseMaterial3D.CULL_BACK
	#m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	#return m
#
## Build a line material for edges
#func _make_line_material(color: Color = Color(0.2, 0.6, 1.0, 0.9)) -> StandardMaterial3D:
	#var m := StandardMaterial3D.new()
	#m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	#m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	#m.albedo_color = color
	#m.cull_mode = BaseMaterial3D.CULL_DISABLED
	#m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	#return m
#
## Utility: convert voxel->world using helper if present, otherwise terrain transform
#func _v2w(v: Vector3) -> Vector3:
	#if has_method("voxel_to_world"):
		#return voxel_to_world(v)
	#else:
		#return terrain.to_global(v)
#
## Compute a world-space AABB of editable region around start_world by probing ±X/±Y/±Z
## Returns {min_v, max_v, min_world, max_world, size_world, center_world, results}
#func compute_world_limit_aabb(start_world: Vector3 = Vector3.ZERO, max_steps: int = 200000, test_block_id: int = 2) -> Dictionary:
	#if not has_method("test_world_limits"):
		#push_error("test_world_limits() not found; add probing helpers first.")
		#return {}
	#var res := test_world_limits(start_world, max_steps, test_block_id)
#
	#var vx_min := int(res["-X"]["last_ok"].x)
	#var vx_max := int(res["+X"]["last_ok"].x)
	#var vy_min := int(res["-Y"]["last_ok"].y)
	#var vy_max := int(res["+Y"]["last_ok"].y)
	#var vz_min := int(res["-Z"]["last_ok"].z)
	#var vz_max := int(res["+Z"]["last_ok"].z)
#
	#var min_v := Vector3i(vx_min, vy_min, vz_min)
	#var max_v := Vector3i(vx_max, vy_max, vz_max)
#
	## World corners: min corner at voxel min, max corner at voxel (max+1) since voxels occupy [i, i+1)
	#var min_world := _v2w(Vector3(min_v))
	#var max_world := _v2w(Vector3(max_v + Vector3i.ONE))
	#var size_world := max_world - min_world
	#var center_world := (min_world + max_world) * 0.5
#
	#return {
		#"min_v": min_v,
		#"max_v": max_v,
		#"min_world": min_world,
		#"max_world": max_world,
		#"size_world": size_world,
		#"center_world": center_world,
		#"results": res,
	#}
#
## Create an ImmediateMesh that draws 12 edges of a box from (0,0,0) to size_world
#func _make_wire_box(size_world: Vector3, material: Material) -> Mesh:
	#var im := ImmediateMesh.new()
	#im.surface_begin(Mesh.PRIMITIVE_LINES, material)
#
	#var sx := size_world.x
	#var sy := size_world.y
	#var sz := size_world.z
#
	#var p000 := Vector3(0, 0, 0)
	#var p100 := Vector3(sx, 0, 0)
	#var p010 := Vector3(0, sy, 0)
	#var p110 := Vector3(sx, sy, 0)
	#var p001 := Vector3(0, 0, sz)
	#var p101 := Vector3(sx, 0, sz)
	#var p011 := Vector3(0, sy, sz)
	#var p111 := Vector3(sx, sy, sz)
#
	## bottom rectangle
	#im.surface_add_vertex(p000); im.surface_add_vertex(p100)
	#im.surface_add_vertex(p100); im.surface_add_vertex(p101)
	#im.surface_add_vertex(p101); im.surface_add_vertex(p001)
	#im.surface_add_vertex(p001); im.surface_add_vertex(p000)
#
	## top rectangle
	#im.surface_add_vertex(p010); im.surface_add_vertex(p110)
	#im.surface_add_vertex(p110); im.surface_add_vertex(p111)
	#im.surface_add_vertex(p111); im.surface_add_vertex(p011)
	#im.surface_add_vertex(p011); im.surface_add_vertex(p010)
#
	## verticals
	#im.surface_add_vertex(p000); im.surface_add_vertex(p010)
	#im.surface_add_vertex(p100); im.surface_add_vertex(p110)
	#im.surface_add_vertex(p101); im.surface_add_vertex(p111)
	#im.surface_add_vertex(p001); im.surface_add_vertex(p011)
#
	#im.surface_end()
	#return im
#
## Draw (or redraw) the world border from a given world start position.
## If a previous box exists, it is removed first.
#func draw_world_border_box(start_world: Vector3 = Vector3.ZERO, max_steps: int = 200000, test_block_id: int = 2, fill_color: Color = Color(0.2, 0.6, 1.0, 0.12), line_color: Color = Color(0.2, 0.6, 1.0, 0.9)) -> void:
	#_clear_world_border_viz()
	#var data := compute_world_limit_aabb(start_world, max_steps, test_block_id)
	#if data.is_empty():
		#return
#
	#var root := Node3D.new()
	#root.name = _WORLD_BORDER_NODE_NAME
	#add_child(root)
#
	#var size_world: Vector3 = data["size_world"]
	#var min_world: Vector3 = data["min_world"]
	#var center_world: Vector3 = data["center_world"]
#
	## Transparent fill box
	#var box := MeshInstance3D.new()
	#var bm := BoxMesh.new()
	#bm.size = size_world
	#box.mesh = bm
	#box.material_override = _make_transparent_fill_material(fill_color)
	#box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	#box.global_transform = Transform3D(Basis.IDENTITY, center_world)
	#root.add_child(box)
#
	## Wire edges
	#var wire := MeshInstance3D.new()
	#wire.mesh = _make_wire_box(size_world, _make_line_material(line_color))
	#wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	#wire.global_transform = Transform3D(Basis.IDENTITY, min_world)
	#root.add_child(wire)
#
## Convenience: erase the current border box, if any
#func erase_world_border_box() -> void:
	#_clear_world_border_viz()


enum Shape { BOX, SPHERE, CYLINDER, CAPSULE, LINE, POINT }

func voxel_debug_place_structure_from_ray(origin: Vector3, dir: Vector3, max_distance: float, cfg: Dictionary) -> bool:
	print("Debug cfg", cfg)
	var vt := _get_tool()
	if vt == null:
		print("Failed debug add because Could not get voxel tool")
		return false

	if max_distance <= 0.0:
		var _vox_size := voxel_size_world()
		max_distance = (float(max_place_distance_voxels) * _vox_size if use_voxel_relative_distances else max_place_distance)
	
	vt.set_raycast_normal_enabled(true)
	var player_dir := dir.normalized()
	var hit := vt.raycast(origin, player_dir, max_distance)
	
	if hit == null:
		print("Failed debug add because could not find a hit from the raycast")
		return false
	var hit_pos: Vector3i = hit.position
	var n := hit.normal   
	var step := Vector3i(_axis_step(n.x), _axis_step(n.y), _axis_step(n.z))
	
	var place_pos: Vector3i = hit_pos + step
	# (optional) bounds/editability check around the place position
	if not vt.is_area_editable(AABB(Vector3(place_pos), Vector3.ONE)):
		print("Failed debug add because area we are trying to place in is not editable")
		return false
	
	vt.mode = VoxelTool.MODE_SET
	vt.channel = VoxelBuffer.CHANNEL_TYPE
	#if placing:
		#vt.value = block_id
		#vt.do_point(place_pos)
		
	#var hit := _raycast_voxel_surface(origin, dir, max_distance)
	#if hit == null:
		#return false

	var block_id: int = int(cfg.get("material_idx", 1))
	var override_voxels: bool = bool(cfg.get("override", true))
	var grid: int = int(cfg.get("grid", 1))

	# Snap to grid if needed
	var pos: Vector3i = _to_grid(hit.position, grid)
	
	vt.value = block_id
	print("Starting the match for placing block ID", block_id)
	match int(cfg.get("shape", Shape.BOX)):
		Shape.BOX:
			return _place_box(pos, Vector3i(int(cfg.size_x), int(cfg.size_y), int(cfg.size_z)), block_id, override_voxels, vt)
		Shape.SPHERE:
			return _place_sphere(pos, int(cfg.radius), block_id, override_voxels, vt)
		Shape.CYLINDER:
			return _place_cylinder(pos, int(cfg.radius), int(cfg.height), block_id, override_voxels, vt)
		Shape.CAPSULE:
			return _place_capsule(pos, int(cfg.radius), int(cfg.height), block_id, override_voxels, vt)
		Shape.LINE:
			return _place_line(pos, int(cfg.length), block_id, override_voxels, dir, vt)
		Shape.POINT:
			return _place_point(pos, block_id, override_voxels, vt)
		_:
			return _place_point(pos, block_id, override_voxels, vt)

# --- helpers (replace with your engine/world access) ---
func _raycast_voxel_surface(origin: Vector3, dir: Vector3, max_dist: float) -> Dictionary:
	# Return {'position': Vector3, 'normal': Vector3} or null
	# Use your physics raycast or your voxel engine’s ray function
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * max_dist)
	var res := space.intersect_ray(q)
	if res.is_empty(): return {}
	return {"position": res.position, "normal": res.normal}

func _to_grid(p: Vector3, g: int) -> Vector3i:
	if g <= 1: return Vector3i(round(p.x), round(p.y), round(p.z))
	return Vector3i(round(p.x / g) * g, round(p.y / g) * g, round(p.z / g) * g)

# --- structure placers (implement with your voxel world API) ---
func _place_point(pos: Vector3i, block_id: int, override_voxels: bool, vt: VoxelTool) -> bool:
	#return _set_block(pos, block_id, override_voxels)
	vt.do_point(pos)
	return true

func _place_box(pos: Vector3i, size: Vector3i, block_id: int, override_voxels: bool, vt: VoxelTool) -> bool:
	var ok := true
	for x in range(pos.x, pos.x + size.x):
		for y in range(pos.y, pos.y + size.y):
			for z in range(pos.z, pos.z + size.z):
				#ok = _set_block(Vector3i(x,y,z), block_id, override_voxels) and ok
				var p = Vector3i(x,y,z)
				var cur := vt.get_voxel(p)
				if !override_voxels:
					if cur == 0:
						vt.set_voxel(p, block_id)
						continue
				else:
					vt.do_point(p)
	return ok

func _place_sphere(center: Vector3i, r: int, block_id: int, override_voxels: bool, vt: VoxelTool) -> bool:
	var ok := true
	var r2 := r * r
	for x in range(center.x - r, center.x + r + 1):
		for y in range(center.y - r, center.y + r + 1):
			for z in range(center.z - r, center.z + r + 1):
				var d := Vector3i(x - center.x, y - center.y, z - center.z)
				if d.x*d.x + d.y*d.y + d.z*d.z <= r2:
					#ok = _set_block(Vector3i(x,y,z), block_id, override_voxels) and ok
					var p = Vector3i(x,y,z)
					var cur := vt.get_voxel(p)
					if !override_voxels:
						if cur == 0:
							vt.set_voxel(p, block_id)
							continue
					else:
						vt.do_point(p)
	return ok

func _place_cylinder(center: Vector3i, r: int, h: int, block_id: int, override_voxels: bool, vt: VoxelTool) -> bool:
	var ok := true
	var r2 := r * r
	var y0 := center.y
	for y in range(y0, y0 + h):
		for x in range(center.x - r, center.x + r + 1):
			for z in range(center.z - r, center.z + r + 1):
				var dx := x - center.x
				var dz := z - center.z
				if dx*dx + dz*dz <= r2:
					#ok = _set_block(Vector3i(x,y,z), block_id, override_voxels) and ok
					var p = Vector3i(x,y,z)
					var cur := vt.get_voxel(p)
					if !override_voxels:
						if cur == 0:
							vt.set_voxel(p, block_id)
							continue
					else:
						vt.do_point(p)
	return ok

#func _place_capsule(center: Vector3i, r: int, h: int, block_id: int, override_voxels: bool, vt: VoxelTool) -> bool:
	## cylinder + two hemispheres (simple discrete approach)
	#
	#var ok: bool = _place_sphere(center + Vector3i(0,  h/2, 0), r, block_id, override_voxels, vt)
	#ok = _place_sphere(center + Vector3i(0, -h/2, 0), r, block_id, override_voxels, vt) and ok
	#ok = _place_cylinder(center, r, max(0, h - 2*r), block_id, override_voxels, vt) and ok
	#return ok
	
func _place_capsule(bottom: Vector3i, r: int, h: int, block_id: int, override_voxels: bool, vt: VoxelTool) -> bool:
	# cylinder + two hemispheres (simple discrete approach)
	if r > h:
		var temp = h
		h = r
		r = temp
	
	var ok: bool = _place_sphere(bottom + Vector3i(0,  r, 0), r, block_id, override_voxels, vt)
	ok = _place_sphere(bottom + Vector3i(0, h - r, 0), r, block_id, override_voxels, vt) and ok
	ok = _place_cylinder(bottom + Vector3i(0,  r, 0), r, max(0, h - 2*r), block_id, override_voxels, vt) and ok
	return ok

func _place_line(start: Vector3i, length: int, block_id: int, override_voxels: bool, dir: Vector3, vt: VoxelTool) -> bool:
	# Lay blocks along aim direction
	var ok := true
	var step := dir.normalized()
	var p := Vector3(start)
	for i in length:
		#ok = _set_block(Vector3i(round(p.x), round(p.y), round(p.z)), block_id, override_voxels) and ok
		var q = Vector3i(round(p.x), round(p.y), round(p.z))
		var cur := vt.get_voxel(p)
		if !override_voxels:
			if cur == 0:
				vt.set_voxel(q, block_id)
				continue
		else:
			vt.do_point(q)
		p += step
	return ok

# Replace this with your voxel world’s API
func _set_block(pos: Vector3i, block_id: int, override_voxels: bool) -> bool:
	# e.g., world.set_voxel(pos, block_id, override_voxels)
	return true


func _pop_sphere(center: Vector3i, dir: Vector3, block_id: int) -> bool:
	var tool := _get_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	var hit := tool.raycast(center, dir, 64)
	if hit == null:
		return false
	var ok := true
	var r: int = 2
	var r2 := r * r
	for x in range(center.x - r, center.x + r + 1):
		for y in range(center.y - r, center.y + r + 1):
			for z in range(center.z - r, center.z + r + 1):
				var d := Vector3i(x - center.x, y - center.y, z - center.z)
				if d.x*d.x + d.y*d.y + d.z*d.z <= r2:
					#ok = _set_block(Vector3i(x,y,z), block_id, override_voxels) and ok
					var p = Vector3i(x,y,z)
					var cur := tool.get_voxel(p)
					if cur > 0:
						#tool.set_voxel(p, block_id)
						_pop_voxel_as_rigidbody
						continue
	return ok
func _pop_voxel_sphere_as_rigidbody(origin: Vector3, dir: Vector3, r: int) -> void:
	if terrain == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	var tool := _get_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	var hit := tool.raycast(origin, dir, 64)
	if hit == null:
		return

	var vpos: Vector3i = hit.position 
	var id := tool.get_voxel(vpos)
	if id == 0:
		return
	
	for x in range(vpos.x - r, vpos.x + r + 1):
		for y in range(vpos.y - r, vpos.y + r + 1):
			for z in range(vpos.z - r, vpos.z + r + 1):
				var d := Vector3i(x - vpos.x, y - vpos.y, z - vpos.z)
				if d.x*d.x + d.y*d.y + d.z*d.z <= r * r:
					#ok = _set_block(Vector3i(x,y,z), block_id, override_voxels) and ok
					var p = Vector3i(x,y,z)
					var cur := tool.get_voxel(p)
					if cur > 0:
						tool.mode = VoxelTool.MODE_SET
						tool.set_voxel(p, 0)

						var rb := RigidBody3D.new()
						rb.freeze = false
						rb.mass = 1.0
						rb.linear_damp = 0.05
						rb.angular_damp = 0.05
						#rb.gravity_scale = 0.0

						var voxel_scale := terrain.global_transform.basis.get_scale().abs()
						var scale_factor := voxel_scale.x
						
						var mesh: Mesh = null
						var material: Material = null
						var lib: VoxelBlockyLibrary = null
						
						if "mesher" in terrain and terrain.mesher and "library" in terrain.mesher:
							lib = terrain.mesher.library
						print("Library?", lib)
						if lib and lib.has_method("get_model"):
							var model := lib.get_model(id) 
							print("Got model", model)
							if model and model.has_method("get"):
								mesh = model.get("mesh")
								print("Got mesh", mesh)
								if mesh is ArrayMesh:
									var aabb = mesh.get_aabb()
									print("Mesh AABB: ", aabb)
								
							if "material_override_0" in model and model.material_override_0 != null:
									material = model.material_override_0
									print("Got material", material)

						mesh = null
						if mesh == null:
							print("Fallback mesh")
							var box_mesh := BoxMesh.new()
							box_mesh.size = voxel_scale
							mesh = box_mesh
						
						var mi := MeshInstance3D.new()
						mi.mesh = mesh
						if material != null:
							print("Valid Material")
							mi.material_override = material
						rb.add_child(mi)

						var shape: Shape3D = null
						if mesh is ArrayMesh or mesh is Mesh:
							shape = mesh.create_convex_shape()
						if shape == null:
							print("No ArrayMesh")
							var bs := BoxShape3D.new()
							bs.size = voxel_scale
							shape = bs
						var cs := CollisionShape3D.new()
						cs.shape = shape
						rb.add_child(cs)

						var voxel_center_local := Vector3(p) + Vector3(0.5, 0.5, 0.5)
						var world_pos := terrain.to_global(voxel_center_local)
						
						rb.scale = voxel_scale
						
						get_tree().current_scene.add_child(rb)
						rb.global_transform.origin = world_pos
						#var impulse_strength := 2.0 * scale_factor  # Scale impulse with voxel size
						var impulse_strength := 2.0 
						rb.apply_impulse(-dir.normalized() * impulse_strength, Vector3.ZERO)


func _pop_voxel_as_rigidbody(origin: Vector3, dir: Vector3) -> void:
	if terrain == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	var tool := _get_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	var hit := tool.raycast(origin, dir, 64)
	if hit == null:
		return

	var vpos: Vector3i = hit.position 
	var id := tool.get_voxel(vpos)
	if id == 0:
		return
		
	tool.mode = VoxelTool.MODE_SET
	tool.set_voxel(vpos, 0)
	print("got hit at", hit)
	print("got vpos", vpos)

	# 4) Spawn rigid body representing that voxel
	var rb := RigidBody3D.new()
	rb.freeze = false
	rb.mass = 1.0
	rb.linear_damp = 0.05
	rb.angular_damp = 0.05
	#rb.gravity_scale = 0.0

	var voxel_scale := terrain.global_transform.basis.get_scale().abs()
	var scale_factor := voxel_scale.x
	
	var mesh: Mesh = null
	var material: Material = null
	var lib: VoxelBlockyLibrary = null
	
	if "mesher" in terrain and terrain.mesher and "library" in terrain.mesher:
		lib = terrain.mesher.library
	print("Library?", lib)
	if lib and lib.has_method("get_model"):
		var model := lib.get_model(id) # VoxelBlockyModel (Cube/Mesh/etc.)
		print("Got model", model)
		if model and model.has_method("get"):
			mesh = model.get("mesh")
			print("Got mesh", mesh)
			if mesh is ArrayMesh:
				var aabb = mesh.get_aabb()
				print("Mesh AABB: ", aabb)
			
		if "material_override_0" in model and model.material_override_0 != null:
				material = model.material_override_0
				print("Got material", material)

	mesh = null
	if mesh == null:
		print("Fallback mesh")
		var box_mesh := BoxMesh.new()
		#box_mesh.size = Vector3.ONE  # Unit size, will be scaled by transform
		box_mesh.size = voxel_scale
		mesh = box_mesh
	
	# Create mesh instance
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if material != null:
		print("Valid Material")
		mi.material_override = material
	rb.add_child(mi)

	# Collision: best-effort
	var shape: Shape3D = null
	if mesh is ArrayMesh or mesh is Mesh:
		# Trimesh for arbitrary mesh; if you prefer boxes, use BoxShape3D
		#shape = mesh.create_trimesh_shape()
		shape = mesh.create_convex_shape()
	if shape == null:
		print("No ArrayMesh")
		var bs := BoxShape3D.new()
		#bs.size = Vector3.ONE          # unit voxel
		bs.size = voxel_scale
		shape = bs
	var cs := CollisionShape3D.new()
	cs.shape = shape
	rb.add_child(cs)

	# Place at voxel center (assuming 1x1x1 voxels; offset as needed if you scale)
	#rb.global_transform.origin = Vector3(vpos) + Vector3(0.5, 0.5, 0.5)
	#rb.global_transform.origin = Vector3(vpos) + terrain.global_transform.basis.get_scale().abs()
	#rb.scale = terrain.global_transform.basis.get_scale().abs()
	#var voxel_center_local := Vector3(vpos) + Vector3(0.5, 0.5, 0.5)
	var voxel_center_local := Vector3(vpos) + Vector3(0.5, 0.5, 0.5)
	print("spawning rigid body at ", voxel_center_local)
	var world_pos := terrain.to_global(voxel_center_local)
	
	print("Voxel local position: ", vpos)
	print("Voxel center (local): ", voxel_center_local)
	print("World position: ", world_pos)
	print("Applying scale: ", voxel_scale)
	
	rb.scale = voxel_scale
	
	print("RigidBody scale set to: ", rb.scale)
	
	# Add to tree
	print("Current scene ", get_tree().current_scene)
	#print("Current scene scale", get_tree().current_scene.)
	get_tree().current_scene.add_child(rb)
	
	# Set position (AFTER adding to tree)
	rb.global_transform.origin = world_pos
	print("RigidBody spawned at world position: ", rb.global_position)
	print("RigidBody final scale: ", rb.scale)
	

	# Optional: give it a little impulse so it "pops" out
	#rb.apply_impulse(-dir * 2.0, Vector3.ZERO)
	var impulse_strength := 2.0 * scale_factor  # Scale impulse with voxel size
	rb.apply_impulse(-dir.normalized() * impulse_strength, Vector3.ZERO)

	# Add to scene
	#get_tree().current_scene.add_child(rb)
