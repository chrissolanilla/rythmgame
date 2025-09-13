extends Node2D

@export var arrow_scene: PackedScene
@export var scroll_speed := 300.0 # pixels per second
@export var chart_path: String = GlobalSettings.startingChartPath
@onready var notes_layer := $NotesLayer
@onready var music := $"../AudioStreamPlayer"
var judgement_label_scene = preload("res://judgementLabel/JudgementLabel.tscn")
@onready var judgement_layer := $"UI/Judgements"
@onready var ScoreLabel := $"../NoteScore"
@onready var globalScoring := $"../GlobalScoring"
@onready var comboTracker := $"../ComboScoring"

var globalScore: int = 0
var globalCombo: int = 0


func show_judgement(text: String, position: Vector2):
	var label = judgement_label_scene.instantiate()
	label.text = text
	label.position = position + Vector2(0, -40)

	# set custom color
	match text:
		"Perfect!":
			label.modulate = Color("34cfeb") # bright blue
		"Good!":
			label.modulate = Color("00c92c") # greenish
		"Bad!":
			label.modulate = Color("03005c") # dark blue
		"Miss":
			label.modulate = Color("ff1900") # red

	judgement_layer.add_child(label)

	if label.has_node("AnimationPlayer"):
		label.get_node("AnimationPlayer").play("fade_out")

	await get_tree().create_timer(1.0).timeout
	if label.is_inside_tree():
		label.queue_free()



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
	
	print(chart_path)
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
		
		#Function for holding note
		#Check if note is a type hold
		#Create boolean of if type hold
		
		#miss detection
		if note.note_time < song_time -0.2:
			print("Miss HERE")
			show_judgement("Miss", receptor_positions.get(note.direction,note.position))
			reset_Combo()
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
	if dir == "center":
		arrow.scale = Vector2(0.1, 0.1) 
	else:
		arrow.scale = Vector2(0.2, 0.2)
		
	#Hold Note Creation
	if note_data.has("end_Time"):
		arrow.is_Hold = true
		arrow.end_Time = note_data["end_Time"]
		arrow.note_time = note_data["time"]
		

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
		"center", "middleNote": return Color("c671ff")
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
		if not note is BaseArrow:
			continue
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
		show_judgement("Perfect!", closest_note.position)
		update_Shown_Acc(10)
		update_Score(10)
		update_Combo()
		closest_note.queue_free()
	elif closest_diff <= 0.1:
		print("Good!")
		show_judgement("Good!", closest_note.position)
		update_Shown_Acc(5)
		update_Score(5)
		update_Combo()
		closest_note.queue_free()
	elif closest_diff <= 0.2:
		print("Bad!")
		show_judgement("Bad!", closest_note.position)
		update_Shown_Acc(1)
		update_Score(1)
		reset_Combo()
		closest_note.queue_free()
	else:
		print("Miss")
		reset_Combo()
		show_judgement("Miss", receptor_positions[direction])
		
func update_Shown_Acc(x):
	if x is int:
		ScoreLabel.text = "[b][color=green] %s [/color][/b]" % x
	else:
		ScoreLabel.text = "[b][color=green] 0 [/color][/b]"

func update_Score(x):
	globalScore += x
	globalScoring.text = "[b][color=green] %s [/color][/b]" % globalScore
	
	#Could add to updating the score of based on the 2 parameters scoring and combo, total score could be the following formula
	#globalscore = (shown acc score * globalCombo) + globalScore
	
func update_Combo():
	globalCombo += 1
	comboTracker.text = "[b][color=green] %s [/color][/b]" % globalCombo
	
func reset_Combo():
	globalCombo = 0
	comboTracker.text = "[b][color=green] %s [/color][/b]" % globalCombo
