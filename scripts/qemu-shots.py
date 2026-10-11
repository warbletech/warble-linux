#!/usr/bin/env python3
"""Boot a Warble Linux ISO in a disposable QEMU VM and capture what users see.

  scripts/qemu-shots.py <iso> <out_dir> [--uefi] [--timeout 600]

1. Waits for the serial login prompt, logs in as root (the live ISO has an empty
   root password) and saves the MOTD/welcome text (motd-serial.txt, ANSI kept),
   plus a terminal-style rendering (motd-terminal.png).
2. Dismisses the one-time welcome dialogs on tty1 (QEMU `sendkey`) and takes a
   `screendump` of the console (console-tty1.png): the MOTD on tty1.
3. If the edition has a desktop (startx + openbox), starts X on vt7 and takes
   desktop screenshots: desktop-wallpaper.png (WARBLE_NO_BROWSER=1, so the
   wallpaper is visible) and desktop-firefox.png (after launching Firefox, as
   autostart normally does).
The VM runs with -snapshot and is killed afterwards. PPM screendumps become PNG
when Pillow is installed (otherwise .ppm is kept).
"""
import os, re, socket, subprocess, sys, tempfile, threading, time

def die(msg):
    print(f"[shots] FAIL: {msg}", file=sys.stderr); sys.exit(1)

class Serial:
    def __init__(self, path):
        self.s = connect(path); self.buf = b""; self.lock = threading.Lock()
        threading.Thread(target=self._rx, daemon=True).start()
    def _rx(self):
        while True:
            try:
                d = self.s.recv(4096)
            except OSError:
                return
            if not d:
                return
            with self.lock:
                self.buf += d
    def text(self):
        with self.lock:
            return self.buf.decode("utf-8", "replace")
    def mark(self):
        with self.lock:
            return len(self.buf)
    def since(self, m):
        with self.lock:
            return self.buf[m:].decode("utf-8", "replace")
    def send(self, s):
        self.s.sendall(s.encode())
    def wait(self, pattern, timeout, start=0):
        end = time.time() + timeout
        while time.time() < end:
            if re.search(pattern, self.since(start)):
                return True
            time.sleep(0.5)
        return False

def connect(path, tries=60):
    for _ in range(tries):
        try:
            s = socket.socket(socket.AF_UNIX); s.connect(path); return s
        except OSError:
            time.sleep(0.5)
    die(f"cannot connect to {path}")

class Monitor:
    def __init__(self, path):
        self.s = connect(path); self.s.settimeout(5); self._drain()
    def _drain(self):
        out = b""
        try:
            while True:
                d = self.s.recv(65536)
                if not d: break
                out += d
                if out.endswith(b"(qemu) "): break
        except socket.timeout:
            pass
        return out.decode("utf-8", "replace")
    def cmd(self, c):
        self.s.sendall((c + "\n").encode()); time.sleep(0.3); return self._drain()

def to_png(ppm, png):
    try:
        from PIL import Image
        Image.open(ppm).save(png); os.remove(ppm); return png
    except Exception as e:  # keep the PPM if Pillow is missing
        print(f"[shots] keeping PPM ({e})"); return ppm

ANSI = re.compile(r"\x1b\[([0-9;]*)m")
OSC = re.compile(r"\x1b\].*?(?:\x07|\x1b\\)", re.S)
COLORS = {"30": (40, 40, 52), "31": (248, 113, 113), "32": (52, 211, 153), "33": (251, 191, 36),
          "34": (96, 165, 250), "35": (167, 139, 250), "36": (79, 195, 247), "37": (232, 232, 240)}

def render_terminal(text, png):
    """Render ANSI-coloured text into a terminal-style PNG (fallback for screendump)."""
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("[shots] Pillow missing: no motd-terminal.png"); return
    font = None
    for f in ("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", "/usr/share/fonts/TTF/DejaVuSansMono.ttf"):
        if os.path.exists(f):
            font = ImageFont.truetype(f, 18); bold = ImageFont.truetype(f.replace("Mono.ttf", "Mono-Bold.ttf"), 18); break
    if font is None:
        font = bold = ImageFont.load_default()
    text = OSC.sub("", text)  # e.g. systemd's OSC 3008 context markers
    lines = [re.sub(r"[\r\x07]|\x1b\[[0-9;?]*[A-HJKSTfhlr]", "", l) for l in text.replace("\r\n", "\n").split("\n")]
    lines = lines[:60]
    cw, lh = 11, 24
    width = max(80, max((len(ANSI.sub("", l)) for l in lines), default=80)) * cw + 60
    img = Image.new("RGB", (width, len(lines) * lh + 90), (13, 13, 22))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, width, 34], fill=(26, 26, 46))
    for i, c in enumerate([(248, 113, 113), (251, 191, 36), (52, 211, 153)]):
        d.ellipse([16 + i * 22, 11, 28 + i * 22, 23], fill=c)
    d.text((100, 8), "root@warble: serial console (ttyS0)", fill=(136, 136, 160), font=font)
    y = 50
    for l in lines:
        x, col, b, dim = 30, (232, 232, 240), False, False
        pos = 0
        for m in list(ANSI.finditer(l)) + [None]:
            seg = l[pos:m.start()] if m else l[pos:]
            if seg:
                c = tuple(int(v * 0.55) for v in col) if dim else col
                d.text((x, y), seg, fill=c, font=bold if b else font); x += cw * len(seg)
            if not m: break
            pos = m.end()
            for code in (m.group(1) or "0").split(";"):
                if code in ("0", ""): col, b, dim = (232, 232, 240), False, False
                elif code == "1": b = True
                elif code == "2": dim = True
                elif code in COLORS: col = COLORS[code]
        y += lh
    img.save(png)

def main():
    a = sys.argv[1:]
    if len(a) < 2: die(__doc__)
    iso, out = a[0], a[1]; uefi = "--uefi" in a
    limit = int(a[a.index("--timeout") + 1]) if "--timeout" in a else 600
    os.makedirs(out, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="warble-shots-")
    ser, mon = os.path.join(tmp, "serial.sock"), os.path.join(tmp, "monitor.sock")
    accel = "kvm" if os.access("/dev/kvm", os.W_OK) else "tcg"
    cmd = ["qemu-system-x86_64", "-accel", accel, "-m", "3072", "-smp", "2", "-vga", "std",
           "-cdrom", iso, "-boot", "d", "-snapshot", "-nic", "user,model=virtio-net-pci",
           "-display", "none", "-serial", f"unix:{ser},server,nowait", "-monitor", f"unix:{mon},server,nowait"]
    if uefi:
        code = next((f for f in ("/usr/share/OVMF/OVMF_CODE_4M.fd", "/usr/share/OVMF/OVMF_CODE.fd") if os.path.exists(f)), None)
        if code: cmd += ["-bios", code]
    print("[shots]", " ".join(cmd))
    q = subprocess.Popen(cmd)
    shots = []
    try:
        s = Serial(ser); m = Monitor(mon)
        if not s.wait(r"login:", limit): die("no serial login prompt")
        time.sleep(3)                               # let tty1 autologin + dialogs settle
        mk = s.mark(); s.send("root\r")
        if not s.wait(r"\]# $|# $", 60, mk): die("no root shell prompt after login")
        motd = s.since(mk)
        open(os.path.join(out, "motd-serial.txt"), "w").write(motd)
        render_terminal(motd, os.path.join(out, "motd-terminal.png")); shots.append("motd-terminal.png")
        print("----- MOTD (serial) -----"); print(ANSI.sub("", OSC.sub("", motd)))

        # tty1: dismiss the 2 welcome dialogs so the MOTD is visible, then dump
        for _ in range(2):
            m.cmd("sendkey ret"); time.sleep(1.5)
        time.sleep(2)
        m.cmd(f"screendump {tmp}/tty1.ppm"); time.sleep(1)
        shots.append(os.path.basename(to_png(f"{tmp}/tty1.ppm", os.path.join(out, "console-tty1.png"))))

        def run(c, wait=30):
            mk2 = s.mark(); s.send(c + "\r"); s.wait(r"# $", wait, mk2); return s.since(mk2)
        has_x = "yes" in run("command -v startx >/dev/null && command -v openbox >/dev/null && echo y''es")
        if has_x:
            # desktop first without the browser, so the wallpaper is visible
            run("(WARBLE_NO_BROWSER=1 startx -- :0 vt7 > /tmp/xorg-start.log 2>&1 &)")
            time.sleep(15)
            m.cmd(f"screendump {tmp}/desk1.ppm"); time.sleep(1)
            shots.append(os.path.basename(to_png(f"{tmp}/desk1.ppm", os.path.join(out, "desktop-wallpaper.png"))))
            print(run("tail -n 5 /tmp/xorg-start.log; pgrep -a openbox | head -2", 15))
            # then what autostart normally adds: Firefox
            run("(DISPLAY=:0 firefox https://duckduckgo.com > /dev/null 2>&1 &)")
            time.sleep(30)
            m.cmd(f"screendump {tmp}/desk2.ppm"); time.sleep(1)
            shots.append(os.path.basename(to_png(f"{tmp}/desk2.ppm", os.path.join(out, "desktop-firefox.png"))))
        open(os.path.join(out, "serial.log"), "w").write(s.text())
    finally:
        q.terminate()
        try: q.wait(10)
        except subprocess.TimeoutExpired: q.kill()
    print("[shots] wrote:", ", ".join(shots))

if __name__ == "__main__":
    main()
