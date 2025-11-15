extends Control

# ----------------------------
# Node references
# ----------------------------
@onready var difficultyButton: Button = $Difficulty
@onready var Next: Button = $"next"
@onready var Prev: Button = $"prev"
@onready var TextureRectNode: TextureRect = $TextureRect
@onready var SongLabel: RichTextLabel = $RichTextLabel
@onready var play_map: Button = $PlayMap

# ----------------------------
# Lifecycle
# ----------------------------
func _ready() -> void:
	for button in get_tree().get_nodes_in_group("themed_Buttons"):
		if button is Button:
			button.add_theme_color_override("font_focus_color", Color.RED)
	GlobalSettings.test_play = false
	play_map.grab_focus()

	_update_song_display()
	_update_difficulty_button()
	_update_difficulty_button_color()

	if not difficultyButton.is_connected("pressed", Callable(self, "_on_difficulty_pressed")):
		difficultyButton.connect("pressed", Callable(self, "_on_difficulty_pressed"))

# ----------------------------
# Play / Menu buttons
# ----------------------------
func _on_play_map_pressed() -> void:
	get_tree().change_scene_to_file("res://9ArrowScene/Game.tscn")

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://MenuScene/Menu.tscn")

# ----------------------------
# Next / Previous Songs
# ----------------------------
func _on_next_pressed() -> void:
	GlobalSettings.startingChartPath = get_Next_Song()
	_update_song_display()
	_update_difficulty_button()
	_update_difficulty_button_color()

func _on_prev_pressed() -> void:
	GlobalSettings.startingChartPath = get_Prev_Song()
	_update_song_display()
	_update_difficulty_button()
	_update_difficulty_button_color()

# ----------------------------
# Difficulty button pressed
# ----------------------------
func _on_difficulty_pressed() -> void:
	GlobalSettings.cycle_difficulty()
	_update_difficulty_button()
	_update_difficulty_button_color()

# ----------------------------
# Update display helpers
# ----------------------------
func _update_song_display() -> void:
	TextureRectNode.texture = load(GlobalSettings.startingChartImage)
	SongLabel.text = parse_filename(GlobalSettings.current_song)

func _update_difficulty_button() -> void:
	difficultyButton.text = GlobalSettings.difficulty

func _update_difficulty_button_color() -> void:
	var color = Color.GRAY
	match GlobalSettings.difficulty:
		"Easy": color = Color(0,1,0)
		"Medium": color = Color(1,1,0)
		"Hard": color = Color(1,0,0)
		_: color = Color.GRAY

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = color
	stylebox.set_corner_radius_all(25)
	print("Color is : ", color)
	if color == Color(1.0, 0.0, 0.0, 1.0):
		print("making font white")
		difficultyButton.add_theme_color_override("font_focus_color", Color.WHITE)
		difficultyButton.add_theme_color_override("font_color", Color.WHITE)
	elif color == Color(1.0, 1.0, 0.0, 1.0):
		difficultyButton.add_theme_color_override("font_color", Color.BLACK)
		difficultyButton.add_theme_color_override("font_focus_color", Color.RED)
	difficultyButton.add_theme_stylebox_override("normal", stylebox)
	difficultyButton.add_theme_stylebox_override("hover", stylebox)
	difficultyButton.add_theme_stylebox_override("pressed", stylebox)

# ----------------------------
# Song cycling
# ----------------------------
func get_Next_Song() -> String:
	GlobalSettings.song_index = (GlobalSettings.song_index + 1) % GlobalSettings.songs.size()
	GlobalSettings.current_song_dict = GlobalSettings.songs[GlobalSettings.song_index]

	var charts = GlobalSettings.current_song_dict.get("charts", {})
	var ordered = ["Easy","Medium","Hard"]
	var diffs = []
	for d in ordered:
		if d in charts.keys():
			diffs.append(d)

	GlobalSettings.currentDifficultyIndex = 0
	GlobalSettings.difficulty = diffs[0] if diffs.size() > 0 else "None"
	GlobalSettings.startingChartPath = charts.get(GlobalSettings.difficulty,"")
	GlobalSettings.startingChartImage = GlobalSettings.current_song_dict.get("image","")
	GlobalSettings.current_song = GlobalSettings.current_song_dict.get("audio","")
	GlobalSettings.startingIndex = GlobalSettings.song_index

	GlobalSettings._update_starting_chart_array()
	GlobalSettings.save_config()
	return GlobalSettings.startingChartPath

func get_Prev_Song() -> String:
	GlobalSettings.song_index = (GlobalSettings.song_index - 1 + GlobalSettings.songs.size()) % GlobalSettings.songs.size()
	GlobalSettings.current_song_dict = GlobalSettings.songs[GlobalSettings.song_index]

	var charts = GlobalSettings.current_song_dict.get("charts", {})
	var ordered = ["Easy","Medium","Hard"]
	var diffs = []
	for d in ordered:
		if d in charts.keys():
			diffs.append(d)

	GlobalSettings.currentDifficultyIndex = 0
	GlobalSettings.difficulty = diffs[0] if diffs.size() > 0 else "None"
	GlobalSettings.startingChartPath = charts.get(GlobalSettings.difficulty,"")
	GlobalSettings.startingChartImage = GlobalSettings.current_song_dict.get("image","")
	GlobalSettings.current_song = GlobalSettings.current_song_dict.get("audio","")
	GlobalSettings.startingIndex = GlobalSettings.song_index

	GlobalSettings._update_starting_chart_array()
	GlobalSettings.save_config()
	return GlobalSettings.startingChartPath

# ----------------------------
# Helper: parse filename
# ----------------------------
func parse_filename(path: String) -> String:
	var prefix = "res://mp3files/"
	var suffix = ".mp3"
	if path.begins_with(prefix):
		path = path.substr(prefix.length())
	if path.to_lower().ends_with(suffix):
		path = path.substr(0, path.length() - suffix.length())
	return path
