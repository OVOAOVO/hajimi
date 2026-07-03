extends CharacterBody2D


# ============================================================
# 物理参数
# ============================================================
@export var gravity: float = 980.0               # 重力加速度（仅第一次下落使用）
@export var max_fall_speed: float = 800.0        # 最大下落速度
@export var bounce_strength: float = 600.0       # 每次弹跳的固定力度

var _first_fall: bool = true                     # 是否还在第一次下落中


# ============================================================
# 物理处理
# ============================================================

func _physics_process(delta: float) -> void:
	if _first_fall:
		# 第一次下落：受重力加速
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	# 弹跳阶段：无重力，速度保持不变

	move_and_slide()

	# 检测碰撞，沿碰撞面的法线方向反弹
	var collision_count := get_slide_collision_count()
	if collision_count > 0:
		_first_fall = false  # 第一次落地后，不再有重力

		# 取最后一次碰撞的法线（墙壁推你的方向）
		var collision := get_last_slide_collision()
		var normal := collision.get_normal()

		# 基于法线方向反弹，并加随机偏移（±45°）
		var base_angle := normal.angle()
		var random_offset := randf_range(-PI / 4.0, PI / 4.0)
		var angle := base_angle + random_offset

		velocity = Vector2(
			cos(angle) * bounce_strength,
			sin(angle) * bounce_strength
		)
