extends Node
# I dont like the item usage for this, instead I want some "structures"
# What these are is I specify an area and if the "structure" is selected then I fill in that area with the "structure"
const ROOT = "res://Levels/AllInOneLevel/Structures/"

const Item = preload("./structure.gd")


var _items := []


func _init():
	_create_item({
		"name": "copper_wall",
		"behavior": "copper_wall.gd"
	})


func get_item(id: int) -> Item:
	assert(id >= 0)
	return _items[id]


func _create_item(d: Dictionary):
	var dir = str(ROOT, "/", d.name, "/")
	
	var item : Item
	if d.has("behavior"):
		var behavior_script = load(str(dir, d.name, ".gd"))
		item = behavior_script.new()
	else:
		item = Item.new()
	
	# Give the node a deterministic name for networking
	item.name = d.name
	
	var base_info = item.base_info
	base_info.id = len(_items)
	base_info.name = d.name
	base_info.sprite = load(str(dir, d.name, "_sprite.png"))
	_items.append(item)
	add_child(item)
