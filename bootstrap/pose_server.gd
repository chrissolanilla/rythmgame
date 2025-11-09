extends Node
class_name PoseServer

const ADDR := "127.0.0.1"
const PORT := 54545

var _pid: int = -1

func _ready() -> void:
	ensure_server_running()

func _exit_tree() -> void:
	stop_server_if_started()

# ----------------- Public -----------------
func ensure_server_running() -> void:
	# If port already bound (likely by your UDP node), don't fight it.
	if await _have_udp_packets_recently():
		return

	_copy_payload_to_user()
	var user_dir := OS.get_user_data_dir()

	if !_create_venv_if_needed(user_dir):
		push_error("PoseServer: Python 3.10–3.12 is required.")
		return

	if !_install_deps(user_dir):
		push_error("PoseServer: dependency install failed.")
		return

	var cmd := _build_server_cmd(user_dir)
	_pid = OS.create_process(cmd[0], PackedStringArray([cmd[1]]))
	if _pid <= 0:
		push_error("PoseServer: failed to start process")

	await get_tree().create_timer(1.0).timeout
	if !(await _have_udp_packets_recently()):
		push_warning("PoseServer started but no packets yet (camera/permissions?).")

func stop_server_if_started() -> void:
	if _pid > 0:
		OS.kill(_pid)
		_pid = -1

# ----------------- Internals -----------------
func _platform_key() -> String:
	var osn := OS.get_name()
	if osn == "Windows": return "windows-x86_64"
	if osn == "Linux" or osn == "FreeBSD": return "linux-x86_64"
	if osn == "macOS": return "" # you decided to skip macOS for now
	return ""

func _get_system_python_candidates() -> PackedStringArray:
	match OS.get_name():
		"Windows":
			# Try launcher first for exact 3.11; then generic
			return ["py","py -3.11","python","python3"]
		_:
			return ["python3","python"]

func _ensure_system_python() -> Dictionary:
	# returns {"exe": "py", "args": PackedStringArray(["-3.11"])} or {"exe":"python3","args":[]}
	for cand in _get_system_python_candidates():
		var parts := cand.split(" ")
		var exe := parts[0]
		var args := PackedStringArray()
		if parts.size() > 1:
			args.append(parts[1])
		var code := OS.execute(exe, args + PackedStringArray(["--version"]), [], true)
		if code == 0:
			return {"exe": exe, "args": args}
	return {}


func _venv_python(user_dir: String) -> String:
	if OS.get_name() == "Windows":
		return user_dir.path_join("python_server/venv/Scripts/python.exe")
	return user_dir.path_join("python_server/venv/bin/python")

func _copy_file(src: String, dst_dir: String) -> void:
	# Make sure the destination directory exists
	DirAccess.make_dir_recursive_absolute(dst_dir)

	var dst_path := dst_dir.path_join(src.get_file())
	var bytes := FileAccess.get_file_as_bytes(src)
	var f := FileAccess.open(dst_path, FileAccess.WRITE)
	if f == null:
		push_error("Failed to open %s for write".format([dst_path]))
		return
	f.store_buffer(bytes)
	f.close()
#func _copy_file(src: String, dst_dir: String) -> void:
	#var dst_path := dst_dir.path_join(src.get_file())
	#var bytes := FileAccess.get_file_as_bytes(src)
	#var f := FileAccess.open(dst_path, FileAccess.WRITE)
	#if f == null:
		#push_error("Failed to open %s for write".format([dst_path]))
		#return
	#f.store_buffer(bytes)
	#f.close()

func _copy_payload_to_user() -> void:
	var dst := "user://python_server"
	DirAccess.make_dir_recursive_absolute(dst)
	for p in [
		"res://python_server/main.py",
		"res://python_server/poses.py",
		"res://python_server/requirements.txt"
	]:
		#Static function "copy()" not found in base "GDScriptNativeClass".
		#FileAccess.copy(p, dst.path_join(p.get_file()))
		_copy_file(p, dst)
	_copy_dir_recursive("res://python_server/wheels", "user://python_server/wheels")

func _copy_dir_recursive(src: String, dst: String) -> void:
	if !DirAccess.dir_exists_absolute(src): return
	DirAccess.make_dir_recursive_absolute(dst)

	var da := DirAccess.open(src)
	if da:
		da.list_dir_begin()
		while true:
			var name := da.get_next()
			if name == "": break
			if name == "." or name == "..": continue

			var s := src.path_join(name)
			var d := dst.path_join(name)

			if da.current_is_dir():
				# For directories, recurse into the new dst directory
				_copy_dir_recursive(s, d)
			else:
				# For files, copy into the *parent* directory (dst), not d
				_copy_file(s, dst)
		da.list_dir_end()

#func _copy_dir_recursive(src: String, dst: String) -> void:
	#if !DirAccess.dir_exists_absolute(src): return
	#DirAccess.make_dir_recursive_absolute(dst)
	#var da := DirAccess.open(src)
	#if da:
		#da.list_dir_begin()
		#while true:
			#var name := da.get_next()
			#if name == "": break
			#if name == "." or name == "..": continue
			#var s := src.path_join(name)
			#var d := dst.path_join(name)
			#if da.current_is_dir(): _copy_dir_recursive(s, d)
			##Static fuciton "copy" not found in base syayayay
			##else: FileAccess.copy(s, d)
			#_copy_file(s,d)
		#da.list_dir_end()


func _create_venv_if_needed(user_dir: String) -> bool:
	var vpy := _venv_python(user_dir)
	if FileAccess.file_exists(vpy): return true

	#var sys_py := _ensure_system_python()
	var found := _ensure_system_python()
	#if sys_py == "":
		#push_error("Python not found. Please install Python 3.11.")
		#return false

	if found.is_empty():
		push_error("Python not found Please Install Python 3.11(64 bit)")
		OS.shell_open("https://www.python.org/downloads/release/python-3110/")
		return false
		
	var venv_dir := user_dir.path_join("python_server/venv")
	DirAccess.make_dir_recursive_absolute(venv_dir.get_base_dir())

	# Handle "py -3.11 -m venv" on Windows
	#var parts := sys_py.split(" ")
	#var exe := parts[0]
	var exe := String(found["exe"])
	#var args := parts.size() > 1 ? [parts[1],"-m","venv", venv_dir] : ["-m","venv", venv_dir]
	#var args := [parts[1], "-m", "venv", venv_dir] if parts.size() > 1 else ["-m", "venv", venv_dir]
	var base_args := PackedStringArray(found["args"])
	#var code := OS.execute(exe, args, [], true)
	#var code := OS.execute(exe,base_args, [], true)
	var code := OS.execute(
							exe,
							base_args + PackedStringArray(["-m", "venv", venv_dir]),
							[],
							true
						)

	return code == 0

func _install_deps(user_dir: String) -> bool:
	var vpy := _venv_python(user_dir)
	var code := OS.execute(vpy, ["-m","pip","install","-U","pip","wheel"], [], true)
	if code != 0: return false

	var req := user_dir.path_join("python_server/requirements.txt")
	var plat := _platform_key()
	if plat != "":
		var wheels_dir := user_dir.path_join("python_server/wheels").path_join(plat)
		if DirAccess.dir_exists_absolute(wheels_dir):
			code = OS.execute(vpy, [
				"-m","pip","install",
				"--no-index","--find-links", wheels_dir,
				"-r", req
			], [], true)
			if code == 0: return true
			push_warning("Offline install failed; trying online.")

	code = OS.execute(vpy, ["-m","pip","install","-r", req], [], true)
	return code == 0

func _build_server_cmd(user_dir: String) -> Array:
	return [_venv_python(user_dir), user_dir.path_join("python_server/main.py")]

func _have_udp_packets_recently() -> bool:
	var udp := PacketPeerUDP.new()
	var err := udp.bind(PORT, ADDR)  # Godot 4 API uses bind()
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
		# Your real UDP node already bound the port — assume packets will flow
		return true
	else:
		# Some other error (e.g., permission)
		return false

#func _have_udp_packets_recently() -> bool:
	#var udp := PacketPeerUDP.new()
	## we cant infer the type with :=, what is this type?
	#var err = udp.listen(PORT, ADDR)
	#if err != OK:
		## Port already bound by your UDP receiver → assume server running/coming
		#return true
	#var t0 := Time.get_ticks_msec()
	#while Time.get_ticks_msec() - t0 < 200:
		#if udp.get_available_packet_count() > 0:
			#udp.close()
			#return true
		#await get_tree().process_frame
	#udp.close()
	#return false
