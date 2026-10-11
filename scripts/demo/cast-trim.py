#!/usr/bin/env python3
"""Tidy an asciinema v2 recording of the Warble Linux demo.

- squeezes everything before the first "login:" (bootloader + kernel/systemd
  boot log) into BOOT_SECS seconds, so the boot is shown but doesn't drag;
- caps any remaining idle gap at IDLE_SECS;
- removes OSC escape sequences (e.g. systemd's OSC 3008 session context,
  which carries machine/boot ids) — invisible in a terminal anyway.

usage: cast-trim.py in.cast out.cast [--boot-secs 7] [--idle-secs 2]
"""
import argparse
import json
import re

OSC = re.compile(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--boot-secs", type=float, default=7.0)
    ap.add_argument("--idle-secs", type=float, default=2.0)
    a = ap.parse_args()

    with open(a.src, encoding="utf-8") as f:
        header = json.loads(f.readline())
        events = [json.loads(line) for line in f if line.strip()]
    if header.get("version") != 2:
        raise SystemExit("expected an asciicast v2 file")

    # Join output so OSC sequences split across events are removed whole.
    out, pending = [], None
    for t, kind, data in events:
        if kind != "o":
            continue
        if pending:
            data, t = pending[1] + data, pending[0]
            pending = None
        cut = data.rfind("\x1b]")
        if cut != -1 and not OSC.match(data, cut):
            pending, data = (t, data[cut:]), data[:cut]
        data = OSC.sub("", data)
        if data:
            out.append([t, data])
    if pending:
        out.append([pending[0], OSC.sub("", pending[1])])

    # Find the login prompt (may be split across events).
    t_login, tail = None, ""
    for t, data in out:
        tail = (tail + data)[-64:]
        if "login:" in tail:
            t_login = t
            break

    res, prev_src, prev_dst = [], 0.0, 0.0
    for t, data in out:
        if t_login is not None and t <= t_login and t_login > 0:
            nt = t * a.boot_secs / t_login
        else:
            gap = min(t - prev_src, a.idle_secs)
            nt = prev_dst + max(gap, 0.0)
        prev_src, prev_dst = t, nt
        res.append([round(nt, 6), "o", data])

    header.pop("idle_time_limit", None)
    with open(a.dst, "w", encoding="utf-8") as f:
        f.write(json.dumps(header) + "\n")
        for e in res:
            f.write(json.dumps(e, ensure_ascii=False) + "\n")
    dur = res[-1][0] if res else 0
    print(f"cast-trim: {len(events)} -> {len(res)} events, {dur:.1f}s"
          f" (boot squeezed from {t_login or 0:.1f}s to {a.boot_secs if t_login else 0:.1f}s)")


if __name__ == "__main__":
    main()
