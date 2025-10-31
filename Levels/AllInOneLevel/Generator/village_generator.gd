#tool
extends Resource

const Structure = preload("./structure.gd")

# Block IDs provided by user
const AIR := 0
const DIRT := 1
const GRASS := 2
const LOG_X := 3
const LOG_Y := 4
const LOG_Z := 5
const STAIRS_UP_NX := 6
const PLANKS := 7
const TALL_GRASS := 8
const STAIRS_NX := 9
const STAIRS_PY := 10
const STAIRS_PZ := 11
const GLASS := 12
const LEAVES := 25
const DEAD_SHRUB := 26

var channel := VoxelBuffer.CHANNEL_TYPE

func generate(stretch: Vector3 = Vector3(1,1,1), grow_by: int = 1) -> Structure:
	var voxels := {}
	
	# Combine stretch and grow_by into a single scale vector
	var layout_scale := Vector3(stretch.x * grow_by, stretch.y * grow_by, stretch.z * grow_by)
	
	# Layout parameters
	var house_count := 5
	var spacing := 12 * int(layout_scale.x)  # distance between house origins
	var origin := Vector3i(0, 1, 0)  # build one block above Y=0 to avoid seam artifacts
	
	for i in house_count:
		
		var house_scale := Vector3(stretch.x * (i + 1), stretch.y * (i + 1), stretch.z * (i + 1))
		
		var hx := i * spacing * (i + 1)
		var house_origin := origin + Vector3i(hx, 0, 0)
		
		# Alternate between different house types
		match i % 4:
			0:  # Square house
				_build_square_house(voxels, house_origin, Vector3i(9, 6, 7), house_scale)
			1:  # Cottage with sloped roof
				_build_cottage_house(voxels, house_origin, Vector3i(10, 8, 10), house_scale)
			2:  # Tower house
				_build_tower_house(voxels, house_origin, Vector3i(7, 10, 7), house_scale)
			3:  # Another square house variant
				_build_square_house(voxels, house_origin, Vector3i(11, 8, 8), house_scale)
		
		# Simple front yard pad + path
		var sx := int(house_scale.x)
		var sy := int(house_scale.y)
		var sz := int(house_scale.z)
		
		# Front yard grass pad (scaled with house)
		_fill_rect(voxels, house_origin + Vector3i(-2 * sx, -1, -3 * sz), 
				   Vector3i(13 * sx, 1, 3 * sz), GRASS)
		
		# Dirt path (scaled with house)
		_fill_rect(voxels, house_origin + Vector3i(3 * sx, -1, -6 * sz), 
				   Vector3i(3 * sx, 1, 3 * sz), DIRT)
	
		
		# Trees left/right/front
		#_build_tree(voxels, house_origin + Vector3i(-4, 0,  4))
		#_build_tree(voxels, house_origin + Vector3i(12, 0,  4))
		#_build_tree(voxels, house_origin + Vector3i( 4, 0, -8))
	
	# Convert sparse -> Structure (compute AABB bounds)
	var aabb := _compute_bounds(voxels)
	var structure := Structure.new()
	structure.offset = -aabb.position
	
	var size := Vector3i(int(aabb.size.x) + 1, int(aabb.size.y) + 1, int(aabb.size.z) + 1)
	structure.voxels.create(size.x, size.y, size.z)
	
	for pos in voxels.keys():
		var rpos: Vector3i = pos + Vector3i(structure.offset)
		var v = voxels[pos]
		structure.voxels.set_voxel(v, rpos.x, rpos.y, rpos.z, channel)
	
	return structure

func _set_if_empty(voxels: Dictionary, p: Vector3i, v: int) -> void:
	if not voxels.has(p):
		voxels[p] = v

func _build_square_house(voxels: Dictionary, o: Vector3i, base_dims: Vector3i, layout_scale: Vector3) -> void:
	# Apply scaling to dimensions
	var sx := int(layout_scale.x)
	var sy := int(layout_scale.y)
	var sz := int(layout_scale.z)
	
	var w := base_dims.x * sx
	var h := base_dims.y * sy
	var d := base_dims.z * sz
	
	# Foundation (dirt under house), floor (planks)
	_fill_rect(voxels, o + Vector3i(0, -1, 0), Vector3i(w, 1, d), DIRT)
	_fill_rect(voxels, o + Vector3i(0,  0, 0), Vector3i(w, sy, d), PLANKS)
	
	# Corner posts (vertical logs)
	var corners := [
		o + Vector3i(0, 0, 0),
		o + Vector3i(w-sx, 0, 0),
		o + Vector3i(0, 0, d-sz),
		o + Vector3i(w-sx, 0, d-sz),
	]
	print("Built square house at ", o)
	for c in corners:
		_fill_rect(voxels, c, Vector3i(sx, h, sz), LOG_Y)
	
	# Walls (planks with windows)
	# Front and back walls
	for x in range(sx, w-sx):
		for y in range(sy, h-sy):
			for z in range(1, sz + 1):
				# Front side (z=0)
				_set_if_empty(voxels, o + Vector3i(x, y, z), _wall_block_for(y, sy))
				# Back side (z=d-sz)
				_set_if_empty(voxels, o + Vector3i(x, y, d-z), _wall_block_for(y, sy))
	
	# Left and right walls
	for z in range(sz, d-sz):
		for y in range(sy, h-sy):
			for x in range(1, sx + 1):
				# Left side (x=0)
				_set_if_empty(voxels, o + Vector3i(x, y, z), _wall_block_for(y, sy))
				# Right side (x=w-sx)
				_set_if_empty(voxels, o + Vector3i(w-x, y, z), _wall_block_for(y, sy))
		
	# Door opening on front center

	
	# Fill in remaining wall blocks (between corners)
	for x in range(sx, w-sx):
		for y in range(sy, h-sy):
			# Front/back
			_set_if_empty(voxels, o + Vector3i(x, y, 0), PLANKS)
			_set_if_empty(voxels, o + Vector3i(x, y, d-sz), PLANKS)
	
	for z in range(sz, d-sz):
		for y in range(sy, h-sy):
			# Left/right
			_set_if_empty(voxels, o + Vector3i(0, y, z), PLANKS)
			_set_if_empty(voxels, o + Vector3i(w-sx, y, z), PLANKS)
	
	# Ceiling
	#_fill_rect(voxels, o + Vector3i(0, h-sy, 0), Vector3i(w, sy, d), PLANKS)
	
	# Simple flat roof border (log beams along X and Z)
	_fill_rect(voxels, o + Vector3i(0, h - sy, 0), Vector3i(w, sy, sz), LOG_X)
	_fill_rect(voxels, o + Vector3i(0, h - sy, d-sz), Vector3i(w, sy, sz), LOG_X)
	_fill_rect(voxels, o + Vector3i(0, h - sy, 0), Vector3i(sx, sy, d), LOG_Z)
	_fill_rect(voxels, o + Vector3i(w-sx, h - sy, 0), Vector3i(sx, sy, d), LOG_Z)
	_fill_rect(voxels, o + Vector3i(sx, h - sy, sz), Vector3i(w-2*sx, sy, d-2*sz), PLANKS)
	
	# Windows (glass panes) on sides
	var wy := o.y + 2 * sy
	# Front and back windows
	for x in range(o.x + sx, o.x + w - sx):
		#if x >= 0 and x < o.x + w:
		for z in range(1, sz + 1):
			for y in range(wy, wy + sy):
				voxels[Vector3i(x, y, o.z + z - 1)] = GLASS
				voxels[Vector3i(x, y, o.z + d - z)] = GLASS
	# Side windows
	for z in range(o.z + sz, o.z + d - sz):
		#if z >= 0 and z < o.z + d:
		for x in range(1, sx + 1):
			for y in range(wy, wy + sy):
				voxels[Vector3i(o.x + x - 1, y, z)] = GLASS
				voxels[Vector3i(o.x + w - x, y, z)] = GLASS
	
	var door_x_start := int(w / 2.0) - sx
	var door_x_end := int(w / 2.0) + sx
	var door_height := 3 * sy
	
	for door_x in range(door_x_start, door_x_end):
		for door_y in range(sy, door_height):
			for door_z in range(0, sz):
				var door_pos := Vector3i(o.x + door_x, o.y + door_y, o.z + door_z)
				voxels[door_pos] = AIR
	# Interior: clear space
	for x in range(sx, w-sx):
		for y in range(sy, h-sy):
			for z in range(sz, d-sz):
				voxels[Vector3i(o.x + x, o.y + y, o.z + z)] = AIR

# Add these functions to village_generator.gd

# Cottage-style house with sloped roof using stairs
func _build_cottage_house(voxels: Dictionary, o: Vector3i, base_dims: Vector3i, layout_scale: Vector3) -> void:
	var sx := int(layout_scale.x)
	var sy := int(layout_scale.y)
	var sz := int(layout_scale.z)
	
	var w := base_dims.x * sx
	var h := base_dims.y * sy
	var d := base_dims.z * sz
	
	# Foundation and floor
	_fill_rect(voxels, o + Vector3i(0, -1, 0), Vector3i(w, 1, d), DIRT)
	_fill_rect(voxels, o + Vector3i(0, 0, 0), Vector3i(w, sy, d), PLANKS)
	
	# Corner posts
	var corners := [
		o + Vector3i(0, 0, 0),
		o + Vector3i(w-sx, 0, 0),
		o + Vector3i(0, 0, d-sz),
		o + Vector3i(w-sx, 0, d-sz),
	]
	print("Built cottage house at ", o)
	for c in corners:
		_fill_rect(voxels, c, Vector3i(sx, h, sz), LOG_Y)
	
	# Walls with stone brick base
	for x in range(sx, w-sx):
		for y in range(sy, h-sy):
			for z in range(0, sz + 1):
				# Add cobblestone base (using DIRT as substitute, change to your stone ID)
				if y < 2 * sy:
					_set_if_empty(voxels, o + Vector3i(x, y, z), DIRT)
					_set_if_empty(voxels, o + Vector3i(x, y, d-z-1), DIRT)
				else:
					_set_if_empty(voxels, o + Vector3i(x, y, z), _wall_block_for(y, sy))
					_set_if_empty(voxels, o + Vector3i(x, y, d-z-1), _wall_block_for(y, sy))
	
	for z in range(sz, d-sz):
		for y in range(sy, h-sy):
			for x in range(0, sx + 1):
				if y < 2 * sy:
					_set_if_empty(voxels, o + Vector3i(x, y, z), DIRT)
					_set_if_empty(voxels, o + Vector3i(w-x-1, y, z), DIRT)
				else:
					_set_if_empty(voxels, o + Vector3i(x, y, z), _wall_block_for(y, sy))
					_set_if_empty(voxels, o + Vector3i(w-x-1, y, z), _wall_block_for(y, sy))
	
	# Fill walls
	for x in range(sx, w-sx):
		for y in range(sy, h-sy):
			_set_if_empty(voxels, o + Vector3i(x, y, 0), PLANKS)
			_set_if_empty(voxels, o + Vector3i(x, y, d-sz), PLANKS)
	
	for z in range(sz, d-sz):
		for y in range(sy, h-sy):
			_set_if_empty(voxels, o + Vector3i(0, y, z), PLANKS)
			_set_if_empty(voxels, o + Vector3i(w-sx, y, z), PLANKS)
	
	# Sloped roof using stairs (A-frame style)
	var roof_height := int(d / 2) + sy
	for roof_layer in range(roof_height):
		var inset := roof_layer
		if inset * 2 >= d:
			break
		
		# Front slope (stairs facing +Z)
		for x in range(0, w):
			for s in range(sy):
				voxels[Vector3i(o.x + x, o.y + h - sy + roof_layer + s, o.z + inset)] = STAIRS_PZ
		
		# Back slope (stairs facing -Z)
		for x in range(0, w):
			for s in range(sy):
				voxels[Vector3i(o.x + x, o.y + h - sy + roof_layer + s, o.z + d - sz - inset + 1)] = STAIRS_NX
		
		# Fill top with planks when slopes meet
		if d - sz - 2 * inset > 0:
			for x in range(sx):
				for z in range(o.z + inset + sz, o.z + d - 2 * sz - inset + 2):
					for s in range(sy):
						voxels[Vector3i(o.x + x, o.y + h - sy + roof_layer + s, o.z + z)] = PLANKS
						voxels[Vector3i(o.x + w - sx + x, o.y + h - sy + roof_layer + s, o.z + z)] = PLANKS
	
	# Windows
	var wy := o.y + 3 * sy
	var window_spacing = max(3 * sx, 1)
	
	# Front and back windows
	for x in range(o.x + 2*sx, o.x + w - 2*sx, window_spacing):
		for y_offset in range(sy):
			for x_offset in range(sx):
				for z_offset in range(sz):
					voxels[Vector3i(x + x_offset, wy + y_offset, o.z + z_offset)] = GLASS
					voxels[Vector3i(x + x_offset, wy + y_offset, o.z + d - sz + z_offset)] = GLASS
	
	# Side windows
	var window_spacing_z = max(3 * sz, 1)
	for z in range(o.z + 2*sz, o.z + d - 2*sz, window_spacing_z):
		for y_offset in range(sy):
			for x_offset in range(sx):
				for z_offset in range(sz):
					voxels[Vector3i(o.x + x_offset, wy + y_offset, z + z_offset)] = GLASS
					voxels[Vector3i(o.x + w - sx + x_offset, wy + y_offset, z + z_offset)] = GLASS
	
	# Door
	var door_x_start := int(w / 2.0) - sx
	var door_x_end := int(w / 2.0) + sx
	var door_height := 3 * sy
	
	for door_x in range(door_x_start, door_x_end):
		for door_y in range(sy, door_height):
			for door_z in range(0, sz):
				voxels[Vector3i(o.x + door_x, o.y + door_y, o.z + door_z)] = AIR
	
	# Interior
	for x in range(sx, w-sx):
		for y in range(sy, h-sy):
			for z in range(sz, d-sz):
				voxels[Vector3i(o.x + x, o.y + y, o.z + z)] = AIR


# Tower house with stairs forming a spiral roof
func _build_tower_house(voxels: Dictionary, o: Vector3i, base_dims: Vector3i, layout_scale: Vector3) -> void:
	var sx := int(layout_scale.x)
	var sy := int(layout_scale.y)
	var sz := int(layout_scale.z)
	
	var w := base_dims.x * sx
	var h := base_dims.y * sy
	var d := base_dims.z * sz
	print("Built tower house at ", o)
	
	# Foundation and floor
	_fill_rect(voxels, o + Vector3i(0, -1, 0), Vector3i(w, 1, d), DIRT)
	_fill_rect(voxels, o + Vector3i(0, 0, 0), Vector3i(w, sy, d), PLANKS)
	
	# Walls (all planks, no corner posts for tower style)
	for x in range(0, w):
		for y in range(sy, h-sy):
			for z_offset in range(sz):
				_set_if_empty(voxels, o + Vector3i(x, y, z_offset), PLANKS)
				_set_if_empty(voxels, o + Vector3i(x, y, d-sz+z_offset), PLANKS)
	
	# Left and right walls
	for z in range(0, d):
		for y in range(sy, h-sy):
			for x_offset in range(sx):
				_set_if_empty(voxels, o + Vector3i(x_offset, y, z), PLANKS)
				_set_if_empty(voxels, o + Vector3i(w-sx+x_offset, y, z), PLANKS)
	
	# Pyramid roof using stairs
	var roof_base := h - sy
	var max_inset = min(int(w / 2), int(d / 2))
	#var max_inset = min(int(w / 2), int(d / 2)) - sx
	#var max_inset = min(int((w + sx) / 2), int((d + sz) / 2)) - sx
	
	for layer in range(max_inset):
		var inset := layer
		var current_y := o.y + roof_base + layer
		
		# North side (stairs facing +Z)
		for x in range(inset + 1, w - inset):
			for s in range(sy):
				voxels[Vector3i(o.x + x, current_y + s, o.z + inset)] = STAIRS_PZ
		
		# South side (stairs facing -Z) 
		for x in range(inset + 1, w - inset):
			for s in range(sy):
				voxels[Vector3i(o.x + x, current_y + s, o.z + d - inset - 1)] = STAIRS_NX
		
		# East side (stairs facing +X)
		for z in range(inset + 1, d - inset ):
			for s in range(sy):
				voxels[Vector3i(o.x + inset, current_y + s, o.z + z)] = STAIRS_PY
		
		# West side (stairs facing -X)
		for z in range(inset + 1, d - inset):
			for s in range(sy):
				voxels[Vector3i(o.x + w - inset - 1, current_y + s, o.z + z)] = STAIRS_UP_NX
		# Adding planks in at the stair intersections
		for s in range(sy):
			voxels[Vector3i(o.x + w - inset - 1, current_y + s, o.z + inset )] = PLANKS
			voxels[Vector3i(o.x + w - inset - 1, current_y + s, o.z + d - inset - 1)] = PLANKS
			voxels[Vector3i(o.x + inset, current_y + s,o.z + inset )] = PLANKS
			voxels[Vector3i(o.x + inset, current_y + s, o.z + d - inset - 1)] = PLANKS
	
	# Top capstone
	#var cap_y = o.y + roof_base + max_inset
	#for x in range(max_inset, w - max_inset):
		#for z in range(max_inset, d - max_inset):
			#for s in range(sy):
				#voxels[Vector3i(o.x + x, cap_y + s, o.z + z)] = LOG_Y
	
	# Windows with cross pattern
	var wy := o.y + 2 * sy
	var num_levels := 2
	
	for level in range(num_levels):
		var window_y := wy + level * 3 * sy
		
		# Cardinal direction windows - scale them properly
		var center_x := int(w / 2)
		var center_z := int(d / 2)
		
		# North window
		for x_off in range(sx):
			for y_off in range(sy):
				for z_off in range(sz):
					voxels[Vector3i(o.x + center_x + x_off, window_y + y_off, o.z + z_off)] = GLASS
		
		# South window
		for x_off in range(sx):
			for y_off in range(sy):
				for z_off in range(sz):
					voxels[Vector3i(o.x + center_x + x_off, window_y + y_off, o.z + d - sz + z_off)] = GLASS
		
		# West window
		for x_off in range(sx):
			for y_off in range(sy):
				for z_off in range(sz):
					voxels[Vector3i(o.x + x_off, window_y + y_off, o.z + center_z + z_off)] = GLASS
		
		# East window
		for x_off in range(sx):
			for y_off in range(sy):
				for z_off in range(sz):
					voxels[Vector3i(o.x + w - sx + x_off, window_y + y_off, o.z + center_z + z_off)] = GLASS
	
	# Door
	var door_x_start := int(w / 2.0) - sx
	var door_x_end := int(w / 2.0) + sx
	var door_height := 3 * sy
	
	for door_x in range(door_x_start, door_x_end):
		for door_y in range(sy, door_height):
			for door_z in range(0, sz):
				voxels[Vector3i(o.x + door_x, o.y + door_y, o.z + door_z)] = AIR
	
	# Interior with floor separations
	var floors: int = 0
	for x in range(sx, w-sx):
		for y in range(sy, h-sy):
			for z in range(sz, d-sz):
				# Add a floor every 4*sy blocks
				if y % (4 * sy) == 0:
					for x_stretch in range(sx):
						for y_stretch in range(sy):
							for z_stretch in range(sz):
								voxels[Vector3i(o.x + x + x_stretch, o.y + y + y_stretch, o.z + z + z_stretch)] = PLANKS
					floors += 1
				#else:
					#voxels[Vector3i(o.x + x, o.y + y, o.z + z)] = AIR
	
	# Add spiral staircase inside (optional detail)
	# start at sx and then climb however tall the first floor is
	# Only put in stairs if there is enough width
	if w >= 4*sy:
		for step in range(0, 4):
			for x in range(sx):
				for y in range(sy):
					for z in range(sz):
						# IDC about the x stretch, does not matter
						if (sy + step * sy + y) <= (sz + step * sz + z):
							voxels[Vector3i(o.x + sx + x, o.y + sy + step * sy + y, o.z + sz + step * sz + z)] = STAIRS_PZ
						else:
							voxels[Vector3i(o.x + sx + x, o.y + sy + step * sy + y, o.z + sz + step * sz + z)] = AIR
		# Need to remove the flooring so from the last guy move back on the z
		for step in range(0, 3):
			for x in range(sx):
				for y in range(sy):
					for z in range(sz):
						voxels[Vector3i(o.x + sx + x, o.y + sy + 3 * sy + y, o.z + sz + step * sz + z)] = AIR
		
	#var stair_x := o.x + int(w/2)
	#var stair_z := o.z + int(d/2)
	#for stair_y in range(sy, h-sy, sy):
		#var rotation := int(stair_y / sy) % 4
		#match rotation:
			#0: voxels[Vector3i(stair_x, o.y + stair_y, stair_z)] = STAIRS_PZ
			#1: voxels[Vector3i(stair_x, o.y + stair_y, stair_z)] = STAIRS_UP_NX
			#2: voxels[Vector3i(stair_x, o.y + stair_y, stair_z)] = STAIRS_NX
			#3: voxels[Vector3i(stair_x, o.y + stair_y, stair_z)] = STAIRS_PY

func _build_tree(voxels: Dictionary, root: Vector3i) -> void:
	# Simple oak-ish: trunk up, cross of leaves, small canopy
	var trunk_h := 5 + int(randf() * 3.0)
	for i in range(trunk_h):
		voxels[Vector3i(root.x, root.y + i, root.z)] = LOG_Y
	
	var top := root + Vector3i(0, trunk_h, 0)
	# Cross arms
	for dx in range(-2, 3):
		voxels[Vector3i(top.x + dx, top.y, top.z)] = LEAVES
	for dz in range(-2, 3):
		voxels[Vector3i(top.x, top.y, top.z + dz)] = LEAVES
	# Puffy canopy around top
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for dy in range(-1, 2):
				var p := top + Vector3i(dx, dy, dz)
				if abs(dx) + abs(dy) + abs(dz) <= 3:
					voxels[p] = LEAVES
	
	# Grass around base
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			voxels[Vector3i(root.x + dx, root.y - 1, root.z + dz)] = GRASS

func _wall_block_for(y: int, scale_y: int) -> int:
	# Place windows at y==2*scale_y otherwise planks
	return GLASS if y == 2 * scale_y else PLANKS

func _place(voxels: Dictionary, p: Vector3i, v: int, scale: Vector3) -> void:
	# Expand a single voxel into a scale.x × scale.y × scale.z block
	var sx := int(scale.x)
	var sy := int(scale.y)
	var sz := int(scale.z)
	
	if sx <= 1 and sy <= 1 and sz <= 1:
		voxels[p] = v
		return
				
func _place_more(voxels: Dictionary, p: Vector3i, v: int, scale: Vector3) -> void:
	# Expand a single voxel into a scale.x × scale.y × scale.z block
	var sx := int(scale.x)
	var sy := int(scale.y)
	var sz := int(scale.z)
	
	if sx <= 1 and sy <= 1 and sz <= 1:
		voxels[p] = v
		return
		
	for dx in sx:
		for dy in sy:
			for dz in sz:
				voxels[Vector3i(p.x + dx, p.y + dy, p.z + dz)] = v

func _fill_rect_scaled(voxels: Dictionary, o: Vector3i, size: Vector3i, v: int, scale: Vector3) -> void:
	# Fill a rectangular region, where each logical voxel is expanded by scale
	for x in size.x:
		for y in size.y:
			for z in size.z:
				_place(voxels, Vector3i(o.x + x, o.y + y, o.z + z), v, scale)

func _fill_rect(voxels: Dictionary, o: Vector3i, size: Vector3i, v: int) -> void:
	# Fill a rectangular region, where each logical voxel is expanded by scale
	for x in size.x:
		for y in size.y:
			for z in size.z:
				#_place(voxels, Vector3i(o.x + x, o.y + y, o.z + z), v,)
				voxels[Vector3i(o.x + x, o.y + y, o.z + z)] = v
				
func _compute_bounds(voxels: Dictionary) -> AABB:
	var aabb := AABB(Vector3(0,0,0), Vector3(0,0,0))
	var first := true
	for p in voxels.keys():
		var vec := Vector3(p.x, p.y, p.z)
		if first:
			aabb = AABB(vec, Vector3(1,1,1))
			first = false
		else:
			aabb = aabb.expand(vec)
	return aabb
