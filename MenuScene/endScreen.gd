extends Control
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	audio_stream_player.stream = load(GlobalSettings.current_song)
	audio_stream_player.play(GlobalSettings.songTime)
	show_stats()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func show_stats() -> void:
	var perfectCounter = GlobalSettings.perfectCounter
	var goodCounter = GlobalSettings.goodCounter
	var badCounter = GlobalSettings.badCounter
	var missCounter = GlobalSettings.missCounter
	$Stats.text = "[rainbow freq=1.0 sat=0.8 val=0.8 speed=1.0][b][font_size=86][font=res://Fonts/Johnny Fever.otf]Perfect: %d[/font][/font_size][/b][/rainbow]\n[b][color=green][font_size=86][font=res://Fonts/Johnny Fever.otf]Good:       %d\n[/font][/font_size][/color][/b][b][color=yellow][font_size=86][font=res://Fonts/Johnny Fever.otf]Bad:         %d\n[/font][/font_size][/color][/b][b][color=red][font_size=86][font=res://Fonts/Johnny Fever.otf]Miss:        %d\n[/font][/font_size][/color][/b]" % [perfectCounter, goodCounter, badCounter, missCounter]



func _on_quit_pressed() -> void:
	get_tree().quit()
	pass # Replace with function body.


func _on_play_again_pressed() -> void:
	pass # Replace with function body.


func _on_song_selection_pressed() -> void:
	pass # Replace with function body.
