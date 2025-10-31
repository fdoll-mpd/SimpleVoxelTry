const Structure = preload("./structure.gd")

var trunk_len_min := 6
var trunk_len_max := 25
var log_type := 1
var leaves_type := 2
var channel := VoxelBuffer.CHANNEL_TYPE


func generate(stretch: Vector3 = Vector3(1,1,1), grow_by: int = 1) -> Structure:
	var voxels := {}
	
	# Combine stretch and grow_by into a single scale vector
	var scale := Vector3(stretch.x * grow_by, stretch.y * grow_by, stretch.z * grow_by)
	var sx := int(scale.x)
	var sy := int(scale.y)
	var sz := int(scale.z)
	
	# Scale trunk length
	var trunk_len := int(randf_range(trunk_len_min, trunk_len_max))
	var scaled_trunk_len := trunk_len * sy
	
	# Trunk - now scaled
	for y in scaled_trunk_len:
		_place_block(voxels, Vector3i(0, y, 0), log_type, scale)

	# Branches
	var branches_start := int(randf_range(trunk_len / 3, trunk_len / 2)) * sy
	for y in range(branches_start, scaled_trunk_len):
		var t := float(y - branches_start) / float(scaled_trunk_len)
		var branch_chance := 1.0 - pow(t - 0.5, 2)
		if randf() < branch_chance:
			var branch_len := int((trunk_len / 2.0) * branch_chance * randf())
			var pos := Vector3(0, y, 0)
			var angle := randf_range(-PI, PI)
			# Scale the branch direction based on x/z scale
			var dir := Vector3(cos(angle) * sx, 0.45 * sy, sin(angle) * sz).normalized()
			# Scale branch length
			var scaled_branch_len = branch_len * max(sx, sz)
			for i in scaled_branch_len:
				pos += dir
				var ipos = pos.round()
				_place_block(voxels, Vector3i(ipos), log_type, scale)

	# Leaves - scaled placement
	var log_positions := voxels.keys()
	log_positions.shuffle()
	var leaf_count := int(0.75 * len(log_positions))
	log_positions.resize(leaf_count)
	
	# Scale the leaf offsets
	var dirs := [
		Vector3i(-sx, 0, 0),
		Vector3i(sx, 0, 0),
		Vector3i(0, 0, -sz),
		Vector3i(0, 0, sz),
		Vector3i(0, sy, 0),
		Vector3i(0, -sy, 0)
	]
	
	for c in leaf_count:
		var pos = log_positions[c]
		if pos.y < branches_start:
			continue
		for di in len(dirs):
			var npos = pos + dirs[di]
			if not voxels.has(npos):
				_place_block(voxels, npos, leaves_type, scale)

	# Make structure
	var aabb := AABB()
	for pos in voxels:
		aabb = aabb.expand(pos)

	var structure := Structure.new()
	structure.offset = -aabb.position

	var buffer := structure.voxels
	buffer.create(int(aabb.size.x) + 1, int(aabb.size.y) + 1, int(aabb.size.z) + 1)

	for pos in voxels:
		var rpos: Vector3i = Vector3i(pos) + Vector3i(structure.offset)
		var v = voxels[pos]
		buffer.set_voxel(v, rpos.x, rpos.y, rpos.z, channel)

	return structure


func _place_block(voxels: Dictionary, p: Vector3i, v: int, scale: Vector3) -> void:
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
