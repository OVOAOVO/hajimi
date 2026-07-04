extends Node2D

# ============================================================
# 地图边界（世界坐标）
# ============================================================
const MAP_LEFT: float = 0.0
const MAP_RIGHT: float = 1152.0
const MAP_TOP: float = 0.0
const MAP_BOTTOM: float = 648.0

# 在地图外多远处生成
const SPAWN_MARGIN: float = 120.0

# ============================================================
# 可配置参数
# ============================================================
@export var cat_scene: PackedScene          # 要生成的猫场景
@export var pin_scene: PackedScene          # Pin 场景
@export var coin_scene: PackedScene         # 金币场景
@export var throw_duration: float = 1.0     # 投掷飞行时间（秒）
@export var coin_count: int = 15            # 随机撒的金币数量
@export var coin_margin: float = 40.0       # 金币离地图边缘的最小距离
@export var tile_map: TileMapLayer = null   # 地图 TileMapLayer 引用
# UI Label 引用（在 _ready 中自动查找）
var _current_value_label: Label = null
var _max_value_label: Label = null

# 重力（与 Cat.gd 保持一致）
const GRAVITY: float = 980.0

# 屏幕中心点（地图 1152×648 的正中央）
const SCREEN_CENTER := Vector2(576.0, 324.0)

# 当前唯一的 Pin 实例
var _current_pin: Node2D = null
# 投掷生成的猫引用（用于连线）
var _current_cat: Node2D = null
# 连线节点
var _line: Line2D = null
# 当前存活金币数量
var _coin_alive_count: int = 0
# 是否允许玩家输入（投掷动画结束后才开启）
var _input_enabled: bool = false


# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 如果没在编辑器中指定 cat_scene，尝试自动加载
	if cat_scene == null:
		cat_scene = preload("res://prefab/cat.tscn")
	if pin_scene == null:
		pin_scene = preload("res://prefab/pin.tscn")
	if coin_scene == null:
		coin_scene = preload("res://prefab/coin.tscn")

	# 从 CountPanel 场景中查找 UI Label
	var panel := $CanvasLayer/CountPanel/BoxContainer/TextureRect
	if panel:
		_current_value_label = panel.get_node_or_null("currentValue")
		_max_value_label = panel.get_node_or_null("maxValue")

	# 随机撒金币
	_spawn_coins()
	# 设置 UI 最大值
	if _max_value_label:
		_max_value_label.text = str(coin_count)

	# 只生成一次，扔向屏幕中心
	spawn_and_throw_to_center()


func _process(delta: float) -> void:
	_update_line()


func _input(event: InputEvent) -> void:
	# ESC 切换暂停界面显示/隐藏
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		var pause_panel := $CanvasLayer.get_node_or_null("暂停界面")
		if pause_panel:
			pause_panel.visible = not pause_panel.visible
			get_tree().paused = pause_panel.visible
		return

	if not _input_enabled:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# 左键：没有 Pin 时才创建新的
			if _current_pin == null:
				_place_pin(get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 右键：删除 Pin，猫恢复自由弹跳
			_remove_pin()


# ============================================================
# 公开方法
# ============================================================

## 生成一只猫，从地图外侧随机位置扔向屏幕中心
func spawn_and_throw_to_center() -> Node2D:
	return spawn_and_throw_to(_random_edge_spawn_pos(), SCREEN_CENTER)


## 在指定地图外侧位置生成一只猫并扔向目标点
func spawn_and_throw_to(spawn_pos: Vector2, target_pos: Vector2) -> Node2D:
	if cat_scene == null:
		push_error("CoreLogic: cat_scene 未设置！")
		return null

	var cat: Node2D = cat_scene.instantiate()
	add_child(cat)
	cat.position = spawn_pos

	# 记录猫的引用，用于连线
	_current_cat = cat

	# 创建连线节点
	if _line == null:
		_line = Line2D.new()
		_line.width = 3.0
		_line.default_color = Color.WHITE
		add_child(_line)

	# 给 CharacterBody2D 挂载物理脚本，投掷期间先禁用
	var body := cat.get_node_or_null("CharacterBody2D")
	if body != null:
		body.set_script(preload("res://scripts/CatController.gd"))
		body.set_physics_process(false)

		# 连接碰撞信号 → 相机抖动
		var camera := get_node_or_null("Camera2D")
		if camera and camera.has_method("on_wall_hit"):
			body.wall_hit.connect(camera.on_wall_hit)

	# 启动投掷动画，传入 body 以便结束后启用物理
	_animate_throw(cat, body, spawn_pos, target_pos)
	return cat


# ============================================================
# 内部方法
# ============================================================

## 在鼠标点击位置放置 Pin（始终只有一个，每次点击移位置）
func _place_pin(at_position: Vector2) -> void:
	if pin_scene == null:
		return
	if _current_pin == null:
		_current_pin = pin_scene.instantiate()
		add_child(_current_pin)
	_current_pin.position = at_position

	# 让猫绕 Pin 做圆周运动
	_start_orbit_on_cat(at_position)


## 删除 Pin，猫恢复自由弹跳
func _remove_pin() -> void:
	if _current_pin == null:
		return
	_current_pin.queue_free()
	_current_pin = null

	# 猫恢复自由弹跳
	_stop_orbit_on_cat()


## 让猫开始/更新圆周运动，绕 center 旋转
func _start_orbit_on_cat(center: Vector2) -> void:
	if _current_cat == null or not is_instance_valid(_current_cat):
		return
	var body := _current_cat.get_node_or_null("CharacterBody2D")
	if body == null:
		return

	if body.get("_orbiting"):
		# 已经在绕圈，只更新中心
		body.update_orbit_center(center)
	else:
		# 开始绕圈
		body.start_orbit(center)


## 让猫停止圆周运动，恢复自由弹跳
func _stop_orbit_on_cat() -> void:
	if _current_cat == null or not is_instance_valid(_current_cat):
		return
	var body := _current_cat.get_node_or_null("CharacterBody2D")
	if body == null:
		return
	if body.get("_orbiting"):
		body.stop_orbit()


## 更新 Pin 到 Cat 的连线
func _update_line() -> void:
	if _line == null or _current_pin == null or _current_cat == null:
		if _line != null:
			_line.clear_points()
		return
	if not is_instance_valid(_current_cat):
		_line.clear_points()
		_current_cat = null
		return

	# 获取 Cat 的 CharacterBody2D 世界位置（物理体才是实际位置）
	var body := _current_cat.get_node_or_null("CharacterBody2D")
	var cat_pos: Vector2
	if body != null:
		cat_pos = body.global_position
	else:
		cat_pos = _current_cat.global_position

	_line.clear_points()
	_line.add_point(_current_pin.position)
	_line.add_point(cat_pos)


## 在地图内随机撒金币（避开 TileMapLayer 的物理碰撞区域）
func _spawn_coins() -> void:
	if coin_scene == null:
		return
	for i in range(coin_count):
		var coin: Node2D = coin_scene.instantiate()
		add_child(coin)
		coin.position = _find_valid_coin_position()
		# 连接 Area2D 的 body_entered 信号，猫碰到金币就消失
		var area: Area2D = coin.get_node_or_null("Area2D")
		if area:
			area.body_entered.connect(_on_coin_body_entered.bind(coin))
	_coin_alive_count = coin_count
	_update_coin_ui()


## 寻找一个不在 TileMapLayer 碰撞区域内的随机金币位置
func _find_valid_coin_position() -> Vector2:
	const MAX_ATTEMPTS := 100
	for _attempt in range(MAX_ATTEMPTS):
		var pos := Vector2(
			randf_range(MAP_LEFT + coin_margin, MAP_RIGHT - coin_margin),
			randf_range(MAP_TOP + coin_margin, MAP_BOTTOM - coin_margin)
		)
		if _is_position_free(pos):
			return pos
	# 兜底：返回最后一次随机位置（即使可能被占用）
	return Vector2(
		randf_range(MAP_LEFT + coin_margin, MAP_RIGHT - coin_margin),
		randf_range(MAP_TOP + coin_margin, MAP_BOTTOM - coin_margin)
	)


## 检查某个世界坐标位置是否没有 TileMapLayer 物理碰撞
func _is_position_free(world_pos: Vector2) -> bool:
	if tile_map == null:
		return true
	var tile_coords := tile_map.local_to_map(world_pos)
	var tile_data := tile_map.get_cell_tile_data(tile_coords)
	if tile_data == null:
		return true
	# physics_layer 0 有碰撞多边形 → 该位置被占用
	return tile_data.get_collision_polygons_count(0) == 0


## 刷新金币 UI（已收集数量 / 总数量）
func _update_coin_ui() -> void:
	if _current_value_label:
		_current_value_label.text = str(coin_count - _coin_alive_count)


## 显示结算界面并暂停游戏
func _show_settlement() -> void:
	var settlement := $CanvasLayer.get_node_or_null("结算界面")
	if settlement:
		settlement.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		settlement.visible = true
		get_tree().paused = true


## 猫碰到金币时触发，让金币消失（仅在圆周旋转模式下生效）
func _on_coin_body_entered(body: Node2D, coin: Node2D) -> void:
	if _current_cat == null or not is_instance_valid(_current_cat):
		return
	var cat_body := _current_cat.get_node_or_null("CharacterBody2D")
	if body != cat_body or not is_instance_valid(coin):
		return
	# 只有在圆周运动（_orbiting == true）时才吃掉金币
	if not cat_body.get("_orbiting"):
		return
	coin.queue_free()
	_coin_alive_count -= 1
	_update_coin_ui()
	AudioManager.play_eat()
	# 金币吃完了 → 显示结算界面并暂停
	if _coin_alive_count <= 0:
		_show_settlement()


## 随机选择地图四条边之一的外侧位置
func _random_edge_spawn_pos() -> Vector2:
	var edge := randi() % 4
	match edge:
		0: # 上方
			return Vector2(
				randf_range(MAP_LEFT, MAP_RIGHT),
				MAP_TOP - randf_range(SPAWN_MARGIN * 0.5, SPAWN_MARGIN)
			)
		1: # 下方
			return Vector2(
				randf_range(MAP_LEFT, MAP_RIGHT),
				MAP_BOTTOM + randf_range(SPAWN_MARGIN * 0.5, SPAWN_MARGIN)
			)
		2: # 左侧
			return Vector2(
				MAP_LEFT - randf_range(SPAWN_MARGIN * 0.5, SPAWN_MARGIN),
				randf_range(MAP_TOP, MAP_BOTTOM)
			)
		_: # 右侧
			return Vector2(
				MAP_RIGHT + randf_range(SPAWN_MARGIN * 0.5, SPAWN_MARGIN),
				randf_range(MAP_TOP, MAP_BOTTOM)
			)


## 使用 Tween 播放抛体投掷动画，落地后自动启用物理
func _animate_throw(cat: Node2D, body: Node2D, from: Vector2, to: Vector2) -> void:
	var T := throw_duration

	# 抛体运动：计算初速度，使猫在 T 秒后到达目标点
	# x(t) = x0 + vx * t
	# y(t) = y0 + vy * t + 0.5 * g * t²
	var vx := (to.x - from.x) / T
	var vy := (to.y - from.y - 0.5 * GRAVITY * T * T) / T

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_LINEAR)

	# 用抛体公式逐帧更新位置（自动形成真实抛物线）
	tween.tween_method(
		func(t: float):
			if not is_instance_valid(cat):
				return
			var elapsed := t * T
			cat.position = Vector2(
				from.x + vx * elapsed,
				from.y + vy * elapsed + 0.5 * GRAVITY * elapsed * elapsed
			),
		0.0, 1.0, T
	)

	# 飞行中旋转
	var spins := randf_range(1.0, 2.0)
	tween.tween_property(cat, "rotation", TAU * spins * signf(vx), T)

	# 落地后启用物理，让猫开始自由弹跳，同时开放玩家输入
	tween.chain().tween_callback(
		func():
			if is_instance_valid(body):
				# 先同步 CharacterBody2D 的世界位置
				body.global_position = cat.global_position
				body.velocity = Vector2(randf_range(-200, 200), randf_range(-300, -100))
				body.set_physics_process(true)
				# 切换为 Roll 动画
				var sprite: AnimatedSprite2D = body.get_node_or_null("AnimatedSprite2D")
				if sprite:
					sprite.play("Roll")
			_input_enabled = true
	)
