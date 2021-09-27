extends RigidBody
class_name Rope3DSegment

signal rope_body_entered(segment, body)

var joint: PinJoint
var rope: Spatial

func _on_body_entered(body):
	emit_signal('rope_body_entered', self, body)

func cut():
	if is_instance_valid(joint):
		joint.queue_free()
		joint = null
		print("Cutting does not fully work!")
