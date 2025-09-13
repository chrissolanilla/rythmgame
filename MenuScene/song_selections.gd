extends Control

func _on_song_1_pressed() -> void:
	GlobalSettings.startingChartPath = "res://MapsJson/simple_chart.json"
	print("Chart set to ",GlobalSettings.startingChartPath)
	pass # Replace with function body.


func _on_song_2_pressed() -> void:
	GlobalSettings.startingChartPath = "res://MapsJson/recorded_chart_2.json"
	print("Chart set to ",GlobalSettings.startingChartPath)
	pass # Replace with function body.


func _on_play_map_pressed() -> void:
	get_tree().change_scene_to_file("res://9ArrowScene/Game.tscn")
	pass # Replace with function body.
