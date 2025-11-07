extends Node

var startingChartPath
var startingVolume
var startingIndex
var startingChartArray
var scrollSpeed: int
var test_play: bool = false
var edit_chart
var current_song: String

func _ready() -> void:
	startingChartPath = "res://MapsJson/recorded_chart.json"

	load_data()  # Load values when the game starts


func load_data() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://Settings.cfg")

	if err == OK:
		# Read values from the file (with defaults in case they are missing)
		startingChartArray = config.get_value("game", "chartArray", "Empty")
		startingVolume = config.get_value("game", "volume", 0)
		scrollSpeed = config.get_value("game", "scrollSpeed", 300)
		startingIndex = config.get_value("game", "chartIndex", 0)
		#startingChartPath = startingChartArray[0] this fuckign bug wtf

		print("Starting Game\n")
		print("✅ Loaded settings:", startingVolume)
		print("Scroll Speed:", scrollSpeed)
