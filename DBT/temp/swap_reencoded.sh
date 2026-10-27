#!/bin/bash
# Swap verified re-encoded clips into assets/videos, preserving the originals
# in temp/videos_original/ (same filesystem, so these are instant moves).
# This project has no git history -- the originals are the only backup.
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

NEW_ROOT="temp/videos_reencoded"
SRC_ROOT="assets/videos"
BAK_ROOT="temp/videos_original"

moved=0
while IFS= read -r new; do
  rel="${new#"$NEW_ROOT"/}"
  src="$SRC_ROOT/$rel"
  bak="$BAK_ROOT/$rel"

  if [ ! -f "$src" ]; then
    echo "SKIP (no original) $rel"
    continue
  fi

  mkdir -p "$(dirname "$bak")"
  mv "$src" "$bak"
  mv "$new" "$src"
  printf 'swapped  %s\n' "$rel"
  moved=$((moved + 1))
done < <(find "$NEW_ROOT" -name '*.mp4' | sort)

echo
echo "swapped=$moved"
echo "originals preserved in $BAK_ROOT"
