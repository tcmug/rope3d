extends Spatial
class_name Rope3D

export var width: float = 0.05
export var segment_length: float = 0.25
export var segment_mass: float = 2.0
export var material: Material
export var node_a: NodePath
export var node_b: NodePath

export var bias: float = 0.3 setget set_bias
export var damping: float = 1.0 setget set_damping
export var impulse_clamp: float = 0.0 setget set_impulse_clamp

func set_bias(value):
	bias = value
	for node in joints:
		var joint = node as PinJoint
		if is_instance_valid(joint):
			joint.set_param(PinJoint.PARAM_BIAS, bias)

func set_damping(value):
	damping = value
	for node in joints:
		var joint = node as PinJoint
		if is_instance_valid(joint):
			joint.set_param(PinJoint.PARAM_DAMPING, damping)
	
func set_impulse_clamp(value):
	impulse_clamp = value
	for node in joints:
		var joint = node as PinJoint
		if is_instance_valid(joint):
			joint.set_param(PinJoint.PARAM_IMPULSE_CLAMP, impulse_clamp)
	
	
var tracking = [] 
var joints = []
var joint_a: Joint
var joint_b: Joint
var anchor_a: Position3D
var anchor_b: Position3D
var vertices: PoolVector3Array
var normals: PoolVector3Array
var vertex_uvs: PoolVector2Array
var mesh_instance: MeshInstance = null
var mesh: Mesh = null

func _ready():
	mesh_instance = MeshInstance.new()
	mesh_instance.set_as_toplevel(true)
	mesh_instance.material_override = material
	set_as_toplevel(true)
	set_physics_process(false)
	if tracking.size() == 0:
		create_rope()

func _physics_process(_delta):
	update_rope_geometry()

func create_rope():
	
	# Both start and end required
	if !node_a or !node_b:
		return

	var na = get_node(node_a)
	var nb = get_node(node_b)

	if !get_parent_physic_body(na) or !get_parent_physic_body(nb):
		return

	var a = na.get_global_transform().origin
	var b = nb.get_global_transform().origin

	var number_of_segments = ceil(a.distance_to(b) / segment_length)
	var dir = a.direction_to(b)
	var segment_adjusted_length = a.distance_to(b) / number_of_segments
	var segment_step = dir * segment_adjusted_length
	var previous = get_parent_physic_body(na)
	
	# Rigids are centered, so adjust starting pos to half
	var segment_pos = a - (segment_step * 0.5)
	
	# Joint position starts from the position of node a
	var joint_position = a
	for _i in range(number_of_segments):
		segment_pos += segment_step
		var segment = create_segment(segment_pos, dir)
		var joint = create_joint(
			joint_position, 
			previous.get_path(),
			segment.get_path()
		)
		if !joint_a:
			joint_a = joint
		joint_position += segment_step
		previous = segment
		tracking.push_back(segment)

	joint_b = create_joint(
		joint_position, 
		previous.get_path(),
		get_parent_physic_body(nb).get_path()
	)

	vertices = PoolVector3Array()
	vertices.resize(tracking.size() * 2)

	normals = PoolVector3Array()
	normals.resize(tracking.size() * 2)

	vertex_uvs = PoolVector2Array()
	vertex_uvs.resize(tracking.size() * 2)

	transform = Transform()
	mesh = ArrayMesh.new()
	var uvs = [
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(0, 1),
		Vector2(1, 1)
	]
	for i in range(tracking.size() * 2):
		vertices.set(i, Vector3(0, 0, 0))
		vertex_uvs.set(i, uvs[i % 4])
	set_physics_process(true)
	
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

func get_parent_physic_body(node: Node):
	while node and !node is PhysicsBody:
		node = node.get_parent()
	return node

func create_segment(global_position: Vector3, global_direction: Vector3):
	var cylinder = CylinderShape.new()
	cylinder.height = segment_length
	cylinder.radius = width
	var shape = CollisionShape.new()
	shape.shape = cylinder
	shape.rotation_degrees.x = 90
	var segment = RigidBody.new()
	segment.set_as_toplevel(true)
	segment.add_child(shape)
	segment.mass = segment_mass
	var up = Vector3(0, 1, 0).cross(global_direction)
	up = global_direction.cross(up)
	add_child(segment)
	segment.look_at_from_position(global_position, global_position + global_direction, up)
	return segment

func create_joint(global_position: Vector3, a: NodePath, b: NodePath):
	var joint := PinJoint.new()
	#Generic6DOFJoint.new()

	joint.set_as_toplevel(true)
	joint.set_param(PinJoint.PARAM_BIAS, bias)
	joint.set_param(PinJoint.PARAM_DAMPING, damping)
	joint.set_param(PinJoint.PARAM_IMPULSE_CLAMP, impulse_clamp)
#	joint.set_flag_y(Generic6DOFJoint.FLAG_ENABLE_ANGULAR_LIMIT, false)
#	joint.set_flag_z(Generic6DOFJoint.FLAG_ENABLE_ANGULAR_LIMIT, false)
#	joint.set_flag_y(Generic6DOFJoint.FLAG_ENABLE_LINEAR_LIMIT, true)
#	joint.set_flag_z(Generic6DOFJoint.FLAG_ENABLE_LINEAR_LIMIT, true)

#	joint.set_flag_x(Generic6DOFJoint.FLAG_ENABLE_ANGULAR_SPRING, true)
#	joint.set_flag_y(Generic6DOFJoint.FLAG_ENABLE_ANGULAR_SPRING, true)
#	joint.set_flag_z(Generic6DOFJoint.FLAG_ENABLE_ANGULAR_SPRING, true)

#	joint.set_param_x(Generic6DOFJoint.PARAM_ANGULAR_SPRING_STIFFNESS, 1.5)
#	joint.set_param_y(Generic6DOFJoint.PARAM_ANGULAR_SPRING_STIFFNESS, 1.5)
#	joint.set_param_z(Generic6DOFJoint.PARAM_ANGULAR_SPRING_STIFFNESS, 1.5)
#
#	joint.set_param_x(Generic6DOFJoint.PARAM_ANGULAR_SPRING_DAMPING, 0.5)
#	joint.set_param_y(Generic6DOFJoint.PARAM_ANGULAR_SPRING_DAMPING, 0.5)
#	joint.set_param_z(Generic6DOFJoint.PARAM_ANGULAR_SPRING_DAMPING, 0.5)

#	joint.set_param_x(Generic6DOFJoint.PARAM_LINEAR_SPRING_STIFFNESS, 20)
#	joint.set_param_y(Generic6DOFJoint.PARAM_LINEAR_SPRING_STIFFNESS, 20)
#	joint.set_param_z(Generic6DOFJoint.PARAM_LINEAR_SPRING_STIFFNESS, 20)
#
#	joint.set_param_x(Generic6DOFJoint.PARAM_LINEAR_SPRING_DAMPING, 10)
#	joint.set_param_y(Generic6DOFJoint.PARAM_LINEAR_SPRING_DAMPING, 10)
#	joint.set_param_z(Generic6DOFJoint.PARAM_LINEAR_SPRING_DAMPING, 10)
#
#	joint.set_param_x(Generic6DOFJoint.PARAM_LINEAR_LIMIT_SOFTNESS, softness)
#	joint.set_param_x(Generic6DOFJoint.PARAM_LINEAR_RESTITUTION, restitution)
#	joint.set_param_x(Generic6DOFJoint.PARAM_LINEAR_DAMPING, damping)
#
#	joint.set_param_y(Generic6DOFJoint.PARAM_LINEAR_LIMIT_SOFTNESS, softness)
#	joint.set_param_y(Generic6DOFJoint.PARAM_LINEAR_RESTITUTION, restitution)
#	joint.set_param_y(Generic6DOFJoint.PARAM_LINEAR_DAMPING, damping)
#
#	joint.set_param_z(Generic6DOFJoint.PARAM_LINEAR_LIMIT_SOFTNESS, softness)
#	joint.set_param_z(Generic6DOFJoint.PARAM_LINEAR_RESTITUTION, restitution)
#	joint.set_param_z(Generic6DOFJoint.PARAM_LINEAR_DAMPING, damping)
#
#	joint.set("linear_limit_x/softness", softness)
#	joint.set("linear_limit_x/restitution", restitution)
#	joint.set("linear_limit_x/damping", damping)
#
#	joint.set("linear_limit_y/softness", softness)
#	joint.set("linear_limit_y/restitution", restitution)
#	joint.set("linear_limit_y/damping", damping)
#
#	joint.set("linear_limit_z/softness", softness)
#	joint.set("linear_limit_z/restitution", restitution)
#	joint.set("linear_limit_z/damping", damping)
#
	joint.translation = to_local(global_position)
	joint.set_node_a(a)
	joint.set_node_b(b)
	joints.push_back(joint)
	add_child(joint)

	return joint

func update_rope_geometry():
	var v := 0
	var cam_trx := get_viewport().get_camera().get_global_transform()
	var normal := cam_trx.basis.z
	var cam_dir := -cam_trx.basis.z
	var adjs := Vector3(0, 0, 0)
	
	for i in range(tracking.size() - 1):
		var origin = tracking[i].get_global_transform().origin
		var dir = origin.direction_to(tracking[i+1].get_global_transform().origin)
		adjs = dir.cross(cam_dir) * width
		vertices.set(v, origin - adjs)
		normals.set(v, normal)
		v += 1
		vertices.set(v, origin + adjs)
		normals.set(v, normal)
		v += 1

	var origin = tracking[tracking.size() - 1].get_global_transform().origin
	vertices.set(v, origin - adjs)
	v += 1
	vertices.set(v, origin + adjs)
	v += 1

	var geometry = []
	geometry.resize(ArrayMesh.ARRAY_MAX)
	geometry[ArrayMesh.ARRAY_VERTEX] = vertices
	geometry[ArrayMesh.ARRAY_NORMAL] = normals
	geometry[ArrayMesh.ARRAY_TEX_UV] = vertex_uvs
	mesh.surface_remove(0)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, geometry)

func detach_a():
	if is_instance_valid(joint_a):
		joint_a.queue_free()
		tracking.pop_front()
		vertex_uvs.resize(vertex_uvs.size() - 2)
		normals.resize(normals.size() - 2)
		vertices.resize(vertices.size() - 2)
	joint_a = null
	
func detach_b():
	if is_instance_valid(joint_b):
		joint_b.queue_free()
		tracking.pop_back()
		vertex_uvs.resize(vertex_uvs.size() - 2)
		normals.resize(normals.size() - 2)
		vertices.resize(vertices.size() - 2)
	joint_b = null
