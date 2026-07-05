extends Node

@export var pool_size: int = 10
@export var default_bus: String = "SFX"
 
var audio_pool: Array[AudioStreamPlayer] = []
var available_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var background_music: AudioStream = preload("res://assets/New 3 2026-07-05 0908.wav")

var bounce_sounds: Array[AudioStream] = [
	preload("res://assets/SFX/哈吉米弹弹弹1.wav"),
	preload("res://assets/SFX/哈吉米弹弹弹2.wav"),
	preload("res://assets/SFX/哈吉米弹弹弹3.wav"),
	preload("res://assets/SFX/哈吉米弹弹弹4.wav"),
]
var eat_sounds: Array[AudioStream] = [
	preload("res://assets/SFX/c吃东西 1.wav"),
	preload("res://assets/SFX/c吃东西 2.wav"),
	preload("res://assets/SFX/c吃东西 3.wav"),
]

func _ready():
	# 让音频管理器在结算界面或其他暂停场景下仍然工作
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 创建音效池
	randomize()
	create_audio_pool()
	create_music_player()
	play_background_music()
 
func create_audio_pool():
	for i in range(pool_size):
		var player = AudioStreamPlayer.new()
		player.bus = default_bus
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.finished.connect(_on_player_finished.bind(player))
		
		add_child(player)
		audio_pool.append(player)
		available_players.append(player)
 
func play_sound(sound: AudioStream) -> bool:
	if available_players.is_empty():
		print("音效池已满")
		return false
	
	var player = available_players.pop_back()
	player.stream = sound
	player.play()
	
	return true

func play_random_sound(sounds: Array[AudioStream]) -> bool:
	if sounds.is_empty():
		print("音效列表为空")
		return false
	var index = randi() % sounds.size()
	return play_sound(sounds[index])

func play_bounce() -> bool:
	return play_random_sound(bounce_sounds)

func play_eat() -> bool:
	return play_random_sound(eat_sounds)

func play_insert() -> bool:
	return play_sound(preload("res://assets/SFX/插入锚点.wav"))	

func play_pull () -> bool:
	return play_sound(preload("res://assets/SFX/拔出锚点.wav"))	

func play_error () -> bool:
	return play_sound(preload("res://assets/SFX/生成失败.wav"))	
	
func play_begin () -> bool:
	return play_sound(preload("res://assets/SFX/神秘猫叫.wav"))	
	
func play_win () -> bool:
	return play_sound(preload("res://assets/SFX/胜利音效.wav"))	
	
func create_music_player():
	music_player = AudioStreamPlayer.new()
	music_player.name = "BackgroundMusic"
	music_player.stream = background_music
	music_player.bus = "Music"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.volume_db = 0.0
	music_player.autoplay = false
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)

func play_background_music() -> void:
	if music_player != null:
		music_player.play()

func pause_background_music() -> void:
	if music_player != null:
		music_player.stream_paused = true

func resume_background_music() -> void:
	if music_player != null:
		music_player.stream_paused = false

func _on_music_finished() -> void:
	if music_player != null:
		music_player.play()

func stop_background_music() -> void:
	if music_player != null:
		music_player.stop()

func _on_player_finished(player: AudioStreamPlayer):
	# 音效播放完成，回收到池中
	if player in audio_pool and not player in available_players:
		available_players.append(player)
