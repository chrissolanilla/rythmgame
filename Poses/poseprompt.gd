extends Control

@export var target_pose: String
@export var target_time: float = 0.0      # absolute song time to evaluate
@export var countdown_len: float = 5.0
@export var window: float = 0.25          # +/- timing window
@export var points: int = 10
@export var udp_node: NodePath            # optional: if you want the prompt to read UDP itself
@export var icon: Texture2D

var _udp: Node
var _done := false


@onready var _title := $VBoxContainer/Title as Label
@onready var _count := $VBoxContainer/Countdown as Label
@onready var _icon  := $VBoxContainer/Icon as TextureRect

# signal to the spawner to score
signal pose_judged(success: bool, at_position: Vector2, points: int)

func _ready():
	_title.text = "Do: %s" % target_pose
	if icon:
		_icon.texture = icon
		# optional: keep aspect
		if _icon.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_udp = null if udp_node.is_empty() else get_node_or_null(udp_node)


# The spawner calls this every frame with current song_time
func drive(song_time: float, latest_udp: Dictionary = {}):
	if _done: return
	#print("drive t=", song_time, " target = " , target_time)

	var time_to_go := target_time - song_time
	var left = clamp(ceil(time_to_go), 0, int(ceil(countdown_len)))
	_count.text = str(left)

	# Past the window end → fail if never evaluated
	if song_time > target_time + window and not _done:
		print("[POSE] Miss by timeout at ", song_time)
		_finalize(false)
		return

	# Within the evaluation window → check the pose
	if abs(song_time - target_time) <= window and not _done:
		var latest := latest_udp
		# if not provided by caller, try to read from udp_node
		if (latest.is_empty() and _udp):
			if _udp.has_variable("latest"):
				latest = _udp.latest

		var g := String(latest.get("gesture",""))
		var tracking := bool(latest.get("tracking", false))
		var ok := tracking and g == target_pose
		print("[POSE] Eval: g='", g, "' vs target='", target_pose, "' -> ", ok)
		_finalize(ok)

func _finalize(success: bool):
	_done = true
	emit_signal("pose_judged", success, global_position, points)
	# either free or hide to reuse (your call)
	queue_free()
	# alternatively: visible = false   (then add a "reset()" method for pooling)
