#!/bin/bash
# iOS video_player cannot open assets whose path contains whitespace
# (flutter/flutter#51031 -- initialize() hangs forever). Rename every video
# folder/file to space-free names.
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
V="assets/videos"

mvq() {
  if [ -e "$1" ]; then
    mv "$1" "$2"
    echo "  $1  ->  $2"
  else
    echo "  MISSING: $1"
  fi
}

echo "folders:"
mvq "$V/1-3 Aaron-Kevin James Bond - new an improved videos" "$V/level_1_3"
mvq "$V/4-6 Johnny Boy - new improved videos"                "$V/level_4_6"
mvq "$V/7-8 Nischella"                                       "$V/level_7_8"
mvq "$V/9-10 Hope - new improved videos"                     "$V/level_9_10"

echo "level_1_3:"
mvq "$V/level_1_3/label what you notice.mp4"   "$V/level_1_3/label_what_you_notice.mp4"
mvq "$V/level_1_3/get in the zone.mp4"         "$V/level_1_3/get_in_the_zone.mp4"
mvq "$V/level_1_3/do something fun.mp4"        "$V/level_1_3/do_something_fun.mp4"
mvq "$V/level_1_3/take care of your body.mp4"  "$V/level_1_3/take_care_of_your_body.mp4"

echo "level_4_6:"
mvq "$V/level_4_6/check your thougts.mp4"       "$V/level_4_6/check_your_thoughts.mp4"
mvq "$V/level_4_6/let your emtions flow.mp4"    "$V/level_4_6/let_your_emotions_flow.mp4"
mvq "$V/level_4_6/Compare your options.mp4"     "$V/level_4_6/compare_your_options.mp4"
mvq "$V/level_4_6/try problem solving.mp4"      "$V/level_4_6/try_problem_solving.mp4"
mvq "$V/level_4_6/recognize your feelings.mp4"  "$V/level_4_6/recognize_your_feelings.mp4"
mvq "$V/level_4_6/others point of view.mp4"     "$V/level_4_6/others_point_of_view.mp4"

echo "level_9_10:"
mvq "$V/level_9_10/Hope_coldShock with graphics.mp4"   "$V/level_9_10/cold_shock.mp4"
mvq "$V/level_9_10/burst of excersies.mp4"             "$V/level_9_10/burst_of_exercise.mp4"
mvq "$V/level_9_10/Counting Breaths.mp4"               "$V/level_9_10/counting_breaths.mp4"
mvq "$V/level_9_10/Hope - Squeeze and Release.mp4"     "$V/level_9_10/tense_and_release.mp4"

echo "root (unused duplicate, renamed so nothing in assets/videos has spaces):"
mvq "$V/Ambient with open wings.mp4" "$V/ambient_open_wings_duplicate.mp4"

echo
echo "remaining paths containing a space (should be none):"
find "$V" -name '* *' -print || true
echo "done"
