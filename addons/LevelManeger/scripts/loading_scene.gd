extends CanvasLayer

signal loading_screen_ready

@export var animation_player: AnimationPlayer
@export var progress_bar: ProgressBar

func _ready() -> void:
	if animation_player:
		# 如果动画已在播放（autoplay），等待其完成
		if animation_player.is_playing():
			await animation_player.animation_finished
	loading_screen_ready.emit()

func _on_progress_changed(new_value: float) -> void:
	if progress_bar:
		progress_bar.value = new_value * 100.0

func _on_load_finished() -> void:
	if progress_bar:
		progress_bar.value = progress_bar.max_value
	if animation_player and animation_player.has_animation("transition"):
		animation_player.play_backwards("transition")
		await animation_player.animation_finished
	queue_free()
	
