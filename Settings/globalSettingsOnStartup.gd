extends Node

var startingChartPath: String
var startingVolume: float
var startingIndex: int
var startingChartArray: Array
var scrollSpeed: int

var test_play: bool = false
var edit_chart
var current_song: String
var poses_array: Array
var notes: Array
var bars: Array
var current_pose: String = "None"

const CFG_PATH := "user://Settings.cfg"

# your desired default structure
const DEFAULTS := {
	"game": {
		"volume": 50.0,
		"scrollSpeed": 450,
		"chartPath": [
			"res://MapsJson/recorded_chart.json",
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
		"chartIndex": 0
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


func load_data() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CFG_PATH)
	if err != OK:
		push_error("Could not load Settings.cfg, using in-memory defaults")
		# fall back to DEFAULTS without writing
		_apply_values_from(DEFAULTS)
		return

	# Back-fill any missing keys (keeps file healthy as you add new settings)
	var wrote := false
	for section in DEFAULTS.keys():
		for key in DEFAULTS[section].keys():
			if not cfg.has_section_key(section, key):
				cfg.set_value(section, key, DEFAULTS[section][key])
				wrote = true
	if wrote:
		cfg.save(CFG_PATH)

	# Now read values (use your actual key names; you used "chartArray" earlier but
	# your structure shows "chartPath"—so read "chartPath")
	startingChartArray = cfg.get_value("game", "chartPath", DEFAULTS["game"]["chartPath"])
	startingVolume = float(cfg.get_value("game", "volume", DEFAULTS["game"]["volume"]))
	scrollSpeed = int(cfg.get_value("game", "scrollSpeed", DEFAULTS["game"]["scrollSpeed"]))
	startingIndex = int(cfg.get_value("game", "chartIndex", DEFAULTS["game"]["chartIndex"]))

	# Convenience: the currently selected path (guard for bounds)
	if startingChartArray is Array and not startingChartArray.is_empty():
		var idx = clamp(startingIndex, 0, startingChartArray.size() - 1)
		startingChartPath = startingChartArray[idx]
	else:
		startingChartPath = "res://MapsJson/recorded_chart.json"

	print("✅ Loaded settings:",
		" vol=", startingVolume,
		" scroll=", scrollSpeed,
		" index=", startingIndex,
		" path=", startingChartPath
	)


func _apply_values_from(dict: Dictionary) -> void:
	# Lets you keep behavior consistent if file load fails.
	startingChartArray = dict["game"]["chartPath"]
	startingVolume = dict["game"]["volume"]
	scrollSpeed = dict["game"]["scrollSpeed"]
	startingIndex = dict["game"]["chartIndex"]
	var idx = clamp(startingIndex, 0, startingChartArray.size() - 1)
	startingChartPath = startingChartArray[idx]
