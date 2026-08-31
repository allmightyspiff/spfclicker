extends Node

signal score_changed(new_score: int)
signal player_name_changed(new_name: String)
signal volume_changed(new_volume: float)
signal clickers_changed()
signal game_saved()
signal game_loaded()

var player_name: String = "Player":
	set(value):
		player_name = value.strip_edges()
		if player_name.is_empty():
			player_name = "Player"
		player_name_changed.emit(player_name)

var volume: float = 1.0: # 0.0 to 1.0
	set(value):
		volume = clampf(value, 0.0, 1.0)
		_update_audio_server(volume)
		volume_changed.emit(volume)

var score: int = 0:
	set(value):
		score = maxi(0, value)
		score_changed.emit(score)

# Clicker Upgrades
var auto_clickers: int = 0:
	set(value):
		auto_clickers = maxi(0, value)
		clickers_changed.emit()

var double_clickers: int = 0:
	set(value):
		double_clickers = maxi(0, value)
		clickers_changed.emit()

const AUTO_CLICKER_BASE_COST: int = 100
const DOUBLE_CLICKER_BASE_COST: int = 200
const COST_MULTIPLIER: float = 1.12

const SAVE_PATHS: Array[String] = [
	"user://savegame.json",
	"res://savegame.json"
]

var _auto_click_accumulator: float = 0.0
var _auto_save_timer: float = 0.0
const AUTO_SAVE_INTERVAL: float = 15.0

func _ready() -> void:
	# Load settings / preferences if saved file exists
	if has_save_file():
		_load_settings_from_save()
	_update_audio_server(volume)

func _notification(what: int) -> void:
	# Automatically persist game state when closing or quitting
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_PREDELETE:
		if score > 0 or auto_clickers > 0 or double_clickers > 0:
			save_game()

func _process(delta: float) -> void:
	var cps = get_total_cps()
	if cps > 0:
		_auto_click_accumulator += delta * float(cps)
		if _auto_click_accumulator >= 1.0:
			var clicks_to_add = int(_auto_click_accumulator)
			_auto_click_accumulator -= float(clicks_to_add)
			add_click(clicks_to_add)
			
	# Periodic background auto-save if in a game session with progress
	if score > 0 or auto_clickers > 0 or double_clickers > 0:
		_auto_save_timer += delta
		if _auto_save_timer >= AUTO_SAVE_INTERVAL:
			_auto_save_timer = 0.0
			save_game()

func add_click(amount: int = 1) -> void:
	score += amount

func get_total_cps() -> int:
	return (auto_clickers * 1) + (double_clickers * 2)

func get_auto_clicker_cost() -> int:
	return int(round(AUTO_CLICKER_BASE_COST * pow(COST_MULTIPLIER, auto_clickers)))

func get_double_clicker_cost() -> int:
	return int(round(DOUBLE_CLICKER_BASE_COST * pow(COST_MULTIPLIER, double_clickers)))

func can_afford_auto_clicker() -> bool:
	return score >= get_auto_clicker_cost()

func can_afford_double_clicker() -> bool:
	return score >= get_double_clicker_cost()

func buy_auto_clicker() -> bool:
	var cost = get_auto_clicker_cost()
	if score >= cost:
		score -= cost
		auto_clickers += 1
		save_game() # Save progress immediately on milestone purchase
		return true
	return false

func buy_double_clicker() -> bool:
	var cost = get_double_clicker_cost()
	if score >= cost:
		score -= cost
		double_clickers += 1
		save_game() # Save progress immediately on milestone purchase
		return true
	return false

func reset_score() -> void:
	score = 0
	auto_clickers = 0
	double_clickers = 0
	_auto_click_accumulator = 0.0
	_auto_save_timer = 0.0

# ---------------------------------------------------------
# Save & Load File System
# ---------------------------------------------------------

func _get_writable_save_path() -> String:
	for path in SAVE_PATHS:
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.close()
			return path
	return SAVE_PATHS[0]

func _get_existing_save_path() -> String:
	for path in SAVE_PATHS:
		if FileAccess.file_exists(path):
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				file.close()
				return path
	return ""

func has_save_file() -> bool:
	return _get_existing_save_path() != ""

func save_game() -> bool:
	var path = _get_writable_save_path()
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		printerr("Failed to save game to file at path: ", path, " error code: ", FileAccess.get_open_error())
		return false
	
	var save_data = {
		"version": 1,
		"player_name": player_name,
		"volume": volume,
		"score": score,
		"auto_clickers": auto_clickers,
		"double_clickers": double_clickers,
		"saved_at": Time.get_datetime_string_from_system()
	}
	
	var json_str = JSON.stringify(save_data, "\t")
	file.store_string(json_str)
	file.flush()
	file.close()
	game_saved.emit()
	return true

func load_game() -> bool:
	var path = _get_existing_save_path()
	if path == "":
		return false
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(content)
	if err != OK:
		printerr("Failed to parse save file JSON: ", json.get_error_message())
		return false
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return false
	
	if data.has("player_name"):
		player_name = str(data["player_name"])
	if data.has("volume"):
		volume = float(data["volume"])
	if data.has("score"):
		score = int(data["score"])
	if data.has("auto_clickers"):
		auto_clickers = int(data["auto_clickers"])
	if data.has("double_clickers"):
		double_clickers = int(data["double_clickers"])
	
	_auto_click_accumulator = 0.0
	_auto_save_timer = 0.0
	
	game_loaded.emit()
	return true

func _load_settings_from_save() -> void:
	var path = _get_existing_save_path()
	if path == "":
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) == OK and typeof(json.data) == TYPE_DICTIONARY:
		var data = json.data
		if data.has("player_name"):
			player_name = str(data["player_name"])
		if data.has("volume"):
			volume = float(data["volume"])

func delete_save() -> void:
	for path in SAVE_PATHS:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _update_audio_server(vol: float) -> void:
	var master_bus_idx = AudioServer.get_bus_index("Master")
	if master_bus_idx >= 0:
		if vol <= 0.001:
			AudioServer.set_bus_mute(master_bus_idx, true)
		else:
			AudioServer.set_bus_mute(master_bus_idx, false)
			AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(vol))
