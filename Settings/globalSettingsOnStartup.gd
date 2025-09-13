extends Node

var startingChartPath
var startingVolume

func _ready() -> void:
	load_data()  # Load values when the game starts


func load_data() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://Settings.cfg")

	if err == OK:
		# Read values from the file (with defaults in case they are missing)
		startingChartPath = config.get_value("game", "chartPath", "Empty")
		startingVolume = config.get_value("game", "volume", 0)
		print("Starting Game\n")
		print("✅ Loaded settings:", startingVolume)
