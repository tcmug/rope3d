extends Spatial
class_name Rope3D

export var width: float = 0.05
export var segment_length: float = 0.25
export var segment_mass: float = 2.0
export var material: Material
export var attached_to: NodePath

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
var container = null
var source = self

func _ready():
	# TODO: Do we ever need the physics container to be anything other than self?
	container = self
	if tracking.size() == 0:
		create_rope()

func _physics_process(_delta):
	update_rope_geometry()

func create_rope():
	var target = get_node(attached_to)
	var physics_object = get_parent_physic_body(source)
	var target_physics_object = get_parent_physic_body(target)
	
	# Check that both have a physics body parent.
	if !physics_object or !target_physics_object:
		return

	var point_a = source.get_global_transform().origin
	var point_b = target.get_global_transform().origin

	var number_of_segments = ceil(point_a.distance_to(point_b) / segment_length)
	var dir = point_a.direction_to(point_b)
	var segment_adjusted_length = point_a.distance_to(point_b) / number_of_segments
	var segment_step = dir * segment_adjusted_length

	# Rigids are centered, so adjust starting pos to half
	var segment_pos = point_a - (segment_step * 0.5)
	# TODO: Seems odd but the Joint position starts from the origin position 
	# of container, but this can change when container != self!
	var joint_position = Vector3(0, 0, 0)
	var previous = physics_object
	
	# Rope starts from source
	tracking.push_back(self)
	
	for _i in range(number_of_segments):
		segment_pos += segment_step
		var segment = create_segment(segment_pos, dir)
		var joint = create_joint(
			joint_position, 
			dir,
			previous.get_path(),
			segment.get_path()
		)
		if !joint_a:
			joint_a = joint

		joint_position += segment_step
		previous = segment
		tracking.push_back(segment)
 
	# Rope connects to target
	tracking.push_back(target)
	
	joint_b = create_joint(
		joint_position, 
		dir,
		previous.get_path(),
		target_physics_object.get_path()
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
		vertex_uvs.set(i, uvs[i % 4])
	
	mesh_instance = MeshInstance.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	# FIXME: For some reason the translation affects our
	# mesh even when it is toplevel, so shift it to world origin.
	mesh_instance.translation = -get_global_transform().origin
	mesh_instance.set_as_toplevel(true)
	add_child(mesh_instance)

func get_parent_physic_body(node: Node):
	while node and !node is PhysicsBody:
		node = node.get_parent()
	return node

func create_segment(global_position: Vector3, global_direction: Vector3):
	var collider = CylinderShape.new()
	collider.height = segment_length
	collider.radius = width
	
	var shape = CollisionShape.new()
	shape.shape = collider
	shape.rotation_degrees.x = 90
	
	var segment = RigidBody.new()
	segment.set_as_toplevel(true)
	segment.add_child(shape)
	segment.mass = segment_mass
	# TODO: Make these tweakable!
	segment.linear_damp = 0
	segment.angular_damp = 50
	var up = Vector3(0, 1, 0)
	container.add_child(segment)
	segment.look_at_from_position(global_position, global_position + global_direction, up)
	return segment

func create_joint(local_position: Vector3, direction: Vector3, a: NodePath, b: NodePath):
	var joint := PinJoint.new()
# 	TODO: See if Generic6DOFJoint could be used
#	joint.set_flag_y(Generic6DOFJoint.FLAG_ENABLE_ANGULAR_LIMIT, false)
#	joint.set_flag_z(Generic6DOFJoint.FLAG_ENABLE_ANGULAR_LIMIT, false)
#	joint.set_flag_y(Generic6DOFJoint.FLAG_ENABLE_LINEAR_LIMIT, true)
#	joint.set_flag_z(Generic6DOFJoint.FLAG_ENABLE_LINEAR_LIMIT, true)
	joint.translation = local_position
	joint.set_node_a(a)
	joint.set_node_b(b)
	
	container.add_child(joint)
	joints.push_back(joint)
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
