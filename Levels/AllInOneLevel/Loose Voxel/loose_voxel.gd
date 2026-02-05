extends RigidBody3D

const GRAVITY = Vector3(0, -14, 0)

const LIFETIME = 100.0
const BASE_VALUE = 1000
const VALUE_DECAY_RATE = 2.0  # Value lost per second when not vacuuming
const VELOCITY_VALUE_LOSS_MULTIPLIER = 1500.0  # Value lost based on velocity change
#var _mesh_instance = MeshInstance3D.new()
#var _collision_shape = CollisionShape3D.new()

@onready var _mesh_instance = $MeshInstance
@onready var _collision_shape = $CollisionShape

var _velocity := Vector3()
var _rotation_axis := Vector3()
var _angular_velocity := 4.0 * TAU * randf_range(-1.0, 1.0)
var _remaining_time := randf_range(0.5, 1.5) * LIFETIME
var _is_being_vacuumed := false
var _vacuum_target := Vector3.ZERO
var _current_value := BASE_VALUE
var _last_velocity := Vector3.ZERO

signal collected(value: int)

func _ready():
	# Configure RigidBody3D properties
	mass = 1.0
	gravity_scale = 1.0
	linear_damp = 0.1
	angular_damp = 0.1

	if _mesh_instance.mesh == null:
		_mesh_instance.mesh = BoxMesh.new()
	if _mesh_instance.material_override == null:
		_mesh_instance.material_override = StandardMaterial3D.new()
	
	# Set up collision shape (use existing child node)
	if _collision_shape.shape == null:
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3.ONE
		_collision_shape.shape = box_shape
	
	rotation = Vector3(randf_range(-PI, PI), randf_range(-PI, PI), randf_range(-PI, PI))
	_rotation_axis = Vector3(randf_range(-PI, PI), randf_range(-PI, PI), randf_range(-PI, PI)).normalized()
	
	_last_velocity = linear_velocity


func set_velocity(vel: Vector3):
	_velocity = vel

func set_mesh(mesh: BoxMesh):
	if _mesh_instance and _mesh_instance.mesh:
		_mesh_instance.mesh = mesh

func set_material(mat: StandardMaterial3D):
	if _mesh_instance:
		_mesh_instance.material_override = mat
	
func set_size(size: Vector3):
	#print("loose _mesh_instance", _mesh_instance)
	#print("Now mesh ", _mesh_instance.mesh)
	if _mesh_instance and _mesh_instance.mesh is BoxMesh:
		_mesh_instance.mesh.size = size
	
	#_collision_shape.shape.size = size
	#print("loose collision_shape", _collision_shape)
	#print("Now shape ", _collision_shape.shape)
	if _collision_shape and _collision_shape.shape is BoxShape3D:
		#print("Changing collision shape to be ", size)
		_collision_shape.shape.size = size

func start_vacuum(target_pos: Vector3):
	_is_being_vacuumed = true
	_vacuum_target = target_pos
	
func update_vacuum_target(target_pos: Vector3):
	if _is_being_vacuumed:
		_vacuum_target = target_pos
		
func stop_vacuum():
	_is_being_vacuumed = false
	
func get_current_value() -> int:
	return int(_current_value)
	
func _process(delta: float):
	_remaining_time -= delta
	if _remaining_time <= 0:
		queue_free()
		return

	# Handle vacuum logic
	if _is_being_vacuumed:
		var direction = (_vacuum_target - global_position).normalized()
		var distance = global_position.distance_to(_vacuum_target)
		
		#freeze = true
		gravity_scale = 0.0
		#var vacuum_strength = 20.0
		#_velocity = direction * vacuum_strength
		var vacuum_speed = 1.0
		#global_position += direction * vacuum_speed * delta
		move_and_collide(direction * vacuum_speed * delta)
		
		# If close enough, collect it
		if distance < 1.0:
			#print("Distance so trying to emit collected")
			collected.emit(get_current_value())
			queue_free()
			return
	else:
		#freeze = false
		gravity_scale = 1.0
		var current_vel = linear_velocity
		var velocity_delta = _last_velocity - current_vel
		var velocity_loss = velocity_delta.length()
		
		# Apply value decay
		#_current_value -= VALUE_DECAY_RATE * delta
		
		# Apply additional value loss based on velocity decrease
		# Sharp deceleration = more value loss
		if velocity_loss > 1:  # Only count significant changes
			var value_loss = velocity_loss * VELOCITY_VALUE_LOSS_MULTIPLIER * delta
			_current_value -= value_loss
			#print("Velocity loss", velocity_loss, " minus value ", value_loss)
		# Clamp value to minimum of 0
		_current_value = max(0, _current_value)
		
		_last_velocity = current_vel
#
	## Rotation
	#var trans := transform
	#trans.basis = trans.basis.rotated(_rotation_axis, _angular_velocity * delta)
	#
	## Movement
	#trans.origin += _velocity * delta
	#transform = trans

func clean() -> void:
	queue_free()
