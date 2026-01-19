# Service Recorder

**Service Recorder** is a lightweight Windows background application that allows you to record your screen and/or webcam using global hotkeys. The program runs silently in the background and automatically saves recordings to your `Documents` folder.

It is designed to be simple, fast, and easy to use — you can either run a pre-built `.exe` file immediately or build it yourself from source.

## 📁 Repository Contents

This repository contains three main files:

service.py # Python source code
service.exe # Pre-built Windows executable (recommended)
requirements.txt # Python dependencies (for building from source)


## 🚀 Option 1 — Run Immediately (Recommended)

If you just want to use the application without installing Python:

1. Download **`service.exe`**
2. Double-click to run it  
3. The application will start in the background (no visible window)

You do **not** need Python installed for this option.

## 🛠 Option 2 — Build From Source (Advanced Users)

If you prefer to run or modify the source code and build your own executable:

### Step 1 — Install Python

Make sure you have **Python 3.9 or newer** installed from:
https://www.python.org/downloads/

### Step 2 — Install dependencies

Open a terminal in the project folder and run:

```bash
pip install -r requirements.txt

pip install pyinstaller
```

dist/service.exe

How to Use (Hotkeys)

Once the application is running in the background, you can control it using these global hotkeys:

Hotkey	Action
Ctrl + Shift + C	Start recording webcam
Ctrl + Shift + K	Start recording screen
Ctrl + Shift + Q	Stop current recording (application keeps running)

You can start and stop recordings as many times as you like.

📂 Where are recordings saved?

All recordings are automatically stored in:

C:\Users\<YourUsername>\Documents\Services\


Example filenames:

screen_2026-01-19_10-30-01.mp4
camera_2026-01-19_10-30-05.mp4