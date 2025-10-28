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

# Public API mirrors tree_generator.gd: generate() -> Structure
func generate(grow_by: int = 1) -> Structure:
	var voxels := {}
	const stretch: Vector3 = Vector3(1,1,1)
	
	# Layout parameters
	var house_count := 3
	var spacing := 24 * grow_by  # distance between house origins
	var origin := Vector3i(0, 1, 0)  # build one block above Y=0 to avoid seam artifacts
	const layout_scale: int = 1
	
	for i in house_count:
		var hx := i * spacing
		var house_origin := origin + Vector3i(hx, 0, 0)
		#_build_house(voxels, house_origin, Vector3i(9, 6, 7), scale)
		_build_house(voxels, house_origin, Vector3i(9, 6, 7), stretch, grow_by)
		
		# Simple front yard pad + path
		#_fill_rect(voxels, house_origin + Vector3i(-2, -1, -3), Vector3i(13, 1, 3), GRASS)
		#_fill_rect(voxels, house_origin + Vector3i(3, -1, -6), Vector3i(3, 1, 3), DIRT)
		_fill_rect(voxels, house_origin + Vector3i(-2 * layout_scale, -1, -3 * layout_scale), Vector3i(13 * layout_scale, 1, 3 * layout_scale), GRASS, grow_by)
		_fill_rect(voxels, house_origin + Vector3i(3 * layout_scale, -1, -6 * layout_scale), Vector3i(3 * layout_scale, 1, 3 * layout_scale), DIRT, grow_by)
		
		# Trees left/right/front
		_build_tree(voxels, house_origin + Vector3i(-4, 0,  4))
		_build_tree(voxels, house_origin + Vector3i(12, 0,  4))
		_build_tree(voxels, house_origin + Vector3i( 4, 0, -8))
	
	# Convert sparse -> Structure (compute AABB bounds)
	var aabb := _compute_bounds(voxels)
	var structure := Structure.new()
	structure.offset = -aabb.position
	
	var size := Vector3i(int(aabb.size.x) + 1, int(aabb.size.y) + 1, int(aabb.size.z) + 1)
	structure.voxels.create(size.x, size.y, size.z)
	
	for pos in voxels.keys():
		#var rpos = pos + structure.offset
		var rpos: Vector3i = pos + Vector3i(structure.offset)
		var v = voxels[pos]
		structure.voxels.set_voxel(v, rpos.x, rpos.y, rpos.z, channel)
	
	return structure

func _set_if_empty(voxels: Dictionary, p: Vector3i, v: int) -> void:
	if not voxels.has(p):
		voxels[p] = v

func _build_house(voxels: Dictionary, o: Vector3i, base_dims: Vector3i, layout_scale: Vector3, a: int) -> void:
	var w := base_dims.x * a
	var h := base_dims.y * a
	var d := base_dims.z * a

	# Foundation (dirt) and floor (planks)
	#var dirt_extent := Vector3i(floor(w * layout_scale.x), floor(1 * layout_scale.y), floor(d* layout_scale.z))
	var floor_extent := Vector3i(floor(w * layout_scale.x), floor(1 * layout_scale.y), floor(d * layout_scale.z))
	_fill_rect(voxels, o + Vector3i(0, -1, 0), floor_extent, DIRT, a)
	_fill_rect(voxels, o + Vector3i(0,  0, 0), floor_extent, PLANKS, a)

	# Corner posts (vertical logs), thickness = layout_scale
	#var t = max(1, layout_scale * a)
	var corners := [
		o + Vector3i(0, 0, 0),
		o + Vector3i(w - layout_scale.x, 0, 0),
		o + Vector3i(0, 0, d - layout_scale.z),
		o + Vector3i(w - layout_scale.x, 0, d - layout_scale.z)
	]
	for c in corners:
		_fill_rect(voxels, c, Vector3i(layout_scale.x, h, layout_scale.z), LOG_Y, a)

	# Walls (planks with window band). Build as solid ring of thickness t first.
	# Front/back slabs
	_fill_rect(voxels, o + Vector3i(0, 1, 0),     Vector3i(w, h - 2, layout_scale.z), PLANKS, a)         # front
	_fill_rect(voxels, o + Vector3i(0, 1, d - layout_scale.z), Vector3i(w, h - 2, layout_scale.z), PLANKS, a)         # back
	# Left/right slabs
	_fill_rect(voxels, o + Vector3i(0, 1, 0),     Vector3i(layout_scale.x, h - 2, d), PLANKS, a)         # left
	_fill_rect(voxels, o + Vector3i(w - layout_scale.x, 1, 0), Vector3i(layout_scale.x, h - 2, d), PLANKS, a)         # right

	# Carve and glaze window band
	var y0 := o.y + layout_scale.y
	for y in range(y0, y0 + (h - (layout_scale.y * 2))):
		var y_local := y - o.y
		if _is_window_row(y_local, layout_scale.y):
			# Front/back strips: carve then glass
			for x in range(o.x + layout_scale.x, o.x + w - layout_scale.x):
				# front
				for z in layout_scale.z:
					_place(voxels, Vector3i(x, y, o.z + z), AIR, a)
				_place(voxels, Vector3i(x, y, o.z + int(layout_scale.z/2)), GLASS, a)
				# back
				for z in layout_scale.z:
					_place(voxels, Vector3i(x, y, o.z + d - 1 - z), AIR, a)
				_place(voxels, Vector3i(x, y, o.z + d - 1 - int(layout_scale.z/2)), GLASS, a)
			# Left/right strips: carve then glass
			for z in range(o.z + layout_scale.z, o.z + d - layout_scale.z):
				# left
				for x in layout_scale.x:
					_place(voxels, Vector3i(o.x + x, y, z), AIR, a)
				_place(voxels, Vector3i(o.x + int(layout_scale.x/2), y, z), GLASS, a)
				# right
				for x in layout_scale.x:
					_place(voxels, Vector3i(o.x + w - 1 - x, y, z), AIR, a)
				_place(voxels, Vector3i(o.x + w - 1 - int(layout_scale.x/2), y, z), GLASS, a)

	# Door opening on front center (width = t, height = 2*layout_scale)
	var door_w = layout_scale.z
	#var door_h = max(2 * layout_scale, t)
	var door_h = layout_scale.y
	var door_x0 := o.x + int((w - door_w) / 2)
	for y in range(o.y + 1, o.y + 1 + door_h):
		for x in range(door_x0, door_x0 + door_w):
			for z in layout_scale.z:
				_place(voxels, Vector3i(x, y, o.z + z), AIR, a)

	# Ceiling
	_fill_rect(voxels, o + Vector3i(0, h - 1, 0), Vector3i(w, layout_scale.y, d), PLANKS, a)

	# Simple roof border and cap
	_fill_rect(voxels, o + Vector3i(0, h, 0),     Vector3i(w, layout_scale.y, layout_scale.z), LOG_X, a)
	_fill_rect(voxels, o + Vector3i(0, h, d - layout_scale.z), Vector3i(w, layout_scale.y, layout_scale.z), LOG_X, a)
	_fill_rect(voxels, o + Vector3i(0, h, 0),     Vector3i(layout_scale.x, layout_scale.y, d), LOG_Z, a)
	_fill_rect(voxels, o + Vector3i(w - layout_scale.x, h, 0), Vector3i(layout_scale.x, layout_scale.y, d), LOG_Z, a)
	_fill_rect(voxels, o + Vector3i(layout_scale.x, h, layout_scale.z),     Vector3i(w - 2 * layout_scale.x, layout_scale.y, d - 2 * layout_scale.z), PLANKS, a)

	# Interior: clear
	for x in range(o.x + layout_scale.x, o.x + w - layout_scale.x):
		for y in range(o.y + layout_scale.y, o.y + h - layout_scale.y):
			for z in range(o.z + layout_scale.z, o.z + d - layout_scale.z):
				voxels[Vector3i(x, y, z)] = AIR
		
#func _build_house(voxels: Dictionary, o: Vector3i, dims: Vector3i, scale: int = 1) -> void:
	## dims = (width, height, depth)
	#var w := dims.x * scale
	#var h := dims.y * scale
	#var d := dims.z * scale
	#
	## Foundation (dirt under house), floor (planks), and grass perimeter
	#_fill_rect(voxels, o + Vector3i(0, -1, 0), Vector3i(w, 1, d), DIRT)
	#_fill_rect(voxels, o + Vector3i(0,  0, 0), Vector3i(w, 1, d), PLANKS)
	#
	## Corner posts (vertical logs)
	#var corners := [
		#o + Vector3i(0, 0, 0),
		#o + Vector3i(w-1, 0, 0),
		#o + Vector3i(0, 0, d-1),
		#o + Vector3i(w-1, 0, d-1),
	#]
	#for c in corners:
		#_fill_rect(voxels, c, Vector3i(scale, h, scale), LOG_Y)
	#
	## Walls (planks with windows)
	#for x in range(0, w):
		#for y in range(1, h-1):
			## front/back
			## Front side
			#for indent in range(1, scale + 1):
				#_set_if_empty(voxels, o + Vector3i(x, y, indent - 1), _wall_block_for(y))
			## Back side
			#for indent in range(1, scale + 1):
				#_set_if_empty(voxels, o + Vector3i(x, y, d-indent), _wall_block_for(y))
	#for z in range(0, d):
		#for y in range(1, h-1):
			## left/right
			#for indent in range(1, scale + 1):
				#_set_if_empty(voxels, o + Vector3i(indent-1, y, z), _wall_block_for(y))
			#for indent in range(1, scale + 1):
				#_set_if_empty(voxels, o + Vector3i(w-indent, y, z), _wall_block_for(y))
	#
	## Door opening on front center
	#var door_base:= o.x + int(w/2)
	## TODO workout the scaling for the door
	#for door_x in range(door_base, (door_base * scale) + 1):
		#for y in range(1 * scale, 3 * scale):
			#voxels.erase(Vector3i(door_x, o.y + y, o.z))
			#voxels[Vector3i(door_x, o.y + y, o.z)] = AIR
	#
	## Fill-in solid walls for remaining positions (inside left as air)
	#for x in range(1, w-1):
		#for y in range(1, h-1):
			## front/back strip
			#for indent in range(1, scale + 1):
				#_set_if_empty(voxels, o + Vector3i(x, y, indent - 1), PLANKS)
			#for indent in range(1, scale + 1):
				#_set_if_empty(voxels, o + Vector3i(x, y, d-indent), PLANKS)
	#for z in range(1, d-1):
		#for y in range(1, h-1):
			## left/right strip
			#for indent in range(1, scale + 1):
				#_set_if_empty(voxels, o + Vector3i(indent - 1, y, z), PLANKS)
			#for indent in range(1, scale + 1):
				#_set_if_empty(voxels, o + Vector3i(w-indent, y, z), PLANKS)
	#
	## Ceiling
	##for indent in range(1, scale + 1):
	#_fill_rect(voxels, o + Vector3i(0, h-1, 0), Vector3i(w, scale, d), PLANKS)
	#
	## Simple flat roof border (log beams along X and Z)
	#_fill_rect(voxels, o + Vector3i(0, h, 0), Vector3i(w, scale, scale), LOG_X)
	#_fill_rect(voxels, o + Vector3i(0, h, d-1), Vector3i(w, scale, scale), LOG_X)
	#_fill_rect(voxels, o + Vector3i(0, h, 0), Vector3i(scale, scale, d), LOG_Z)
	#_fill_rect(voxels, o + Vector3i(w-1, h, 0), Vector3i(scale, scale, d), LOG_Z)
	#_fill_rect(voxels, o + Vector3i(1, h, 1), Vector3i(w-2 * scale, scale, d-2 * scale), PLANKS)
	#
	## Windows (glass panes) on sides
	#var wy := o.y + 2 * scale
	#for x in [o.x + 2 * scale, o.x + w - 3]:
		#voxels[Vector3i(x, wy, o.z)] = GLASS
		#voxels[Vector3i(x, wy, o.z + d - 1)] = GLASS
	#for z in [o.z + 2, o.z + d - 3]:
		#voxels[Vector3i(o.x, wy, z)] = GLASS
		#voxels[Vector3i(o.x + w - 1, wy, z)] = GLASS
	#
	## Interior: clear space
	#for x in range(scale, w-scale):
		#for y in range(scale, h-scale):
			#for z in range(scale, d-scale):
				#voxels[Vector3i(o.x + x, o.y + y, o.z + z)] = AIR


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

func _is_window_row(y_local: int, layout_scale: int) -> bool:
	# choose a band around y ≈ 2 blocks high in geometric terms
	var wy := 2 * layout_scale
	return y_local >= wy and y_local < wy + max(1, layout_scale)
	
func _wall_block_for(y: int) -> int:
	# Place windows at y==2 otherwise planks
	return (GLASS if y == 2 else PLANKS)
	
func _place(voxels: Dictionary, p: Vector3i, v: int, a: int) -> void:
	# expand a single voxel into an a×a×a block
	if a <= 1:
		voxels[p] = v
		return
	for dz in a:
		for dy in a:
			for dx in a:
				voxels[Vector3i(p.x + dx, p.y + dy, p.z + dz)] = v


func _fill_rect(voxels: Dictionary, o: Vector3i, size: Vector3i, v: int, a: int) -> void:
	for x in size.x:
		for y in size.y:
			for z in size.z:
				_place(voxels, Vector3i(o.x + x, o.y + y, o.z + z), v, a)

#func _fill_rect(voxels: Dictionary, o: Vector3i, size: Vector3i, v: int) -> void:
	#for x in range(size.x):
		#for y in range(size.y):
			#for z in range(size.z):
				#voxels[Vector3i(o.x + x, o.y + y, o.z + z)] = v


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
