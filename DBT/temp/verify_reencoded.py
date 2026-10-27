#!/usr/bin/env python3
"""Verify re-encoded clips match their originals before swapping them in."""
import json
import struct
import subprocess
import sys
from pathlib import Path

SRC_ROOT = Path("assets/videos")
OUT_ROOT = Path("temp/videos_reencoded")


def probe(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=width,height,codec_name",
         "-show_entries", "format=duration,bit_rate",
         "-of", "json", str(path)],
        capture_output=True, text=True, stdin=subprocess.DEVNULL, check=True,
    )
    data = json.loads(out.stdout)
    stream = data["streams"][0]
    fmt = data["format"]
    return {
        "w": stream["width"],
        "h": stream["height"],
        "codec": stream["codec_name"],
        "dur": float(fmt["duration"]),
        "bitrate": int(fmt["bit_rate"]),
    }


def atom_order(path, limit=10):
    order = []
    with open(path, "rb") as fh:
        off = 0
        while len(order) < limit:
            fh.seek(off)
            hdr = fh.read(8)
            if len(hdr) < 8:
                break
            size = struct.unpack(">I", hdr[:4])[0]
            typ = hdr[4:8].decode("latin-1")
            if size == 1:
                size = struct.unpack(">Q", fh.read(8))[0]
            elif size == 0:
                order.append(typ)
                break
            order.append(typ)
            off += size
    return order


def is_faststart(path):
    order = atom_order(path)
    return "moov" in order and "mdat" in order and order.index("moov") < order.index("mdat")


def main():
    problems = []
    rows = []
    for out in sorted(OUT_ROOT.rglob("*.mp4")):
        rel = out.relative_to(OUT_ROOT)
        src = SRC_ROOT / rel
        if not src.exists():
            problems.append(f"{rel}: no matching original")
            continue

        s, o = probe(src), probe(out)
        issues = []
        if (s["w"], s["h"]) != (o["w"], o["h"]):
            issues.append("resolution changed")
        if abs(s["dur"] - o["dur"]) > 0.5:
            issues.append(f"duration drift {s['dur']:.1f}->{o['dur']:.1f}")
        if not is_faststart(out):
            issues.append("not faststart")
        if o["bitrate"] > 2_600_000:
            issues.append(f"bitrate still high ({o['bitrate']/1e6:.1f} Mbps)")

        if issues:
            problems.append(f"{rel}: {', '.join(issues)}")

        rows.append((
            "FAIL" if issues else "ok",
            f"{s['bitrate']/1e6:.1f}->{o['bitrate']/1e6:.1f} Mbps",
            f"{src.stat().st_size/1e6:.0f}->{out.stat().st_size/1e6:.0f} MB",
            f"{o['w']}x{o['h']}",
            f"{o['dur']:.1f}s",
            str(rel),
        ))

    width = max(len(r[1]) for r in rows)
    for status, br, size, res, dur, rel in rows:
        print(f"{status:<5} {br:<{width}} {size:>12}  {res:>9} {dur:>7}  {rel}")

    print()
    if problems:
        print(f"PROBLEMS ({len(problems)}):")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(f"All {len(rows)} clips verified: resolution and duration preserved, faststart intact.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
