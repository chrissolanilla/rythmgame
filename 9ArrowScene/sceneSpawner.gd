extends Node2D
var judgement_tween: Tween

@export var arrow_scene: PackedScene
var scroll_speed
@export var chart_path: String
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
@export var beatbar: PackedScene = preload("res://beatbar/beatbar.tscn")
var test_play : bool
@onready var current_pose_text: Label = $"../CurrentPoseText"
var chartFinished: bool = false
@onready var progress_bar: ProgressBar = $"../ProgressBar"
@onready var middle_note: Node2D = $"../MiddleNote"


var perfects: int
var goods: int
var bads: int
var misses: int
var highestCombo: int = 0
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

	
func show_judgement(text: String, position: Vector2) -> void:
	var label: RichTextLabel = ScoreLabel
	if label == null:
		return

	# Kill previous tween if it exists
	if judgement_tween and judgement_tween.is_valid():
		judgement_tween.kill()  # or judgement_tween.stop()

	# Reset state so it's definitely visible
	label.visible = true
	label.scale = Vector2.ONE
	label.modulate = Color.WHITE
	label.modulate.a = 1.0

	label.text = "[b]%s" % text
	match text:
		"Perfect!":
			label.modulate = Color("34cfeb")
		"Good!":
			label.modulate = Color("00c92c")
		"Bad!":
			label.modulate = Color("03005c")
		"Miss":
			label.modulate = Color("ff1900")

	# Create a new tween and keep a handle to it
	judgement_tween = get_tree().create_tween()

	judgement_tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.08) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	judgement_tween.tween_property(label, "scale", Vector2.ONE, 0.10) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)

	# Slightly shorter fade helps on dense patterns
	judgement_tween.parallel().tween_property(label, "modulate:a", 0.0, 0.25) \
		.set_delay(0.10)

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
var bar_interval: float
var next_bar_time: float
@export var bar_offset :float =0.0

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
	middle_note.is_receptor = true
	print("gloabl offset is : ", GlobalSettings.timing_offset)
	perfects = 0
	bads = 0
	goods = 0
	misses = 0
	
	test_play = GlobalSettings.test_play
	chart_path = GlobalSettings.startingChartPath
	print("chart path is " , chart_path)
	# connect signals manually or via editor

	var receptors = get_parent().get_children()
	for node in receptors:
		if node is BaseArrow and node.is_receptor:
			node.arrow_pressed.connect(check_hits)
			node.arrow_released.connect(_on_arrow_released)
			# use global_position
			receptor_positions[node.direction] = node.global_position

	#var file = FileAccess.open(chart_path, FileAccess.READ)
	#if file:
		#var json_text = file.get_as_text()
		#chart_data = JSON.parse_string(json_text)
		#chart_data.sort_custom(func(a, b): return a["time"] < b["time"])
		#var songPath = load(GlobalSettings.current_song)
		#print("current song path is ", GlobalSettings.current_song)
		#music.stream = songPath
		#music.play()
	var file = FileAccess.open(chart_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		chart_data = JSON.parse_string(json_text)
		chart_data.sort_custom(func(a, b): return a["time"] < b["time"])

		# --- load audio for both built-in and external paths ---
		var path := GlobalSettings.current_song
		print("current song path is ", path)

		var stream: AudioStream = null

		if path.begins_with("res://"):
			# normal in-project resource
			stream = load(path) as AudioStream
		else:
			# external file: do what chart editor does
			var ext := path.get_extension().to_lower()
			if ext == "mp3":
				var s_mp3 := AudioStreamMP3.new()
				s_mp3.data = FileAccess.get_file_as_bytes(path)
				stream = s_mp3
			elif ext == "wav":
				var s_wav := AudioStreamWAV.new()
				s_wav.data = FileAccess.get_file_as_bytes(path)
				stream = s_wav
			elif ext == "ogg" or ext == "oga":
				var s_ogg := AudioStreamOggVorbis.new()
				if s_ogg.has_method("load_from_file"):
					s_ogg.load_from_file(path)
					stream = s_ogg

		if stream:
			music.stream = stream
			music.play()
		else:
			push_error("Failed to load song for test play: %s" % path)


	scroll_speed = GlobalSettings.scrollSpeed
	print("scroll speed: ", scroll_speed)
	bar_interval = (60.0 / scroll_speed) *4.0
	next_bar_time = bar_offset+bar_interval



func _active_hold_notes() -> Array:
	var arr: Array = []
	for d in active_holds.keys():
		var n = active_holds[d].get("note", null)
		if n != null: arr.append(n)
	return arr
#

func _process(delta):
	var song_time_raw : float = music.get_playback_position()
	var song_time_adj :float = song_time_raw - GlobalSettings.timing_offset
	progress_bar.value = (song_time_raw / music.stream.get_length()) * 100
	#if song_time > 3:
		
	if chartFinished == true :
		var counter = 0
		var notesList = notes_layer.get_children()
		for note in notesList:
			if not note.has_meta("is_bar"):
				counter += 1
		if counter == 0:
			GlobalSettings.songTime = song_time_raw
			GlobalSettings.perfectCounter = perfects
			GlobalSettings.goodCounter = goods
			GlobalSettings.badCounter = bads
			GlobalSettings.missCounter = misses
			GlobalSettings.highestComboAchieved = highestCombo
			
			get_tree().change_scene_to_file("res://MenuScene/SongEnd.tscn")
	if spawn_index == chart_data.size():
		chartFinished = true
	#get_tree().change_scene_to_file("res://MenuScene/SongEnd.tscn")
	# -------- SPAWN (poses + notes) --------
	while spawn_index < chart_data.size():
		var nd = chart_data[spawn_index]
		var t  := float(nd["time"])

		if nd.get("type", "arrow") == "pose":
			var cd := float(nd.get("countdown", 5.0))
			if song_time_raw + 0.01 >= t - cd:
				_spawn_pose(nd)
				spawn_index += 1
			else:
				break
		else:
			if song_time_raw + get_lead_time() >= t:
				spawn_note(nd)
				spawn_index += 1
			else:
				break

	# beat bars
	while song_time_raw + get_lead_time() >= next_bar_time:
		spawn_bar_at_time(next_bar_time)
		next_bar_time += (60.0 / scroll_speed) * 4.0

	# -------- MOVE / CLEANUP --------
	for child in notes_layer.get_children():
		# bars
		if child.has_meta("is_bar"):
			child.position.y -= scroll_speed * delta
			if song_time_raw > float(child.get_meta("bar_time", -1.0)) + 0.2:
				child.queue_free()
			continue

		# notes
		var note := child as BaseArrow
		if note == null:
			continue

		# scroll unless it's a frozen hold head
		if not _is_frozen_hold(note):
			note.position.y -= scroll_speed * delta

		# generic miss cleanup (skip active, frozen holds)
		if note.note_time < song_time_adj - 0.2 and not note in _active_hold_notes():
			if note.is_Hold:
				if note.end_Time < song_time_adj - 0.2:
					show_judgement("Miss", receptor_positions.get(note.direction, note.position))
					misses+=1
					reset_Combo()
					note.queue_free()
			else:
				show_judgement("Miss", receptor_positions.get(note.direction, note.position))
				misses+=1
				print("clean up miss here")
				reset_Combo()
				note.queue_free()

	# drive pose UI
	var latest_udp: Dictionary = $"../UDP".latest
	var changed: bool = bool(latest_udp.get("changed", false))
	if changed:
		current_pose_text.text = "Current Pose: %s, " % GlobalSettings.current_pose
		#update text of current pose
		
	for p in pose_layer.get_children():
		if p.has_method("drive"):
			#i think we use raw for poses?
			p.drive(song_time_raw, latest_udp)

	# -------- ACTIVE HOLDS: shrink tails & finish --------
	var dirs_to_erase: Array = []
	for dir in active_holds.keys():
		var data = active_holds[dir]
		var n: BaseArrow = data.get("note")
		if not is_instance_valid(n):
			dirs_to_erase.append(dir)
			continue

		var tail := n.get_node_or_null("Tail") as Sprite2D
		var remaining = float(n.end_Time) - song_time_adj  # seconds left

		# keep frozen while held; small grace for micro unholds
		if pressed.get(dir, false):
			data["break_timer"] = 0.0
			data["frozen"] = true
		else:
			data["break_timer"] = data.get("break_timer", 0.0) + delta
			if data["break_timer"] > BREAK_GRACE:
				data["frozen"] = false

		# shrink/update tail pixels
		if tail:
			var remaining_px : float= max(0.0, remaining) * scroll_speed
			_set_tail_length_px(n, tail, remaining_px)
			tail.visible = remaining_px > 0.5

		# completion: tail reached
		if remaining <= END_WINDOW:
			# (optional: award if still holding)
			# if pressed.get(dir, false): show_judgement("Hold OK!", receptor_positions[dir])
			if is_instance_valid(n):
				n.queue_free()
			dirs_to_erase.append(dir)
		else:
			# write back updated data
			active_holds[dir] = data

	# remove finished/invalid holds outside the loop
	for d in dirs_to_erase:
		active_holds.erase(d)

func get_lead_time() -> float:
	return 2.5 # seconds to reach the receptor from spawn point

func spawn_note(note_data: Dictionary):
	var dir = note_data["direction"]
	var arrow = arrow_scenes[dir].instantiate()

	var global_pos = receptor_positions[dir] + Vector2(0, scroll_speed * get_lead_time())
	arrow.position = notes_layer.to_local(global_pos)

	arrow.direction = dir
	arrow.inputAction = ""  # disables input for scrolling arrows
	arrow.is_receptor = false
	arrow.z_index = 2
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
		arrow.is_Hold = true
		arrow.end_Time = note_data["end_Time"]
		arrow.note_time = note_data["time"]


	arrow.baseColor = get_color_for_direction(dir)
	# print("arrow base color is ", arrow.baseColor)
	arrow.note_time = note_data["time"]  # assign for hit detection
	arrow.modulate = Color.WHITE
	arrow.modulate.a = 4.5
	notes_layer.add_child(arrow)
	arrow.is_receptor = false

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
	var song_time_raw :float= music.get_playback_position()
	var song_time_adj :float= song_time_raw - GlobalSettings.timing_offset
	#var song_time = music.get_playback_position()
	var closest_note: BaseArrow = null
	var closest_diff := INF
	pressed[direction] = true

	for note in notes_layer.get_children():
		if not note is BaseArrow: continue
		if note.direction != direction: continue
		var diff = abs(note.note_time - song_time_adj)
		if diff < closest_diff:
			closest_note = note
			closest_diff = diff

	if closest_note == null:
		return

	# HEAD judgement window
	if closest_diff <= 0.050:
		show_judgement("Perfect!", closest_note.position)
		update_Shown_Acc(10); update_Score(10); update_Combo(); perfects += 1; 
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
		update_Shown_Acc(5); update_Score(5); update_Combo(); goods += 1; 

		if closest_note.is_Hold:
			active_holds[direction] = {"note": closest_note, "break_timer": 0.0, "frozen": true}
			var head_poly := closest_note.get_node_or_null("Polygon2D") as Polygon2D
			var head_sprite := closest_note.get_node_or_null("Sprite2D") as Sprite2D
			if head_poly:   head_poly.visible = false
			if head_sprite: head_sprite.visible = false
		else:
			closest_note.queue_free()

	#instead of making it bad if within 0.2 and miss after that, make it else bad and dont do miss for early or late press
	elif closest_diff <= 0.2:
		show_judgement("Bad!", closest_note.position)
		update_Shown_Acc(1); update_Score(1); reset_Combo(); bads += 1; 
		
		closest_note.queue_free()
	#actually dont give them misses for hitting it too early or late at this time
	#there always gonna be standing on the pad on at leats one arrow so yeah. 
	#you need to be able to press on it and shit 
	#else:
		#reset_Combo(); misses += 1;
		#show_judgement("Miss", receptor_positions[direction])
		#print("we doing miss here")
		#misses+=1


func _on_arrow_released(direction: String) -> void:
	pressed[direction] = false


func update_Shown_Acc(x):
	pass
	#if x is int:
		#ScoreLabel.text = "[b][color=green] %s [/color][/b]" % x
	#else:
		#ScoreLabel.text = "[b][color=green] 0 [/color][/b]"

func update_Score(x):
	globalScore += x
	globalScoring.text = "%s" % globalScore

	#Could add to updating the score of based on the 2 parameters scoring and combo, total score could be the following formula
	#globalscore = (shown acc score * globalCombo) + globalScore

func update_Combo():
	globalCombo += 1
	highestCombo = max(highestCombo, globalCombo)
	comboTracker.text = "x%s" % globalCombo

func reset_Combo():
	highestCombo = max(highestCombo, globalCombo)
	globalCombo = 0
	comboTracker.text = "x%s" % globalCombo

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
	p.global_position.x= $"../ComboScoring".global_position.x + 1500
	p.z_index = 10
	print("p.global_postion.x is : ", p.global_position.x)
	#p.pose_judged.connect(_on_pose_judged)
	p.pose_judged.connect(Callable(self, "_on_pose_judged"))

func _on_pose_judged(success: bool, at_position: Vector2, points: int):
	print("[POSE] judged: ", success, " pts=", points)
	var center = comboTracker.global_position
	if success:
		show_judgement("Perfect!", at_position)
		sfx_success.play()
		#correct.global_position =get_viewport_rect().size / 2.0 -correct.size /2.0
		correct.global_position = center +Vector2(1200, -400)
		correct.visible = true
		timer.start()
		update_Shown_Acc(points)
		update_Score(points)
		update_Combo()
	else:
		sfx_fail.play()
		#wrong.global_position = get_viewport_rect().size / 2.0 - wrong.size /2.0
		wrong.global_position = center+ Vector2(1200,-400)
		wrong.visible = true
		timer.start()
		show_judgement("Miss", at_position)
		misses+=1
		reset_Combo()


func _on_timer_timeout() -> void:
	correct.visible = false
	wrong.visible = false
	pass # Replace with function body.


func spawn_bar_at_time(t: float) -> void:
	var bar := beatbar.instantiate() as Sprite2D
	if bar == null:
		return
	bar.set_meta("is_bar", true)
	bar.set_meta("bar_time", t)
	bar.z_index = 0
	bar.centered = false
	# compute lane span from receptor Xs
	var xs: Array = []
	for k in receptor_positions.keys():
		xs.append(receptor_positions[k].x)
	xs.sort()
	var left_x  := float(xs.front())
	var right_x := float(xs.back())
	var width_px := right_x - left_x

	# spawn Y = receptor line + travel distance for lead time
	var spawn_y = receptor_positions["center"].y + scroll_speed * get_lead_time()

	# place in notes_layer space at left edge
	bar.position = notes_layer.to_local(Vector2(left_x, spawn_y))

	# stretch the sprite horizontally to match lane width
	var tex_w := 1.0
	if bar.texture:
		tex_w = max(1.0, float(bar.texture.get_size().x))
	bar.scale.x = width_px / tex_w
	bar.modulate = Color.AQUA
	bar.modulate.a = 5
	# tweak thickness if needed:
	# bar.scale.y = 1.5

	notes_layer.add_child(bar)


func _on_audio_stream_player_finished() -> void:	
	get_tree().change_scene_to_file("res://MenuScene/SongEnd.tscn")
	pass # Replace with function body.
