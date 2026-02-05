extends Node
enum Shapes { Rectangle, Sphere, Cylinder, Pyramid, Slope }
enum Orient { North, South, East, West, Up, Down }

# These are the IDs in the voxel blocky library
const Copper := {"light": 28, "normal": 27, "dark": 29}
const Concrete := {"light": 30, "normal": 31, "dark": 32}

const Planks := {"light": 33, "normal": 35, "dark": 34}
const Log := {"light": 38, "normal": 37, "dark": 36}

const Dirt := {"light": 40, "normal": 39, "dark": 41}
const Grass_Yellow := {"light": 44, "normal": 43, "dark": 42}
const Grass_Green := {"light": 47, "normal": 46, "dark": 45}

class BaseInfo:
	var id := 0
	var name := ""
	var sprite : Texture
	var contents := []


var base_info := BaseInfo.new()


func use(_trans: Transform3D):
	pass
