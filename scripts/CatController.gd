extends CharacterBody2D


# ============================================================
# 物理参数
# ============================================================
@export var gravity: float = 980.0               # 重力加速度（仅第一次下落使用）
@export var max_fall_speed: float = 800.0        # 最大下落速度
@export var bounce_strength: float = 600.0       # 每次弹跳的固定力度
@export var orbit_speed: float = 3.0             # 圆周运动角速度（弧度/秒）

var _first_fall: bool = true                     # 是否还在第一次下落中

# 圆周运动状态
var _orbiting: bool = false
var _orbit_center: Vector2 = Vector2.ZERO
var _orbit_radius: float = 0.0
var _orbit_angle: float = 0.0


# ============================================================
# 物理处理
# ============================================================

func _physics_process(delta: float) -> void:
	# 圆周运动模式
	if _orbiting:
		_orbit_angle += orbit_speed * delta
		var target_pos := _orbit_center + Vector2(
			cos(_orbit_angle) * _orbit_radius,
			sin(_orbit_angle) * _orbit_radius
		)

		# 用 move_and_collide 检测墙壁碰撞
		var motion := target_pos - global_position
		var collision := move_and_collide(motion)
		if collision:
			# 碰到墙壁 → 反转圆周方向
			orbit_speed = -orbit_speed
			_orbit_angle = (global_position - _orbit_center).angle()

		# 面朝运动切线方向
		rotation = _orbit_angle + PI / 2.0
		return

	# 自由弹跳模式
	if _first_fall:
		# 第一次下落：受重力加速
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	# 弹跳阶段：无重力，速度保持不变

	move_and_slide()

	# 检测碰撞，沿碰撞面的法线方向反弹
	if get_slide_collision_count() > 0:
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


# ============================================================
# 圆周运动控制（由 CoreLogic 调用）
# ============================================================

## 开始绕 center 做圆周运动
func start_orbit(center: Vector2) -> void:
	_orbiting = true
	_orbit_center = center
	_orbit_radius = global_position.distance_to(center)
	_orbit_angle = (global_position - center).angle()
	_first_fall = false
	velocity = Vector2.ZERO


## 更新圆周运动中心（Pin 移动时调用）
func update_orbit_center(center: Vector2) -> void:
	_orbit_center = center
	_orbit_radius = global_position.distance_to(center)
	_orbit_angle = (global_position - center).angle()


## 停止圆周运动，回到自由弹跳
func stop_orbit() -> void:
	if not _orbiting:
		return
	_orbiting = false
	# 给一个切线方向的初速度，平滑过渡到弹跳
	var tangent := Vector2(-sin(_orbit_angle), cos(_orbit_angle))
	velocity = tangent * orbit_speed * _orbit_radius
	_first_fall = false
