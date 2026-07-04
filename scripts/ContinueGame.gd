extends Button


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	# 恢复游戏
	get_tree().paused = false
	# 在整个场景树中查找"暂停界面"节点并隐藏
	var pause_panel := get_tree().get_first_node_in_group("暂停界面")
	if not pause_panel:
		# 如果没找到 group，尝试按名称查找
		pause_panel = get_tree().root.get_node_or_null("Game1/CanvasLayer/暂停界面")
	if pause_panel:
		pause_panel.visible = false
