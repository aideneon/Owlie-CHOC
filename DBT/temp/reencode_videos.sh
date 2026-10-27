#!/bin/bash
# One-off: re-encode oversized exercise videos to a sane bitrate.
# Encodes into temp/videos_reencoded/ (preserving structure). Does NOT touch
# the originals -- the swap is a separate, verified step.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

SRC_ROOT="assets/videos"
OUT_ROOT="temp/videos_reencoded"
THRESHOLD=4000000   # only re-encode clips above ~4 Mbps

mkdir -p "$OUT_ROOT"

failed=0
skipped=0
encoded=0

while IFS= read -r src; do
  rel="${src#"$SRC_ROOT"/}"
  bitrate=$(ffprobe -v error -show_entries format=bit_rate -of csv=p=0 "$src" 2>/dev/null </dev/null)
  [ -z "$bitrate" ] && bitrate=0

  if [ "$bitrate" -le "$THRESHOLD" ]; then
    printf 'SKIP  %5.1f Mbps  %s\n' "$(echo "$bitrate/1000000" | bc -l)" "$rel"
    skipped=$((skipped + 1))
    continue
  fi

  out="$OUT_ROOT/$rel"
  mkdir -p "$(dirname "$out")"

  # Resume: keep an existing output if it already looks complete.
  if [ -f "$out" ] && [ "$(du -k "$out" | cut -f1)" -gt 100 ]; then
    printf 'HAVE  %5sMB  %s\n' "$(du -m "$out" | cut -f1)" "$rel"
    encoded=$((encoded + 1))
    continue
  fi

  # Preserve resolution and frame rate; cap bitrate and fix audio overhead.
  if ffmpeg -nostdin -v error -y -i "$src" \
      -c:v libx264 -profile:v main -level 4.0 \
      -crf 25 -preset veryfast -maxrate 1800k -bufsize 3600k \
      -c:a aac -b:a 128k \
      -movflags +faststart \
      -max_muxing_queue_size 1024 \
      "$out"; then
    before=$(du -m "$src" | cut -f1)
    after=$(du -m "$out" | cut -f1)
    printf 'OK    %5sMB -> %5sMB  %s\n' "$before" "$after" "$rel"
    encoded=$((encoded + 1))
  else
    printf 'FAIL  %s\n' "$rel"
    rm -f "$out"
    failed=$((failed + 1))
  fi
done < <(find "$SRC_ROOT" -name '*.mp4' | sort)

echo
echo "encoded=$encoded skipped=$skipped failed=$failed"
[ "$failed" -eq 0 ] || exit 1
