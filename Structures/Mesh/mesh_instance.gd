extends MeshInstance3D


var surface_array: Array = []
var verticies = PackedVector3Array()
var normals = PackedVector3Array()
var colors = PackedColorArray()

func _ready() -> void:
	surface_array.resize(Mesh.ARRAY_MAX)

func generate_mesh() -> void:
	commit_mesh()

func commit_mesh() -> void:
	surface_array(Mesh.ARRAY_VERTEX) = verticies
	surface_array(Mesh.ARRAY_NORMAL) = normals
	surface_array(Mesh.ARRAY_COLOR) = colors
