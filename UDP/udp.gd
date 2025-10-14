#extends Node
#
#const PORT := 54545
#var _udp := PacketPeerUDP.new()
#var _thread := Thread.new()
#var _running := false
#
#var latest := {
	#"t": 0.0,
	#"landmarks": [],
	#"gesture": "",
	#"gestures_raw": [],
	#"changed": false,
	#"tracking": false,
	#"fps": 0.0
#}
#
#signal pose_updated  # emitted on every parsed packet
#
#func _ready():
	#process_mode = Node.PROCESS_MODE_ALWAYS
	#var err := _udp.bind(PORT, "127.0.0.1")  # same box; use "0.0.0.0" if receiving over LAN
	#if err != OK:
		#push_error("UDP bind failed: %s" % err)
		#return
	#print("[PoseReceiver] bound on 127.0.0.1:", PORT)
	#_running = true
	#print("running is ", _running)
	#_thread.start(_loop)
#
#func _exit_tree():
	#print("we are maknig shit false")
	#_running = false
	#if _thread.is_started():
		#_thread.wait_to_finish()
	#_udp.close()
#
#func _loop(_u):
	#print("in _loop, running is :", _running)
	#while _running:
		#if _udp.get_available_packet_count() > 0:
			#var pkt := _udp.get_packet()
			#if _udp.get_packet_error() == OK:
				#var txt := pkt.get_string_from_utf8()
				#var json := JSON.new()
				#if json.parse(txt) == OK:
					#latest = json.get_data()
					#call_deferred("_emit_update")
		#else:
			#OS.delay_msec(2)
#
#func _emit_update():
	#print("emitting pose")
	#emit_signal("pose_updated")
#
#func get_landmark(id:int) -> Dictionary:
	#for p in latest.get("landmarks", []):
		#if int(p.get("id",-1)) == id:
			#return p
	#return {}


# PoseReceiverDebug.gd
extends Node

const PORT := 54545
var _udp := PacketPeerUDP.new()
var latest := {"t":0.0, "landmarks": [], "gesture":"", "gestures_raw":[], "changed":false, "tracking":false}

func _ready():
	var err := _udp.bind(PORT, "127.0.0.1")
	if err != OK:
		push_error("UDP bind failed: %s" % err)
	else:
		print("UDP bound on 127.0.0.1:", PORT)

func _process(_dt):
	while _udp.get_available_packet_count() > 0:
		var pkt := _udp.get_packet()
		if _udp.get_packet_error() != OK: break
		var txt := pkt.get_string_from_utf8()
		# print("RAW UDP:", txt)  # noisy but useful
		var json := JSON.new()
		if json.parse(txt) == OK:
			latest = json.get_data()
			var g := String(latest.get("gesture",""))
			var changed := bool(latest.get("changed", false))
			var tracking := bool(latest.get("tracking", false))
			if changed:
				print("→ gesture changed:", g)
			# light throttle for HUD-ish logs
			# print("tracking=", tracking, " fps=", latest.get("fps",0.0))
