extends Spatial
class_name Rope3D

export var line_width: float = 0.05
export var segment_length: float = 0.25
export var segment_mass: float = 2.0

export var node_a: NodePath
export var node_b: NodePath

var tracking = [] 
var vertices: PoolVector3Array
var vertex_uvs: PoolVector2Array
var mesh_instance: MeshInstance = null
var mesh: Mesh = null

func _ready():
	mesh_instance = MeshInstance.new()
	mesh_instance.set_as_toplevel(true)
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
	tracking.push_back(na)
	for _i in range(number_of_segments):
		segment_pos += segment_step
		var segment = create_segment(segment_pos, dir)
		create_joint(
			joint_position, 
			previous.get_path(),
			segment.get_path()
		)
		joint_position += segment_step
		previous = segment
		tracking.push_back(segment)

	create_joint(
		joint_position, 
		previous.get_path(),
		get_parent_physic_body(nb).get_path()
	)
	
	tracking.push_back(nb)

	vertices = PoolVector3Array()
	vertices.resize(tracking.size() * 2)

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
	cylinder.radius = line_width
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
	var joint = Generic6DOFJoint.new()
	joint.set_as_toplevel(true)
	joint.set_flag_x(Generic6DOFJoint.FLAG_ENABLE_ANGULAR_LIMIT, false)
	joint.set_flag_z(Generic6DOFJoint.FLAG_ENABLE_ANGULAR_LIMIT, false)
	joint.set_flag_x(Generic6DOFJoint.FLAG_ENABLE_LINEAR_LIMIT, true)
	joint.set_flag_z(Generic6DOFJoint.FLAG_ENABLE_LINEAR_LIMIT, true)
	joint.translation = to_local(global_position)
	joint.set_node_a(a)
	joint.set_node_b(b)
	add_child(joint)

func update_rope_geometry():
	var v := 0
	var cam_trx := get_viewport().get_camera().get_global_transform()
	var cam_dir := -cam_trx.basis.z
	var adjs := Vector3(0, 0, 0)
	
	for i in range(tracking.size() - 1):
		var origin = tracking[i].get_global_transform().origin
		var dir = origin.direction_to(tracking[i+1].get_global_transform().origin)
		adjs = dir.cross(cam_dir) * line_width
		vertices.set(v, origin - adjs)
		v += 1
		vertices.set(v, origin + adjs)
		v += 1
		
	var origin = tracking[tracking.size() - 1].get_global_transform().origin
	vertices.set(v, origin - adjs)
	v += 1
	vertices.set(v, origin + adjs)
	v += 1

	var geometry = []
	geometry.resize(ArrayMesh.ARRAY_MAX)
	geometry[ArrayMesh.ARRAY_VERTEX] = vertices
	geometry[ArrayMesh.ARRAY_TEX_UV] = vertex_uvs

	mesh.surface_remove(0)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, geometry)

