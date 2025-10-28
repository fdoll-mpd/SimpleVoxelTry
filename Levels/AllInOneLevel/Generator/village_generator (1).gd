#tool
extends Resource

const Structure = preload("./structure.gd")

# Block IDs
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

# Public API: geometric scale (layout_scale) and per-voxel replication (block_scale)
# layout_scale multiplies dimensions and spacing.
# block_scale expands each *placed voxel* into an a×a×a cluster.
func generate(layout_scale: int = 1, block_scale: int = 1) -> Structure:
	layout_scale = max(layout_scale, 1)
	block_scale = max(block_scale, 1)

	var voxels := {}

	# Layout parameters
	var house_count := 3
	var spacing := 24 * layout_scale   # distance between house origins
	var origin := Vector3i(0, 1, 0)    # build one block above Y=0 to avoid seam artifacts

	for i in house_count:
		var hx := i * spacing
		var house_origin := origin + Vector3i(hx, 0, 0)
		_build_house(voxels, house_origin, Vector3i(9, 6, 7), layout_scale, block_scale)

		# Front yard pad + path (geometric scale only; each cell still expanded by block_scale via _fill_rect)
		_fill_rect(voxels, house_origin + Vector3i(-2 * layout_scale, -1, -3 * layout_scale),
			Vector3i(13 * layout_scale, 1, 3 * layout_scale), GRASS, block_scale)
		_fill_rect(voxels, house_origin + Vector3i(3 * layout_scale, -1, -6 * layout_scale),
			Vector3i(3 * layout_scale, 1, 3 * layout_scale), DIRT, block_scale)

		# Trees left/right/front (simple trees; unscaled shape, but placed using block_scale)
		_build_tree(voxels, house_origin + Vector3i(-4 * layout_scale, 0,  4 * layout_scale), block_scale)
		_build_tree(voxels, house_origin + Vector3i(12 * layout_scale, 0,  4 * layout_scale), block_scale)
		_build_tree(voxels, house_origin + Vector3i( 4 * layout_scale, 0, -8 * layout_scale), block_scale)

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


func _is_window_row(y_local: int, layout_scale: int) -> bool:
	# choose a band around y ≈ 2 blocks high in geometric terms
	var wy := 2 * layout_scale
	return y_local >= wy and y_local < wy + max(1, layout_scale)


func _build_house(voxels: Dictionary, o: Vector3i, base_dims: Vector3i, layout_scale: int, a: int) -> void:
	var w := base_dims.x * layout_scale
	var h := base_dims.y * layout_scale
	var d := base_dims.z * layout_scale

	# Foundation (dirt) and floor (planks)
	_fill_rect(voxels, o + Vector3i(0, -1, 0), Vector3i(w, 1, d), DIRT, a)
	_fill_rect(voxels, o + Vector3i(0,  0, 0), Vector3i(w, 1, d), PLANKS, a)

	# Corner posts (vertical logs), thickness = layout_scale
	var t = max(1, layout_scale)
	var corners := [
		o + Vector3i(0, 0, 0),
		o + Vector3i(w - t, 0, 0),
		o + Vector3i(0, 0, d - t),
		o + Vector3i(w - t, 0, d - t)
	]
	for c in corners:
		_fill_rect(voxels, c, Vector3i(t, h, t), LOG_Y, a)

	# Walls (planks with window band). Build as solid ring of thickness t first.
	# Front/back slabs
	_fill_rect(voxels, o + Vector3i(0, 1, 0),     Vector3i(w, h - 2, t), PLANKS, a)         # front
	_fill_rect(voxels, o + Vector3i(0, 1, d - t), Vector3i(w, h - 2, t), PLANKS, a)         # back
	# Left/right slabs
	_fill_rect(voxels, o + Vector3i(0, 1, 0),     Vector3i(t, h - 2, d), PLANKS, a)         # left
	_fill_rect(voxels, o + Vector3i(w - t, 1, 0), Vector3i(t, h - 2, d), PLANKS, a)         # right

	# Carve and glaze window band
	var y0 := o.y + 1
	for y in range(y0, y0 + (h - 2)):
		var y_local := y - o.y
		if _is_window_row(y_local, layout_scale):
			# Front/back strips: carve then glass
			for x in range(o.x + t, o.x + w - t):
				# front
				for z in t:
					_place(voxels, Vector3i(x, y, o.z + z), AIR, a)
				_place(voxels, Vector3i(x, y, o.z + int(t/2)), GLASS, a)
				# back
				for z in t:
					_place(voxels, Vector3i(x, y, o.z + d - 1 - z), AIR, a)
				_place(voxels, Vector3i(x, y, o.z + d - 1 - int(t/2)), GLASS, a)
			# Left/right strips: carve then glass
			for z in range(o.z + t, o.z + d - t):
				# left
				for x in t:
					_place(voxels, Vector3i(o.x + x, y, z), AIR, a)
				_place(voxels, Vector3i(o.x + int(t/2), y, z), GLASS, a)
				# right
				for x in t:
					_place(voxels, Vector3i(o.x + w - 1 - x, y, z), AIR, a)
				_place(voxels, Vector3i(o.x + w - 1 - int(t/2), y, z), GLASS, a)

	# Door opening on front center (width = t, height = 2*layout_scale)
	var door_w = t
	var door_h = max(2 * layout_scale, t)
	var door_x0 := o.x + int((w - door_w) / 2)
	for y in range(o.y + 1, o.y + 1 + door_h):
		for x in range(door_x0, door_x0 + door_w):
			for z in t:
				_place(voxels, Vector3i(x, y, o.z + z), AIR, a)

	# Ceiling
	_fill_rect(voxels, o + Vector3i(0, h - 1, 0), Vector3i(w, t, d), PLANKS, a)

	# Simple roof border and cap
	# THis does 3x3 for the filling, review this later
	_fill_rect(voxels, o + Vector3i(0, h, 0),     Vector3i(w, t, t), LOG_X, a)
	_fill_rect(voxels, o + Vector3i(0, h, d - t), Vector3i(w, t, t), LOG_X, 1)
	_fill_rect(voxels, o + Vector3i(0, h, 0),     Vector3i(t, t, d), LOG_Z, a)
	_fill_rect(voxels, o + Vector3i(w - t, h, 0), Vector3i(t, t, d), LOG_Z, a)
	_fill_rect(voxels, o + Vector3i(t, h, t),     Vector3i(w - 2 * t, t, d - 2 * t), PLANKS, a)

	# Interior: clear
	for x in range(o.x + t, o.x + w - t):
		for y in range(o.y + t, o.y + h - t):
			for z in range(o.z + t, o.z + d - t):
				voxels[Vector3i(x, y, z)] = AIR


func _build_tree(voxels: Dictionary, root: Vector3i, a: int) -> void:
	var trunk_h := 5 + int(randf() * 3.0)
	for i in trunk_h:
		_place(voxels, Vector3i(root.x, root.y + i, root.z), LOG_Y, a)

	var top := root + Vector3i(0, trunk_h, 0)
	# Cross arms
	for dx in range(-2, 3):
		_place(voxels, Vector3i(top.x + dx, top.y, top.z), LEAVES, a)
	for dz in range(-2, 3):
		_place(voxels, Vector3i(top.x, top.y, top.z + dz), LEAVES, a)
	# Puffy canopy
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for dy in range(-1, 2):
				if abs(dx) + abs(dy) + abs(dz) <= 3:
					_place(voxels, top + Vector3i(dx, dy, dz), LEAVES, a)

	# Grass around base (not block-scaled above ground; the single-call _place will handle)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			_place(voxels, Vector3i(root.x + dx, root.y - 1, root.z + dz), GRASS, a)


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
