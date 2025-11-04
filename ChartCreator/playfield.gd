extends Node2D
class_name PlayField

@export var pixels_per_second: float = 400.0
@export var note_scene_path: String = "res://BaseArrow/arrow.tscn"
@export var beatbar: PackedScene = preload("res://beatbar/beatbar.tscn")
var note_scenes: Dictionary = {
	"left": "res://LeftArrow/left_arrow.tscn",
	"right": "res://RightArrow/right_arrow.tscn",
	"up": "res://UpArrow/up_arrow.tscn",
	"down": "res://DownArrow/down_arrow.tscn",
	"upLeft": "res://UpLeftArrow/UpLeftArrow.tscn",
	"upRight": "res://UpRightArrow/UpRightArrow.tscn",
	"downRight": "res://DownRight/DownRight.tscn",
	"downLeft": "res://DownLeft/DownLeft.tscn",
	"center": "res://middleNote/middleNote.tscn"

}
@export var pose_prompter_scene:PackedScene = preload("res://Poses/PosePrompter.tscn")
@export var pose_pre_spawn_sec: float = 5.0
@export var pose_ui_path: NodePath 
var _pose_events: Array = []   
var _pose_cursor: int = 0  
var _active_prompts: Array[Control] = []

var audio: AudioStreamPlayer
var bpm: float = 120.0
var snap_div: int = 4
var song_offset_ms: int = 0

var chart_data: Array = []          # {"time": float, "direction": "up", ...}
var receptors: Dictionary = {}      # direction -> Node2D

var bars: Array = []                # Sprite2D
var notes: Array = []               # BaseArrow (or Node2D)

var _ghost: BaseArrow = null
var _ghost_dir: String = "center"
var _ghost_visible: bool = false

var ghost_enabled : bool = true
var drag_active: bool = false
var drag_from: Vector2 = Vector2.ZERO
var drag_to: Vector2 = Vector2.ZERO
var selected_notes: Array[Node2D] = []

var _dir_palette: Dictionary = {
	"upLeft":    Color8(198,113,255,255),
	"left":      Color8(113,190,255,255),
	"downLeft":  Color8(113,255,190,255),
	"down":      Color8(255,113,113,255),
	"center":    Color8(198,113,255,255),
	"up":        Color8(113,255,113,255),
	"upRight":   Color8(255,206,113,255),
	"right":     Color8(255,113,206,255),
	"downRight": Color8(190,190,255,255),
}

@export var sfx_enabled: bool = true
@export var flash_enabled: bool = true
@export var hit_window_sec: float = 0.03   # 30 ms
@export var flash_duration: float = 0.08
@export var flash_scale: float = 1.15
					  # optional: Control/CanvasLayer to parent prompts under
@export var udp_source_path: NodePath                    # optional: node that has a `latest` dict
				  # optional: node that has a `latest` dict
@onready var _pose_ui := get_node_or_null(pose_ui_path)
@onready var _udp_src := get_node_or_null(udp_source_path)
@onready var _hit_player: AudioStreamPlayer = $"../../../hitSound"

@export var pose_mode: bool = false              # set by your Control
@export var pose_current_name: String = "Stop Pose"

var _scrub_active : bool = false
var _scrub_time : float = 0.0

func set_scrub_time(t: float) -> void:
	_scrub_active = true
	_scrub_time = t

func clear_scrub_time() -> void:
	_scrub_active = false

func _ready() -> void:
	set_process(true)
	set_process_unhandled_input(true)

# ------------ time mapping
func _now() -> float:
	var base: float

	if _scrub_active:
		base = _scrub_time
	elif audio != null:
		base = audio.get_playback_position()
	else:
		base = 0.0

	return base + float(song_offset_ms) / 1000.0

#func _now() -> float:
	#if audio != null:
		## stream_paused keeps playback_position steady (good for editor view)
		#return audio.get_playback_position() + float(song_offset_ms) / 1000.0
	#return float(song_offset_ms) / 1000.0

func snap_time(t: float) -> float:
	var beat_len: float = 60.0 / max(1.0, bpm)
	var beats: float = (t - float(song_offset_ms) / 1000.0) / beat_len
	var snapped: float = round(beats * snap_div) / snap_div
	return (snapped * beat_len) + float(song_offset_ms) / 1000.0

func receptor_y() -> float:
	if receptors.has("center"):
		return to_local((receptors["center"] as Node2D).global_position).y
	return 0.0

func time_to_y(t: float) -> float:
	return receptor_y() + (t - _now()) * pixels_per_second

# ------------ public: called when audio loads
func build_bars_for_song(song_len: float) -> void:
	_clear_nodes(bars)
	bars.clear()
	var beat_len: float = 60.0 / max(1.0, bpm)
	var t: float = float(song_offset_ms) / 1000.0
	while t <= song_len + float(song_offset_ms) / 1000.0:
		_spawn_bar(t)
		t += beat_len
		
func _collect_pose_events() -> void:
	_pose_events.clear()
	for ev in chart_data:
		if ev.get("type","arrow") == "pose":
			_pose_events.append(ev)
	_pose_events.sort_custom(func(a,b): return float(a["time"]) < float(b["time"]))
	_pose_cursor = 0

func rebuild_notes() -> void:
	_clear_nodes(notes)
	notes.clear()
	for ev in chart_data:
		if ev.get("type", "arrow") != "arrow":
			continue
		var dir: String = str(ev.get("direction", "center"))
		_spawn_note(dir, float(ev["time"]), ev)
		# collect poses too
	_collect_pose_events()
	# clear any old prompts if you want a full rebuild
	for p in _active_prompts:
		if is_instance_valid(p): p.queue_free()
	_active_prompts.clear()

# ------------ spawning
func _spawn_bar(t: float) -> void:
	if beatbar == null:
		return
	var bar: Sprite2D = beatbar.instantiate() as Sprite2D
	if bar == null:
		return
	bar.set_meta("is_bar", true)
	bar.set_meta("bar_time", t)
	bar.z_index = 0
	bar.centered = false

	var xs: Array = []
	for k in receptors.keys():
		var n: Node2D = receptors[k] as Node2D
		xs.append(n.global_position.x)
	xs.sort()
	if xs.is_empty():
		return
	var left_x: float = float(xs.front())
	var right_x: float = float(xs.back())
	var width_px: float = right_x - left_x

	var left_local: Vector2 = to_local(Vector2(left_x, 0.0))
	bar.position = Vector2(left_local.x, time_to_y(t))

	var tex_w: float = 1.0
	if bar.texture != null:
		tex_w = max(1.0, float(bar.texture.get_size().x))
	bar.scale.x = width_px / tex_w

	add_child(bar)
	bars.append(bar)

func _spawn_note(direction: String, t: float, ev: Dictionary) -> void:
	var scene: PackedScene = null
	print("direction is ", direction)
	if note_scenes.has(direction):
		#scene = note_scenes[direction]
		scene = load(note_scenes[direction]) as PackedScene
		print("scene is ", scene, "and direction is ", direction)
	else:
		scene = load(note_scene_path) as PackedScene
		print("scene in else is ", scene)
	if scene == null:
		return

	var a_node: Node = scene.instantiate()
	if a_node == null:
		return

	# apply data fields before placement
	var a_pre: BaseArrow = a_node as BaseArrow
	if a_pre != null:
		a_pre.is_receptor = false
		a_pre.direction = direction
		a_pre.note_time = t
		a_pre.is_Hold = ev.has("end_Time")
		if a_pre.is_Hold and ev.has("end_Time"):
			a_pre.end_Time = float(ev["end_Time"])
		if not note_scenes.has(direction) and a_pre.has_node("Polygon2D") and _dir_palette.has(direction):
			var poly0: Polygon2D = a_pre.get_node("Polygon2D") as Polygon2D
			if poly0 != null:
				a_pre.baseColor = (_dir_palette[direction] as Color)
				a_pre.pressedColor = (_dir_palette[direction] as Color)
				poly0.color = a_pre.baseColor
	else:
		a_node.set_meta("direction", direction)
		a_node.set_meta("note_time", t)

	# place at lane X
	var rec: Node2D = receptors.get(direction, null)
	if rec == null:
		a_node.queue_free()
		return
	var rec_local: Vector2 = to_local(rec.global_position)
	(a_node as Node2D).position = Vector2(rec_local.x, time_to_y(t))
	(a_node as Node2D).z_index = 5

	add_child(a_node)  # let child _ready() run (some set is_receptor=true there)

	# enforce non-receptor after ready
	var a: BaseArrow = a_node as BaseArrow
	if a != null:
		a.is_receptor = false

	# match gameplay scales (center slightly smaller)
	var node2d: Node2D = a_node as Node2D
	if node2d != null:
		node2d.scale = (Vector2(0.1, 0.1) if direction == "center" else Vector2(0.2, 0.2))

	notes.append(a_node)

# ------------ frame update
func _process(_dt: float) -> void:
	for bar in bars:
		if not is_instance_valid(bar):
			continue
		var t: float = float(bar.get_meta("bar_time"))
		bar.position.y = time_to_y(t)
		bar.visible = bar.position.y > -200.0 and bar.position.y < get_viewport_rect().size.y + 200.0

	for n in notes:
		if not is_instance_valid(n):
			continue
		var ba: BaseArrow = n as BaseArrow
		var dir: String = "center"
		if ba != null:
			dir = ba.direction
		elif n.has_meta("direction"):
			dir = str(n.get_meta("direction"))
		if receptors.has(dir):
			var rec_local: Vector2 = to_local((receptors[dir] as Node2D).global_position)
			(n as Node2D).position.x = rec_local.x
		var t_note: float = 0.0
		if ba != null:
			t_note = ba.note_time
		elif n.has_meta("note_time"):
			t_note = float(n.get_meta("note_time"))
		(n as Node2D).position.y = time_to_y(t_note)
		#play sound when t_note is close enough
		if(absf(t_note - _now()) <= hit_window_sec):
			if not n.has_meta("fx_done"):
				_hit_player.play()
				_flash_note(n)
				n.set_meta("fx_done", true)
		else:
			n.set_meta("fx_done" , null)
		(n as Node2D).visible = (n as Node2D).position.y > -200.0 and (n as Node2D).position.y < get_viewport_rect().size.y + 200.0

	# hover ghost preview (direction-specific + recolor + 0.2 scale)
	if ghost_enabled:
		_unselect_all_notes()
		_ensure_ghost()
	if _ghost != null:
		var lp: Vector2 = to_local(get_global_mouse_position())
		if _is_inside_lanes(lp.x):
			var hovered_dir: String = _nearest_lane_from_x(lp.x)
			if hovered_dir != _ghost_dir:
				_ghost_dir = hovered_dir
				_replace_ghost_for_dir(_ghost_dir)

			var rec: Node2D = receptors.get(_ghost_dir, null)
			if rec != null:
				var rec_local: Vector2 = to_local(rec.global_position)
				var t_raw: float = _now() + (lp.y - receptor_y()) / pixels_per_second
				var t_snap: float = snap_time(t_raw)
				_ghost.direction = _ghost_dir
				_ghost.note_time = t_snap
				_ghost.position = Vector2(rec_local.x, time_to_y(t_snap))
				_ghost.visible = true if ghost_enabled else false
		else:
			_ghost_visible = false
			
	# --- Pose prompts: spawn & drive ---
	var now := _now()
	# spawn when countdown should begin
	while _pose_cursor < _pose_events.size():
		var ev = _pose_events[_pose_cursor]
		var t  := float(ev["time"])
		var pre := float(ev.get("countdown_len", pose_pre_spawn_sec))
		if now >= t - pre:
			_spawn_pose_prompt(ev)
			_pose_cursor += 1
		else:
			break
	# pass latest UDP if you centralize it here (optional)
	var latest_udp := {}
	if _udp_src and _udp_src.has_variable("latest"):
		latest_udp = _udp_src.latest
	var keep: Array[Control] = []
	for p in _active_prompts:
		if not is_instance_valid(p): continue
		p.drive(now, latest_udp)
		if p.is_inside_tree():
			keep.append(p)
	_active_prompts = keep

func _unhandled_input(e: InputEvent) -> void:
	# toggles
	if e is InputEventKey and e.pressed:
		if e.keycode == KEY_G:
			ghost_enabled = !ghost_enabled
			#hide ghost immediately when turning off
			if not ghost_enabled and _ghost and is_instance_valid(_ghost):
				_ghost.visible = false
			#clear note selection
			_unselect_all_notes()
			

		# delete selection
		if e.keycode == KEY_DELETE or KEY_BACKSPACE and not ghost_enabled:
			if selected_notes.size() > 0:
				print("deleting slected notes: ")
				_delete_selected()
			else:
				print("size is not greater than 0")
			return

	#place notes
	#if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and ghost_enabled:
		#if receptors.is_empty(): return
		#var lp := to_local(get_global_mouse_position())
		#var lane := _nearest_lane_from_x(lp.x)
		#var t_raw := _now() + (lp.y - receptor_y()) / pixels_per_second
		#var t := snap_time(t_raw)
		#var ev := {"type":"arrow", "direction": lane, "time": t}
		#chart_data.append(ev)
		#chart_data.sort_custom(func(a, b): return a["time"] < b["time"])
		#_spawn_note(lane, t, ev)
		#return
	# place notes OR poses
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and ghost_enabled:
		if receptors.is_empty(): return
		var lp := to_local(get_global_mouse_position())
		var lane := _nearest_lane_from_x(lp.x)
		var t_raw := _now() + (lp.y - receptor_y()) / pixels_per_second
		var t := snap_time(t_raw)

		if pose_mode:
			var ev := {
				"type": "pose",
				"pose": pose_current_name,
				"time": t,
				"countdown_len": pose_pre_spawn_sec,  # or expose per-event if you like
				"window": 0.25,
				"points": 50
			}
			chart_data.append(ev)
			chart_data.sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
			_collect_pose_events()
			# optional: if you're already inside the pre-spawn window, spawn immediately
			# (handled below in _process anyway)
		else:
			var ev := {"type":"arrow", "direction": lane, "time": t}
			chart_data.append(ev)
			chart_data.sort_custom(func(a, b): return a["time"] < b["time"])
			_spawn_note(lane, t, ev)
		return


	# selection drag begin (ghost OFF)
	if not ghost_enabled and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		drag_active = true
		drag_from = to_local(get_global_mouse_position())
		drag_to = drag_from
		queue_redraw()
		return

	# selection drag update
	if e is InputEventMouseMotion and drag_active and not ghost_enabled:
		drag_to = to_local(get_global_mouse_position())
		queue_redraw()
		return

	# selection drag end
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		if drag_active and not ghost_enabled:
			drag_active = false
			var r := _rect_from_drag()
			_set_selected(_notes_in_rect(r))
			queue_redraw()
			return

func _nearest_lane_from_x(local_x: float) -> String:
	var best: String = "center"
	var best_d: float = 1.0e9
	var order: Array = ["upLeft","left","downLeft","down","center","up","upRight","right","downRight"]
	for k in order:
		if not receptors.has(k):
			continue
		var n: Node2D = receptors[k] as Node2D
		var lx: float = to_local(n.global_position).x
		var d: float = absf(local_x - lx)
		if d < best_d:
			best_d = d
			best = k
	return best

func _is_inside_lanes(local_x: float) -> bool:
	var xs: Array = []
	for k in receptors.keys():
		var n: Node2D = receptors[k] as Node2D
		xs.append(to_local(n.global_position).x)
	xs.sort()
	if xs.is_empty():
		return false
	return local_x >= float(xs.front()) and local_x <= float(xs.back())

func _ensure_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		return
	_replace_ghost_for_dir(_ghost_dir)

func _replace_ghost_for_dir(direction: String) -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
		_ghost = null

	var scene: PackedScene = null
	#fix this logic
	if note_scenes.has(direction):
		scene = load(note_scenes[direction]) as PackedScene
	else:
		scene = load(note_scene_path) as PackedScene
	if scene == null:
		return

	var n: Node = scene.instantiate()
	_ghost = n as BaseArrow
	if _ghost != null:
		_ghost.is_receptor = false
		_ghost.modulate.a = 0.45
		_ghost.z_index = 6
		_ghost.scale = Vector2(0.2, 0.2) if direction != "center" else Vector2(0.1,0.1)
		_ghost.direction = direction
		if _dir_palette.has(direction):
			_ghost.baseColor = (_dir_palette[direction] as Color)
			_ghost.pressedColor = (_dir_palette[direction] as Color)
			var poly: Polygon2D = _ghost.get_node_or_null("Polygon2D") as Polygon2D
			if poly != null:
				poly.color = _ghost.baseColor
		add_child(_ghost)

# ------------ utils
func _clear_nodes(arr: Array) -> void:
	for n in arr:
		if is_instance_valid(n):
			n.queue_free()


func _draw() -> void:
	if drag_active and not ghost_enabled:
		var p0: Vector2 = Vector2(min(drag_from.x, drag_to.x), min(drag_from.y, drag_to.y))
		var p1: Vector2 = Vector2(max(drag_from.x, drag_to.x), max(drag_from.y, drag_to.y))
		var r := Rect2(p0, p1 - p0)
		# fill
		draw_rect(r, Color(1,1,1,0.12), true)
		# outline
		draw_rect(r, Color(1,1,1,0.9), false, 2.0)

func _rect_from_drag() -> Rect2:
	var p0: Vector2 = Vector2(min(drag_from.x, drag_to.x), min(drag_from.y, drag_to.y))
	var p1: Vector2 = Vector2(max(drag_from.x, drag_to.x), max(drag_from.y, drag_to.y))
	return Rect2(p0, p1 - p0)

func _notes_in_rect(r: Rect2) -> Array[Node2D]:
	var res: Array[Node2D] = []
	for n in notes:
		if not is_instance_valid(n): continue
		var p: Vector2 = (n as Node2D).position  # already local
		if r.has_point(p):
			res.append(n)
	return res

func _set_selected(ns: Array[Node2D]) -> void:
	# simple visual—tint selected; clear old
	for n in selected_notes:
		if is_instance_valid(n): (n as Node2D).modulate = Color(1,1,1,1)
		var poly = n.get_node_or_null("Polygon2D")
		if poly:
			poly.color = n.pressedColor
	selected_notes = ns.duplicate()
	for n in selected_notes:
		#(n as Node2D).modulate = Color(164,244,255,0.8)
		var poly = n.get_node_or_null("Polygon2D")
		if poly:
			poly.color = Color(0.3, 0.8, 1.0)

func _delete_selected() -> void:
	if selected_notes.is_empty(): return
	# remove nodes
	for n in selected_notes:
		if is_instance_valid(n):
			n.queue_free()
			notes.erase(n)
	#remove from chart_data by time+dir match (tolerance for float)
	var approx := func(a: float, b: float) -> bool: return absf(a - b) < 0.0005
	for sn in selected_notes:
		var ba: BaseArrow = sn as BaseArrow
		var dir := ba.direction if ba != null else (sn.get_meta("direction") as String)
		var t  := ba.note_time  if ba != null else  float(sn.get_meta("note_time"))
		for i in range(chart_data.size() - 1, -1, -1):
			var ev = chart_data[i]
			if ev.get("type","arrow") == "arrow" and ev.get("direction","center") == dir and approx.call(float(ev["time"]), t):
				chart_data.remove_at(i)
	selected_notes.clear()
	
func _unselect_all_notes() -> void:
	if selected_notes.is_empty():
		return
	for n in selected_notes:
		if not is_instance_valid(n):
			continue
		var polygon := n.get_node_or_null("Polygon2D")
		polygon.color = n.pressedColor

	selected_notes.clear()
	
func _flash_note(n: Node2D) -> void:
	if not flash_enabled: return
	var poly := n.get_node_or_null("Polygon2D") as Polygon2D
	if poly == null: return
	var base_color: Color = poly.color
	var base_scale: Vector2 = n.scale
	var flash_color: Color = Color(0.3, 0.8, 1.0, base_color.a)

	var d := flash_duration / play_rate  # so it feels the same in “song time”

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", base_scale * flash_scale, d * 0.5)
	tw.parallel().tween_property(poly, "color", flash_color, d * 0.5)
	tw.tween_property(n, "scale", base_scale, d * 0.5)
	tw.parallel().tween_property(poly, "color", base_color, d * 0.5)

#func _flash_note(n: Node2D) -> void:
	#if not flash_enabled:
		#return
	#var poly: Polygon2D = n.get_node_or_null("Polygon2D")
	#if poly == null:
		#return
	#var base_color: Color = poly.color
	#var base_scale: Vector2 = n.scale
	#var flash_color: Color = Color(0.3, 0.8, 1.0, base_color.a)
#
	#var tw := create_tween()
	#tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
#
	##scale pop + color flash
	#tw.tween_property(n, "scale", base_scale * flash_scale, flash_duration * 0.5)
	#tw.parallel().tween_property(poly, "color", flash_color, flash_duration * 0.5)
#
	##return to normal
	#tw.tween_property(n, "scale", base_scale, flash_duration * 0.5)
	#tw.parallel().tween_property(poly, "color", base_color, flash_duration * 0.5)


func _spawn_pose_prompt(ev: Dictionary) -> void:
	if pose_prompter_scene == null:
		return
	var p := pose_prompter_scene.instantiate() as Control
	if p == null:
		return

	# set exported fields on the prompt
	p.target_pose  = String(ev.get("pose",""))
	p.target_time  = float(ev.get("time", 0.0))
	p.countdown_len = float(ev.get("countdown_len", pose_pre_spawn_sec))
	p.window       = float(ev.get("window", 0.25))
	p.points       = int(ev.get("points", 10))

	# per-event icon (optional)
	if ev.has("icon") and ev["icon"] is Texture2D:
		p.icon = ev["icon"]

	# if you prefer the prompt to read UDP by itself:
	if _udp_src and _udp_src != null:
		p.udp_node = udp_source_path

	# parent under UI (if provided), else under PlayField
	var parent := _pose_ui if _pose_ui != null else self
	parent.add_child(p)

	# place somewhere sensible (centered above receptors)
	var y := receptor_y() - 160.0
	p.global_position = Vector2(global_position.x, to_global(Vector2(0,y)).y)

	# connect scoring signal
	p.pose_judged.connect(_on_pose_judged)

	_active_prompts.append(p)

func _on_pose_judged(success: bool, at_position: Vector2, points: int) -> void:
	if success:
		# simple feedback: sound + screen flash
		_hit_player.play()
		# you could also flash a receptor or spawn a checkmark sprite here
	else:
		# miss feedback, e.g., different sfx or shake
		pass
	# TODO: add to your score/state machine as needed
	
@export_range(0.25, 2.0, 0.05) var play_rate := 1.0 : set = set_play_rate

func set_play_rate(r: float) -> void:
	play_rate = clamp(r, 0.25, 2.0)
	if audio:
		audio.pitch_scale = play_rate          # speed + pitch change
	if _hit_player:
		_hit_player.pitch_scale = play_rate    # optional: keep SFX feel
