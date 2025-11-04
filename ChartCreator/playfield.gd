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

func _ready() -> void:
	set_process(true)
	set_process_unhandled_input(true)

# ------------ time mapping
func _now() -> float:
	if audio != null:
		# stream_paused keeps playback_position steady (good for editor view)
		return audio.get_playback_position() + float(song_offset_ms) / 1000.0
	return float(song_offset_ms) / 1000.0

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
		(n as Node2D).visible = (n as Node2D).position.y > -200.0 and (n as Node2D).position.y < get_viewport_rect().size.y + 200.0

	# hover ghost preview (direction-specific + recolor + 0.2 scale)
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
				_ghost.visible = true
		else:
			_ghost_visible = false
			_ghost.visible = false

# ------------ click to place notes
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		print("we clicked")
		if receptors.is_empty():
			return
		var lp: Vector2 = to_local(get_global_mouse_position())
		var lane: String = _nearest_lane_from_x(lp.x)
		var t_raw: float = _now() + (lp.y - receptor_y()) / pixels_per_second
		var t: float = snap_time(t_raw)

		var ev: Dictionary = {"type":"arrow", "direction": lane, "time": t}
		chart_data.append(ev)
		chart_data.sort_custom(func(a, b): return a["time"] < b["time"])
		_spawn_note(lane, t, ev)

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
