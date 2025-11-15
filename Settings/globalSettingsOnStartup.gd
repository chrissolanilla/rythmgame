extends Node

# -----------------------
# Legacy / external vars
# -----------------------
var startingChartPath: String = ""
var startingVolume: float = 50.0
var startingIndex: int = 0
var startingChartArray: Array = []    # legacy compatibility
var scrollSpeed: int = 450
var startingChartImage: String = ""
var timing_offset =0.0

var test_play: bool = false
var edit_chart
var current_song: String = ""
var current_video : String = ""
var poses_array: Array = []
var notes: Array = []
var bars: Array = []
var current_pose: String = "None"

var perfectCounter: int = 0
var goodCounter: int = 0
var badCounter: int = 0
var missCounter: int = 0

var songTime: float = 0.0
var highestComboAchieved: int = 0

# -----------------------
# Config & state
# -----------------------
const CFG_PATH := "user://Settings.cfg"

var songs: Array = []                 # array of song dictionaries
var song_index: int = 0
var difficulty: String = "Easy"
var current_song_dict: Dictionary = {}
var currentDifficultyIndex: int = 0    # tracks current difficulty in ordered list

# -----------------------
# Lifecycle
# -----------------------
func _ready() -> void:
	ensure_config_exists()
	load_config()

	if songs.is_empty():
		songs = _get_default_songs()

	_update_state_from_loaded()
	print("GlobalSettings ready. song_index=", song_index, " difficulty=", difficulty, " volume=", startingVolume)

# -----------------------
# Default songs
# -----------------------
func _get_default_songs() -> Array:
	return [
		{
			"name": "Bad Apple",
			"image": "res://art/IMG_1269.jpg",
			"video": "res://mp3files/【東方】Bad Apple!! ＰＶ【影絵】 - kasidid2 (360p, h264).ogv",
			"audio": "res://mp3files/bad_apple.mp3",
			"charts": {"Easy":"res://MapsJson/bad_apple_easy.json","Medium": "res://MapsJson/77bada.json","Hard": "res://MapsJson/bad_apple_hard.json"}
		},
		{
			"name": "Song B",
			"image": "res://art/IMG_4256.png",
			"video": "res://mp3files/blazingHeart.ogv",
			"audio": "res://mp3files/togsk-ba.mp3",
			"charts": {"Easy":"res://MapsJson/77bada.json","Hard": "res://MapsJson/77bada.json"}
		},
		{
			"name": "RickRoll",
			"image": "res://art/uniform_samurai.png",
			"video": "res://mp3files/rickroll.ogv",
			"audio": "res://mp3files/rickroll.MP3",
			"charts": {"Medium":"res://MapsJson/poses_rickroll.json","Hard": "res://MapsJson/poses_rickroll.json"}
		}
	]

# -----------------------
# Ensure config exists
# -----------------------
func ensure_config_exists() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(CFG_PATH)
	if err == OK:
		return

	cfg.set_value("game", "volume", startingVolume)
	cfg.set_value("game", "scroll_speed", scrollSpeed)
	cfg.set_value("game", "song_index", song_index)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "songs", _get_default_songs())
	cfg.save(CFG_PATH)

# -----------------------
# Load config
# -----------------------
func load_config() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(CFG_PATH)
	if err != OK:
		push_error("Could not load Settings.cfg, using defaults")
		songs = _get_default_songs()
		return

	startingVolume = float(cfg.get_value("game", "volume", startingVolume))
	scrollSpeed = int(cfg.get_value("game", "scroll_speed", scrollSpeed))
	song_index = int(cfg.get_value("game", "song_index", song_index))
	difficulty = str(cfg.get_value("game", "difficulty", difficulty))
	songs = cfg.get_value("game", "songs", _get_default_songs())

# -----------------------
# Update legacy vars
# -----------------------
func _update_state_from_loaded() -> void:
	if songs.is_empty():
		push_error("No songs available in settings, creating defaults.")
		songs = _get_default_songs()

	song_index = clamp(song_index, 0, songs.size() - 1)
	current_song_dict = songs[song_index]

	if not (current_song_dict.has("charts") and current_song_dict["charts"] is Dictionary):
		current_song_dict["charts"] = {}

	if not current_song_dict["charts"].has(difficulty):
		var keys = current_song_dict["charts"].keys()
		if keys.size() > 0:
			difficulty = str(keys[0])
		else:
			difficulty = "None"

	# Set currentDifficultyIndex according to desired order
	var ordered = ["Easy","Medium","Hard"]
	var keys = current_song_dict["charts"].keys()
	currentDifficultyIndex = 0
	for i in range(ordered.size()):
		if ordered[i] in keys and ordered[i] == difficulty:
			currentDifficultyIndex = i
			break

	# Populate legacy chart array
	startingChartArray.clear()
	for s in songs:
		var chosen_chart = ""
		if s["charts"].has("Easy"):
			chosen_chart = s["charts"]["Easy"]
		else:
			var k = s["charts"].keys()
			if k.size() > 0:
				chosen_chart = s["charts"][k[0]]
		startingChartArray.append(chosen_chart)

	# Legacy vars
	startingIndex = song_index
	startingChartPath = startingChartArray[startingIndex] if startingChartArray.size() > 0 else ""
	startingChartImage = current_song_dict.get("image","")
	current_song = current_song_dict.get("audio","")
	current_video = current_song_dict.get("video","")

# -----------------------
# Save config
# -----------------------
func save_config() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(CFG_PATH)
	if err != OK:
		ensure_config_exists()
		cfg.load(CFG_PATH)

	cfg.set_value("game", "volume", startingVolume)
	cfg.set_value("game", "scroll_speed", scrollSpeed)
	cfg.set_value("game", "song_index", song_index)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "songs", songs)
	cfg.save(CFG_PATH)

# -----------------------
# Cycle difficulty (forward)
# -----------------------
func cycle_difficulty() -> void:
	if not current_song_dict.has("charts"):
		difficulty = "None"
		return

	var available_diffs = current_song_dict["charts"].keys()
	var ordered_diffs = ["Easy","Medium","Hard"]
	var diffs = []

	for d in ordered_diffs:
		if d in available_diffs:
			diffs.append(d)

	if diffs.size() == 0:
		difficulty = "None"
		return

	currentDifficultyIndex = (currentDifficultyIndex + 1) % diffs.size()
	difficulty = diffs[currentDifficultyIndex]
	startingChartPath = current_song_dict["charts"].get(difficulty, startingChartPath)
	save_config()

# -----------------------
# Helpers
# -----------------------
func _update_starting_chart_array() -> void:
	startingChartArray.clear()
	for s in songs:
		var chosen = ""
		if s["charts"].has("Easy"):
			chosen = s["charts"]["Easy"]
		else:
			var k = s["charts"].keys()
			if k.size() > 0:
				chosen = s["charts"][k[0]]
		startingChartArray.append(chosen)

func get_active_chart_path() -> String:
	return startingChartPath

func get_current_song_display_name() -> String:
	var audio_path = current_song
	if audio_path == null:
		return ""
	var prefix = "res://mp3files/"
	if audio_path.begins_with(prefix):
		audio_path = audio_path.substr(prefix.length())
	if audio_path.to_lower().ends_with(".mp3"):
		audio_path = audio_path.substr(0, audio_path.length()-4)
	return audio_path


func reset_config_file() -> void:
	# 1) Delete existing config file if it exists
	if FileAccess.file_exists(CFG_PATH):
		var abs_path := ProjectSettings.globalize_path(CFG_PATH)
		var err = DirAccess.remove_absolute(abs_path)
		if err != OK:
			push_error("Failed to remove config file: %s" % error_string(err))
			return

	# 2) Recreate it with defaults (using your existing logic)
	ensure_config_exists()
	load_config()
	_update_state_from_loaded()

	print("Settings.cfg has been reset to default.")
