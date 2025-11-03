#tool
extends VoxelGeneratorScript

const Structure = preload("./structure.gd")
const TreeGenerator = preload("./tree_generator.gd")
const VillageGenerator = preload("./village_generator.gd")
const CubeGenerator = preload("./cube_generator.gd")

# Helper: paste a Structure if it overlaps this block
func _place_if_intersect(buffer: VoxelBuffer, origin: Vector3i, s: Structure, lower_world: Vector3i) -> void:
	if s == null: return
	var vt := buffer.get_voxel_tool()
	var block_size := buffer.get_size()

	var aabb_block := AABB(Vector3(origin), Vector3(block_size))
	var aabb_struct := AABB(Vector3(lower_world), Vector3(s.voxels.get_size()))

	if aabb_struct.intersects(aabb_block):
		var local_pos := lower_world - origin
		vt.paste_masked(
			local_pos,
			s.voxels,
			1 << VoxelBuffer.CHANNEL_TYPE,
			VoxelBuffer.CHANNEL_TYPE,
			-1  # don't mask out anything; full paste
		)
var _cube_structure: Structure = null
var enable_copper_cube := true
var copper_cube_size := 50
var copper_cube_seed := 20251031  # pick any; change for a different pattern

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
@export var structure_scale := 1 # integer >= 1; scales trees & village voxels

var _tree_structures: Array = []
var _village_structure: Structure = null

# For intersection culling when stamping structures
var _trees_min_y := 0
var _trees_max_y := 0
var _villages_min_y := 0
var _villages_max_y := 0

# Store village exclusion zone
var _village_exclusion_zone: AABB


func _init():
	# Apply scaling factor
	var scale_factor := structure_scale if enable_structure_scale else 1
	var tree_scale := Vector3(scale_factor, scale_factor, scale_factor)
	var village_scale := Vector3(scale_factor, scale_factor, scale_factor)
	
	# Pre-bake a pool of varied trees
	var tree_generator := TreeGenerator.new()
	tree_generator.log_type = LOG
	tree_generator.leaves_type = LEAVES
	
	# Generate multiple tree variations with different scales
	var tree_count = 8  # Create 8 different tree types
	for i in tree_count:
		# Vary the tree scale for diversity
		var tree_stretch := Vector3(1, 1, 1)
		var tree_grow := 1
		
		match i:
			0: # Normal tree
				tree_stretch = Vector3(1, 1, 1)
				tree_grow = 1
			1: # Tall thin tree
				tree_stretch = Vector3(1, 1.5, 1)
				tree_grow = 1
			2: # Short wide tree
				tree_stretch = Vector3(1.3, 0.8, 1.3)
				tree_grow = 1
			3: # Very tall tree
				tree_stretch = Vector3(1, 2, 1)
				tree_grow = 1
			4: # Slightly bigger normal tree
				tree_stretch = Vector3(1, 1, 1)
				tree_grow = 2
			5: # Wide squat tree
				tree_stretch = Vector3(1.5, 0.7, 1.5)
				tree_grow = 1
			6: # Tall and wide tree
				tree_stretch = Vector3(1.2, 1.3, 1.2)
				tree_grow = 1
			7: # Small tree
				tree_stretch = Vector3(0.8, 0.8, 0.8)
				tree_grow = 1
		
		# Apply global scale to tree stretch
		var final_stretch := Vector3(
			tree_stretch.x * tree_scale.x,
			tree_stretch.y * tree_scale.y,
			tree_stretch.z * tree_scale.z
		)
		var tree_struct = tree_generator.generate(final_stretch, tree_grow)
		_tree_structures.append(tree_struct)
		
		print("Generated tree ", i, " with size: ", tree_struct.voxels.get_size())
	
	# Pre-bake one village (contains 5 houses)
	var vg := VillageGenerator.new()
	_village_structure = vg.generate(village_scale, 1)
	
	if _village_structure:
		print("Generated village with size: ", _village_structure.voxels.get_size())
		print("Village offset: ", _village_structure.offset)
		
		# Calculate village exclusion zone with buffer
		var village_size := _village_structure.voxels.get_size()
		# Village is centered around origin, accounting for offset
		var village_min := Vector3(-int(village_size.x)/2, SURFACE_Y, -int(village_size.z)/2)
		var buffer_distance := 15  # Keep trees at least 15 blocks away from village edges
		
		_village_exclusion_zone = AABB(
			village_min - Vector3(buffer_distance, 0, buffer_distance),
			Vector3(village_size.x + buffer_distance * 2, village_size.y + 10, village_size.z + buffer_distance * 2)
		)
		
		print("Village exclusion zone: ", _village_exclusion_zone)
	else:
		print("WARNING: Village structure failed to generate!")
	
	# Y bounds for visibility checks
	var tallest_tree_h := 0
	for s in _tree_structures:
		tallest_tree_h = max(tallest_tree_h, int(s.voxels.get_size().y))
	_trees_min_y = SURFACE_Y
	_trees_max_y = SURFACE_Y + tallest_tree_h + 5  # Add buffer
	
	if _village_structure:
		_villages_min_y = SURFACE_Y
		_villages_max_y = SURFACE_Y + int(_village_structure.voxels.get_size().y) + 5
	
	if enable_copper_cube:
		var cube_gen := CubeGenerator.new()
		_cube_structure = cube_gen.generate(copper_cube_size, 5, copper_cube_seed)
		if _cube_structure:
			print("Copper cube ready: size = ", _cube_structure.voxels.get_size(), " offset = ", _cube_structure.offset)

	print("Trees Y range: ", _trees_min_y, " to ", _trees_max_y)
	print("Village Y range: ", _villages_min_y, " to ", _villages_max_y)

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
	
	# ---- Stamp village FIRST (so trees don't overlap) ----
	if _village_structure and oy <= _villages_max_y and oy + block_size >= _villages_min_y:
		var voxel_tool2 := buffer.get_voxel_tool()
		var block_aabb2 := AABB(Vector3(origin_in_voxels), buffer.get_size())
		
		# Village is centered around origin
		var village_size := _village_structure.voxels.get_size()
		var village_pos := Vector3(
			-int(village_size.x)/2, 
			SURFACE_Y + 1,  # Place on top of grass
			-int(village_size.z)/2
		)
		
		var lower2 := village_pos - _village_structure.offset
		var village_aabb := AABB(lower2, Vector3(_village_structure.voxels.get_size()))
		
		if village_aabb.intersects(block_aabb2):
			var local_pos := lower2 - Vector3(origin_in_voxels)
			voxel_tool2.paste_masked(
				local_pos, 
				_village_structure.voxels, 
				1 << VoxelBuffer.CHANNEL_TYPE, 
				VoxelBuffer.CHANNEL_TYPE, 
				AIR
			)
			print("Stamped village in block at origin: ", origin_in_voxels)
	
	# ---- Stamp trees ----
	if oy <= _trees_max_y and oy + block_size >= _trees_min_y:
		var voxel_tool := buffer.get_voxel_tool()
		var block_aabb := AABB(Vector3(origin_in_voxels), buffer.get_size())
		var structure_instances := []
		
		# Get trees from current chunk and neighboring chunks
		_get_tree_instances_in_chunk(chunk_pos, origin_in_voxels, block_size, structure_instances)
		for dir in _moore_dirs:
			_get_tree_instances_in_chunk((chunk_pos + dir).round(), origin_in_voxels, block_size, structure_instances)
		
		# Stamp each tree
		for inst in structure_instances:
			var pos: Vector3 = inst[0]
			var s: Structure = inst[1]
			var lower := pos - s.offset
			var aabb := AABB(lower, Vector3(s.voxels.get_size()))
			
			if aabb.intersects(block_aabb):
				var local_pos := lower - Vector3(origin_in_voxels)
				voxel_tool.paste_masked(
					local_pos, 
					s.voxels, 
					1 << VoxelBuffer.CHANNEL_TYPE, 
					VoxelBuffer.CHANNEL_TYPE, 
					AIR
				)
	
	if _cube_structure:
		var voxel_tool := buffer.get_voxel_tool()
		var block_aabb := AABB(Vector3(origin_in_voxels), buffer.get_size())

		var cube_center := Vector3(0, SURFACE_Y + 1 + int(_cube_structure.voxels.get_size().y) / 2, 0)
		var lower := cube_center - _cube_structure.offset
		var cube_aabb := AABB(lower, Vector3(_cube_structure.voxels.get_size()))

		if cube_aabb.intersects(block_aabb):
			var local_pos := lower - Vector3(origin_in_voxels)
			voxel_tool.paste_masked(
				local_pos,
				_cube_structure.voxels,
				1 << VoxelBuffer.CHANNEL_TYPE,
				VoxelBuffer.CHANNEL_TYPE,
				AIR # don’t overwrite air inside structure
			)
	
	buffer.compress_uniform_channels()


static func _get_chunk_seed_2d(cpos: Vector3) -> int:
	return int(cpos.x) ^ (31 * int(cpos.z))

func _get_tree_instances_in_chunk(cpos: Vector3, offset: Vector3, chunk_size: int, out: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _get_chunk_seed_2d(cpos)
	
	for i in TREE_DENSITY_PER_CHUNK:
		var pos := Vector3(rng.randi() % chunk_size, 0, rng.randi() % chunk_size)
		pos += cpos * chunk_size
		
		# Place trunk base at grass level (SURFACE_Y)
		pos.y = SURFACE_Y + 1  # One block above grass for trunk base
		
		# Check if this tree position is inside the village exclusion zone
		if _is_in_village_exclusion_zone(pos):
			continue  # Skip this tree
		
		# Use a varied tree structure based on position (deterministic but varied)
		var tree_variant_seed := int(pos.x * 73856093) ^ int(pos.z * 19349663)
		var si = abs(tree_variant_seed) % _tree_structures.size()
		var s: Structure = _tree_structures[si]
		
		out.append([pos, s])

func _is_in_village_exclusion_zone(world_pos: Vector3) -> bool:
	if not _village_structure:
		return false
	
	# Check if the point is inside the exclusion zone (XZ plane check)
	return _village_exclusion_zone.has_point(world_pos)
