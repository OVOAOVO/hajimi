extends Node

signal progress_changed(progress)
signal load_finished

@export var loading_screen: PackedScene
var loaded_resource: PackedScene
var scene_path: String
var progress: Array = []
var use_sub_threads: bool = true

func _ready() -> void:
	set_process(false)
	# 如果编辑器未赋值，尝试从项目设置中加载
	if not loading_screen:
		var path: String = ProjectSettings.get_setting("level_manager/loading_screen_path", "")
		if not path.is_empty() and ResourceLoader.exists(path):
			loading_screen = load(path)

func load_scene(_scene_path:String) -> void:
	scene_path = _scene_path

	# 没有配置加载画面时，直接切换场景
	if not loading_screen:
		get_tree().change_scene_to_file(scene_path)
		return

	var new_load_screen = loading_screen.instantiate()
	add_child(new_load_screen)
	progress_changed.connect(new_load_screen._on_progress_changed)
	load_finished.connect(new_load_screen._on_load_finished)

	await new_load_screen.loading_screen_ready

	start_load()

func start_load() -> void:
	var state = ResourceLoader.load_threaded_request(scene_path, "", use_sub_threads)
	if state == OK:
		set_process(true)
	else:
		print("Failed to start loading scene: " + scene_path)


func _process(_delta: float) -> void:
	var load_status = ResourceLoader.load_threaded_get_status(scene_path, progress)
	progress_changed.emit(progress[0])
	match load_status:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, ResourceLoader.THREAD_LOAD_FAILED:
			set_process(false)
			# 加载失败时也要通知 loading_screen 清理，否则会永远黑屏
			printerr("LevelManager: 加载场景失败: " + scene_path)
			load_finished.emit()
		ResourceLoader.THREAD_LOAD_LOADED:
			loaded_resource = ResourceLoader.load_threaded_get(scene_path)
			get_tree().change_scene_to_packed(loaded_resource)
			load_finished.emit()
			set_process(false)