tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("Rope3D", "Spatial", preload("Rope3D.gd"), preload("icon.png"))

func _exit_tree():
	remove_custom_type("Rope3D")
