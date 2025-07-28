import keyboard
import pygame
import json
import time

# === CONFIG ===
audio_file = "bad_apple.mp3"
output_file = "recorded_chart.json"

# Map keys to your game directions
key_to_direction = {
    '1': 'downLeft',
    '2': 'down',
    '3': 'downRight',
    '4': 'left',
    '5': 'center',
    '6': 'right',
    '7': 'upLeft',
    '8': 'up',
    '9': 'upRight'
}

# === INIT ===
chart_data = []
start_time = None

def on_key_event(e):
    if e.event_type == 'down':
        if e.name in key_to_direction:
            t = time.time() - start_time
            direction = key_to_direction[e.name]
            chart_data.append({
                "time": round(t, 4),
                "direction": direction
            })
            print(f"[{round(t, 4)}s] {direction}")

def main():
    global start_time

    print("🎵 Loading and playing song...")
    pygame.mixer.init()
    pygame.mixer.music.load(audio_file)
    pygame.mixer.music.play()
    start_time = time.time()

    print("🎮 Start pressing keys! (Press ESC to stop)")
    keyboard.hook(on_key_event)

    # Wait for the song or ESC key
    while pygame.mixer.music.get_busy():
        if keyboard.is_pressed('esc'):
            print("🛑 Recording stopped by user.")
            break
        time.sleep(0.01)

    # Save output
    with open(output_file, 'w') as f:
        json.dump(chart_data, f, indent=2)
    print(f"✅ Saved {len(chart_data)} notes to {output_file}")

if __name__ == "__main__":
    main()

