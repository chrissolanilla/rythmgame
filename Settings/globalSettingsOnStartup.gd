extends Node

var startingChartPath: String
var startingVolume: float
var startingIndex: int
var startingChartArray: Array
var scrollSpeed: int
var startingChartImage: String
var timing_offset =0.0

var test_play: bool = false
var edit_chart
var current_song: String
var poses_array: Array
var notes: Array
var bars: Array
var current_pose: String = "None"

var perfectCounter = 0
var goodCounter = 0
var badCounter = 0
var missCounter = 0

var songTime: float = 0.0

var highestComboAchieved: int

const CFG_PATH := "user://Settings.cfg"
var chartDifficulties: Array = []       # Array of Arrays, one per song
var currentDifficultyIndex: int = 0     # index into current song’s difficulty list
var currentDifficulty: String = "Easy"

# your desired default structure
const DEFAULTS := {
	"game": {
		"volume": 50.0,
		"scrollSpeed": 450,
		"chartPath": [
			#"res://MapsJson/recorded_chart.json",
			"res://MapsJson/77bada.json",
			"res://MapsJson/recorded_chart_2.json",
			"res://MapsJson/simple_chart.json",
			"res://MapsJson/poses_rickroll.json"
		],
		"chartImage": [
			"res://art/IMG_1269.jpg",
			"res://art/IMG_4256.png",
			"res://art/Screenshot 2024-08-20 025111.png",
			"res://art/uniform_samurai.png"
		],
		"chartSong": [
			"res://mp3files/bad_apple.mp3",
			"res://mp3files/togsk-ba.mp3",
			"res://mp3files/rickroll.MP3",
			"res://mp3files/rickroll.MP3"
		],
		"chartIndex": 0,
		"chartDifficulties": [
			["Easy", "Medium", "Hard"],   # song 0
			["Easy", "Hard"],             # song 1
			["Medium", "Hard"],           # song 2
			["Easy", "Medium"]            # song 3
		],
		"chartDifficultyIndex": 0       # global current difficulty index
	}
}

func _ready() -> void:
	ensure_config_exists()  # creates the file with defaults if missing
	load_data()             # then load (and back-fill any missing keys)


func ensure_config_exists() -> void:
	# If missing or unreadable, write defaults.
	var cfg := ConfigFile.new()
	var err := cfg.load(CFG_PATH)
	if err != OK:
		for section in DEFAULTS.keys():
			for key in DEFAULTS[section].keys():
				cfg.set_value(section, key, DEFAULTS[section][key])
		var save_err := cfg.save(CFG_PATH)
		if save_err != OK:
			push_error("Failed to create default Settings.cfg: %s" % str(save_err))
func _update_current_difficulty() -> void:
	if chartDifficulties is Array and not chartDifficulties.is_empty():
		var song_idx = clamp(startingIndex, 0, chartDifficulties.size() - 1)
		var diffs = chartDifficulties[song_idx]
		if diffs is Array and not diffs.is_empty():
			var idx = clamp(currentDifficultyIndex, 0, diffs.size() - 1)
			currentDifficultyIndex = idx
			currentDifficulty = str(diffs[idx])
		else:
			currentDifficulty = "None"
	else:
		currentDifficulty = "None"

func load_data() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CFG_PATH)
	if err != OK:
		push_error("Could not load Settings.cfg, using in-memory defaults")
		_apply_values_from(DEFAULTS)
		return

	var wrote := false
	for section in DEFAULTS.keys():
		for key in DEFAULTS[section].keys():
			if not cfg.has_section_key(section, key):
				cfg.set_value(section, key, DEFAULTS[section][key])
				wrote = true
	if wrote:
		cfg.save(CFG_PATH)

	# Existing stuff
	startingChartArray = cfg.get_value("game", "chartPath", DEFAULTS["game"]["chartPath"])
	startingVolume = float(cfg.get_value("game", "volume", DEFAULTS["game"]["volume"]))
	scrollSpeed = int(cfg.get_value("game", "scrollSpeed", DEFAULTS["game"]["scrollSpeed"]))
	startingIndex = int(cfg.get_value("game", "chartIndex", DEFAULTS["game"]["chartIndex"]))

	# NEW: load difficulty data
	chartDifficulties = cfg.get_value("game", "chartDifficulties", DEFAULTS["game"]["chartDifficulties"])
	currentDifficultyIndex = int(cfg.get_value("game", "chartDifficultyIndex", 0))

	# Clamp indexes and derive paths
	if startingChartArray is Array and not startingChartArray.is_empty():
		var idx = clamp(startingIndex, 0, startingChartArray.size() - 1)
		startingIndex = idx
		startingChartPath = startingChartArray[idx]
	else:
		startingChartPath = "res://MapsJson/recorded_chart.json"

	# Derive currentDifficulty based on current song
	_update_current_difficulty()

	print("✅ Loaded settings:",
		" vol=", startingVolume,
		" scroll=", scrollSpeed,
		" index=", startingIndex,
		" path=", startingChartPath,
		" difficulty=", currentDifficulty
	)

#func load_data() -> void:
	#var cfg := ConfigFile.new()
	#var err := cfg.load(CFG_PATH)
	#if err != OK:
		#push_error("Could not load Settings.cfg, using in-memory defaults")
		## fall back to DEFAULTS without writing
		#_apply_values_from(DEFAULTS)
		#return
#
	## Back-fill any missing keys (keeps file healthy as you add new settings)
	#var wrote := false
	#for section in DEFAULTS.keys():
		#for key in DEFAULTS[section].keys():
			#if not cfg.has_section_key(section, key):
				#cfg.set_value(section, key, DEFAULTS[section][key])
				#wrote = true
	#if wrote:
		#cfg.save(CFG_PATH)
#
	## Now read values (use your actual key names; you used "chartArray" earlier but
	## your structure shows "chartPath"—so read "chartPath")
	#startingChartArray = cfg.get_value("game", "chartPath", DEFAULTS["game"]["chartPath"])
	#startingVolume = float(cfg.get_value("game", "volume", DEFAULTS["game"]["volume"]))
	#scrollSpeed = int(cfg.get_value("game", "scrollSpeed", DEFAULTS["game"]["scrollSpeed"]))
	#startingIndex = int(cfg.get_value("game", "chartIndex", DEFAULTS["game"]["chartIndex"]))
#
	## Convenience: the currently selected path (guard for bounds)
	#if startingChartArray is Array and not startingChartArray.is_empty():
		#var idx = clamp(startingIndex, 0, startingChartArray.size() - 1)
		#startingChartPath = startingChartArray[idx]
	#else:
		#startingChartPath = "res://MapsJson/recorded_chart.json"
#
	#print("✅ Loaded settings:",
		#" vol=", startingVolume,
		#" scroll=", scrollSpeed,
		#" index=", startingIndex,
		#" path=", startingChartPath
	#)
#
func _apply_values_from(dict: Dictionary) -> void:
	startingChartArray = dict["game"]["chartPath"]
	startingVolume = dict["game"]["volume"]
	scrollSpeed = dict["game"]["scrollSpeed"]
	startingIndex = dict["game"]["chartIndex"]
	chartDifficulties = dict["game"]["chartDifficulties"]
	currentDifficultyIndex = dict["game"]["chartDifficultyIndex"]

	var idx = clamp(startingIndex, 0, startingChartArray.size() - 1)
	startingChartPath = startingChartArray[idx]
	_update_current_difficulty()

#func _apply_values_from(dict: Dictionary) -> void:
	## Lets you keep behavior consistent if file load fails.
	#startingChartArray = dict["game"]["chartPath"]
	#startingVolume = dict["game"]["volume"]
	#scrollSpeed = dict["game"]["scrollSpeed"]
	#startingIndex = dict["game"]["chartIndex"]
	#var idx = clamp(startingIndex, 0, startingChartArray.size() - 1)
	#startingChartPath = startingChartArray[idx]
