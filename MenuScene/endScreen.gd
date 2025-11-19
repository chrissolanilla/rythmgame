extends Control
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var perfect: RichTextLabel = $Perfect
@onready var good: RichTextLabel = $Good
@onready var bad: RichTextLabel = $Bad
@onready var miss: RichTextLabel = $Miss
@onready var combo: RichTextLabel = $Combo
@onready var texture_rect: TextureRect = $TextureRect
@onready var score: RichTextLabel = $Score


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for button in get_tree().get_nodes_in_group("themed_Buttons"):
		if button is Button:
			button.add_theme_color_override("font_focus_color", Color.RED)
	audio_stream_player.stream = load(GlobalSettings.current_song)
	audio_stream_player.play(GlobalSettings.songTime)
	perfect.text = "[rainbow freq=1.0 sat=0.8 val=0.8 speed=1.0][b][font_size=86][font=res://Fonts/Johnny Fever.otf]Perfect: %d[/font][/font_size][/b][/rainbow]\n" % GlobalSettings.perfectCounter
	good.text = "[b][color=green][font_size=86][font=res://Fonts/Johnny Fever.otf]Good:       %d\n[/font][/font_size][/color][/b]" % GlobalSettings.goodCounter
	bad.text = "[b][color=yellow][font_size=86][font=res://Fonts/Johnny Fever.otf]Bad:         %d\n[/font][/font_size][/color][/b]" % GlobalSettings.badCounter
	miss.text = "[b][color=red][font_size=86][font=res://Fonts/Johnny Fever.otf]Miss:        %d\n[/font][/font_size][/color][/b]\n" % GlobalSettings.missCounter
	combo.text = "[b][font_size=86][font=res://Fonts/Johnny Fever.otf]Highest Combo: x%d[/font][/font_size][/b]\n" % GlobalSettings.highestComboAchieved
	score.text = "[b][font_size=86][font=res://Fonts/Johnny Fever.tf]Score: %d" % GlobalSettings.score
	texture_rect.texture = load(GlobalSettings.startingChartImage)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_quit_pressed() -> void:
	get_tree().quit()
	pass # Replace with function body.


func _on_play_again_pressed() -> void:
	get_tree().change_scene_to_file("res://9ArrowScene/Game.tscn")
	pass # Replace with function body.


func _on_song_selection_pressed() -> void:
	get_tree().change_scene_to_file("res://MenuScene/SongSelections.tscn")
	pass # Replace with function body.
