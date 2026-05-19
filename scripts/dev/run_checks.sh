#!/usr/bin/env bash
set -euo pipefail

if command -v godot4 >/dev/null 2>&1; then
  GODOT_BIN="godot4"
elif command -v godot >/dev/null 2>&1; then
  GODOT_BIN="godot"
else
  echo "Godot binary not found (godot4/godot)." >&2
  exit 127
fi

"$GODOT_BIN" --headless --path . --quit
"$GODOT_BIN" --headless --path . --script res://tests/smoke_test.gd
