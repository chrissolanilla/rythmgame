import math
import mediapipe as mp

mp_pose = mp.solutions.pose
M = mp_pose.PoseLandmark

def pt(lms, name):
    return lms[M[name].value]

def vis_ok(p, th=0.6):
    return (getattr(p, "visibility", 0.0) or 0.0) >= th and -0.05 <= p.x <= 1.05 and -0.05 <= p.y <= 1.05

def dist(a, b):
    return math.hypot(a.x - b.x, a.y - b.y)

def angle(a, b, c):
    abx, aby = a.x - b.x, a.y - b.y
    cbx, cby = c.x - b.x, c.y - b.y
    da = math.hypot(abx, aby); dc = math.hypot(cbx, cby)
    if da * dc == 0:
        return 180.0
    cosv = max(-1.0, min(1.0, (abx*cbx + aby*cby)/(da*dc)))
    return math.degrees(math.acos(cosv))

def torso_scale(lms):
    """Reference length to make thresholds resolution/body-size invariant."""
    ls, rs = pt(lms,"LEFT_SHOULDER"), pt(lms,"RIGHT_SHOULDER")
    lh, rh = pt(lms,"LEFT_HIP"), pt(lms,"RIGHT_HIP")
    if not all(map(vis_ok, (ls,rs,lh,rh))):
        return 0.35
    sh = dist(ls, rs)
    th = 0.5*(dist(ls, lh) + dist(rs, rh))
    return max(0.25, min(0.7, 0.6*sh + 0.4*th))

def above(p, q, margin=0.0):  # y goes down; smaller y is higher
    return p.y < q.y - margin

def near(a, b, s, k):  # distance < k * scale
    return dist(a,b) <= (k * s)

def horiz_aligned(a, b, s, eps=0.12):
    return abs(a.y - b.y) <= eps * s

def between_vertical(p, top, bottom, s, top_eps=0.12, bot_eps=0.10):
    # Ensures p is between top and bottom (inclusive, with margins).
    top_y = min(top.y, bottom.y)   # visually higher (smaller y)
    bot_y = max(top.y, bottom.y)   # visually lower
    return (p.y >= top_y - top_eps * s) and (p.y <= bot_y + bot_eps * s)

# Export list if you want to whitelist on the Godot side
POSE_LABELS = {
    "Tough Guy Pose",
    "Muscle Man Pose",
    "What? Pose",
    "Point Up Pose (L)",
    "Point Up Pose (R)",
    "Samurai Pose",
    "Stop Pose",
}

# ---------- main classifier ----------
def classify_pose(lms):
    """
    Returns one of:
    'Tough Guy Pose', 'Muscle Man Pose', 'What? Pose',
    'Point Up Pose (L/R)', 'Samurai Pose', 'Stop Pose', or ''.
    """
    s = torso_scale(lms)

    lw, rw = pt(lms,"LEFT_WRIST"), pt(lms,"RIGHT_WRIST")
    le, re = pt(lms,"LEFT_ELBOW"), pt(lms,"RIGHT_ELBOW")
    ls, rs = pt(lms,"LEFT_SHOULDER"), pt(lms,"RIGHT_SHOULDER")
    lh, rh = pt(lms,"LEFT_HIP"), pt(lms,"RIGHT_HIP")
    leye = pt(lms,"LEFT_EYE")
    reye = pt(lms,"RIGHT_EYE")
    nose = pt(lms,"NOSE")

    ok = vis_ok

    # Precompute safe angles
    ang_le = angle(ls, le, lw) if all(map(ok,(ls,le,lw))) else 180
    ang_re = angle(rs, re, rw) if all(map(ok,(rs,re,rw))) else 180

    # 1) Tough Guy (arms crossed)
    if all(map(ok,(rw,ls,lw,rs))) and near(rw, ls, s, 0.45) and near(lw, rs, s, 0.45):
        return "Tough Guy Pose"

    # 2) Muscle Man (double biceps)
    if all(map(ok,(lw, rw, le, re, ls, rs, nose))):
        wrists_high = (above(lw, ls, 0.05) or above(lw, nose, -0.02)) and \
                      (above(rw, rs, 0.05) or above(rw, nose, -0.02))
        elbows_bent = (50 <= ang_le <= 120) and (50 <= ang_re <= 120)
        if wrists_high and elbows_bent:
            return "Muscle Man Pose"

    # 3) What? (shrug) – wrists between shoulder and elbow bands + bent elbows
    if all(map(ok,(lw,rw,ls,rs,nose,le,re))):
        left_in_band  = between_vertical(lw, ls, le, s, top_eps=0.14, bot_eps=0.12)
        right_in_band = between_vertical(rw, rs, re, s, top_eps=0.14, bot_eps=0.12)
        elbows_bentish = (ang_le < 150 and ang_re < 150)
        if left_in_band and right_in_band and elbows_bentish:
            return "What? Pose"

    # 4) Point Up: exactly one straight-up arm
    up_l = all(map(ok,(lw, le, ls))) and above(lw, ls, 0.15) and ang_le > 150
    up_r = all(map(ok,(rw, re, rs))) and above(rw, rs, 0.15) and ang_re > 150
    if up_l ^ up_r:
        return "Point Up Pose (L)" if up_l else "Point Up Pose (R)"

    # 5) Samurai: one arm horizontal (extended) + other hand near opposite hip
    arm_l_horizontal = all(map(ok,(ls,le,lw))) and ang_le > 150 and horiz_aligned(lw, ls, s, 0.10)
    arm_r_horizontal = all(map(ok,(rs,re,rw))) and ang_re > 150 and horiz_aligned(rw, rs, s, 0.10)
    hand_on_hip_l = all(map(ok,(lw,lh))) and near(lw, lh, s, 0.55)
    hand_on_hip_r = all(map(ok,(rw,rh))) and near(rw, rh, s, 0.55)
    if (arm_l_horizontal and hand_on_hip_r) or (arm_r_horizontal and hand_on_hip_l):
        return "Samurai Pose"

    # 6) Stop: hand up near face, above shoulder, within face band, elbow bent, forwardish
    if all(map(ok, (lw, rw, nose, ls, rs, le, re, leye, reye))):
        head_top_y = min(nose.y, leye.y, reye.y)

        def is_stop(wrist, elbow, shoulder):
            close_to_face  = near(wrist, nose, s, 0.45)
            above_shoulder = wrist.y < shoulder.y - 0.02 * s
            not_too_high   = wrist.y >= head_top_y - 0.12 * s
            elbow_bentish  = angle(shoulder, elbow, wrist) < 150
            forwardish     = (getattr(wrist, "z", 0.0) < getattr(elbow, "z", 0.0) - 0.03)
            lateral_ok     = abs(wrist.x - nose.x) <= 0.30 * s
            return close_to_face and above_shoulder and not_too_high and elbow_bentish and forwardish and lateral_ok

        if (all(map(ok,(lw,le,ls))) and is_stop(lw, le, ls)) or \
           (all(map(ok,(rw,re,rs))) and is_stop(rw, re, rs)):
            return "Stop Pose"

    return ""

