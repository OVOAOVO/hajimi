extends Camera2D

## 抖动强度（像素）
@export var shake_strength: float = 8.0
## 抖动持续时间（秒）
@export var shake_duration: float = 0.25
## 抖动频率（越大抖得越快）
@export var shake_frequency: float = 40.0

var _shake_timer: float = 0.0
var _is_shaking: bool = false
var _base_offset: Vector2


func _ready() -> void:
	_base_offset = offset


## 由 CatController 的 wall_hit 信号触发
func on_wall_hit(_point: Vector2 = Vector2.ZERO, _normal: Vector2 = Vector2.ZERO) -> void:
	_shake_timer = shake_duration
	_is_shaking = true


func _process(delta: float) -> void:
	if not _is_shaking:
		return

	_shake_timer -= delta
	if _shake_timer <= 0.0:
		_is_shaking = false
		offset = _base_offset
		return

	# 衰减系数：从 1 衰减到 0
	var decay := _shake_timer / shake_duration
	var shake_x := sin(_shake_timer * shake_frequency) * shake_strength * decay
	var shake_y := cos(_shake_timer * shake_frequency * 1.3) * shake_strength * decay * 0.7

	offset = _base_offset + Vector2(shake_x, shake_y)
