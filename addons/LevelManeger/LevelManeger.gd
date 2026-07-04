@tool
extends EditorPlugin


func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	add_autoload_singleton("scene_loader", "res://addons/LevelManeger/scripts/scene_loader.gd")
	# 注册项目设置：加载画面场景路径
	if not ProjectSettings.has_setting("level_manager/loading_screen_path"):
		ProjectSettings.set_setting("level_manager/loading_screen_path", "")
	ProjectSettings.set_initial_value("level_manager/loading_screen_path", "")
	ProjectSettings.add_property_info({
		"name": "level_manager/loading_screen_path",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.tscn,*.scn"
	})
	ProjectSettings.save()


func _exit_tree() -> void:
	remove_autoload_singleton("scene_loader")

