extends Node2D

@export var arrow_scene: PackedScene
var scroll_speed
@export var chart_path: String = GlobalSettings.startingChartPath
@onready var notes_layer := $NotesLayer
@onready var music := $"../AudioStreamPlayer"
var judgement_label_scene = preload("res://judgementLabel/JudgementLabel.tscn")
@onready var judgement_layer := $"UI/Judgements"
@onready var ScoreLabel := $"../NoteScore"
@onready var globalScoring := $"../GlobalScoring"
@onready var comboTracker := $"../ComboScoring"
@export var pose_prompt_scene: PackedScene = preload("res://Poses/PosePrompter.tscn")
@onready var pose_layer: Node2D = $UI/PoseLayer
@onready var sfx_success: AudioStreamPlayer = $UI/SFXSuccess
@onready var sfx_fail: AudioStreamPlayer = $UI/SFXFail
@onready var correct: Sprite2D = $UI/Judgements/Correct
@onready var wrong: Sprite2D = $UI/Judgements/Wrong
@onready var timer: Timer = $UI/Judgements/Timer


var pose_icons := {
	"Samurai Pose": preload("res://art/uniform_samurai.png"),
	"Stop Pose": preload("res://art/uniform_stop.png"),
	"What? Pose": preload("res://art/uniform_what.png"),
	"Muscle Man Pose": preload("res://art/uniform_muscleman.png"),
	"Tough Guy Pose": preload("res://art/uniform_toughguy.png"),
	"Point Up Pose (L)": preload("res://art/uniform_pointup.png"),
	"Point Up Pose (R)": preload("res://art/uniform_pointup.png")
}

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

#state vars for our hold notes
var pressed := {
	"upLeft": false, "left": false, "downLeft": false,
	"down": false, "center": false, "up": false,
	"upRight": false, "right": false, "downRight": false
}
var active_holds := {}
# Tunables
const START_WINDOW := 0.1   # seconds to hit the head
const END_WINDOW   := 0.12  # seconds tolerance at the tail
const BREAK_GRACE  := 0.05  # brief grace for micro unholds

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
			node.arrow_released.connect(_on_arrow_released)
			# use global_position
			receptor_positions[node.direction] = node.global_position

	var file = FileAccess.open(chart_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		chart_data = JSON.parse_string(json_text)
		chart_data.sort_custom(func(a, b): return a["time"] < b["time"])
		music.play()

	scroll_speed = GlobalSettings.scrollSpeed
	print("scroll speed: ", scroll_speed)

func _active_hold_notes() -> Array:
	var arr: Array = []
	for d in active_holds.keys():
		var n = active_holds[d].get("note", null)
		if n != null: arr.append(n)
	return arr

func _process(delta):
	var song_time = music.get_playback_position()
	while spawn_index < chart_data.size():
	#while spawn_index < chart_data.size() and chart_data[spawn_index]["time"] <= song_time + get_lead_time():
		var nd = chart_data[spawn_index]
		var t: float = float(nd["time"])
		if nd.get("type", "arrow") == "pose":
			var cd := float(nd.get("countdown", 5.0))
			if song_time + 0.01 >= t- cd:
				_spawn_pose(nd)
				spawn_index +=1
			else:
				break
		else:
			if song_time + get_lead_time() >= t:
				spawn_note(nd)
				spawn_index += 1
			else:
				break
		#spawn_note(chart_data[spawn_index])
		#spawn_index += 1
	for note in notes_layer.get_children():
		if note is BaseArrow:
			if not _is_frozen_hold(note):
				note.position.y -= scroll_speed * delta
		else:
			continue
		if note.note_time < song_time -0.2 and not note in _active_hold_notes():
			if note.is_Hold:
				if note.end_Time < song_time - 0.2:
					# print("freeing")
					# print("missed")
					show_judgement("Miss", receptor_positions.get(note.direction,note.position))
					reset_Combo()
					note.queue_free()
				#we dont want them to constantly miss if they miss a hold

			else:
				# print("Miss HERE")
				show_judgement("Miss", receptor_positions.get(note.direction,note.position))
				reset_Combo()
				#dont queue free the hold notes until the end time.
				if not note.is_Hold:
					note.queue_free()
			#queue free after the hold is over
		#holds
		for dir in active_holds.keys():
			var data = active_holds[dir]
			var hold_note: BaseArrow = data["note"]
			if hold_note == null or not is_instance_valid(hold_note):
				continue
			var tail = hold_note.get_node_or_null("Tail") as Sprite2D
			if tail:
				#var song_time = music.get_playback_position() song time already declared
				var remaining_px = max(0.0, (hold_note.end_Time - song_time) * scroll_speed)
				_set_tail_length_px(hold_note, tail, remaining_px)
			print("checking hold notes")
			#if before the tail end, require holding but with gracde
			if song_time < hold_note.end_Time - END_WINDOW:
				print("break timer is: ", data["break_timer"])
				if pressed[dir]:
					data["break_timer"] = 0.0
				else:
					data["break_timer"]  += delta
					if data["break_timer"] > BREAK_GRACE:
						show_judgement("Miss", receptor_positions.get(dir,hold_note.position))
						reset_Combo()
						print("queueing free cause it was bigger than break grace")
						hold_note.queue_free()
						active_holds.erase(dir)
			#whenw e reafh tthen end
			else:
				print("we reached the end")
				print("condition value is : ", song_time-hold_note.end_Time)
				if abs(song_time - hold_note.end_Time) <= END_WINDOW and pressed[dir]:
					show_judgement("Perfect!", receptor_positions.get(dir, hold_note.position))
					update_Shown_Acc(10)
					update_Score(10)
				else:
					show_judgement("Miss", receptor_positions.get(dir, hold_note.position))
					reset_Combo()
				if is_instance_valid(hold_note):
					hold_note.queue_free()
				active_holds.erase(dir)

	var latest_udp: Dictionary = $"../UDP".latest
	for p in pose_layer.get_children():
		if p.has_method("drive"):
			p.drive(song_time, latest_udp)

func get_lead_time() -> float:
	return 1.5 # seconds to reach the receptor from spawn point

func spawn_note(note_data: Dictionary):
	# print("note data: ", note_data)
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
		# print("this is a hold note")
		var tail := arrow.get_node_or_null("Tail") as Sprite2D
		if tail:
			tail.centered = false
			tail.position = Vector2.ZERO
			tail.visible = true
			tail.self_modulate = get_color_for_direction(dir)

			var duration := float(note_data["end_Time"]) - float(note_data["time"])
			var total_px = duration * scroll_speed
			_set_tail_length_px(arrow, tail, total_px)

			#
		arrow.is_Hold = true
		arrow.end_Time = note_data["end_Time"]
		arrow.note_time = note_data["time"]


	arrow.baseColor = get_color_for_direction(dir)
	# print("arrow base color is ", arrow.baseColor)
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
		"downLeft", "downRight": return Color("c671ff")
		_:
			print("WTFFFF")
			return Color(1, 1, 1)

func check_hits(direction: String):
	var song_time = music.get_playback_position()
	var closest_note: BaseArrow = null
	var closest_diff := INF
	pressed[direction] = true

	for note in notes_layer.get_children():
		if not note is BaseArrow: continue
		if note.direction != direction: continue
		var diff = abs(note.note_time - song_time)
		if diff < closest_diff:
			closest_note = note
			closest_diff = diff

	if closest_note == null:
		return

	# HEAD judgement window
	if closest_diff <= 0.050:
		show_judgement("Perfect!", closest_note.position)
		update_Shown_Acc(10); update_Score(10); update_Combo()

		if closest_note.is_Hold:
			active_holds[direction] = {"note": closest_note, "break_timer": 0.0, "frozen": true}
			var head_poly := closest_note.get_node_or_null("Polygon2D") as Polygon2D
			var head_sprite := closest_note.get_node_or_null("Sprite2D") as Sprite2D
			if head_poly:   head_poly.visible = false
			if head_sprite: head_sprite.visible = false
		else:
			closest_note.queue_free()

	elif closest_diff <= 0.1:
		show_judgement("Good!", closest_note.position)
		update_Shown_Acc(5); update_Score(5); update_Combo()

		if closest_note.is_Hold:
			active_holds[direction] = {"note": closest_note, "break_timer": 0.0, "frozen": true}
			var head_poly := closest_note.get_node_or_null("Polygon2D") as Polygon2D
			var head_sprite := closest_note.get_node_or_null("Sprite2D") as Sprite2D
			if head_poly:   head_poly.visible = false
			if head_sprite: head_sprite.visible = false
		else:
			closest_note.queue_free()

	elif closest_diff <= 0.2:
		show_judgement("Bad!", closest_note.position)
		update_Shown_Acc(1); update_Score(1); reset_Combo()
		closest_note.queue_free()
	else:
		reset_Combo()
		show_judgement("Miss", receptor_positions[direction])


func _on_arrow_released(direction: String) -> void:
	pressed[direction] = false


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

func _sprite_base_height(s: Sprite2D) -> float:
	if s == null or s.texture == null: return 1.0
	if s.region_enabled: return max(1.0, s.region_rect.size.y)
	var sz := s.texture.get_size()
	if s.hframes > 1: sz.x /= s.hframes
	if s.vframes > 1: sz.y /= s.vframes
	return max(1.0, sz.y)

func _set_tail_length_px(arrow: Node2D, tail: Sprite2D, length_px: float) -> void:
	# Convert desired pixel length into a local Y scale for the tail,
	# compensating for *parent* (arrow) scaling so on-screen pixels match.
	var base_h := _sprite_base_height(tail)
	var parent_sy := arrow.scale.y
	if base_h <= 0.0: base_h = 1.0
	if parent_sy == 0.0: parent_sy = 1.0
	# scale.y_local = desired_pixels / (base_h * parent_world_scale_y)
	tail.scale = Vector2(tail.scale.x, length_px / (base_h * parent_sy))

func _is_frozen_hold(note: BaseArrow) -> bool:
	for d in active_holds.keys():
		var data = active_holds[d]
		if data.get("note") == note and data.get("frozen", false):
			return true
	return false

func _spawn_pose(nd: Dictionary):
	var pose_name := String(nd["pose"])
	var countdown := float(nd.get("countdown", 5.0))
	var window := float(nd.get("window", 0.25))
	var pts := int(nd.get("points", 10))

	var p = pose_prompt_scene.instantiate()
	p.modulate.a = 0.5
	p.target_pose   = pose_name
	p.target_time   = float(nd["time"])
	p.countdown_len = countdown
	p.window        = window
	p.points        = pts
	p.udp_node      = NodePath("../UDP")  # optional; we also pass latest in drive()

	if pose_icons.has(pose_name):
		p.icon = pose_icons[pose_name]

	# position UI
	p.position = Vector2( (get_viewport_rect().size.x - p.size.x)/2.0, 120 )
	pose_layer.add_child(p)
	p.global_position = get_viewport_rect().size / 2.0 -p.size /2.0
	p.global_position.x+= 1000
	#p.pose_judged.connect(_on_pose_judged)
	p.pose_judged.connect(Callable(self, "_on_pose_judged"))

func _on_pose_judged(success: bool, at_position: Vector2, points: int):
	print("[POSE] judged: ", success, " pts=", points)
	var center = globalScoring.global_position
	if success:
		show_judgement("Perfect!", at_position)
		sfx_success.play()
		#correct.global_position =get_viewport_rect().size / 2.0 -correct.size /2.0
		correct.global_position = center +Vector2(500, -120)
		correct.visible = true
		timer.start()
		update_Shown_Acc(points)
		update_Score(points)
		update_Combo()
	else:
		sfx_fail.play()
		#wrong.global_position = get_viewport_rect().size / 2.0 - wrong.size /2.0
		wrong.global_position = center+ Vector2(500,-120)
		wrong.visible = true
		timer.start()
		show_judgement("Miss", at_position)
		reset_Combo()


func _on_timer_timeout() -> void:
	correct.visible = false
	wrong.visible = false
	pass # Replace with function body.
