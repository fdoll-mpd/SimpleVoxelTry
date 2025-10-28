extends Node

const VillageGenerator = preload("./village_generator.gd")
const VoxelLibraryResource = preload("res://CopyFrom/BlockLib/blocks/voxel_library.tres")

const _materials = [
	preload("res://CopyFrom/BlockLib/blocks/terrain_material.tres"),
	preload("res://CopyFrom/BlockLib/blocks/terrain_material_foliage.tres"),
	preload("res://CopyFrom/BlockLib/blocks/terrain_material_transparent.tres")
]

@onready var _mesh_instance : MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	randomize()
	var gen = VillageGenerator.new()
	var s = gen.generate()
	
	var padded := VoxelBuffer.new()
	padded.create(s.voxels.get_size().x + 2, s.voxels.get_size().y + 2, s.voxels.get_size().z + 2)
	padded.copy_channel_from_area(s.voxels, Vector3(), s.voxels.get_size(), Vector3(1,1,1), VoxelBuffer.CHANNEL_TYPE)

	var mesher := VoxelMesherBlocky.new()
	mesher.set_library(VoxelLibraryResource)
	var mesh = mesher.build_mesh(padded, [
		preload("res://CopyFrom/BlockLib/blocks/terrain_material.tres"),
		preload("res://CopyFrom/BlockLib/blocks/terrain_material_foliage.tres"),
		preload("res://CopyFrom/BlockLib/blocks/terrain_material_transparent.tres")
	])
	_mesh_instance.mesh = mesh
