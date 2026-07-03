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
@export var throw_duration: float = 1.0     # 投掷飞行时间（秒）

# 重力（与 Cat.gd 保持一致）
const GRAVITY: float = 980.0

# 屏幕中心点（地图 1152×648 的正中央）
const SCREEN_CENTER := Vector2(576.0, 324.0)

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	# 如果没在编辑器中指定 cat_scene，尝试自动加载
	if cat_scene == null:
		cat_scene = preload("res://prefab/cat.tscn")

	# 只生成一次，扔向屏幕中心
	spawn_and_throw_to_center()


func _process(delta: float) -> void:
	pass


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

	# 给 CharacterBody2D 挂载物理脚本，投掷期间先禁用
	var body := cat.get_node_or_null("CharacterBody2D")
	if body != null:
		body.set_script(preload("res://scripts/CatController.gd"))
		body.set_physics_process(false)

	# 启动投掷动画，传入 body 以便结束后启用物理
	_animate_throw(cat, body, spawn_pos, target_pos)
	return cat


# ============================================================
# 内部方法
# ============================================================

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

	# 落地后启用物理，让猫受重力继续下落
	tween.chain().tween_callback(
		func():
			if is_instance_valid(body):
				body.set_physics_process(true)
	)
