#tool
extends VoxelGeneratorScript

const Structure = preload("./structure.gd")
const TreeGenerator = preload("./tree_generator.gd")
const VillageGenerator = preload("./village_generator.gd")

# Block IDs
const AIR = 0
const DIRT = 1
const GRASS = 2
const LOG = 4
const LEAVES = 25
const TALL_GRASS = 8
const DEAD_SHRUB = 26

const _CHANNEL = VoxelBuffer.CHANNEL_TYPE

const _moore_dirs = [
	Vector3(-1, 0, -1), Vector3(0, 0, -1), Vector3(1, 0, -1),
	Vector3(-1, 0,  0),                         Vector3(1, 0,  0),
	Vector3(-1, 0,  1), Vector3(0,  0,  1), Vector3(1, 0,  1)
]

const SURFACE_Y := 1  
const DIRT_DEPTH := 5 
const TREE_DENSITY_PER_CHUNK := 2  # tries per 16x16 chunk


# === Scaling toggles ===
@export var enable_structure_scale := false
@export var structure_scale := 2 # integer >= 1; scales trees & village voxels

var _tree_structures: Array = []
var _village_structure: Structure = null

# For intersection culling when stamping structures
var _trees_min_y := 0
var _trees_max_y := 0
var _villages_min_y := 0
var _villages_max_y := 0


# Returns a new Structure where each voxel is expanded to an a×a×a block
func _scale_structure(s: Structure, a: int) -> Structure:
	if a <= 1 or s == null:
		return s
	var src := s.voxels
	var sz := src.get_size()
	var out := Structure.new()
	out.offset = s.offset * float(a)
	out.voxels.create(sz.x * a, sz.y * a, sz.z * a)
	var vt := out.voxels.get_voxel_tool()
	for z in sz.z:
		for y in sz.y:
			for x in sz.x:
				var v := src.get_voxel(x, y, z, VoxelBuffer.CHANNEL_TYPE)
				if v != 0:
					var base := Vector3i(x * a, y * a, z * a)
					# fill a^3 region with v
					out.voxels.fill_area(v, base, base + Vector3i(a, a, a), VoxelBuffer.CHANNEL_TYPE)
	return out
func _init():
	# Pre-bake a pool of trees
	var tree_generator := TreeGenerator.new()
	tree_generator.log_type = LOG
	tree_generator.leaves_type = LEAVES
	for i in 16:
		_tree_structures.append(tree_generator.generate())
	
	# Pre-bake one village (contains 3 houses + trees)
	var vg := VillageGenerator.new()
	_village_structure = vg.generate(2)
	# Optional scaling
	#if enable_structure_scale and structure_scale > 1:
		#var scaled_list := []
		#for s in _tree_structures:
			#scaled_list.append(_scale_structure(s, structure_scale))
		#_tree_structures = scaled_list
		#_village_structure = _scale_structure(_village_structure, structure_scale)
	
	# Y bounds for visibility checks
	var tallest_tree_h := 0
	for s in _tree_structures:
		tallest_tree_h = max(tallest_tree_h, int(s.voxels.get_size().y))
	_trees_min_y = SURFACE_Y
	_trees_max_y = SURFACE_Y + tallest_tree_h
	
	if _village_structure:
		_villages_min_y = SURFACE_Y
		_villages_max_y = SURFACE_Y + int(_village_structure.voxels.get_size().y)

func _get_used_channels_mask() -> int:
	return 1 << _CHANNEL

func _generate_block(buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int) -> void:
	var block_size := int(buffer.get_size().x)
	var oy := origin_in_voxels.y
	
	# Chunk position (size assumed 16 for RNG tiling; adjust if your block size differs)
	var chunk_pos := Vector3(
		origin_in_voxels.x >> 4,
		origin_in_voxels.y >> 4,
		origin_in_voxels.z >> 4)
	
	# ---- Flat ground ----
	# Fill below our plane with dirt, put grass at SURFACE_Y, and air above.
	var gy0 := SURFACE_Y - DIRT_DEPTH          # base of dirt
	var gy1 := SURFACE_Y                       # grass y
	
	# If this whole block is entirely above the grass layer, fill with air
	if oy > gy1:
		buffer.fill(AIR, _CHANNEL)
	# If this whole block is entirely below the dirt base, fill with dirt
	elif oy + block_size <= gy0:
		buffer.fill(DIRT, _CHANNEL)
	else:
		# Mixed block: lay dirt/grass/air columns per (x,z)
		var rng := RandomNumberGenerator.new()
		rng.seed = _get_chunk_seed_2d(chunk_pos)
		
		for z in block_size:
			for x in block_size:
				# Column world-space Y extents
				var col_min := oy
				var col_max := oy + block_size - 1
				
				# Dirt part intersects this buffer?
				var dirt_top := gy1 - 1
				var dirt_start = max(col_min, gy0)
				var dirt_end = min(col_max, dirt_top)
				if dirt_end >= dirt_start:
					buffer.fill_area(DIRT, Vector3(x, dirt_start - oy, z), Vector3(x+1, dirt_end - oy + 1, z+1), _CHANNEL)
				
				# Grass at SURFACE_Y if inside this buffer
				if gy1 >= col_min and gy1 <= col_max:
					buffer.set_voxel(GRASS, x, gy1 - oy, z, _CHANNEL)
					# Some tall grass on top
					if gy1 + 1 <= col_max and rng.randf() < 0.1:
						buffer.set_voxel(DEAD_SHRUB if rng.randf() < 0.15 else TALL_GRASS, x, gy1 - oy + 1, z, _CHANNEL)
	
	# ---- Stamp trees ----
	if oy <= _trees_max_y and oy + block_size >= _trees_min_y:
		var voxel_tool := buffer.get_voxel_tool()
		var block_aabb := AABB(Vector3(), buffer.get_size() + Vector3i(1,1,1))
		var structure_instances := []
		_get_tree_instances_in_chunk(chunk_pos, origin_in_voxels, block_size, structure_instances)
		for dir in _moore_dirs:
			_get_tree_instances_in_chunk((chunk_pos + dir).round(), origin_in_voxels, block_size, structure_instances)
		for inst in structure_instances:
			var pos: Vector3 = inst[0]
			var s: Structure = inst[1]
			var lower := pos - s.offset
			var aabb := AABB(lower, s.voxels.get_size() + Vector3i(1,1,1))
			if aabb.intersects(block_aabb):
				voxel_tool.paste_masked(lower, s.voxels, 1 << VoxelBuffer.CHANNEL_TYPE, VoxelBuffer.CHANNEL_TYPE, AIR)
	
	# ---- Stamp a single village near origin ----
	# Place once, centered near (0, SURFACE_Y, 0). We add +Vector3(0,1,0) to ensure it's not cut by the seam.
	if _village_structure and oy <= _villages_max_y and oy + block_size >= _villages_min_y:
		var voxel_tool2 := buffer.get_voxel_tool()
		var block_aabb2 := AABB(Vector3(), buffer.get_size() + Vector3i(1,1,1))
		# choose a fixed world-space location
		var village_pos := Vector3( -int(_village_structure.voxels.get_size().x)/2, SURFACE_Y, -int(_village_structure.voxels.get_size().z)/2 )
		var lower2 := village_pos - _village_structure.offset
		var local_pos: Vector3 = village_pos - Vector3(origin_in_voxels)
		var lower2_local: Vector3 = local_pos - _village_structure.offset
		var aabb2 := AABB(lower2_local, _village_structure.voxels.get_size() + Vector3i(1,1,1))
		if aabb2.intersects(block_aabb2):
			voxel_tool2.paste_masked(lower2_local, _village_structure.voxels, 1 << VoxelBuffer.CHANNEL_TYPE, VoxelBuffer.CHANNEL_TYPE, AIR)
	
	buffer.compress_uniform_channels()

# ----- Helpers -----

static func _get_chunk_seed_2d(cpos: Vector3) -> int:
	return int(cpos.x) ^ (31 * int(cpos.z))

func _get_tree_instances_in_chunk(cpos: Vector3, offset: Vector3, chunk_size: int, out: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _get_chunk_seed_2d(cpos)
	for i in TREE_DENSITY_PER_CHUNK:
		var pos := Vector3(rng.randi() % chunk_size, 0, rng.randi() % chunk_size)
		pos += cpos * chunk_size
		# place on our flat plane
		pos.y = SURFACE_Y + 1  # trunk base at SURFACE_Y + 1 (one above grass top) so paste won't overwrite grass
		pos -= offset
		var si := rng.randi() % _tree_structures.size()
		var s: Structure = _tree_structures[si]
		out.append([pos.round(), s])
