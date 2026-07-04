extends Node2D

@export var angle_range: float = 30.0   ## 摆动角度范围（度），即 ±30°
@export var interval: float = 0.5       ## 每隔多少秒跳变一次

var _base_rotation: float = 0.0
var _timer: float = 0.0
var _target_angle: float = 0.0


func _ready() -> void:
	_base_rotation = rotation
	_jump_to_new_angle()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= interval:
		_timer -= interval
		_jump_to_new_angle()
	
	rotation = _base_rotation + deg_to_rad(_target_angle)


func _jump_to_new_angle() -> void:
	_target_angle = randf_range(-angle_range, angle_range)
