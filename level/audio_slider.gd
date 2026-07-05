extends HSlider

@export var bus_name: String = "Master"
@export var default_volume: float = 1.0
@export var save_to_config: bool = true
@export var config_path: String = "user://audio_settings.cfg"
@export var config_section: String = "audio"
@export var config_key: String = "master_volume"

var _bus_index: int = -1
var _config: ConfigFile = ConfigFile.new()


func _ready() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.01
	value_changed.connect(_on_value_changed)

	_bus_index = AudioServer.get_bus_index(bus_name)
	if _bus_index < 0:
		push_warning("找不到音频总线: %s" % bus_name)
		return

	if save_to_config:
		_load_volume_from_config()
	else:
		value = default_volume
		_apply_volume()


func _on_value_changed(new_value: float) -> void:
	_apply_volume()
	if save_to_config:
		_save_volume_to_config(new_value)


func _apply_volume() -> void:
	if _bus_index < 0:
		return

	var clamped_value: float = clampf(value, 0.0, 1.0)
	var volume_db: float = linear_to_db(clamped_value)
	AudioServer.set_bus_volume_db(_bus_index, volume_db)


func _load_volume_from_config() -> void:
	var err: int = _config.load(config_path)
	if err == OK:
		var saved_value: float = _config.get_value(config_section, config_key, default_volume)
		value = clampf(saved_value, 0.0, 1.0)
	else:
		value = default_volume

	_apply_volume()


func _save_volume_to_config(volume: float) -> void:
	var err: int = _config.load(config_path)
	if err != OK:
		_config = ConfigFile.new()

	_config.set_value(config_section, config_key, clampf(volume, 0.0, 1.0))
	_config.save(config_path)
