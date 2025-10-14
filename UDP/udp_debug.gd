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
