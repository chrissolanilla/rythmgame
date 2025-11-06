extends Node2D
class_name PlayField

@export_range(0.25, 2.0, 0.05) var play_rate := 1.0 : set = set_play_rate
@export var pixels_per_second: float = 400.0
@export var note_scene_path: String = "res://BaseArrow/arrow.tscn"
@export var beatbar: PackedScene = preload("res://beatbar/beatbar.tscn")
@export var poseScene: PackedScene = preload("res://ChartCreator/pose.tscn")
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
var poses := {
	0: "Samurai",
	1: "Point up(L)",
	2: "Point up(R)",
	3: "Stop",
	4: "Muscle Man",
	5: "What",
	6: "Tough Guy",
}

var poses_array: Array = []

var pose_sprites := {
	0: preload("res://art/uniform_samurai.png"),
	1: preload("res://art/uniform_stop.png"),
	2: preload("res://art/uniform_what.png"),
	3: preload("res://art/uniform_muscleman.png"),
	4: preload("res://art/uniform_toughguy.png"),
	5: preload("res://art/uniform_pointup.png"),
	6: preload("res://art/uniform_pointup.png")
}


@export var pose_pre_spawn_sec: float = 5.0
var _pose_events: Array = []
var pose_index: int = 0

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
var pose_name: String
var _prev_now: float = -INF

var active_holds := {}

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

@onready var _hit_player: AudioStreamPlayer = $"../../../hitSound"

@export var pose_mode: bool = false              # set by your Control
var hold_enabled: bool = false
@export var hold_duration: float = 1.0
var _scrub_active : bool = false
var _scrub_time : float = 0.0
var select_mode: bool = false

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

func rebuild_notes() -> void:
	_clear_nodes(notes)
	notes.clear()
	for ev in chart_data:
		if ev.get("type", "arrow") != "arrow":
			continue
		var dir: String = str(ev.get("direction", "center"))
		_spawn_note(dir, float(ev["time"]), ev)
		# collect poses too
	# clear any old prompts if you want a full rebuild

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
		scene = load(note_scenes[direction]) as PackedScene
	else:
		print("LOADING NOT IN DIRECTION")
		scene = load(note_scene_path) as PackedScene
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
			print("we in is hold")
			a_pre.end_Time = float(ev["end_Time"])
	else:
		print("this happens")
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
	var tail := a_node.get_node_or_null("Tail")
	if tail and a_node.is_Hold:
		if direction == "center":
			a_node.rotation_degrees = 180
		tail.self_modulate = a_node.pressedColor
		tail.centered = false
		tail.position = Vector2.ZERO
		
		var duration := float(ev["end_Time"]) - float(ev["time"])
		var total_px := duration* pixels_per_second
		_set_tail_length_px(a_node, tail, total_px)
		# save for replay/scrub restoration
		a_node.set_meta("tail_total_px", total_px)
		a_node.set_meta("head_time", float(ev["time"]))
		a_node.set_meta("end_time", float(ev["end_Time"]))

func _spawn_pose(p_index: int, t: float, ev: Dictionary) -> void:
	var tex: Texture2D = pose_sprites.get(p_index)
	if tex == null: return
	var pose = poseScene.instantiate()
	pose.z_index = 8
	pose.pose_name_string = poses[p_index]
	pose.countDown = pose_pre_spawn_sec  
	pose.time = t 
	var sprite := pose.get_node_or_null("Sprite2D")
	if sprite: sprite.texture = tex
	add_child(pose)
	pose.position = to_local(get_global_mouse_position())
	pose.scale = Vector2(0.7, 0.7)

	poses_array.append(pose)

# ------------ frame update
func _process(_dt: float) -> void:
	var now := _now()
	var prev_now := _prev_now
	_prev_now = now
	
	for pose in poses_array:
		if not is_instance_valid(pose):
			continue
		var remaining :float= pose.countDown - _now()   # >0 = countdown before pose.time
		# Visible only during the pre-spawn countdown window: (time - countDown, time]
		if remaining <= pose.countDown and remaining > 0.0:
			var label := pose.get_node_or_null("Countdown") as Label
			if label:
				label.text = "%.2f" % max(0.0, remaining)
			else:
				pose.countdown_string = "%.2f" % max(0.0, remaining)
			pose.visible = true
		else:
			pose.visible = false

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
		if not n.has_meta("frozen"):
			(n as Node2D).position.y = time_to_y(t_note)
		else:
			(n as Node2D).position.y = n.position.y
			var remaining_s :float = max(0.0, n.end_Time- _now())
			var remaining_px := remaining_s * pixels_per_second
			var tail : Sprite2D= n.get_node_or_null("Tail")
			_set_tail_length_px(n, tail, remaining_px)
			if remaining_s <=0.01:
				n.set_meta("frozen", null)
			#print("we should be frozen")
		#play sound when t_note is close enough
		if(absf(t_note - _now()) <= hit_window_sec):
			print("its close enough")
			if not n.has_meta("fx_done"):
				if n.is_Hold:
					if not n.has_meta("frozen"):
						print("freezing the hold")
						_flash_note(n)
						_hit_player.play()
						n.set_meta("frozen", true)
					else:
						_flash_note(n)
					#somehow make it frozen until end_Time is over
				else:
					_hit_player.play()
					_flash_note(n)
					n.set_meta("fx_done", true)
		else:
			n.set_meta("fx_done" , null)
			
			#if n.is_Hold:
				#n.set_meta("frozen", null)
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
	if pose_mode:
		select_mode = false
		ghost_enabled = false
	if select_mode:
		ghost_enabled = false
		pose_mode = false


func _unhandled_input(e: InputEvent) -> void:
	# toggles
	if e is InputEventKey and e.pressed:
		if e.keycode == KEY_S:
			ghost_enabled = false
			pose_mode = false
			select_mode = !select_mode
		if e.keycode == KEY_G:
			ghost_enabled = !ghost_enabled
			if ghost_enabled:
				pose_mode = false
				select_mode = false
			#hide ghost immediately when turning off
			if not ghost_enabled and _ghost and is_instance_valid(_ghost):
				_ghost.visible = false
				select_mode = true
			#clear note selection
			_unselect_all_notes()
		if e.keycode == KEY_H:
			hold_enabled = !hold_enabled
		#go into pose mode
		if e.keycode == KEY_P:
			pose_mode = !pose_mode
			if pose_mode:
				ghost_enabled = false
				select_mode = false
		# delete selection
		if e.keycode == KEY_DELETE or KEY_BACKSPACE and not ghost_enabled:
			if selected_notes.size() > 0:
				print("deleting slected notes: ")
				_delete_selected()
			else:
				print("size is not greater than 0")
			return
	#place notes
	if e is InputEventMouseButton and e.is_pressed() and e.button_index == MOUSE_BUTTON_LEFT and pose_mode:
		if pose_mode:
			var t := _now()
			var ev = { "type":"pose",  "pose": poses[pose_index],  "time": t, "countdown": pose_pre_spawn_sec, "window": 0.25, "points": 10 }
			print("[unhadled_input] making pose with time ", t)
			_spawn_pose(pose_index,t, ev)
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and ghost_enabled:
		if receptors.is_empty(): return

		var lp := to_local(get_global_mouse_position())
		var lane := _nearest_lane_from_x(lp.x)
		var t_raw := _now() + (lp.y - receptor_y()) / pixels_per_second
		var t := snap_time(t_raw)
		var ev:Dictionary

		if hold_enabled:
			print("unhandled input: making hold note with end time: ", hold_duration)
			ev = {"type":"arrow", "direction": lane, "time": t, "end_Time": hold_duration+t}
		else:
			ev = {"type":"arrow", "direction": lane, "time": t}
		chart_data.append(ev)
		chart_data.sort_custom(func(a, b): return a["time"] < b["time"])
		_spawn_note(lane, t, ev)
		return
	# selection drag begin (ghost OFF)
	if select_mode and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
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
	for pnode in poses_array:
		if not is_instance_valid(pnode): continue
		var pos: Vector2 = (pnode as Node2D).position
		if r.has_point(pos):
			res.append(pnode)
	return res
	
func _apply_selected_visual(n: Node2D, selected: bool) -> void:
	# arrows: try Polygon2D
	var poly := n.get_node_or_null("Polygon2D") as Polygon2D
	if poly:
		poly.color = (Color(0.3, 0.8, 1.0) if selected else (n.pressedColor if "pressedColor" in n else Color(1,1,1,1)))
		return

	# poses: try a 'Highlight' node (e.g., ColorRect/NinePatchRect) if present
	var hi := n.get_node_or_null("Highlight")
	if hi:
		hi.visible = selected
		return

	# fallback for poses: tint Sprite2D
	var spr := n.get_node_or_null("Sprite2D") as Sprite2D
	if spr:
		spr.modulate = (Color(0.3, 0.8, 1.0, 1.0) if selected else Color(1,1,1,1))

func _set_selected(ns: Array[Node2D]) -> void:
	# clear old
	for n in selected_notes:
		if is_instance_valid(n):
			_apply_selected_visual(n, false)

	selected_notes = ns.duplicate()

	# apply new
	for n in selected_notes:
		if is_instance_valid(n):
			_apply_selected_visual(n, true)


func _delete_selected() -> void:
	if selected_notes.is_empty(): return

	for n in selected_notes:
		if not is_instance_valid(n): continue

		# if it's an arrow, remove from notes
		if notes.has(n):
			n.queue_free()
			notes.erase(n)
			continue

		# if it's a pose, remove from poses_array
		if poses_array.has(n):
			n.queue_free()
			poses_array.erase(n)
			continue

	selected_notes.clear()


func _unselect_all_notes() -> void:
	if selected_notes.is_empty(): return
	for n in selected_notes:
		if is_instance_valid(n):
			_apply_selected_visual(n, false)
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

func set_play_rate(r: float) -> void:
	play_rate = clamp(r, 0.25, 2.0)
	if audio:
		audio.pitch_scale = play_rate          # speed + pitch change
	if _hit_player:
		_hit_player.pitch_scale = play_rate    # optional: keep SFX feel

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
