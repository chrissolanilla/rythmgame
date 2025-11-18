extends Control
@onready var click: AudioStreamPlayer = $click
@onready var Play: Button = $"Play Game Button"

func _ready() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://Settings.cfg")

	if err == OK:
		# Read values from the file (with defaults in case they are missing)
		var vol := int(config.get_value("game", "volume", 50))  # 0..100
		vol = clamp(vol, 0, 100)
		var lin := pow(float(vol) / 100.0, 2.0)  # 0..1
		var bus := AudioServer.get_bus_index("Master")
		AudioServer.set_bus_volume_db(bus, linear_to_db(lin))

	for button in get_tree().get_nodes_in_group("themed_Buttons"):
		if button is Button:
			button.add_theme_color_override("font_focus_color", Color.RED)
	# Set up neighbors manually (you can also do this in the Inspector)
	Play.grab_focus()
	
func _on_quit_pressed() -> void: 
	click.play()
	get_tree().quit() 
	pass 
# Replace with function body. 

func _on_play_game_button_pressed() -> void: 
	click.play()
	get_tree().change_scene_to_file("res://MenuScene/SongSelections.tscn") 
	pass # Replace with function body. 
	
func _on_settings_pressed() -> void: 
	click.play()
	get_tree().change_scene_to_file("res://Settings/globalSettings.tscn") 
	pass # Replace with function body.		


func _on_chart_creator_button_pressed() -> void:
	click.play()
	get_tree().change_scene_to_file("res://ChartCreator/chart_creator.tscn")
	pass # Replace with function body.
