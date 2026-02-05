extends Node

# This might be a "generate block ID based on distance from edge or center"

@onready var _voxel_world : Node = get_node("/root/AllInOne/VoxelTerrain")
var _vt: VoxelTool = null

const Copper := {"light": 28, "normal": 27, "dark": 29}
const Concrete := {"light": 30, "normal": 31, "dark": 32}

var _wall_thickness: int = 3
var time_rng = randomize()

func _get_tool() -> VoxelTool:
	# Cache the tool – getting it every time is a little slower.
	if _vt == null:
		_vt = _voxel_world.get_voxel_tool()
	return _vt

func _ready() -> void:
	# Ensure we have the vt
	pass

func get_3d_distance(vector: Vector3) -> float:
	return sqrt(vector.x**2 + vector.y**2 + vector.z**2)

# Need to defend against specified thickness, so a sphere of r=2 can only have copper in middle if r = 2

func generate_block_id(distance_to_origin: Vector3, distance_to_edge: Vector3) -> int:
	if(get_3d_distance(distance_to_edge) > _wall_thickness):
		# Get some random chance to be copper now and make some dogass algo for veins
	
	return 1

# IDK what this is going to do, maybe I can concot something for this so it works as I am wantingit to 
func pseudo_vein_generator(approx_size: float):
	pass
