extends Node
class_name PoseServer

const ADDR := "127.0.0.1"
const PORT := 54545

var _pid: int = -1

func _ready() -> void:
	ensure_server_running()

	var root := get_tree().root
	if root and not root.is_connected("close_requested", Callable(self, "_on_close_requested")):
		root.connect("close_requested", Callable(self, "_on_close_requested"))

	if not get_tree().is_connected("tree_exiting", Callable(self, "_on_tree_exiting")):
		get_tree().connect("tree_exiting", Callable(self, "_on_tree_exiting"))

func _on_close_requested() -> void:
	stop_server_if_started()

func _on_tree_exiting() -> void:
	stop_server_if_started()

func _exit_tree() -> void:
	stop_server_if_started()


# ----------------- Public -----------------
func ensure_server_running() -> void:
	# If someone is already sending UDP packets, don’t spawn another.
	if await _have_udp_packets_recently():
		return

	# Kill any stale process from previous runs.
	var old := _read_pid()
	if old > 0:
		await _kill_pid_hard(old)
		_clear_pid()

	# Linux / FreeBSD → launch via /bin/sh so we can cd into the right folder.
	if OS.get_name() in ["Linux", "FreeBSD"]:
		var cmd := _linux_launch_command()
		if cmd == "":
			push_error("PoseServer: could not build Linux launch command.")
			return

		_pid = OS.create_process("/bin/sh", PackedStringArray(["-c", cmd]))
	else:
		# Fallback for Windows (you can adapt this later)
		var exe := _pose_sender_exe()
		if exe == "":
			push_error("PoseServer: no pose_udp_sender binary found.")
			return

		var graph_path := _pose_graph_path()
		if graph_path == "":
			push_error("PoseServer: pose_tracking_cpu.pbtxt not found.")
			return

		var args := PackedStringArray([
			"--calculator_graph_config_file=" + graph_path,
			"--verbose=false"
		])
		_pid = OS.create_process(exe, args)

	if _pid <= 0:
		push_error("PoseServer: failed to start pose_udp_sender")
		return

	_write_pid(_pid)

	# Give it a moment to open the camera and start sending.
	await get_tree().create_timer(2.0).timeout

	if !(await _have_udp_packets_recently()):
		push_warning("pose_udp_sender started but no UDP packets yet (camera / permissions?).")


func stop_server_if_started() -> void:
	var pid := _pid
	if pid <= 0:
		pid = _read_pid()
	if pid > 0:
		OS.kill(pid) # SIGTERM
		await get_tree().create_timer(0.25).timeout
		if OS.get_name() == "Linux":
			OS.execute("kill", PackedStringArray(["-9", str(pid)]), [], true)
	_clear_pid()
	_pid = -1


# ----------------- Internals -----------------

# For Linux: build a shell command that cd's into the cpp_server/linux folder
# and runs pose_udp_sender with a *relative* graph path.
func _linux_launch_command() -> String:
	# Absolute path to the binary inside the project/export.
	var exe := ProjectSettings.globalize_path("res://cpp_server/linux/pose_udp_sender")
	if !FileAccess.file_exists(exe):
		return ""

	var exe_dir := exe.get_base_dir()
	# This must match what works from your manual test:
	#   cd cpp_server/linux
	#   ./pose_udp_sender --calculator_graph_config_file=mediapipe/graphs/pose_tracking/pose_tracking_cpu.pbtxt
	var rel_graph := "mediapipe/graphs/pose_tracking/pose_tracking_cpu.pbtxt"

	# Build: cd '<exe_dir>' && ./pose_udp_sender --calculator_graph_config_file=...
	var cmd := "cd '%s' && ./pose_udp_sender --calculator_graph_config_file=%s --verbose=false" % [
		exe_dir,
		rel_graph
	]
	return cmd


# Windows path helpers (not used on Linux right now, but kept for later)
func _pose_sender_exe() -> String:
	var path := ""

	if OS.get_name() == "Windows":
		path = ProjectSettings.globalize_path("res://cpp_server/windows/pose_udp_sender.exe")

	if path == "" or !FileAccess.file_exists(path):
		return ""
	return path


func _pose_graph_path() -> String:
	var rel := "mediapipe/graphs/pose_tracking/pose_tracking_cpu.pbtxt"
	var path := ""

	if OS.get_name() == "Windows":
		path = ProjectSettings.globalize_path("res://cpp_server/windows/" + rel)

	if path == "" or !FileAccess.file_exists(path):
		return ""
	return path


func _have_udp_packets_recently() -> bool:
	var udp := PacketPeerUDP.new()
	var err := udp.bind(PORT, ADDR)

	if err == OK:
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 200:
			if udp.get_available_packet_count() > 0:
				udp.close()
				return true
			await get_tree().process_frame
		udp.close()
		return false
	elif err == ERR_ALREADY_IN_USE:
		# Port already bound (likely your game's UDP listener).
		return false
	else:
		return false


func _pid_file() -> String:
	return "user://pose_server/pose_server.pid"

func _read_pid() -> int:
	var p := _pid_file()
	if FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.READ)
		if f:
			var txt := f.get_as_text().strip_edges()
			f.close()
			return int(txt)
	return -1

func _write_pid(pid: int) -> void:
	var p := _pid_file()
	DirAccess.make_dir_recursive_absolute("user://pose_server")
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f:
		f.store_string(str(pid))
		f.close()

func _clear_pid() -> void:
	var p := _pid_file()
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)

func _kill_pid_hard(pid: int) -> void:
	OS.kill(pid)
	await get_tree().process_frame
	if OS.get_name() == "Linux":
		OS.execute("kill", PackedStringArray(["-9", str(pid)]), [], true)
