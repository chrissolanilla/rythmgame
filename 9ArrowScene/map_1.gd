extends Node2D

@export var arrow_scene: PackedScene
@export var scroll_speed := 300.0 # pixels per second
@export var chart_path := "res://MapsJson/simple_chart.json"
@onready var notes_layer := $NotesLayer
@onready var music := $"../AudioStreamPlayer"

var chart_data = []
var spawn_index = 0

var receptor_positions = {
	"upLeft": Vector2(807, 417),
	"left": Vector2(690, 417),
	"downLeft": Vector2(588, 417),
	"down": Vector2(941, 417),
	"center": Vector2(1100, 417),
	"up": Vector2(1274, 417),
	"upRight": Vector2(1398, 417),
	"right": Vector2(1510, 417),
	"downRight": Vector2(1608, 417)
}

var arrow_scenes = {
	"up": preload("res://UpArrow/up_arrow.tscn"),
	"down": preload("res://DownArrow/down_arrow.tscn"),
	"left": preload("res://LeftArrow/left_arrow.tscn"),
	"right": preload("res://RightArrow/right_arrow.tscn"),
	"upLeft": preload("res://UpLeftArrow/UpLeftArrow.tscn"),
	"upRight": preload("res://UpRightArrow/UpRightArrow.tscn"),
	"downRight": preload("res://DownRight/DownRight.tscn"),
	"downLeft": preload("res://DownLeft/DownLeft.tscn"),
	"center": preload("res://middleNote/middleNote.tscn")
}

func _ready():
	# connect signals manually or via editor
	var receptors = get_parent().get_children()
	for node in receptors:
		if node is BaseArrow and node.is_receptor:
			node.arrow_pressed.connect(check_hits)
			# use global_position
			receptor_positions[node.direction] = node.global_position  

	var file = FileAccess.open(chart_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		chart_data = JSON.parse_string(json_text)
		chart_data.sort_custom(func(a, b): return a["time"] < b["time"])
		music.play()
	
	

func _process(delta):
	var song_time = music.get_playback_position()

	while spawn_index < chart_data.size() and chart_data[spawn_index]["time"] <= song_time + get_lead_time():
		spawn_note(chart_data[spawn_index])
		spawn_index += 1

	for note in notes_layer.get_children():
		note.position.y -= scroll_speed * delta
		#print("note position y: ", note.position.y)
		#miss detection
		if note.note_time < song_time -0.2:
			print("Miss")
			note.queue_free()

func get_lead_time() -> float:
	return 1.5 # seconds to reach the receptor from spawn point

func spawn_note(note_data: Dictionary):
	#print("note data: ", note_data)
	var dir = note_data["direction"]
	var arrow = arrow_scenes[dir].instantiate()

	var global_pos = receptor_positions[dir] + Vector2(0, scroll_speed * get_lead_time())
	arrow.position = notes_layer.to_local(global_pos)

	arrow.direction = dir
	arrow.inputAction = ""  # disables input for scrolling arrows
	arrow.is_receptor = false
	arrow.scale = Vector2(0.2, 0.2)
	arrow.baseColor = get_color_for_direction(dir)
	arrow.note_time = note_data["time"]  # assign for hit detection
	notes_layer.add_child(arrow)
	
	#print("Final spawn position:", arrow.position)

func get_color_for_direction(dir: String) -> Color:
	match dir:
		"upLeft", "upRight": return Color("fc0303")
		"left": return Color("032cfc")
		"right": return Color("fcf003")
		"down": return Color("e66600")
		"up": return Color("e66600")
		"center": return Color("c671ff")
		"downLeft", "upRight": return Color("c671ff")
		_:
			print("WTFFFF")
			return Color(1, 1, 1)

#this should run when we recieve some sort of signal?
func check_hits(direction: String):
	var song_time = music.get_playback_position()
	var closest_note = null
	var closest_diff = INF

	for note in notes_layer.get_children():
		if note.direction != direction:
			continue

		var diff = abs(note.note_time - song_time)
		if diff < closest_diff:
			closest_note = note
			closest_diff = diff

	if closest_note == null:
		return  # no matching note

	if closest_diff <= 0.050:
		print("Perfect!")
		closest_note.queue_free()
	elif closest_diff <= 0.1:
		print("Good!")
		closest_note.queue_free()
	elif closest_diff <= 0.2:
		print("Bad!")
		closest_note.queue_free()
	else:
		print("Too early/late, no hit")
