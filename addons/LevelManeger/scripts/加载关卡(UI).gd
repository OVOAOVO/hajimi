# 已弃用 2026.6.6

extends Button

@export_file("*.tscn") var next_level: String

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	if next_level != "":
		get_tree().call_deferred("change_scene_to_file", next_level)
