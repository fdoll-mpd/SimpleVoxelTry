extends Control

@onready var _color_control = $CenterContainer/PanelContainer/HBoxContainer/ColorPickControl
@onready var _color_rect = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/ColorRect

signal config_changed(config: Dictionary)

enum Shape { BOX, SPHERE, CYLINDER, CAPSULE, LINE, POINT }
var _voxel_library: VoxelBlockyLibrary = preload("res://CopyFrom/BlockLib/blocks/voxel_library.tres")
func get_material_names():
	var library_materials: Array[String] = []
	for block in _voxel_library.get_models():
		library_materials.append(block.resource_name)
	
	return library_materials
	
#@export var materials: Array[StringName] = ["Dirt", "Stone", "Wood", "Metal"]
@export var materials: Array[String] = get_material_names()

@onready var shape_select: OptionButton    = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/ShapeSelect
@onready var material_select: OptionButton = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/MaterialSelect
@onready var grid_size: Range              = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/GridSizeSlider
@onready var color_picker: ColorPicker     = $CenterContainer/PanelContainer/HBoxContainer/ColorPickControl/ColorPicker

@onready var x_slider: Range = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/XSlider
@onready var y_slider: Range = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/YSlider
@onready var z_slider: Range = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/ZSlider
@onready var r_slider: Range = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/RSlider
@onready var h_slider: Range = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/HSlider
@onready var l_slider: Range = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/LSlider

@onready var x_label: Label = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/X
@onready var y_label: Label = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/Y
@onready var z_label: Label = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/Z
@onready var r_label: Label = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/Radius
@onready var h_label: Label = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/Height
@onready var l_label: Label = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/Length

@onready var xy_seperator: HSeparator = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/XYSeperator
@onready var yz_seperator: HSeparator = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/YZSeperator
@onready var zr_seperator: HSeparator = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/ZRSeperator
@onready var rh_seperator: HSeparator = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/RHSeperator
@onready var hl_seperator: HSeparator = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/HLSeperator

@onready var override_voxels: CheckButton  = $CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/OverrideVoxels

# Sliders/SpinBoxes for placement & size
#@onready var s_size_x: Range = %CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/XSlider
#@onready var s_size_y: Range = %CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/YSlider
#@onready var s_size_z: Range = %CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/ZSlider
#@onready var s_radius: Range = %CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/RSlider
#@onready var s_height: Range = %CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/HSlider
#@onready var s_length: Range = %CenterContainer/PanelContainer/HBoxContainer/VBoxContainer/PlacementSizeSliders/LSlider

# (Optional) labels to dim when disabled
#@onready var l_size_x: Label = %SizeXLabel
#@onready var l_size_y: Label = %SizeYLabel
#@onready var l_size_z: Label = %SizeZLabel
#@onready var l_radius: Label = %RadiusLabel
#@onready var l_height: Label = %HeightLabel
#@onready var l_length: Label = %LengthLabel


const SHAPE_TO_ENABLED := {
	Shape.BOX:      ["size_x","size_y","size_z"],
	Shape.SPHERE:   ["radius"],
	Shape.CYLINDER: ["radius","height"],
	Shape.CAPSULE:  ["radius","height"],
	Shape.LINE:     ["length"],
	Shape.POINT:    [], # no size controls
}

const SHAPE_TO_LABEL := {
	Shape.BOX:      ["X","Y","Z"],
	Shape.SPHERE:   ["Radius"],
	Shape.CYLINDER: ["Radius","Height"],
	Shape.CAPSULE:  ["Radius","Height"],
	Shape.LINE:     ["Length"],
	Shape.POINT:    [], # no size controls
}

var _sliders := {}
var _labels := {}
var _seperators := {}


func _emit_config():
	emit_signal("config_changed", get_config())
	#emit_signal("config_changed", {"shape": shape_select.get_selected_id(), 
	#"material": materials[material_select.get_selected_id()], 
	#"size_x": x_slider.value, 
	#"size_y": y_slider.value,
	#"size_z": z_slider.value,
	#"radius": r_slider.value, "height": h_slider.value, "length": l_slider.value})

func dump_node_tree(root: Node, n: Node = null, depth: int = 0) -> void:
	if n == null:
		n = root
		print("--- DUMP from ", root.name, "  abs:", root.get_path(), " ---")
	var rel_path: NodePath = root.get_path_to(n)
	print("%s%s (%s)  rel:%s" % ["  ".repeat(depth), n.name, n.get_class(), rel_path])
	for c in n.get_children():
		dump_node_tree(root, c, depth + 1)
		
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#dump_node_tree(self)
	#var found := find_child("ShapeSelect", true, false)
	#if found:
		#print("ShapeSelect at: ", get_path_to(found), "  unique_name_in_owner=", found.unique_name_in_owner)
	#else:
		#print("ShapeSelect not found under ", name)
	#assert(shape_select,    "ShapeSelect path is wrong")
	#assert(material_select, "MaterialSelect path is wrong")
	#assert(color_picker,    "ColorPicker path is wrong")
	#assert(x_slider && y_slider && z_slider && r_slider && h_slider && l_slider, "One or more size sliders not found")
	_color_control.hide()
	_sliders = { "size_x": x_slider, "size_y": y_slider, "size_z": z_slider, "radius": r_slider, "height": h_slider, "length": l_slider}
	#_labels = { "size_x": l_size_x, "size_y": l_size_y, "size_z": l_size_z, "radius": l_radius, "height": l_height, "length": l_length,}
	_labels = { "size_x": x_label, "size_y": y_label, "size_z": z_label, "radius": r_label, "height": h_label, "length": l_label}
	_seperators = { "size_x": xy_seperator, "size_y": yz_seperator, "size_z": zr_seperator, "radius": rh_seperator, "height": hl_seperator, "length": hl_seperator}
	_populate_shape_select()
	_populate_material_select()

	# React to user changes
	shape_select.item_selected.connect(_on_shape_selected)
	material_select.item_selected.connect(_on_material_selected)
	for r in _sliders.values():
		r.value_changed.connect(func(_v): _emit_config())
	shape_select.item_selected.connect(func(_i): _apply_shape(shape_select.get_selected_id()); _emit_config())
	material_select.item_selected.connect(func(_i): _emit_config())
	grid_size.value_changed.connect(func(_v): _emit_config())
	override_voxels.toggled.connect(func(_b): _emit_config())
	# Initialize state
	_apply_shape(shape_select.get_selected_id())
	
	color_picker.color_changed.connect(func(c: Color): _color_rect.color = c)
	_color_rect.color = color_picker.color

	# react to clicks on the rect
	_color_rect.gui_input.connect(_on_color_rect_gui_input)
	
	_color_rect.visible = true
	if _color_rect.color.a <= 0.0:
		_color_rect.color.a = 1.0  # ensure not transparent

	# Give it some space and let it expand in containers
	_color_rect.custom_minimum_size = Vector2(160, 28)  # tweak to taste
	_color_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_rect.size_flags_vertical   = Control.SIZE_SHRINK_CENTER

	# (Optional) set a starter color so you can see it instantly
	if _color_rect.color.a == 0.0 or _color_rect.color == Color(0,0,0,0):
		_color_rect.color = Color(0.9, 0.2, 0.2, 1.0)
	
	_emit_config()

func _populate_shape_select() -> void:
	shape_select.clear()
	for id in Shape.values():
		shape_select.add_item(Shape.keys()[id], id)
	shape_select.select(Shape.BOX)

func _populate_material_select() -> void:
	material_select.clear()
	for i in materials.size():
		material_select.add_item(str(materials[i]), i)
	material_select.select(0)

func _on_shape_selected(id: int) -> void:
	_apply_shape(id)
	# TODO: also update your placement logic if needed.

func _on_material_selected(index: int) -> void:
	var chosen: StringName = materials[index]
	# TODO: pass this to your placement system, e.g.:
	# get_tree().call_group("voxel_placer", "set_material", chosen)

func _apply_shape(shape_id: int) -> void:
	var enabled_keys: Array = SHAPE_TO_ENABLED.get(shape_id, [])
	for key in _sliders.keys():
		var en = key in enabled_keys
		_set_range_enabled(_sliders[key], en)
		_set_range_visible(_sliders[key], _labels[key], _seperators[key], en)
		if _labels.has(key):
			_labels[key].modulate.a = (1.0 if en else 0.5)

func _set_range_visible(r: Range, l: Label, s: HSeparator, enabled: bool) -> void:
	if enabled:
		r.show()
		l.show()
		s.show()
	else:
		r.hide()
		l.hide()
		s.hide()

func _set_range_enabled(r: Range, enabled: bool) -> void:
	# Works for HSlider/VSlider/SpinBox in Godot 4
	r.editable = enabled
	r.mouse_filter =  (Control.MOUSE_FILTER_PASS if enabled else Control.MOUSE_FILTER_IGNORE)
	r.modulate.a =  (1.0 if enabled else 0.5)


func _on_color_picker_color_changed(color: Color) -> void:
	_color_rect.color = color


func _on_hide_button_pressed() -> void:
	_color_control.hide()
	
func _on_color_rect_gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_color_control.show()
		color_picker.grab_focus()


func get_config() -> Dictionary:
	# Always return the full config object
	var mat_idx := material_select.get_selected_id()
	var cfg := {
		"shape":        shape_select.get_selected_id(),    # use enum Shape
		"material_idx": mat_idx,
		"material":     materials[mat_idx],
		#"block_id":     material_block_ids[min(mat_idx, material_block_ids.size() - 1)],
		"grid":         int(grid_size.value),
		"size_x":       int(x_slider.value),
		"size_y":       int(y_slider.value),
		"size_z":       int(z_slider.value),
		"radius":       int(r_slider.value),
		"height":       int(h_slider.value),
		"length":       int(l_slider.value),
		"override":     override_voxels.button_pressed,
	}
	if is_instance_valid(color_picker):
		cfg["color"] = color_picker.color
	return cfg

func set_config(cfg: Dictionary) -> void:
	# Apply external config (from TestCharacter) into the UI without reordering signals
	if cfg.has("shape"):        shape_select.select(int(cfg.shape))
	if cfg.has("material_idx"): material_select.select(int(cfg.material_idx))
	if cfg.has("grid"):         grid_size.value = cfg.grid
	if cfg.has("size_x"):       x_slider.value = cfg.size_x
	if cfg.has("size_y"):       y_slider.value = cfg.size_y
	if cfg.has("size_z"):       z_slider.value = cfg.size_z
	if cfg.has("radius"):       r_slider.value = cfg.radius
	if cfg.has("height"):       h_slider.value = cfg.height
	if cfg.has("length"):       l_slider.value = cfg.length
	if cfg.has("override"):     override_voxels.button_pressed = cfg.override
	if cfg.has("color") and is_instance_valid(color_picker):
		color_picker.color = cfg.color

	_apply_shape(shape_select.get_selected_id())
	_emit_config()
