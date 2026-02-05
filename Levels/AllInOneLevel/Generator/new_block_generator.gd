extends Resource
class_name WorldGeneratorStructures


const Structure = preload("./structure.gd")

const Copper := {"light": 28, "normal": 27, "dark": 29}
const Concrete := {"light": 30, "normal": 31, "dark": 32}

const Planks := {"light": 33, "normal": 35, "dark": 34}
const Log := {"light": 38, "normal": 37, "dark": 36}

const Dirt := {"light": 40, "normal": 39, "dark": 41}
const Grass_Yellow := {"light": 44, "normal": 43, "dark": 42}
const Grass_Green := {"light": 47, "normal": 46, "dark": 45}


const TYPE_CH := VoxelBuffer.CHANNEL_TYPE

#@export var SURFACE_Y := 64  
#@export var GRASS_DEPTH := 2   
#@export var DIRT_DEPTH := 15     
@export var SURFACE_Y := 0  
@export var GRASS_DEPTH := 4   
@export var DIRT_DEPTH := 15                     
@export var grass_is_green := true           
@export var enable_wall := true
@export var wall_size := Vector3i(10, 20, 40) 
@export var wall_pos := Vector3i(-60, SURFACE_Y + 1, -20)

@export var enable_copper_cube := true
@export var copper_cube_size := 30
@export var copper_cube_pos := Vector3i(0, SURFACE_Y + 1, 0)
@export var copper_vein_count := 5
@export var copper_seed := 20251031

@export var enable_planks_cube := true
@export var planks_cube_size := 5
@export var planks_cube_pos := Vector3i(50, SURFACE_Y + 1, -10)

@export var enable_house := true
@export var house_size := Vector3i(30, 16, 22) 
@export var house_pos := Vector3i(-10, SURFACE_Y + 1, 50)
@export var window_size := Vector3i(3, 2, 1) 
@export var door_size := Vector3i(2, 3, 1) 

@export var enable_table := true
@export var table_size := Vector3i(25, 50, 25)
@export var table_pos := Vector3i(100, SURFACE_Y + 1, 0)

var _rng := RandomNumberGenerator.new()
var _S_wall: Structure
var _S_copper_cube: Structure
var _S_planks_cube: Structure
var _S_house: Structure
var _S_table: Structure

func _init() -> void:
	_rng.seed = int(Time.get_unix_time_from_system())

	if enable_wall:
		_S_wall = _gen_wall(wall_size)
	if enable_copper_cube:
		_S_copper_cube = _gen_concrete_cube_with_hidden_copper(copper_cube_size, copper_vein_count, copper_seed)
	if enable_planks_cube:
		_S_planks_cube = _gen_solid_cube(planks_cube_size, Planks)
	if enable_house:
		_S_house = _gen_house(house_size)
	if enable_table:
		_S_table = _gen_tall_table(table_size)

func _generate_block(buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int) -> void:
	_fill_ground(buffer, origin_in_voxels)

	var tool := buffer.get_voxel_tool()
	var block_aabb := AABB(Vector3(origin_in_voxels), Vector3(buffer.get_size()))

	if _S_wall:
		_stamp_structure_if_intersect(tool, block_aabb, _S_wall, wall_pos)

	if _S_copper_cube:
		_stamp_structure_if_intersect(tool, block_aabb, _S_copper_cube, copper_cube_pos)

	if _S_planks_cube:
		_stamp_structure_if_intersect(tool, block_aabb, _S_planks_cube, planks_cube_pos)

	if _S_house:
		_stamp_structure_if_intersect(tool, block_aabb, _S_house, house_pos)
	
	if _S_table:
		_stamp_structure_if_intersect(tool, block_aabb, _S_table, table_pos)

func _fill_ground(buffer: VoxelBuffer, origin: Vector3i) -> void:
	var size := Vector3i(buffer.get_size())
	var grass_ids := [ (Grass_Green.light if grass_is_green else Grass_Yellow.light),
					   (Grass_Green.normal if grass_is_green else Grass_Yellow.normal),
					   (Grass_Green.dark if grass_is_green else  Grass_Yellow.dark) ]
	var dirt_ids := [Dirt.light, Dirt.normal, Dirt.dark]

	for ly in size.y:
		var gy := origin.y + ly
		if gy >= SURFACE_Y - (GRASS_DEPTH - 1) and gy <= SURFACE_Y:
			# grass
			for lz in size.z:
				for lx in size.x:
					buffer.set_voxel(_pick(grass_ids), lx, ly, lz, TYPE_CH)
		# DIRT_DEPTH layers under grass
		elif gy >= SURFACE_Y - (GRASS_DEPTH + DIRT_DEPTH) and gy < SURFACE_Y - (GRASS_DEPTH - 1):
			for lz in size.z:
				for lx in size.x:
					buffer.set_voxel(_pick(dirt_ids), lx, ly, lz, TYPE_CH)

func _gen_wall(sz: Vector3i) -> Structure:
	var S := Structure.new()
	S.offset = Vector3i(0, 0, 0) 
	var buf := S.voxels
	buf.create(sz.x, sz.y, sz.z)
	var ids := [Concrete.light, Concrete.normal, Concrete.dark]
	for y in sz.y:
		for z in sz.z:
			for x in sz.x:
				buf.set_voxel(_pick(ids), x, y, z, TYPE_CH)
	return S


func _gen_solid_cube(size: int, palette: Dictionary) -> Structure:
	var S := Structure.new()
	S.offset = Vector3i(0, 0, 0)
	var buf := S.voxels
	buf.create(size, size, size)
	var ids := [palette.light, palette.normal, palette.dark]
	for y in size:
		for z in size:
			for x in size:
				buf.set_voxel(_pick(ids), x, y, z, TYPE_CH)
	return S

func _gen_concrete_cube_with_hidden_copper(size: int, vein_count: int, seed: int) -> Structure:
	var S := Structure.new()
	S.offset = Vector3i(0, 0, 0)
	var buf := S.voxels
	buf.create(size, size, size)

	var c_ids := [Concrete.light, Concrete.normal, Concrete.dark]
	var cu_ids := [Copper.light, Copper.normal, Copper.dark]


	for y in size:
		for z in size:
			for x in size:
				buf.set_voxel(_pick(c_ids), x, y, z, TYPE_CH)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var inner_min := 1
	var inner_max := size - 2

	var dirs := [
		Vector3i( 1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i( 0, 1, 0), Vector3i( 0,-1, 0),
		Vector3i( 0, 0, 1), Vector3i( 0, 0,-1),
		Vector3i( 1, 1, 0), Vector3i( 1,-1, 0), Vector3i(-1, 1, 0), Vector3i(-1,-1, 0),
		Vector3i( 1, 0, 1), Vector3i( 1, 0,-1), Vector3i(-1, 0, 1), Vector3i(-1, 0,-1),
		Vector3i( 0, 1, 1), Vector3i( 0, 1,-1), Vector3i( 0,-1, 1), Vector3i( 0,-1,-1)
	]

	for _i in vein_count:
		var p := Vector3i(
			rng.randi_range(inner_min + 2, inner_max - 2),
			rng.randi_range(inner_min + 2, inner_max - 2),
			rng.randi_range(inner_min + 2, inner_max - 2)
		)
		var steps := rng.randi_range(int(size * 1.2), int(size * 2.0))
		var radius := rng.randi_range(1, 2) 

		for _s in steps:
			_paint_blob(buf, p, radius, cu_ids, rng, Vector3i(inner_min, inner_min, inner_min), Vector3i(inner_max, inner_max, inner_max))
			# step
			var d = dirs[rng.randi_range(0, dirs.size() - 1)]
			if rng.randf() < 0.6:
				d += dirs[rng.randi_range(0, dirs.size() - 1)]
			p += d
			# clamp to inner area so copper never touches faces
			p.x = clamp(p.x, inner_min + 1, inner_max - 1)
			p.y = clamp(p.y, inner_min + 1, inner_max - 1)
			p.z = clamp(p.z, inner_min + 1, inner_max - 1)


	for x in size:
		for y in size:
			buf.set_voxel(_pick(c_ids), x, y, 0, TYPE_CH)
			buf.set_voxel(_pick(c_ids), x, y, size - 1, TYPE_CH)
	for z in size:
		for y in size:
			buf.set_voxel(_pick(c_ids), 0, y, z, TYPE_CH)
			buf.set_voxel(_pick(c_ids), size - 1, y, z, TYPE_CH)
	for x in size:
		for z in size:
			buf.set_voxel(_pick(c_ids), x, 0, z, TYPE_CH)
			buf.set_voxel(_pick(c_ids), x, size - 1, z, TYPE_CH)

	return S

func _gen_house(sz: Vector3i) -> Structure:
	# Require some minimal sizes to fit features
	var W = max(sz.x, 12)
	var H = max(sz.y, 8)
	var D = max(sz.z, 12)

	var S := Structure.new()
	S.offset = Vector3i(0, 0, 0)
	var buf := S.voxels
	buf.create(W, H, D)

	var plank_ids := [Planks.light, Planks.normal, Planks.dark]
	var log_ids := [Log.light, Log.normal, Log.dark]
	var concrete_ids := [Concrete.light, Concrete.normal, Concrete.dark] # for floor if desired


	for z in D:
		for x in W:
			buf.set_voxel(_pick(plank_ids), x, 0, z, TYPE_CH)

	var P := 4
	var corners := [
		Rect2i(0, 0, P, P),   
		Rect2i(W - P, 0, P, P),  
		Rect2i(0, D - P, P, P),  
		Rect2i(W - P, D - P, P, P)  
	]
	for y in H:
		for r in corners:
			for z in r.size.y:
				for x in r.size.x:
					buf.set_voxel(_pick(log_ids), r.position.x + x, y, r.position.y + z, TYPE_CH)

	for y in range(1, H - 1):
		var zN := P - 1
		var zS = D - P
		for x in range(P, W - P):
			buf.set_voxel(_pick(plank_ids), x, y, zN, TYPE_CH)
			buf.set_voxel(_pick(plank_ids), x, y, zS, TYPE_CH) 

		var xW := P - 1
		var xE = W - P
		for z in range(P, D - P):
			buf.set_voxel(_pick(plank_ids), xW, y, z, TYPE_CH) 
			buf.set_voxel(_pick(plank_ids), xE, y, z, TYPE_CH)

	for z in D:
		for x in W:
			buf.set_voxel(_pick(plank_ids), x, H - 1, z, TYPE_CH)

	_make_window(buf, "N", W, H, D, window_size)
	_make_window(buf, "E", W, H, D, window_size)
	_make_window(buf, "S", W, H, D, window_size)
	_make_door(buf, "W", W, H, D, door_size)

	return S

func _make_window(buf: VoxelBuffer, side: String, W: int, H: int, D: int, wsize: Vector3i) -> void:
	var wx := wsize.x
	var wy := wsize.y
	var wz = max(1, wsize.z)
	var cy = max(2, H / 2) # vertical placement
	match side:
		"N":
			var z := 3 
			var x0 := (W - wx) / 2
			for y in range(cy, cy + wy):
				for x in range(x0, x0 + wx):
					buf.set_voxel(0, x, y, z, TYPE_CH)
		"E": # at x = W-P
			var x := W - 4
			var z0 := (D - wx) / 2
			for y in range(cy, cy + wy):
				for z in range(z0, z0 + wx):
					buf.set_voxel(0, x, y, z, TYPE_CH)
		"S": # at z = D-P
			var z := D - 4
			var x0 := (W - wx) / 2
			for y in range(cy, cy + wy):
				for x in range(x0, x0 + wx):
					buf.set_voxel(0, x, y, z, TYPE_CH)
		"W": # reserved for door
			pass

func _make_door(buf: VoxelBuffer, side: String, W: int, H: int, D: int, dsize: Vector3i) -> void:
	var dx := dsize.x
	var dy := dsize.y
	var dz = max(1, dsize.z)
	var base_y := 1
	match side:
		"W":
			var x := 3
			var z0 := (D - dx) / 2
			for y in range(base_y, base_y + dy):
				for z in range(z0, z0 + dx):
					buf.set_voxel(0, x, y, z, TYPE_CH)
		_:
			# Fallback: put door on North if side not recognized
			var z := 3
			var x0 := (W - dx) / 2
			for y in range(base_y, base_y + dy):
				for x in range(x0, x0 + dx):
					buf.set_voxel(0, x, y, z, TYPE_CH)
					
func _pick(ids: Array) -> int:
	return ids[int(randi()) % ids.size()]

func _gen_tall_table(sz: Vector3i) -> Structure:
	# Require some minimal sizes to fit features
	var W = max(sz.x, 24)
	var H = max(sz.y, 50)
	var D = max(sz.z, 24)

	var S := Structure.new()
	S.offset = Vector3i(0, 0, 0)
	var buf := S.voxels
	buf.create(W, H, D)

	var plank_ids := [Planks.light, Planks.normal, Planks.dark]
	var P := 4
	var corners := [
		Rect2i(0, 0, P, P),   
		Rect2i(W - P, 0, P, P),  
		Rect2i(0, D - P, P, P),  
		Rect2i(W - P, D - P, P, P)  
	]
	for y in H:
		for r in corners:
			for z in r.size.y:
				for x in r.size.x:
					buf.set_voxel(_pick(plank_ids), r.position.x + x, y, r.position.y + z, TYPE_CH)
	
	for z in D:
		for x in W:
			buf.set_voxel(_pick(plank_ids), x, H-P, z, TYPE_CH)

	return S

func _paint_blob(buf: VoxelBuffer, center: Vector3i, radius: int, ids: Array, rng: RandomNumberGenerator, inner_min: Vector3i, inner_max: Vector3i) -> void:
	var r2 := radius * radius
	for dz in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var d2 := dx * dx + dy * dy + dz * dz
				if d2 <= r2:
					var p := center + Vector3i(dx, dy, dz)
					if p.x >= inner_min.x and p.x <= inner_max.x and p.y >= inner_min.y and p.y <= inner_max.y and p.z >= inner_min.z and p.z <= inner_max.z:
						buf.set_voxel(ids[rng.randi_range(0, ids.size() - 1)], p.x, p.y, p.z, TYPE_CH)

func _stamp_structure_if_intersect(tool: VoxelTool, block_aabb: AABB, S: Structure, world_pos: Vector3i) -> void:
	var size_i := S.voxels.get_size()
	var size_v := Vector3(size_i.x, size_i.y, size_i.z)

	var world_pos_v := Vector3(world_pos.x, world_pos.y, world_pos.z)
	var offset_v := Vector3(S.offset.x, S.offset.y, S.offset.z)  
	var lower_v := world_pos_v - offset_v

	var aabb := AABB(lower_v, size_v)
	if not aabb.intersects(block_aabb):
		return
	var local_v := lower_v - block_aabb.position

	var local_i := Vector3i(int(local_v.x), int(local_v.y), int(local_v.z))
	tool.paste(local_i, S.voxels, TYPE_CH)
