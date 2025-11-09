# main.py
import socket, json, time, cv2
import mediapipe as mp
from collections import deque, Counter
from poses import classify_pose  # <-- new

ADDR = ("127.0.0.1", 54545)
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

mp_pose = mp.solutions.pose
pose = mp_pose.Pose(model_complexity=0, enable_segmentation=False)

# Prefer V4L2 on Linux; fall back if needed
cap = cv2.VideoCapture(0, cv2.CAP_V4L2)
if not cap.isOpened():
    cap = cv2.VideoCapture(0, cv2.CAP_ANY)

cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

# --- Stability state ---
WINDOW = 10                 # frames to vote over
COOLDOWN = 0.25             # seconds min between changes (debounce)
hist = deque(maxlen=WINDOW)
last_stable = ""
last_change = 0.0

def to_packet(results, fps, gestures_raw, gesture, changed, tracking):
    lm = []
    if results.pose_landmarks:
        for i, p in enumerate(results.pose_landmarks.landmark):
            lm.append({
                "id": i,
                "x": round(float(p.x), 3),
                "y": round(float(p.y), 3),
                "z": round(float(getattr(p, "z", 0.0)), 3),
                "v": round(float(getattr(p, "visibility", 0.0)), 3)
            })
    return {
        "t": time.time(),
        "fps": round(fps, 2),
        "tracking": tracking,          # True if landmarks present
        "landmarks": lm,               # raw landmarks (optional in Godot)
        "gestures_raw": gestures_raw,  # per-frame label list (single)
        "gesture": gesture,            # stable label or ""
        "changed": changed             # True only on edge
    }

prev = time.time()
while True:
    ok, frame = cap.read()
    if not ok:
        break

    frame = cv2.flip(frame, 1)
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = pose.process(rgb)

    # Per-frame label from your new classifier
    tracking = results.pose_landmarks is not None
    label_now = ""
    if tracking:
        label_now = classify_pose(results.pose_landmarks.landmark) or ""
    gestures_raw = [label_now] if label_now else []

    # Append single label (or "") into voting window
    hist.append(label_now)

    # Majority vote on non-empty
    gesture = last_stable
    changed = False
    if len(hist) == hist.maxlen:
        nonempty = [g for g in hist if g]
        voted = Counter(nonempty).most_common(1)[0][0] if nonempty else ""
        now = time.time()
        if voted != last_stable and (now - last_change) >= COOLDOWN:
            last_stable = voted
            last_change = now
            gesture = voted
            changed = True

    now = time.time()
    fps = 1.0 / max(1e-6, (now - prev)); prev = now

    pkt = to_packet(results, fps, gestures_raw, gesture, changed, tracking)
    buf = json.dumps(pkt, separators=(",",":"), allow_nan=False).encode("utf-8")
    sock.sendto(buf, ADDR)

cap.release()

