#!/usr/bin/env python3
"""PearMac Front Row: Apple Remote six-button lounge, Q4OS/Trinity.

Uses the original hid_appleir evdev device (05ac:8240). Runs as the desktop
user, never as root. Does not modify Xorg, kernel, Mesa, or global keymaps.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tkinter as tk

try:
    from evdev import InputDevice, ecodes
except ImportError:
    sys.exit("Install python3-evdev: sudo apt install python3-evdev")

APPLE_VENDOR = 0x05AC
APPLE_IR_PRODUCT = 0x8240
BUTTONS = {
    ecodes.KEY_VOLUMEUP: "UP",
    ecodes.KEY_VOLUMEDOWN: "DOWN",
    ecodes.KEY_BACK: "LEFT",
    ecodes.KEY_FORWARD: "RIGHT",
    ecodes.KEY_PLAYPAUSE: "SELECT",
    ecodes.KEY_MENU: "MENU",
    ecodes.KEY_ENTER: "SELECT",
}
COLS = 2
ENTRIES = [
    ("YouTube", "Subscriptions, recommendations and search", "youtube"),
    ("Twitch", "Streams and live chat", "twitch"),
    ("Music", "Strawberry music player", "music"),
    ("RetroArch", "Classic games", "retroarch"),
    ("Videos", "Browse local files", "videos"),
    ("Close Menu", "Return to the desktop", "close"),
]


def find_receiver():
    """Discover the receiver from sysfs even if evdev hides unreadable devices.

    Read-only discovery via /sys/class/input avoids relying on event3 or on
    evdev.list_devices(), which may silently omit inaccessible devices.
    """
    candidates = []
    for node in sorted(Path("/sys/class/input").glob("event*")):
        try:
            name = (node / "device/name").read_text().strip()
        except OSError:
            continue
        if "IR Receiver" not in name or "Apple" not in name:
            continue
        path = "/dev/input/" + node.name
        candidates.append(path)
    for path in candidates:
        try:
            dev = InputDevice(path)
        except PermissionError:
            print("Apple IR Receiver found at " + path +
                  " but access is denied for user " + str(os.getuid()) +
                  ". Check: ls -l " + path + " ; getfacl " + path,
                  file=sys.stderr)
            continue
        except OSError as exc:
            print("Cannot open " + path + ": " + str(exc), file=sys.stderr)
            continue
        if (dev.info.vendor == APPLE_VENDOR and
                dev.info.product == APPLE_IR_PRODUCT):
            return dev
        # Some kernel HID input layers expose a different evdev product ID,
        # while the readable sysfs name remains the observed Apple receiver.
        if "Apple" in dev.name and "IR Receiver" in dev.name:
            print("Receiver matched by name; evdev ID " +
                  f"{dev.info.vendor:04x}:{dev.info.product:04x}",
                  file=sys.stderr)
            return dev
        dev.close()
    if not candidates:
        print("Apple IR Receiver absent from /sys/class/input; check lsusb "
              "and /proc/bus/input/devices.", file=sys.stderr)
    return None


def run_utility(args):
    if shutil.which(args[0]):
        try:
            subprocess.Popen(args, stdin=subprocess.DEVNULL,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
            return True
        except OSError:
            pass
    return False


class Lounge:
    def __init__(self, no_grab=False):
        self.root = tk.Tk()
        self.root.withdraw()
        self.root.title("PearMac Remote")
        self.root.protocol("WM_DELETE_WINDOW", self.quit)
        self.root.bind_all("<Escape>", lambda _event: self.hide())
        self.device = None
        self.grabbed = False
        self.no_grab = no_grab
        self.window = None
        self.tiles = []
        self.selected = 0
        self.status = None
        self.connect()
        self.root.after(35, self.poll)

    def connect(self):
        self.device = find_receiver()
        if not self.device:
            print("Apple IR Receiver not ready; retrying.", file=sys.stderr)
            return
        try:
            # Exclusive input avoids Trinity also treating Up/Down as volume.
            # Do not grab if the user requested diagnostic mode.
            if not self.no_grab:
                self.device.grab()
                self.grabbed = True
            print("Apple Remote connected:", self.device.path, "grab:", self.grabbed,
                  flush=True)
        except PermissionError:
            print("Receiver readable, but exclusive grab denied; using shared events.",
                  file=sys.stderr)
        except OSError as exc:
            print("Input grab unavailable:", exc, file=sys.stderr)

    def poll(self):
        if self.device is None:
            try:
                self.connect()
            except OSError:
                self.device = None
            self.root.after(1200, self.poll)
            return
        try:
            for event in self.device.read():
                if event.type != ecodes.EV_KEY or event.value != 1:
                    continue
                action = BUTTONS.get(event.code)
                if action:
                    self.on_remote(action)
        except BlockingIOError:
            pass
        except OSError as exc:
            print("Remote disconnected:", exc, file=sys.stderr)
            self.disconnect()
        self.root.after(35, self.poll)

    def on_remote(self, action):
        if action == "MENU":
            if self.visible():
                self.hide()
            else:
                self.show()
            return
        if self.visible():
            if action == "SELECT":
                self.open_selected()
            elif action == "UP":
                self.select((self.selected - COLS) % len(ENTRIES))
            elif action == "DOWN":
                self.select((self.selected + COLS) % len(ENTRIES))
            elif action == "LEFT":
                self.select(self.selected - 1 if self.selected % COLS else self.selected)
            elif action == "RIGHT":
                self.select(self.selected + 1 if self.selected % COLS == 0 else self.selected)
            return
        # While outside the lounge the remote controls common media actions.
        # Play/Pause tries MPRIS first, then the focused X11 application.
        if action == "UP":
            if not run_utility(["pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%"]):
                run_utility(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"])
        elif action == "DOWN":
            if not run_utility(["pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%"]):
                run_utility(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"])
        elif action in ("LEFT", "RIGHT"):
            run_utility(["xdotool", "key", "--clearmodifiers",
                         "Left" if action == "LEFT" else "Right"])
        elif action == "SELECT":
            result = subprocess.run(["playerctl", "play-pause"], capture_output=True) if shutil.which("playerctl") else None
            if result is None or result.returncode != 0:
                run_utility(["xdotool", "key", "--clearmodifiers", "space"])

    def visible(self):
        return self.window is not None and self.window.winfo_viewable()

    def show(self):
        if self.window is not None:
            self.window.deiconify()
            self.window.lift()
            self.window.focus_force()
            self.select(self.selected)
            return
        self.window = tk.Toplevel(self.root, bg="#101827")
        self.window.title("PearMac · Front Row")
        self.window.attributes("-fullscreen", True)
        self.window.bind("<Escape>", lambda _event: self.hide())
        self.window.bind("<Up>", lambda _event: self.on_remote("UP"))
        self.window.bind("<Down>", lambda _event: self.on_remote("DOWN"))
        self.window.bind("<Left>", lambda _event: self.on_remote("LEFT"))
        self.window.bind("<Right>", lambda _event: self.on_remote("RIGHT"))
        self.window.bind("<Return>", lambda _event: self.on_remote("SELECT"))
        tk.Label(self.window, text="PearMac", fg="#eaf3ff", bg="#101827",
                 font=("DejaVu Sans", 37, "bold")).pack(pady=(42, 4))
        tk.Label(self.window, text="FRONT ROW  ·  APPLE REMOTE",
                 fg="#94b8d4", bg="#101827",
                 font=("DejaVu Sans", 13)).pack(pady=(0, 35))
        grid = tk.Frame(self.window, bg="#101827")
        grid.pack(expand=True, fill="both", padx=75, pady=10)
        self.tiles = []
        for index, (name, subtitle, _) in enumerate(ENTRIES):
            frame = tk.Frame(grid, bg="#26354a", highlightthickness=3,
                             highlightbackground="#26354a")
            frame.grid(row=index // COLS, column=index % COLS,
                       sticky="nsew", padx=12, pady=12)
            tk.Label(frame, text=name, fg="white", bg="#26354a",
                     font=("DejaVu Sans", 24, "bold")).pack(expand=True, pady=(16, 0))
            tk.Label(frame, text=subtitle, fg="#c3d5e6", bg="#26354a",
                     font=("DejaVu Sans", 11), wraplength=420).pack(expand=True, pady=(0, 14))
            frame.bind("<Button-1>", lambda _e, i=index: self.click(i))
            for child in frame.winfo_children():
                child.bind("<Button-1>", lambda _e, i=index: self.click(i))
            self.tiles.append(frame)
        for col in range(COLS):
            grid.columnconfigure(col, weight=1)
        for row in range((len(ENTRIES) + COLS - 1) // COLS):
            grid.rowconfigure(row, weight=1)
        self.status = tk.Label(self.window,
                               text="MENU: close   ·   PLAY: select   ·   arrows: navigate",
                               fg="#a7b4c7", bg="#101827",
                               font=("DejaVu Sans", 12))
        self.status.pack(pady=(8, 25))
        self.window.focus_force()
        self.select(self.selected)

    def click(self, index):
        self.select(index)
        self.open_selected()

    def select(self, index):
        self.selected = index % len(ENTRIES)
        for i, tile in enumerate(self.tiles):
            selected = i == self.selected
            color = "#355f85" if selected else "#26354a"
            tile.configure(bg=color,
                           highlightbackground="#f3c96d" if selected else color)
            for child in tile.winfo_children():
                child.configure(bg=color)

    def hide(self):
        if self.window is not None:
            self.window.withdraw()

    def open_selected(self):
        target = ENTRIES[self.selected][2]
        if target == "close":
            self.hide()
            return
        commands = {
            "youtube": ["librewolf", "--new-window", "https://m.youtube.com/"],
            "twitch": ["librewolf", "--new-window", "https://www.twitch.tv/"],
            "music": ["strawberry"],
            "retroarch": ["retroarch"],
            "videos": ["xdg-open", str(Path.home() / "Videos")],
        }
        cmd = commands[target]
        if not shutil.which(cmd[0]):
            self.status.configure(text=f"{cmd[0]} is not installed or not in PATH")
            return
        self.hide()
        if not run_utility(cmd):
            self.show()
            self.status.configure(text=f"Could not launch {cmd[0]}")

    def disconnect(self):
        if self.device:
            if self.grabbed:
                try:
                    self.device.ungrab()
                except OSError:
                    pass
            self.device.close()
        self.device = None
        self.grabbed = False

    def quit(self):
        self.disconnect()
        self.root.destroy()

    def start(self):
        self.root.mainloop()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="PearMac Apple Remote lounge")
    parser.add_argument("--no-grab", action="store_true",
                        help="Do not exclusively capture IR keys (diagnostics)")
    args = parser.parse_args()
    if os.geteuid() == 0:
        sys.exit("Run as your normal Trinity desktop user, NOT with sudo.")
    Lounge(no_grab=args.no_grab).start()
