#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "${GODOT_BIN:-}" ]]; then
  godot_bin="$GODOT_BIN"
elif [[ -x /workspace/.daemonism-env/bin/Godot_v4.7.2-stable_linux.x86_64 ]]; then
  godot_bin=/workspace/.daemonism-env/bin/Godot_v4.7.2-stable_linux.x86_64
else
  godot_bin=godot
fi
if [[ "$("$godot_bin" --version 2>/dev/null)" != 4.7.2.* ]]; then
  echo 'Godot 4.7.2 is required. Set GODOT_BIN to its executable.' >&2
  exit 1
fi
run_dir=$(mktemp -d)
trap 'rm -rf "$run_dir"' EXIT
export XDG_DATA_HOME="$run_dir/data"
export XDG_CONFIG_HOME="$run_dir/config"
export XDG_CACHE_HOME="$run_dir/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
run_check() {
  local result=0
  timeout 60 "$godot_bin" --headless --path . "$@" > "$run_dir/current.log" 2>&1 || result=$?
  cat "$run_dir/current.log"
  if (( result != 0 )); then return "$result"; fi
  # Godot can return 0 on script parse/resource errors, so inspect diagnostics too.
  if rg -q 'SCRIPT ERROR:|^ERROR:' "$run_dir/current.log"; then return 1; fi
}
run_check --editor --import
run_check --quit-after 30
for suite in combat_director combat_movement combat_patterns combat_integration; do
  run_check --script "res://tests/${suite}_test.gd"
  if ! rg -q "PASS: .*checks" "$run_dir/current.log"; then
    echo "Missing completion marker for $suite" >&2
    exit 1
  fi
done
# Two processes ensure persistence is tested beyond the current WorldState instance.
run_check --script res://tests/save_roundtrip_test.gd -- --save
run_check --script res://tests/save_roundtrip_test.gd -- --load
