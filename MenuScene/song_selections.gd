extends Control

@onready var Next: Button = $"next"
func _ready() -> void:
	GlobalSettings.test_play = false
	Next.grab_focus()
	var config = ConfigFile.new()
	var err = config.load("user://Settings.cfg")
	
	if err == OK:
		var chartPathList = config.get_value("game", "chartPath", [])
		var chartImageList = config.get_value("game", "chartImage", [])
		var chartSongList = config.get_value("game", "chartSong", [])
		var chartIndex = GlobalSettings.startingIndex
		var loadedImage = chartImageList[chartIndex]
		var loadedSong = chartSongList[chartIndex]
		GlobalSettings.startingChartPath = chartPathList[chartIndex]
		GlobalSettings.current_song = chartSongList[chartIndex]
		print("chart song is set to ", chartSongList[chartIndex])
		print("chart is set to : ", chartPathList[chartIndex])
		$TextureRect.texture = load(loadedImage)
		$RichTextLabel.text = loadedSong.split(".")[0]
		
	

func _on_play_map_pressed() -> void:
	get_tree().change_scene_to_file("res://9ArrowScene/Game.tscn")
	pass # Replace with function body.


func _on_next_pressed() -> void:
	GlobalSettings.startingChartPath = get_Next_Song()
	print("Chart set to ",GlobalSettings.startingChartPath)
	pass # Replace with function body.


func _on_prev_pressed() -> void:
	GlobalSettings.startingChartPath = get_Prev_Song()
	print("Chart set to ",GlobalSettings.startingChartPath) # Replace with function body.
	pass # Replace with function body.
	
func get_Prev_Song() -> String:
	var prevSongChart: String = ""
	var prevSongName: String = ""
	var prevChartImage: String = ""
	var newIndex = 0
	var config = ConfigFile.new()
	var err = config.load("user://Settings.cfg")

	if err == OK:
		var chartList = config.get_value("game", "chartPath", [])
		var songNameList = config.get_value("game", "chartSong", [])
		var chartImageList = config.get_value("game", "chartImage", [])
		# Read values from the file (with defaults in case they are missing)
		if(GlobalSettings.startingIndex == 0):
			newIndex = len(chartList)-1
			GlobalSettings.startingIndex = newIndex
			prevSongChart = chartList[GlobalSettings.startingIndex]
			prevSongName = songNameList[GlobalSettings.startingIndex]
			prevChartImage = chartImageList[GlobalSettings.startingIndex]
		else:
			newIndex = GlobalSettings.startingIndex-1
			GlobalSettings.startingIndex = newIndex
			prevSongChart = chartList[GlobalSettings.startingIndex]
			prevSongName = songNameList[GlobalSettings.startingIndex]
			prevChartImage = chartImageList[GlobalSettings.startingIndex]
	$TextureRect.texture = load(prevChartImage)
	$RichTextLabel.text = prevSongName.split(".")[0]
	GlobalSettings.current_song = prevSongName
	print("song is now : ", prevSongName)
	return prevSongChart
	
func get_Next_Song() -> String:
	var nextSongChart: String = ""
	var nextSongName: String = ""
	var nextChartImage: String = ""
	var newIndex = 0
	var config = ConfigFile.new()
	var err = config.load("user://Settings.cfg")

	if err == OK:
		var chartList = config.get_value("game", "chartPath", [])
		var songNameList = config.get_value("game", "chartSong", [])
		var chartImageList = config.get_value("game", "chartImage", [])
		# Read values from the file (with defaults in case they are missing)
		if(GlobalSettings.startingIndex == (len(chartList)-1)):
			newIndex = 0
			GlobalSettings.startingIndex = newIndex
			nextSongChart = chartList[GlobalSettings.startingIndex]
			nextSongName = songNameList[GlobalSettings.startingIndex]
			nextChartImage = chartImageList[GlobalSettings.startingIndex]
		else:
			newIndex = GlobalSettings.startingIndex+1
			GlobalSettings.startingIndex = newIndex
			nextSongChart = chartList[GlobalSettings.startingIndex]
			nextSongName = songNameList[GlobalSettings.startingIndex]
			nextChartImage = chartImageList[GlobalSettings.startingIndex]
	$RichTextLabel.text = nextSongName.split(".")[0]
	$TextureRect.texture = load(nextChartImage)
	GlobalSettings.current_song = nextSongChart
	print("song is now ", nextSongName)
	return nextSongChart
