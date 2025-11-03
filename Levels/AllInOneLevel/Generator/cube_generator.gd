# This generator is a way to test a cube of voxels, whether that be a cube of a type which has a mix of voxels
# or a single type to measure dimensions
extends Resource
const Structure = preload("./structure.gd")

# Block IDs (from your library)
const COPPER  := [27, 28, 29] # normal, bright, dark
const CONCRETE := [30, 31, 32] # light, normal, dark

var channel := VoxelBuffer.CHANNEL_TYPE

# Generates a concrete cube (size³) with N copper veins.
# Each concrete/copper voxel is randomly chosen from the 3 variants.
func generate(size: int = 50, vein_count: int = 5, seed: int = 1337) -> Structure:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# Build the structure + buffer
	var structure := Structure.new()
	# Make "pos" act as the cube center when stamping (nice & simple to place)
	structure.offset = Vector3i(size / 2, size / 2, size / 2)

	var buf := structure.voxels
	buf.create(size, size, size)

	# --- Fill concrete (random variant per voxel) ---
	for y in size:
		for z in size:
			for x in size:
				buf.set_voxel(CONCRETE[rng.randi_range(0, 2)], x, y, z, channel)

	# --- Carve copper veins ---
	# Vein paths = 3D random walks with variable thickness
	var dirs := [
		Vector3i( 1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i( 0, 1, 0), Vector3i( 0,-1, 0),
		Vector3i( 0, 0, 1), Vector3i( 0, 0,-1),
		# diagonals for more organic curves
		Vector3i( 1, 1, 0), Vector3i( 1,-1, 0), Vector3i(-1, 1, 0), Vector3i(-1,-1, 0),
		Vector3i( 1, 0, 1), Vector3i( 1, 0,-1), Vector3i(-1, 0, 1), Vector3i(-1, 0,-1),
		Vector3i( 0, 1, 1), Vector3i( 0, 1,-1), Vector3i( 0,-1, 1), Vector3i( 0,-1,-1)
	]

	for _i in vein_count:
		var p := Vector3i(
			rng.randi_range(4, size - 5),
			rng.randi_range(4, size - 5),
			rng.randi_range(4, size - 5)
		)
		var steps := rng.randi_range(int(size * 1.2), int(size * 2.0))
		var thickness := rng.randi_range(1, 3)     # radius 1..3 (vein thickness varies)

		for _s in steps:
			# paint a small blob around p
			_paint_copper_blob(buf, p, thickness, rng)

			# step to a new direction, sometimes keep direction to make longer streaks
			var d = dirs[rng.randi_range(0, dirs.size() - 1)]
			if rng.randf() < 0.65:
				# slight bias to continue "forward-ish"
				d += dirs[rng.randi_range(0, dirs.size() - 1)]
			p += d

			# clamp to stay inside cube
			p.x = clamp(p.x, 1, size - 2)
			p.y = clamp(p.y, 1, size - 2)
			p.z = clamp(p.z, 1, size - 2)

	return structure


func _paint_copper_blob(buf: VoxelBuffer, center: Vector3i, radius: int, rng: RandomNumberGenerator) -> void:
	var size_v := buf.get_size() # Vector3i
	var r2 := radius * radius
	for dz in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				# squared distance from center
				var d2 := dx * dx + dy * dy + dz * dz
				if d2 <= r2:
					var p := center + Vector3i(dx, dy, dz)
					if p.x >= 0 and p.x < size_v.x and p.y >= 0 and p.y < size_v.y and p.z >= 0 and p.z < size_v.z:
						buf.set_voxel(COPPER[rng.randi_range(0, 2)], p.x, p.y, p.z, channel)
