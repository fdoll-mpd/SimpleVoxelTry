extends TextureRect

const InventoryItem = preload("res://Entities/Player/inventory/inventory_item.gd")
const Blocks = preload("res://CopyFrom/BlockLib/blocks/blocks.gd")
const ItemDB = preload("res://CopyFrom/ItemLib/item_db.gd")

@onready var _block_types : Blocks = get_node("/root/AllInOne/Blocks")
@onready var _item_db : ItemDB = get_node("/root/AllInOne/Items")


func set_item(data: InventoryItem):
	if data == null:
		texture = null
		
	elif data.type == InventoryItem.TYPE_BLOCK:
		var block := _block_types.get_block(data.id)
		texture = block.base_info.sprite_texture

	elif data.type == InventoryItem.TYPE_ITEM:
		var item := _item_db.get_item(data.id)
		texture = item.base_info.sprite
	
	else:
		assert(false)
