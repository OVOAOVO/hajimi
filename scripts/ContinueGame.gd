extends Button


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	# 恢复游戏
	get_tree().paused = false
	AudioManager.resume_background_music()
	# 向上遍历父节点，查找"暂停界面"（按钮在 BoxContainer → 暂停界面 下）
	var node := get_parent()
	while node:
		if node.name == "暂停界面":
			node.visible = false
			break
		node = node.get_parent()
