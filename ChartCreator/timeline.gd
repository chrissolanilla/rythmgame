extends Control
class_name Timeline

# wired by ChartEditor
var scroll_container: ScrollContainer
var chart_data: Array = []
var bpm: float = 120.0
var song_offset_ms: int = 0
var seconds_per_pixel: float = 0.02
var snap_div: int = 4
var audio: AudioStreamPlayer

var lane_names := ["upLeft","left","downLeft","down","center","up","upRight","right","downRight"]

# selection & editing
var selection: int = -1
var drag_kind := ""            # "" | "move" | "resize_start" | "resize_end"
var placing_poses := false
var active_lane := "up"
var recording := false
var pending_hold := {}         # lane -> start_time

# ---------- mapping ----------
func get_top_time() -> float:
	if scroll_container == null: return 0.0
	# v-scroll in pixels -> seconds
	var y_px := scroll_container.get_v_scroll_bar().value
	return y_px * seconds_per_pixel

func time_to_y(t: float) -> float:
	return (t - get_top_time()) / seconds_per_pixel

func y_to_time(y: float) -> float:
	return get_top_time() + y * seconds_per_pixel

func lane_width() -> float:
	return size.x / float(lane_names.size())

func lane_to_x(lane: String) -> float:
	#cant infer this type
	var i:int = max(0, lane_names.find(lane))
	return i * lane_width()

func x_to_lane(x: float) -> String:
	var idx := clampi(int(floor(x / lane_width())), 0, lane_names.size()-1)
	return lane_names[idx]

func snap_time(t: float) -> float:
	var beat_len := 60.0 / bpm
	var beats := (t - (song_offset_ms/1000.0)) / beat_len
	#cant infer this type
	var snapped: float = round(beats * snap_div) / snap_div
	return (snapped * beat_len) + (song_offset_ms/1000.0)

# ---------- drawing ----------
func _draw():
	_draw_grid()
	_draw_events()
	_draw_playhead()

func _draw_grid():
	var lw := lane_width()
	# lane dividers
	for i in lane_names.size()+1:
		var x := i * lw
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.2,0.2,0.25,1), 1.0)
	# beats
	var beat_len := 60.0 / bpm
	var top := get_top_time()
	var bottom := y_to_time(size.y)
	#cant infer this type
	var first_beat:float = floor((top - song_offset_ms/1000.0)/beat_len) * beat_len + (song_offset_ms/1000.0)
	#cant infer this type
	var t:float = first_beat
	while t < bottom:
		var y := time_to_y(t)
		draw_line(Vector2(0,y), Vector2(size.x,y), Color(0.3,0.3,0.35,1), 1.0)
		# sub-beats
		for s in range(1, snap_div):
			var y2 := time_to_y(t + (s * beat_len / snap_div))
			draw_line(Vector2(0,y2), Vector2(size.x,y2), Color(0.25,0.25,0.3,1), 1.0)
		t += beat_len

func _draw_events():
	var lw := lane_width()
	for i in chart_data.size():
		#cant infer this type
		var ev:Dictionary = chart_data[i]
		#cant infer this type
		var is_pose:bool = ev.get("type","arrow") == "pose"
		var x := 0.0
		var w := lw
		if is_pose:
			# draw poses in a thin global row at top
			x = 0
			w = size.x
		else:
			x = lane_to_x(ev.get("direction","center"))
		var y := time_to_y(float(ev["time"]))
		var h := 10.0

		if ev.has("end_Time"): # hold
			var y2 := time_to_y(float(ev["end_Time"]))
			var rect := Rect2(Vector2(x+3, y), Vector2(w-6, max(12.0, y2 - y)))
			draw_rect(rect, Color(0.65,0.65,0.9,0.5))
			# head cap
			draw_rect(Rect2(Vector2(x+2, y-5), Vector2(w-4, 10)), Color(0.85,0.85,1.0,0.9))
		else:
			var rect2 := Rect2(Vector2(x+4, y-5), Vector2(w-8, 10))
			draw_rect(rect2, Color(0.9,0.9,0.9,0.9))

		# selection outline
		if i == selection:
			draw_rect(Rect2(Vector2(x+1, y-7), Vector2(w-2, 14)), Color(0.1,0.8,1.0,1.0), false, 2.0)

func _draw_playhead():
	var play_t := _get_playhead_time()
	var y := time_to_y(play_t)
	draw_line(Vector2(0,y), Vector2(size.x,y), Color(1,0.4,0.2,1), 2.0)

func _get_playhead_time() -> float:
	var player := get_tree().root.get_node_or_null("/root/ChartEditor/AudioStreamPlayer") as AudioStreamPlayer
	if player:
		return player.get_playback_position()
	return 0.0

# ---------- picking ----------
func pick_note_at_pos(p: Vector2) -> int:
	var lw := lane_width()
	for i in range(chart_data.size()-1, -1, -1):
		#cant infer this type
		var ev:Dictionary = chart_data[i]
		#cant infer this type
		var is_pose:bool = ev.get("type","arrow") == "pose"
		var x := 0.0
		var w := lw
		if is_pose:
			x = 0; w = size.x
		else:
			x = lane_to_x(ev.get("direction","center"))
		var y := time_to_y(float(ev["time"]))
		if ev.has("end_Time"):
			var y2 := time_to_y(float(ev["end_Time"]))
			var r := Rect2(Vector2(x+3, y), Vector2(w-6, max(12.0, y2 - y)))
			if r.has_point(p): return i
		else:
			var r2 := Rect2(Vector2(x+4, y-5), Vector2(w-8, 10))
			if r2.has_point(p): return i
	return -1

func pick_drag_handle(p: Vector2, idx: int) -> String:
	#cant infer this type
	var ev:Dictionary = chart_data[idx]
	if not ev.has("end_Time"): return "move"
	var x := lane_to_x(ev.get("direction","center"))
	var w := lane_width()
	var y1 := time_to_y(float(ev["time"]))
	var y2 := time_to_y(float(ev["end_Time"]))
	if absf(p.y - y1) < 6.0 and p.x > x and p.x < x+w: return "resize_start"
	if absf(p.y - y2) < 6.0 and p.x > x and p.x < x+w: return "resize_end"
	return "move"

# ---------- interaction ----------
func _gui_input(e):
	if e is InputEventMouseButton and e.pressed:
		var t := snap_time(y_to_time(e.position.y))
		if e.button_index == MOUSE_BUTTON_LEFT:
			var idx := pick_note_at_pos(e.position)
			if idx >= 0:
				selection = idx
				drag_kind = pick_drag_handle(e.position, idx)
				grab_focus()
			else:
				if placing_poses:
					chart_data.append({"time": t, "type":"pose", "pose":"Stop Pose", "countdown":5.0, "window":0.25, "points":10})
				else:
					var lane := x_to_lane(e.position.x)
					chart_data.append({"time": t, "direction": lane})
				chart_data.sort_custom(func(a,b): return a["time"] < b["time"])
				selection = chart_data.size()-1
				drag_kind = "move"
				grab_focus()
				queue_redraw()
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			selection = -1
			drag_kind = ""
			queue_redraw()

	elif e is InputEventMouseMotion and drag_kind != "":
		if selection >= 0:
			#cant infer this type
			var ev:Dictionary = chart_data[selection]
			match drag_kind:
				"move":
					ev["time"] = max(0.0, snap_time(y_to_time(e.position.y)))
					if ev.has("direction"):
						ev["direction"] = x_to_lane(e.position.x)
				"resize_start":
					ev["time"] = clampf(snap_time(y_to_time(e.position.y)), 0.0, float(ev.get("end_Time", ev["time"])))
				"resize_end":
					ev["end_Time"] = max(snap_time(y_to_time(e.position.y)), float(ev["time"]))
		queue_redraw()

	elif e is InputEventKey and e.pressed and e.keycode == KEY_DELETE and selection >= 0:
		chart_data.remove_at(selection)
		selection = -1
		drag_kind = ""
		queue_redraw()

func _input(e):
	if not recording: return
	if e is InputEventKey:
		for lane in lane_names:
			if Input.is_action_just_pressed(lane):
				var t := snap_time(_get_playhead_time())
				pending_hold[lane] = t
				chart_data.append({"time": t, "direction": lane})
			if Input.is_action_just_released(lane) and pending_hold.has(lane):
				#cant infer this type
				var start_t:float = pending_hold[lane]
				var end_t := snap_time(_get_playhead_time())
				for i in range(chart_data.size()-1, -1, -1):
					#cant infer this type
					var ev = chart_data[i]
					if ev.get("direction","") == lane and abs(ev["time"] - start_t) < 0.0001 and not ev.has("end_Time"):
						ev["end_Time"] = max(end_t, ev["time"])
						break
				pending_hold.erase(lane)
